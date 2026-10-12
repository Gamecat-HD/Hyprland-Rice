pragma ComponentBehavior: Bound
import QtQuick

import qs
import qs.modules.services.config
import qs.modules.services.system

// Kurze Systemwerte fuer die aufgeklappte Notch (Uebersicht): CPU, RAM,
// CPU- und GPU-Temperatur als gleich breite Chips. Die volle Karte steht im
// System-Untermenue (SUPER+I bzw. blaettern). SystemStats misst nur, solange
// die Uebersicht offen ist (Binding in Bar.qml).
Row {
    id: root

    readonly property real memShare: SystemStats.memTotal > 0 ? SystemStats.memUsed / SystemStats.memTotal : 0

    readonly property var entries: {
        const list = [
            { icon: "developer_board", text: `${Math.round(SystemStats.cpuUsage * 100)} %`, warn: SystemStats.cpuUsage >= 0.9 },
            { icon: "memory", text: `${Math.round(root.memShare * 100)} %`, warn: root.memShare >= 0.9 }
        ];
        if (SystemStats.cpuTemp > 0)
            list.push({ icon: "thermostat", text: SystemStats.formatTemp(SystemStats.cpuTemp), warn: SystemStats.cpuTemp >= 80 });
        if (SystemStats.hasGpu && SystemStats.gpuTemp > 0)
            list.push({ icon: "videogame_asset", text: SystemStats.formatTemp(SystemStats.gpuTemp), warn: SystemStats.gpuTemp >= 85 });
        return list;
    }

    spacing: 6
    height: 30

    Repeater {
        model: root.entries

        Item {
            id: chip

            required property var modelData

            width: (root.width - root.spacing * (root.entries.length - 1)) / root.entries.length
            height: root.height

            Rectangle {
                anchors.fill: parent
                radius: 11
                color: chip.modelData.warn ? Colors.alpha(Colors.error, 0.16)
                                           : Colors.alpha(Colors.fgBackground, 0.05)
            }

            Row {
                anchors.centerIn: parent
                spacing: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: chip.modelData.icon
                    color: chip.modelData.warn ? Colors.error : Colors.primary
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 14
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: chip.modelData.text
                    color: chip.modelData.warn ? Colors.error : Colors.fgBackground
                    font.family: Config.font
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
            }
        }
    }
}
