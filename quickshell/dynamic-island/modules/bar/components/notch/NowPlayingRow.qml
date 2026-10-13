pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects

import qs
import qs.modules.services.config
import qs.modules.services.media
import qs.modules.widgets

// "Jetzt laeuft" in der aufgeklappten Notch (Uebersicht): Cover, Titel und
// Interpret, Visualiser, Play/Pause. Nur da, solange es einen Player gibt –
// alles Weitere (Player-Auswahl, Fortschritt, Vor/Zurueck) steht im
// Medien-Untermenue (SUPER+M bzw. blaettern).
Item {
    id: root

    readonly property real artSize: 36

    // Wisch-Geste der Notch (swipe in Notch.qml): nur der Hintergrund
    // gleitet mit (`shift`), Cover und Text bleiben stehen. `pull` ist der
    // Fortschritt bis zur Schwelle, -1..1 (negativ = nach links = naechster
    // Titel): der Text rueckt beiseite und ein Skip-Symbol blendet dort ein.
    // Welcher Titel kommt, verraet MPRIS nicht – deshalb nur das Symbol.
    property real shift: 0
    property real pull: 0
    readonly property real pullNext: Math.max(0, -pull)
    readonly property real pullPrev: Math.max(0, pull)
    readonly property real skipRoom: 26

    implicitHeight: 52

    Rectangle {
        anchors.fill: parent
        transform: Translate { x: root.shift }
        radius: 16
        color: Colors.alpha(Colors.fgBackground, 0.05)

        // Leicht in Akzentfarbe, je weiter gezogen wird
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Colors.primary
            opacity: 0.1 * Math.abs(root.pull)
        }
    }

    // ---- Skip-Symbole (hinter dem Inhalt) ----
    // Zurueck: zwischen Cover und Text, der Text rueckt nach rechts.
    // Weiter: zwischen Text und Visualiser, der Text rueckt nach links.
    Text {
        anchors {
            left: art.right
            leftMargin: 10 + (root.skipRoom - width) / 2
            verticalCenter: parent.verticalCenter
        }
        text: "skip_previous"
        color: Media.canPrevious ? Colors.primary : Colors.fgSurfaceVariant
        font.family: "Material Symbols Outlined"
        font.pixelSize: 20
        font.variableAxes: ({ FILL: 1, wght: 600 })
        opacity: root.pullPrev
        scale: 0.6 + 0.4 * root.pullPrev
        visible: opacity > 0
    }

    Text {
        anchors {
            right: wave.left
            rightMargin: 12 + (root.skipRoom - width) / 2
            verticalCenter: parent.verticalCenter
        }
        text: "skip_next"
        color: Media.canNext ? Colors.primary : Colors.fgSurfaceVariant
        font.family: "Material Symbols Outlined"
        font.pixelSize: 20
        font.variableAxes: ({ FILL: 1, wght: 600 })
        opacity: root.pullNext
        scale: 0.6 + 0.4 * root.pullNext
        visible: opacity > 0
    }

    // ---- Cover, rund maskiert ----
    Item {
        id: art

        anchors {
            left: parent.left
            leftMargin: 8
            verticalCenter: parent.verticalCenter
        }
        width: root.artSize
        height: root.artSize

        Rectangle {
            anchors.fill: parent
            radius: 10
            color: Colors.surfaceContainer

            Text {
                anchors.centerIn: parent
                visible: artImage.status !== Image.Ready
                text: "music_note"
                color: Colors.fgSurfaceVariant
                font.family: "Material Symbols Outlined"
                font.pixelSize: 16
            }
        }

        Image {
            id: artImage

            anchors.fill: parent
            source: Media.art
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: root.artSize * 2
            sourceSize.height: root.artSize * 2
            visible: false
        }

        Rectangle {
            id: artMask

            anchors.fill: parent
            radius: 10
            color: "black"
            layer.enabled: true
            visible: false
        }

        MultiEffect {
            anchors.fill: parent
            source: artImage
            maskEnabled: true
            maskSource: artMask
            visible: artImage.status === Image.Ready
        }
    }

    // ---- Titel / Interpret ----
    Column {
        anchors {
            left: art.right
            leftMargin: 10 + root.skipRoom * root.pullPrev
            right: wave.left
            rightMargin: 10 + root.skipRoom * root.pullNext
            verticalCenter: parent.verticalCenter
        }
        spacing: 2

        Text {
            width: parent.width
            text: Media.title !== "" ? Media.title : Media.source
            color: Colors.fgBackground
            font.family: Config.font
            font.pixelSize: 12
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: Media.artist !== "" ? Media.artist : Media.source
            color: Colors.fgSurfaceVariant
            font.family: Config.font
            font.pixelSize: 11
            elide: Text.ElideRight
        }
    }

    // ---- Visualiser ----
    Visualizer {
        id: wave

        anchors {
            right: playButton.left
            rightMargin: 12
            verticalCenter: parent.verticalCenter
        }
        height: 22
        count: 7
        barWidth: 3
        active: Media.playing
    }

    // ---- Play/Pause ----
    Item {
        id: playButton

        anchors {
            right: parent.right
            rightMargin: 10
            verticalCenter: parent.verticalCenter
        }
        width: 32
        height: 32
        scale: playHover.hovered ? 1.08 : 1

        Morph on scale {}

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: playHover.hovered ? Colors.alpha(Colors.primary, 0.3) : Colors.alpha(Colors.primary, 0.18)
        }

        Text {
            anchors.centerIn: parent
            text: Media.playing ? "pause" : "play_arrow"
            color: Colors.primary
            font.family: "Material Symbols Outlined"
            font.pixelSize: 18
            font.variableAxes: ({ FILL: 1, wght: 600 })
        }

        HoverHandler {
            id: playHover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: Media.playPause()
        }
    }
}
