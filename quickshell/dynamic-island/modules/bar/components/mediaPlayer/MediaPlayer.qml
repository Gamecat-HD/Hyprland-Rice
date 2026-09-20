pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.modules.services.hypr
import qs.modules.services.media
import qs.modules.services.audio

import "root:/"

// Medien-Pille rechts in der Leiste.
//
// Aufbau, von links nach rechts: Cover, Visualiser (4 Balken), Zeit, zurueck,
// Play/Pause, weiter, Aufklapp-Pfeil – alles auf einer Zeile und vertikal
// mittig.
//
// Alles Inhaltliche kommt aus dem Media-Service (modules/services/media),
// die Pegel aus Cava (modules/services/audio). Diese Datei ist reine Ansicht.
Item {
    id: root
    anchors {
        right: parent.right
        rightMargin: HyprGaps.right
    }

    required property real verticalMargin // margin über bzw unter der notch
    required property real borderWidth   // von außen überschreibbar (Bar.qml macht das)
    required property color borderColor
    required property real cardRadius    // gemeinsamer Wert mit Notch und Selektor

    property real padding: 14

    // Ist das Aufklapp-Menue offen?
    property bool popoutOpen: false

    // Groessen der Einzelteile – hier einmal, damit die Breite unten daraus
    // ausgerechnet werden kann statt doppelt gepflegt zu werden.
    readonly property real artSize: 18
    readonly property real iconSize: 15
    readonly property real barWidth: 2
    readonly property real barSpacing: 2

    height: parent.height - verticalMargin
    y: verticalMargin / 2
    // Breite folgt dem Inhalt: so wandert nichts, wenn sich die Reihe aendert
    width: content.implicitWidth + root.padding * 2

    // Der Visualiser ist ein eigener Prozess – er laeuft nur, solange wirklich
    // etwas spielt. `Binding` statt Zuweisung, damit er beim Zerstoeren dieser
    // Komponente automatisch wieder aus geht.
    Binding {
        target: Cava
        property: "enabled"
        value: Media.playing && root.visible
    }

    // Die abgelaufene Zeit muss gepollt werden (MPRIS schickt sie nicht von
    // selbst). Auch das nur, solange die Pille da ist.
    Binding {
        target: Media
        property: "trackPosition"
        value: root.visible
    }

    Rectangle {
        id: pill
        anchors.fill: parent

        // Wie die Notch: Pille, solange sie flach ist; waechst sie ueber ~2x
        // cardRadius, wird daraus eine Karte. Als Formel statt Zustand, damit
        // die Rundung waehrend einer Animation mitwandert.
        radius: Math.min(height / 2, root.cardRadius)
        border.width: root.borderWidth
        border.color: root.borderColor
        color: Colors.background
        clip: true

        // Solange der Zeiger auf der Pille steht, bleibt das Popout offen
        HoverHandler {
            id: pillHover
        }

        // Nach unten ziehen klappt das Menue auf – dieselbe Geste, mit der die
        // Notch ihren Launcher aufzieht. `target: null`, es wird also nichts
        // verschoben; die Knoepfe behalten ihren Tap, weil ein TapHandler bei
        // Bewegung von selbst abbricht.
        DragHandler {
            id: openDrag

            target: null
            xAxis.enabled: false

            readonly property real threshold: 18

            onActiveChanged: if (!openDrag.active) openDrag.triggered = false

            property bool triggered: false

            onTranslationChanged: {
                if (!openDrag.active || openDrag.triggered)
                    return;
                if (openDrag.activeTranslation.y > openDrag.threshold) {
                    openDrag.triggered = true;
                    root.popoutOpen = true;
                }
            }
        }

        // Mausrad auf der Pille schaltet die Audioquelle durch
        WheelHandler {
            parent: pill
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

            property real acc: 0

            onWheel: event => {
                acc += event.angleDelta.y;
                if (Math.abs(acc) < 120)
                    return;
                Media.cycle(acc > 0 ? -1 : 1);
                acc = 0;
            }
        }

        Item {
            id: content

            anchors {
                fill: parent
                leftMargin: root.padding
                rightMargin: root.padding
            }

            implicitWidth: row.implicitWidth

            // Fuellt die ganze Pille; jedes Element darin zentriert sich
            // ueber `Layout.alignment` selbst.
            RowLayout {
                id: row

                anchors.fill: parent
                spacing: 6

                // ---- Cover ----
                Rectangle {
                    Layout.preferredWidth: root.artSize
                    Layout.preferredHeight: root.artSize
                    Layout.alignment: Qt.AlignVCenter

                    radius: 4
                    color: Colors.surfaceContainer
                    clip: true

                    Image {
                        id: art

                        anchors.fill: parent
                        source: Media.art
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        // Cover sind gross (Spotify liefert 640px) – klein
                        // dekodieren spart Speicher und Skalierarbeit.
                        sourceSize.width: root.artSize * 2
                        sourceSize.height: root.artSize * 2
                        visible: status === Image.Ready
                    }

                    // Platzhalter, solange es kein Cover gibt
                    Text {
                        anchors.centerIn: parent
                        visible: !art.visible

                        text: "music_note"
                        color: Colors.fgSurfaceVariant
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 12
                    }
                }

                // ---- Visualiser ----
                Row {
                    // Die Pille zeigt immer vier Balken, egal wie fein cava laeuft
                    readonly property int shown: 4

                    Layout.preferredWidth: root.barWidth * shown + root.barSpacing * (shown - 1)
                    Layout.preferredHeight: root.artSize
                    Layout.alignment: Qt.AlignVCenter

                    spacing: root.barSpacing

                    Repeater {
                        model: parent.shown

                        delegate: Rectangle {
                            id: bar

                            required property int index

                            // 2px Sockel, damit die Balken bei Stille nicht
                            // ganz verschwinden
                            readonly property real level: Cava.bucket(bar.index, 4)

                            width: root.barWidth
                            height: Math.max(2, bar.level * root.artSize)
                            y: root.artSize - height     // von unten wachsen
                            radius: root.barWidth / 2
                            color: Colors.primary
                            opacity: Media.playing ? 1 : 0.35

                            Behavior on height {
                                NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                            }
                            Behavior on opacity {
                                NumberAnimation { duration: 200 }
                            }
                        }
                    }
                }

                // ---- Zeit ----
                Text {
                    Layout.alignment: Qt.AlignVCenter
                    visible: Media.timeLabel !== ""

                    text: Media.timeLabel
                    color: Colors.fgSurfaceVariant
                    font.pixelSize: 9
                    font.weight: Font.Medium
                }

                // ---- Transport ----
                MediaButton {
                    icon: "skip_previous"
                    size: root.iconSize
                    active: Media.canPrevious
                    onTriggered: Media.previous()
                }

                MediaButton {
                    icon: Media.playing ? "pause" : "play_arrow"
                    size: root.iconSize + 3
                    active: Media.canToggle
                    onTriggered: Media.playPause()
                }

                MediaButton {
                    icon: "skip_next"
                    size: root.iconSize
                    active: Media.canNext
                    onTriggered: Media.next()
                }

                // ---- Aufklapp-Pfeil ----
                MediaButton {
                    // Zu = nach unten (dahin klappt es auf), offen = nach oben
                    icon: root.popoutOpen ? "keyboard_arrow_up" : "keyboard_arrow_down"
                    size: root.iconSize
                    active: true
                    onTriggered: root.popoutOpen = !root.popoutOpen
                }
            }

        }
    }

    // Das Popout existiert nur, solange es offen ist – zu gibt es weder
    // Fenster noch Bindings darin.
    Loader {
        id: popoutLoader

        active: root.popoutOpen

        sourceComponent: MediaPopout {
            anchorItem: root
            anchorHovered: pillHover.hovered
            visible: true

            onCloseRequested: root.popoutOpen = false
        }
    }
}
