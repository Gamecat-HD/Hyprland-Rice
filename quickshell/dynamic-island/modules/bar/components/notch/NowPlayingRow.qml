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
//
// Wisch-Geste der Notch (swipe in Notch.qml): die Karte folgt dem Zeiger
// (`shift`), daneben haengt eine Dummy-Karte fuer den naechsten bzw. vorigen
// Titel, die mit hereingezogen wird. `pull` ist der Fortschritt bis zur
// Schwelle, -1..1 (negativ = nach links = naechster Titel). Welcher Titel
// kommt, verraet MPRIS nicht – die Dummy-Karte zeigt nur Richtung und
// denselben Cover-Blend. Beim Wechsel faehrt sie ganz herein, dann springt
// alles auf 0 zurueck und die echte Karte zeigt den neuen Titel.
Item {
    id: root

    readonly property real artSize: 36

    property real shift: 0
    property real pull: 0
    // Kartenfarbe, in die der Cover-Hintergrund nach rechts ausblendet
    property color fadeColor: Appearance.notchColor
    // Abstand zur Dummy-Karte; so weit muss `shift` beim Wechsel laufen
    readonly property real gap: 16
    readonly property real flipDistance: root.width + root.gap
    // Dummy-Karte rechts (naechster) oder links (voriger)
    readonly property real ghostSide: root.pull < 0 ? 1 : -1
    readonly property bool ghostCan: root.pull < 0 ? Media.canNext : Media.canPrevious

    implicitHeight: 52

    // ---- Hintergrund: Karte mit verwaschenem Cover ----
    // Das Cover, stark verwaschen ueber die ganze Zeile gezogen und nach
    // rechts in die Kartenfarbe ausgeblendet – so bleibt der Text lesbar.
    // Winzige Decodegroesse: der Weichzeichner macht ohnehin alles glatt.
    component CardBackground: Rectangle {
        id: bg

        property real strength: 0.45

        radius: 16
        color: Colors.alpha(Colors.fgBackground, 0.05)

        Item {
            anchors.fill: parent
            visible: blendSource.status === Image.Ready

            Image {
                id: blendSource

                anchors.fill: parent
                source: Media.art
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 48
                sourceSize.height: 48
                visible: false
            }

            Rectangle {
                id: blendMask

                anchors.fill: parent
                radius: bg.radius
                color: "black"
                layer.enabled: true
                visible: false
            }

            MultiEffect {
                anchors.fill: parent
                source: blendSource
                blurEnabled: true
                blur: 1
                blurMax: 32
                maskEnabled: true
                maskSource: blendMask
                opacity: bg.strength
            }

            Rectangle {
                anchors.fill: parent
                radius: bg.radius
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Colors.alpha(root.fadeColor, 0.15) }
                    GradientStop { position: 0.55; color: Colors.alpha(root.fadeColor, 0.6) }
                    GradientStop { position: 1.0; color: Colors.alpha(root.fadeColor, 0.85) }
                }
            }
        }
    }

    // ---- Dummy-Karte: naechster / voriger Titel ----
    // Haengt neben der echten Karte und faehrt mit `shift` herein. Solange
    // nichts gezogen wird, liegt sie ausserhalb der Notch-Karte (die clippt).
    Item {
        id: ghost

        x: root.ghostSide * root.flipDistance
        width: root.width
        height: root.height
        transform: Translate { x: root.shift }
        visible: root.pull !== 0
        opacity: 0.45 + 0.55 * Math.abs(root.pull)

        CardBackground {
            anchors.fill: parent
            strength: 0.4
        }

        // Beschriftung an der Kante, die zuerst hereinkommt – so ist sie
        // schon beim Anziehen zu sehen, nicht erst wenn die Karte halb steht
        Row {
            anchors {
                left: root.ghostSide > 0 ? parent.left : undefined
                right: root.ghostSide < 0 ? parent.right : undefined
                margins: 18
                verticalCenter: parent.verticalCenter
            }
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.pull < 0 ? "skip_next" : "skip_previous"
                color: root.ghostCan ? Colors.primary : Colors.fgSurfaceVariant
                font.family: "Material Symbols Outlined"
                font.pixelSize: 20
                font.variableAxes: ({ FILL: 1, wght: 600 })
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.ghostCan ? (root.pull < 0 ? "Nächster Titel" : "Voriger Titel")
                                    : (root.pull < 0 ? "Kein nächster Titel" : "Kein voriger Titel")
                color: root.ghostCan ? Colors.fgBackground : Colors.fgSurfaceVariant
                font.family: Config.font
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }
        }
    }

    // ---- Echte Karte ----
    Item {
        id: card

        anchors.fill: parent
        transform: Translate { x: root.shift }

        CardBackground {
            anchors.fill: parent
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
                leftMargin: 10
                right: wave.left
                rightMargin: 10
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
}
