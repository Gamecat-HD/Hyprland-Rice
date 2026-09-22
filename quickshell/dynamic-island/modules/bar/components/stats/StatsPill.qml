pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.modules.services.system

import qs
import qs.modules.services.config

// System-Pille rechts neben dem Workspace-Selektor.
//
//   Grundzustand   Akkustand (Systemakku, sonst der schwaechste Geraete-Akku)
//   Hover          die Pille waechst nach RECHTS und zeigt die Energieprofile
//   Klick          die Karte waechst nach UNTEN mit Auslastung und Temperaturen
//                  und bleibt stehen, bis man wieder klickt
//
// Die Kreis-zu-Pille-Mechanik ist von der Tray-Pille uebernommen, nur
// spiegelverkehrt: der Inhalt haengt links fest, damit alles nach rechts
// waechst. Das Rasten per Klick ist das Toggle aus der Benachrichtigungs-Pille,
// hier aber ohne Hover-Nachlauf – die Karte soll ja stehenbleiben.
Item {
    id: root

    required property real verticalMargin
    required property real borderWidth
    required property color borderColor
    required property real cardRadius

    readonly property real collapsedSize: parent.height - verticalMargin
    readonly property real padding: 7
    readonly property real cardWidth: 340

    property bool open: false
    property bool profilesOpen: false

    // Breite im Grundzustand: der Kopf, mindestens aber ein Kreis
    readonly property real headWidth: Math.max(root.collapsedSize, head.implicitWidth + root.padding * 2)
    readonly property real profilesWidth: root.headWidth + profiles.implicitWidth + 6

    // Hoehe der Karte: Kopfband + Inhalt
    readonly property real cardHeight: root.collapsedSize + card.implicitHeight + 10
    // Reserve fuer das Bar-Fenster – immer der groesste Fall
    readonly property real maxDrop: Math.max(0, root.verticalMargin / 2 + root.cardHeight - parent.height)

    // Der Dienst misst nur, solange die Karte offen ist
    Binding {
        target: SystemStats
        property: "watching"
        value: root.open
    }

    y: root.verticalMargin / 2
    width: root.open ? Math.max(root.cardWidth, root.headWidth)
         : root.profilesOpen ? root.profilesWidth
         : root.headWidth
    height: root.open ? root.cardHeight : root.collapsedSize

    Behavior on width {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }
    Behavior on height {
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }

    // Profile erst nach kurzem Verweilen – sonst zuckt die Pille bei jedem
    // Vorbeifahren
    Timer {
        id: profileTimer

        interval: 200
        onTriggered: root.profilesOpen = true
    }

    Timer {
        id: closeProfiles

        interval: 260
        onTriggered: root.profilesOpen = false
    }

    Rectangle {
        id: pill

        anchors.fill: parent

        radius: Math.min(height / 2, root.cardRadius)
        color: Colors.background
        border.width: root.borderWidth
        border.color: root.borderColor
        clip: true

        HoverHandler {
            id: hover

            onHoveredChanged: {
                if (hovered) {
                    closeProfiles.stop();
                    if (!root.profilesOpen)
                        profileTimer.restart();
                } else {
                    profileTimer.stop();
                    closeProfiles.restart();
                }
            }
        }

        // ---- Kopf: Akkustand (oder nur das Symbol) ----
        Row {
            id: head

            anchors {
                left: parent.left
                leftMargin: root.padding
                top: parent.top
            }
            height: root.collapsedSize
            spacing: 4

            Text {
                anchors.verticalCenter: parent.verticalCenter

                text: Power.hasBattery && !Power.hasSystemBattery ? Power.deviceIcon(Power.shown)
                    : Power.hasBattery ? Power.batteryIcon
                    : "monitoring"
                color: Power.hasBattery && Power.percent <= 20 && !Power.charging ? Colors.error
                     : root.open ? Colors.primary : Colors.fgSurfaceVariant
                font.family: "Material Symbols Outlined"
                font.pixelSize: 16

                Behavior on color {
                    ColorAnimation { duration: 140 }
                }
            }

            Text {
                font.family: Config.font
                anchors.verticalCenter: parent.verticalCenter
                visible: Power.hasBattery

                text: `${Power.percent} %`
                color: Colors.fgBackground
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
        }

        // Klick auf den Kopf rastet die Karte auf und wieder zu
        TapHandler {
            onTapped: root.open = !root.open
        }

        // ---- Energieprofile, rechts neben dem Kopf ----
        Row {
            id: profiles

            anchors {
                left: parent.left
                leftMargin: root.headWidth
                top: parent.top
            }
            height: root.collapsedSize
            spacing: 2
            opacity: root.profilesOpen && !root.open ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
            }

            Repeater {
                model: Power.profiles

                Rectangle {
                    id: chip

                    required property var modelData

                    readonly property bool current: Power.profile === chip.modelData.value

                    anchors.verticalCenter: parent.verticalCenter
                    width: 24
                    height: 24
                    radius: height / 2
                    color: chip.current ? Colors.alpha(Colors.primary, 0.22)
                         : chipArea.containsMouse ? Colors.alpha(Colors.fgSurface, 0.12)
                         : "transparent"

                    Behavior on color {
                        ColorAnimation { duration: 120 }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: chip.modelData.icon
                        // Gedrosselte Leistung faellt genau hier auf
                        color: chip.current ? (Power.degraded && chip.modelData.value === 2 ? Colors.error
                                                                                           : Colors.primary)
                                            : Colors.fgSurfaceVariant
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 14
                    }

                    MouseArea {
                        id: chipArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Power.setProfile(chip.modelData.value)
                    }
                }
            }
        }

        // ---- Karte: Auslastung und Temperaturen ----
        Column {
            id: card

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                topMargin: root.collapsedSize
                leftMargin: 14
                rightMargin: 14
            }
            spacing: 2
            opacity: root.open ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }

            Text {
                font.family: Config.font
                width: parent.width
                text: SystemStats.cpuName !== "" ? SystemStats.cpuName : "System"
                color: Colors.fgSurfaceVariant
                font.pixelSize: 10
                font.weight: Font.Medium
                elide: Text.ElideRight
                bottomPadding: 4
            }

            StatRow {
                width: parent.width
                icon: "developer_board"
                label: "CPU"
                value: SystemStats.cpuUsage
                warn: SystemStats.cpuTemp >= 80 || SystemStats.cpuUsage >= 0.9
                detail: `${Math.round(SystemStats.cpuUsage * 100)} %` +
                        (SystemStats.cpuTemp > 0 ? ` · ${SystemStats.formatTemp(SystemStats.cpuTemp)}` : "")
            }

            StatRow {
                width: parent.width
                visible: SystemStats.hasGpu
                icon: "monitoring"
                label: "GPU"
                value: SystemStats.gpuUsage
                warn: SystemStats.gpuTemp >= 85 || SystemStats.gpuUsage >= 0.9
                detail: `${Math.round(SystemStats.gpuUsage * 100)} %` +
                        (SystemStats.gpuTemp > 0 ? ` · ${SystemStats.formatTemp(SystemStats.gpuTemp)}` : "")
            }

            StatRow {
                width: parent.width
                visible: SystemStats.vramTotal > 0
                icon: "memory"
                label: "VRAM"
                value: SystemStats.vramTotal > 0 ? SystemStats.vramUsed / SystemStats.vramTotal : 0
                detail: `${SystemStats.formatBytes(SystemStats.vramUsed)} / ${SystemStats.formatBytes(SystemStats.vramTotal)}`
            }

            StatRow {
                width: parent.width
                icon: "memory"
                label: "RAM"
                value: SystemStats.memTotal > 0 ? SystemStats.memUsed / SystemStats.memTotal : 0
                warn: SystemStats.memTotal > 0 && SystemStats.memUsed / SystemStats.memTotal >= 0.9
                detail: `${SystemStats.formatBytes(SystemStats.memUsed)} / ${SystemStats.formatBytes(SystemStats.memTotal)}`
            }

            StatRow {
                width: parent.width
                visible: SystemStats.diskTotal > 0
                icon: "hard_drive"
                label: "Platte"
                value: SystemStats.diskTotal > 0 ? SystemStats.diskUsed / SystemStats.diskTotal : 0
                detail: `${SystemStats.formatBytes(SystemStats.diskFree)} frei`
            }

            // Was sonst noch Temperatur hat, in einer Zeile
            Text {
                font.family: Config.font
                width: parent.width
                topPadding: 4
                visible: text !== ""
                text: {
                    const parts = [];
                    for (const t of SystemStats.nvmeTemps)
                        parts.push(`SSD ${Math.round(t)} °C`);
                    if (SystemStats.waterTemp > 0)
                        parts.push(`Wasser ${Math.round(SystemStats.waterTemp)} °C`);
                    return parts.join("  ·  ");
                }
                color: Colors.fgSurfaceVariant
                font.pixelSize: 10
                elide: Text.ElideRight
            }

            // Geraete-Akkus: am Desktop steht der erste schon in der Pille,
            // hier stehen sie mit Namen
            Text {
                font.family: Config.font
                width: parent.width
                visible: text !== ""
                text: {
                    const parts = [];
                    for (const d of Power.deviceBatteries)
                        parts.push(`${Power.deviceName(d)} ${Math.round(d.percentage * 100)} %`);
                    return parts.join("  ·  ");
                }
                color: Colors.fgSurfaceVariant
                font.pixelSize: 10
                elide: Text.ElideRight
            }

            Text {
                font.family: Config.font
                width: parent.width
                topPadding: 2
                visible: Power.degraded
                text: `Leistung gedrosselt: ${Power.degradedReason}`
                color: Colors.error
                font.pixelSize: 10
                elide: Text.ElideRight
            }
        }
    }
}
