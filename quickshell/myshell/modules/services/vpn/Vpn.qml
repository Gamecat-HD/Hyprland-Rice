pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property bool connected: statusProc.status === "Connected"

    function toggle(): void {
        if (connected) {
            console.log("VPN: disconnecting...");
            disconnectProc.running = true;
        } else {
            console.log("VPN: connecting...");
            connectProc.running = true;
        }

        refreshTimer.restart();
    }

    Process {
        id: connectProc
        command: ["nordvpn", "connect"]
    }

    Process {
        id: disconnectProc
        command: ["nordvpn", "disconnect"]
    }

    Process {
        id: statusProc
        command: ["nordvpn", "status"]
        running: true

        property string status: ""
        property string _prevStatus: ""   // "" = noch nie gelesen -> keine Boot-Notification

        // Notification nur bei echten Übergängen zwischen bekannten Zuständen
        onStatusChanged: {
            const known = s => s === "Connected" || s === "Disconnected";
            const was = _prevStatus === "Connected";
            const now = status === "Connected";

            if (_prevStatus !== "" && known(_prevStatus) && known(status) && was !== now) {
                console.log("VPN status changed:", now ? "connected" : "disconnected");
                Quickshell.execDetached(["notify-send", "-a", "myshell", "NordVPN",
                                         now ? "Verbunden" : "Getrennt"]);
            }
            _prevStatus = status;
        }

        stdout: StdioCollector {
            id: collector
            onStreamFinished: {
                const line = collector.text.split("\n").find(l => l.startsWith("Status:"));
                statusProc.status = line ? line.replace("Status: ", "").trim() : "unknown";
            }
        }
    }

    // Einmal-Timer: nach connect/disconnect den Status neu lesen
    Timer {
        id: refreshTimer
        interval: 5000
        onTriggered: statusProc.running = true
    }

    // Regelmäßiges Polling, falls sich außerhalb der Shell was ändert
    Timer {
        interval: 15000
        running: true
        repeat: true
        onTriggered: statusProc.running = true
    }
}
