pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs.modules.services.media
import qs.modules.services.audio

import qs
import qs.modules.services.config

// Ausklapp-Inhalt der Medien-Pille – kein eigenes Fenster, sondern ein Teil
// der Karte selbst (dasselbe Prinzip wie DatePanel in der Notch). Dadurch
// waechst die Pille nach unten, statt dass darunter ein zweites Fenster
// aufpoppt: eine Flaeche, keine Naht.
//
// Von oben nach unten: Quellenwahl (eigene, abgesetzte Karte), grosses Cover
// mit Visualiser-Ring, Titel, Fortschritt mit den beiden Zeiten, Transport.
Item {
    id: panel

    // Oberkante innerhalb der Karte (= Unterkante der Icon-Reihe)
    property real topOffset: 0
    // Grundfarbe der Karte – die Flaechen hier drin setzen sich davon ab,
    // statt feste Theme-Toene zu nehmen. Sonst beisst sich das Blau des
    // Themes mit einer vom Cover eingefaerbten Karte.
    property color tint: Colors.background
    property real padding: 14

    // Cover samt Ring fuellen die Karte bis auf den Rand. Die Rechnung laeuft
    // von aussen nach innen: das Aussenmass steht fest (Kartenbreite minus
    // Rand), davon gehen Balkenlaenge und Luft ab, der Rest ist das Bild.
    readonly property real ringMax: 16      // maximale Balkenlaenge
    readonly property real ringGap: 8       // Luft zwischen Bild und Balken
    readonly property real ringInset: 10    // Luft zwischen Ring und Kartenrand
    readonly property real ringBox: panel.width - panel.padding * 2 - panel.ringInset * 2
    // Obergrenze fuer das Cover – das Medien-Untermenue der Notch ist breit,
    // dort sollen nur die Zeilen die Breite nutzen, nicht das Bild
    property real maxCoverSize: Infinity
    readonly property real coverSize: Math.min(panel.maxCoverSize,
        Math.max(48, panel.ringBox - (panel.ringGap + panel.ringMax) * 2))
    readonly property int coverDecode: Number.isFinite(panel.maxCoverSize) ? panel.maxCoverSize * 2 : 380
    // Innenkante des Rings – die Balken wachsen von hier nach aussen
    readonly property real ringRadius: panel.coverSize / 2 + panel.ringGap

    // Platz, den die Karte fuer das Panel bereithalten muss
    readonly property real outerHeight: panel.implicitHeight

    anchors {
        left: parent.left
        right: parent.right
    }
    y: panel.topOffset
    implicitHeight: layout.implicitHeight + panel.padding

    ColumnLayout {
        id: layout

        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            leftMargin: panel.padding
            rightMargin: panel.padding
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
            color: Colors.shade(panel.tint, 0.05)
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
                    color: sourceHover.hovered ? Colors.shade(panel.tint, 0.11) : "transparent"

                    Behavior on color {
                        ColorAnimation { duration: 140 }
                    }

                    Text {
                        font.family: Config.font
                        anchors {
                            left: parent.left
                            leftMargin: 8
                            verticalCenter: parent.verticalCenter
                        }
                        width: parent.width - 32

                        text: Media.source || "Keine Quelle"
                        color: Colors.fgBackground
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
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
                        color: entryHover.hovered ? Colors.shade(panel.tint, 0.11) : "transparent"

                        Text {
                            font.family: Config.font
                            anchors {
                                left: parent.left
                                leftMargin: 8
                                verticalCenter: parent.verticalCenter
                            }
                            width: parent.width - 30

                            text: Media.identityOf(entry.modelData)
                            color: entry.current ? Colors.primary : Colors.fgSurfaceVariant
                            font.pixelSize: 10
                            font.weight: Font.Medium
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

        // ---- Cover mit Ring ----
        Item {
            Layout.preferredWidth: (panel.ringRadius + panel.ringMax) * 2
            Layout.preferredHeight: (panel.ringRadius + panel.ringMax) * 2
            Layout.alignment: Qt.AlignHCenter

            // Der Ring: ein Balken je cava-Band, im Kreis angeordnet.
            // Jeder sitzt auf seinem Winkel und waechst nach aussen,
            // deshalb liegt der Mittelpunkt bei Radius + halbe Laenge.
            Repeater {
                model: Cava.bars

                delegate: Rectangle {
                    id: spike

                    required property int index

                    readonly property real angle: (spike.index / Cava.bars) * 2 * Math.PI
                    // Versteckt (Pille im Notch-Layout, zugeklapptes
                    // Untermenue) liegt der Ring still, statt fuer niemanden
                    // 30x pro Sekunde zu rechnen
                    readonly property real len: 3 + (panel.visible ? Cava.values[spike.index] ?? 0 : 0) * panel.ringMax
                    readonly property real dist: panel.ringRadius + len / 2

                    width: 2.5
                    height: spike.len
                    radius: width / 2
                    color: Colors.primary
                    opacity: Media.playing ? 1 : 0.3

                    x: parent.width / 2 + Math.sin(spike.angle) * spike.dist - width / 2
                    y: parent.height / 2 - Math.cos(spike.angle) * spike.dist - height / 2
                    rotation: (spike.index / Cava.bars) * 360

                    // Kein Behavior auf height: die Spitzen folgen cava
                    // direkt (siehe widgets/Visualizer.qml – sonst zeichnet
                    // die Leiste dauerhaft mit Monitorrate)
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

                width: panel.coverSize
                height: panel.coverSize
                radius: width / 2
                color: Colors.shade(panel.tint, 0.08)

                Image {
                    id: cover

                    anchors.fill: parent
                    source: Media.art
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    // Feste Decodiergroesse: haengt sie an coverSize (= an der
                    // Kartenbreite), decodiert jede Morph-Animation das Cover
                    // pro Frame neu
                    sourceSize.width: panel.coverDecode
                    sourceSize.height: panel.coverDecode
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

        // ---- Titel ----
        Text {
            font.family: Config.font
            Layout.fillWidth: true

            text: Media.title || "Nichts"
            color: Colors.fgBackground
            font.pixelSize: 12
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }

        Text {
            font.family: Config.font
            Layout.fillWidth: true
            Layout.topMargin: -8
            visible: text !== ""

            text: Media.artist
            color: Colors.fgSurfaceVariant
            font.pixelSize: 10
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }

        // ---- Fortschritt ----
        // Abgelaufene Zeit links, Gesamtlaenge rechts, der Slider dazwischen.
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                font.family: Config.font
                text: Media.formatTime(Media.position)
                color: Colors.fgSurfaceVariant
                font.pixelSize: 9
                font.weight: Font.Medium
            }

            Rectangle {
                id: track

                Layout.fillWidth: true
                Layout.preferredHeight: 4
                Layout.alignment: Qt.AlignVCenter

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

            Text {
                font.family: Config.font
                text: Media.hasLength ? Media.formatTime(Media.length) : "--:--"
                color: Colors.fgSurfaceVariant
                font.pixelSize: 9
                font.weight: Font.Medium
            }
        }


        // ---- Transport ----
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 14

            MediaButton {
                icon: "skip_previous"
                outlined: true
                size: 20
                active: Media.canPrevious
                onTriggered: Media.previous()
            }

            MediaButton {
                icon: Media.playing ? "pause" : "play_arrow"
                outlined: true
                size: 26
                active: Media.canToggle
                onTriggered: Media.playPause()
            }

            MediaButton {
                icon: "skip_next"
                outlined: true
                size: 20
                active: Media.canNext
                onTriggered: Media.next()
            }
        }

    }
}
