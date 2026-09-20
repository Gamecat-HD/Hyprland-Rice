pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import qs.modules.services.media
import qs.modules.services.audio

import "root:/"

// Aufklapp-Menue der Medien-Pille.
//
// Von oben nach unten: Quellenwahl (eigene, abgesetzte Karte), grosses Cover
// mit Visualiser-Ring samt Titelzeile, Transport, Fortschrittsbalken.
//
// Eigenes Fenster statt Aufklappen der Pille: die Leiste behaelt so ihre
// Hoehe, und das Popout kann breiter werden als die Pille selbst.
PopupWindow {
    id: popout

    required property Item anchorItem
    // Die Pille meldet, ob der Zeiger noch auf ihr steht – zusammen mit dem
    // Hover hier entscheidet das ueber das Zuklappen.
    property bool anchorHovered: false

    signal closeRequested

    readonly property real padding: 14
    readonly property real coverSize: 52
    // Innenkante des Rings – die Balken wachsen von hier nach aussen
    readonly property real ringRadius: popout.coverSize / 2 + 5
    readonly property real ringMax: 11

    anchor {
        item: popout.anchorItem
        edges: Edges.Bottom
        gravity: Edges.Bottom
        margins.top: 6
    }

    implicitWidth: 250
    implicitHeight: card.implicitHeight
    color: "transparent"

    // Zuklappen, wenn der Zeiger weder auf der Pille noch hier drin ist. Ein
    // Klick daneben wuerde einen Focus-Grab brauchen; der Nachlauf-Timer ist
    // fuer ein Menue in der Leiste verlaesslicher (dasselbe tut die Notch).
    Timer {
        id: closeTimer

        interval: 600
        onTriggered: if (!hover.hovered && !popout.anchorHovered) popout.closeRequested()
    }

    // Schonfrist direkt nach dem Aufklappen: wird per Ziehen geoeffnet, liegt
    // der Zeiger noch im Griff des DragHandlers – es kommt also kein
    // Hover-Enter und das Menue wuerde sofort wieder zugehen.
    Timer {
        id: grace

        interval: 1200
        running: true
        onTriggered: if (!hover.hovered && !popout.anchorHovered) closeTimer.restart()
    }

    HoverHandler {
        id: hover

        onHoveredChanged: {
            if (hovered)
                closeTimer.stop();
            else if (!grace.running)
                closeTimer.restart();
        }
    }

    onAnchorHoveredChanged: {
        if (!popout.anchorHovered && !hover.hovered && !grace.running)
            closeTimer.restart();
    }

    Rectangle {
        id: card

        anchors.fill: parent

        radius: 16
        color: Colors.background
        border.width: 1
        border.color: Colors.outlineVariant

        implicitHeight: layout.implicitHeight + popout.padding * 2

        ColumnLayout {
            id: layout

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: popout.padding
            }
            spacing: 12

            // ---- Quellenwahl ----
            // Eigene Karte mit abgesetztem Grund und Rand: das ist der einzige
            // Teil, der den Zustand des Players aendert, statt ihn nur
            // anzuzeigen – das darf man sehen.
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: sources.implicitHeight + 8

                radius: 10
                color: Colors.surface
                border.width: 1
                border.color: Colors.alpha(Colors.outline, 0.4)

                ColumnLayout {
                    id: sources

                    property bool open: false

                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: 4
                    }
                    spacing: 0

                    // Kopfzeile: zeigt die aktuelle Quelle, klappt die Liste auf
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 24

                        radius: 8
                        color: sourceHover.hovered ? Colors.surfaceContainer : "transparent"

                        Behavior on color {
                            ColorAnimation { duration: 140 }
                        }

                        Text {
                            anchors {
                                left: parent.left
                                leftMargin: 8
                                verticalCenter: parent.verticalCenter
                            }
                            width: parent.width - 32

                            text: Media.source || "Keine Quelle"
                            color: Colors.fgBackground
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }

                        Text {
                            anchors {
                                right: parent.right
                                rightMargin: 8
                                verticalCenter: parent.verticalCenter
                            }

                            text: sources.open ? "keyboard_arrow_up" : "keyboard_arrow_down"
                            color: Colors.fgSurfaceVariant
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 14
                        }

                        HoverHandler {
                            id: sourceHover

                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            onTapped: sources.open = !sources.open
                        }
                    }

                    // Die Liste. Sie zaehlt in die implicitHeight, dadurch
                    // waechst die Karte beim Aufklappen von selbst mit.
                    Repeater {
                        model: sources.open ? Media.players : null

                        delegate: Rectangle {
                            id: entry

                            required property var modelData
                            readonly property bool current: Media.active === entry.modelData

                            Layout.fillWidth: true
                            Layout.preferredHeight: 22

                            radius: 8
                            color: entryHover.hovered ? Colors.surfaceContainer : "transparent"

                            Text {
                                anchors {
                                    left: parent.left
                                    leftMargin: 8
                                    verticalCenter: parent.verticalCenter
                                }
                                width: parent.width - 30

                                text: Media.identityOf(entry.modelData)
                                color: entry.current ? Colors.primary : Colors.fgSurfaceVariant
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }

                            // Punkt = spielt gerade
                            Rectangle {
                                anchors {
                                    right: parent.right
                                    rightMargin: 10
                                    verticalCenter: parent.verticalCenter
                                }
                                visible: entry.modelData.isPlaying

                                width: 5
                                height: 5
                                radius: 2.5
                                color: Colors.primary
                            }

                            HoverHandler {
                                id: entryHover

                                cursorShape: Qt.PointingHandCursor
                            }

                            TapHandler {
                                onTapped: {
                                    Media.select(entry.modelData);
                                    sources.open = false;
                                }
                            }
                        }
                    }
                }
            }

            // ---- Cover mit Ring + Titel ----
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Item {
                    Layout.preferredWidth: (popout.ringRadius + popout.ringMax) * 2
                    Layout.preferredHeight: (popout.ringRadius + popout.ringMax) * 2
                    Layout.alignment: Qt.AlignVCenter

                    // Der Ring: ein Balken je cava-Band, im Kreis angeordnet.
                    // Jeder sitzt auf seinem Winkel und waechst nach aussen,
                    // deshalb liegt der Mittelpunkt bei Radius + halbe Laenge.
                    Repeater {
                        model: Cava.bars

                        delegate: Rectangle {
                            id: spike

                            required property int index

                            readonly property real angle: (spike.index / Cava.bars) * 2 * Math.PI
                            readonly property real len: 3 + (Cava.values[spike.index] ?? 0) * popout.ringMax
                            readonly property real dist: popout.ringRadius + len / 2

                            width: 2.5
                            height: spike.len
                            radius: width / 2
                            color: Colors.primary
                            opacity: Media.playing ? 1 : 0.3

                            x: parent.width / 2 + Math.sin(spike.angle) * spike.dist - width / 2
                            y: parent.height / 2 - Math.cos(spike.angle) * spike.dist - height / 2
                            rotation: (spike.index / Cava.bars) * 360

                            Behavior on height {
                                NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                            }
                            Behavior on opacity {
                                NumberAnimation { duration: 200 }
                            }
                        }
                    }

                    // ---- Cover ----
                    // Rund, passend zum Ring. `clip: true` reicht dafuer nicht –
                    // das schneidet nur am Rechteck. Deshalb eine Kreis-Maske.
                    Rectangle {
                        anchors.centerIn: parent

                        width: popout.coverSize
                        height: popout.coverSize
                        radius: width / 2
                        color: Colors.surfaceContainer

                        Image {
                            id: cover

                            anchors.fill: parent
                            source: Media.art
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: popout.coverSize * 2
                            sourceSize.height: popout.coverSize * 2
                            // Wird nur als Quelle fuer den Effekt gebraucht
                            visible: false
                        }

                        Item {
                            id: coverMask

                            anchors.fill: parent
                            layer.enabled: true
                            visible: false

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: "black"
                            }
                        }

                        MultiEffect {
                            anchors.fill: parent
                            visible: cover.status === Image.Ready

                            source: cover
                            maskEnabled: true
                            maskSource: coverMask
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: cover.status !== Image.Ready

                            text: "music_note"
                            color: Colors.fgSurfaceVariant
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 22
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2

                    Text {
                        Layout.fillWidth: true

                        text: Media.title || "Nichts"
                        color: Colors.fgBackground
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: text !== ""

                        text: Media.artist
                        color: Colors.fgSurfaceVariant
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: text !== ""

                        text: Media.timeLabel
                        color: Colors.fgSurfaceVariant
                        font.pixelSize: 9
                        elide: Text.ElideRight
                    }
                }
            }

            // ---- Transport ----
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 14

                MediaButton {
                    icon: "skip_previous"
                    size: 20
                    active: Media.canPrevious
                    onTriggered: Media.previous()
                }

                MediaButton {
                    icon: Media.playing ? "pause" : "play_arrow"
                    size: 26
                    active: Media.canToggle
                    onTriggered: Media.playPause()
                }

                MediaButton {
                    icon: "skip_next"
                    size: 20
                    active: Media.canNext
                    onTriggered: Media.next()
                }
            }

            // ---- Fortschritt ----
            // Hier ist Platz genug fuer einen richtigen Balken – in der Pille
            // war er nur im Weg. Klick und Ziehen springen an die Stelle.
            Rectangle {
                id: track

                Layout.fillWidth: true
                Layout.preferredHeight: 4

                radius: height / 2
                color: Colors.alpha(Colors.outline, 0.5)
                // Ohne bekannte Laenge gibt es nichts anzuzeigen
                opacity: Media.hasLength ? 1 : 0.4

                Rectangle {
                    anchors {
                        left: parent.left
                        top: parent.top
                        bottom: parent.bottom
                    }
                    width: parent.width * Media.progress

                    radius: parent.radius
                    color: Colors.primary
                }

                // Trefferflaeche hoeher als der Balken – 4px trifft niemand
                Item {
                    id: hit

                    anchors.centerIn: parent
                    width: parent.width
                    height: 16

                    TapHandler {
                        enabled: Media.canSeek && Media.hasLength
                        onTapped: point => Media.seek(point.position.x / hit.width)
                    }

                    DragHandler {
                        id: scrub

                        enabled: Media.canSeek && Media.hasLength
                        target: null
                        yAxis.enabled: false

                        onCentroidChanged: if (scrub.active) Media.seek(scrub.centroid.position.x / hit.width)
                    }

                    HoverHandler {
                        cursorShape: Media.hasLength ? Qt.PointingHandCursor : Qt.ArrowCursor
                    }
                }
            }
        }
    }
}
