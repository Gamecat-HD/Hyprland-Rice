pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

import "root:/"

Item {
    id: wrapper
    anchors.fill: parent   // füllt den Kreis aus Settings – sonst hängt alles an (0,0)

    // Zustände
    property bool wifiEnabled: true   // false = WLAN-Funk aus (nmcli radio)
    property bool connected: false
    property int quality: 0

    Text {
        id: signalStrength
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: -0.5   // optisches Feintuning (Glyph-Margins)
        //anchors.verticalCenterOffset: -0.25

        color: !wrapper.wifiEnabled ? Colors.error : Colors.secondary
        text: !wrapper.wifiEnabled ? "wifi_off"
            : !wrapper.connected ? "wifi_off"
            : wrapper.quality >= 80 ? "network_wifi"
            : wrapper.quality >= 60 ? "network_wifi_3_bar"
            : wrapper.quality >= 40 ? "network_wifi_2_bar"
            : wrapper.quality >= 20 ? "network_wifi_1_bar"
            : "signal_wifi_0_bar"
        font.family: "Material Symbols Outlined"
        font.pointSize: 12
    }

    Process {
        id: wifiProcess
        // Erst prüfen, ob die WLAN-Funk an ist (LC_ALL=C wg. "enabled"/"deaktiviert"),
        // dann entweder die Netzliste oder das WIFI_OFF-Sentinel ausgeben.
        command: ["sh", "-c",
            "if LC_ALL=C nmcli -t radio wifi | grep -q enabled; then " +
            "nmcli -t -f IN-USE,SIGNAL dev wifi list --rescan no; " +
            "else echo WIFI_OFF; fi"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                wrapper.connected = false;

                if (this.text.trim() === "WIFI_OFF") {
                    wrapper.wifiEnabled = false;
                    wrapper.quality = 0;
                    return;
                }
                wrapper.wifiEnabled = true;

                for (const line of this.text.split("\n")) {
                    if (line.startsWith("*")) {
                        wrapper.connected = true;
                        wrapper.quality = parseInt(line.split(":")[1]) || 0;
                        break;
                    }
                }
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: wifiProcess.running = true
    }
}
