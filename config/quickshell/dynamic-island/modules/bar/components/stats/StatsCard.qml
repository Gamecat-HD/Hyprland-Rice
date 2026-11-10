pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.services.system

import qs
import qs.modules.services.config

// Inhalt der System-Karte: CPU-Name, Auslastung von CPU/GPU/VRAM/RAM/Platte,
// weitere Temperaturen, Geraete-Akkus. Genutzt von der System-Pille
// (Insel-Layout) und vom System-Untermenue der Notch (SystemPanel).
//
// Misst nur, solange SystemStats.watching an ist – das schaltet Bar.qml
// zentral (ein Binding fuer alle Verbraucher).
Column {
    id: card

    spacing: 2

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
        label: I18n.tr("Platte")
        value: SystemStats.diskTotal > 0 ? SystemStats.diskUsed / SystemStats.diskTotal : 0
        detail: I18n.tr("%1 frei").arg(SystemStats.formatBytes(SystemStats.diskFree))
    }

    // Weitere Temperaturen: Symbol wie die Zeilen oben, dann Name + Wert.
    // Mehrere SSDs werden durchnummeriert, sonst stuende zweimal "SSD" da.
    Item {
        width: parent.width
        height: 26
        visible: temps.count > 0

        Text {
            id: tempIcon

            anchors.verticalCenter: parent.verticalCenter
            text: "thermostat"
            color: Colors.fgSurfaceVariant
            font.family: "Material Symbols Outlined"
            font.pixelSize: 16
        }

        Row {
            anchors {
                left: tempIcon.right
                leftMargin: 8
                verticalCenter: parent.verticalCenter
            }
            spacing: 14

            Repeater {
                id: temps

                model: {
                    const out = [];
                    const ssd = SystemStats.nvmeTemps;
                    for (let i = 0; i < ssd.length; i++)
                        out.push({ name: ssd.length > 1 ? `SSD ${i + 1}` : "SSD", value: ssd[i] });
                    if (SystemStats.waterTemp > 0)
                        out.push({ name: I18n.tr("Wasser"), value: SystemStats.waterTemp });
                    return out;
                }

                Row {
                    id: temp

                    required property var modelData

                    spacing: 5

                    Text {
                        text: temp.modelData.name
                        color: Colors.fgBackground
                        font.family: Config.font
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: `${Math.round(temp.modelData.value)} °C`
                        color: Colors.fgSurfaceVariant
                        font.family: Config.font
                        font.pixelSize: 11
                    }
                }
            }
        }
    }

    // Geraete-Akkus als Zeilen wie oben: Name, Balken, Prozent
    Repeater {
        model: Power.deviceBatteries

        StatRow {
            id: battery

            required property var modelData
            readonly property int percent: Math.round((battery.modelData?.percentage ?? 0) * 100)
            readonly property bool charging: Power.isCharging(battery.modelData)

            width: card.width
            icon: Power.deviceIcon(battery.modelData)
            // Hersteller vorn weglassen – die Zeile hat nur Platz fuers Modell
            label: Power.deviceName(battery.modelData).replace(/^(Logitech|SteelSeries|Razer|Corsair)\s+/i, "")
            labelWidth: 110
            value: battery.percent / 100
            warn: !battery.charging && battery.percent <= 20
            detail: battery.charging ? I18n.tr("%1 % · lädt").arg(battery.percent) : `${battery.percent} %`
        }
    }

    Text {
        font.family: Config.font
        width: parent.width
        topPadding: 2
        visible: Power.degraded
        text: I18n.tr("Leistung gedrosselt: %1").arg(Power.degradedReason)
        color: Colors.error
        font.pixelSize: 10
        elide: Text.ElideRight
    }
}
