pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import qs.modules.services.config

Singleton {
    id: root

    readonly property string provider: Config.vpn.provider === "cloudflare" ? "cloudflare" : "nordvpn"
    readonly property string providerName: provider === "cloudflare" ? "Cloudflare WARP" : "NordVPN"
    readonly property bool connected: statusProc.status === "Connected"
    readonly property string statusText: connected ? "Verbunden"
                                                : statusProc.status === "Disconnected" ? "Getrennt"
                                                : "Nicht bereit"
    property bool nordConnected: false
    property bool warpConnected: false
    property bool nordStatusReady: false
    property bool warpStatusReady: false

    function commandFor(vpnProvider: string, action: string): list<string> {
        return vpnProvider === "cloudflare" ? ["warp-cli", action] : ["nordvpn", action];
    }

    function selectProvider(vpnProvider: string): void {
        if (vpnProvider === root.provider)
            return;

        // Den alten Tunnel nicht unbemerkt weiterlaufen lassen.
        if (root.connected)
            Quickshell.execDetached(root.commandFor(root.provider, "disconnect"));

        Config.set("vpn", "provider", vpnProvider);
    }

    function applyDetectedProvider(): void {
        if (!nordStatusReady || !warpStatusReady)
            return;

        if (warpConnected && !nordConnected && root.provider !== "cloudflare")
            Config.set("vpn", "provider", "cloudflare");
        else if (nordConnected && !warpConnected && root.provider !== "nordvpn")
            Config.set("vpn", "provider", "nordvpn");
    }

    function detectProviders(): void {
        root.nordStatusReady = false;
        root.warpStatusReady = false;
        nordStatusProc.running = true;
        warpStatusProc.running = true;
    }

    function toggle(): void {
        if (connected) {
            console.log("VPN (" + providerName + "): disconnecting...");
            statusProc.status = "Disconnected";
            disconnectProc.command = root.commandFor(root.provider, "disconnect");
            disconnectProc.running = true;
        } else {
            console.log("VPN (" + providerName + "): connecting...");
            statusProc.status = "Connected";
            connectProc.command = root.commandFor(root.provider, "connect");
            connectProc.running = true;
        }

        refreshTimer.restart();
    }

    Process {
        id: connectProc
    }

    Process {
        id: disconnectProc
    }

    Process {
        id: statusProc
        command: root.commandFor(root.provider, "status")
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
                Quickshell.execDetached(["notify-send", "-a", "dynamic-island", root.providerName,
                                         now ? "Verbunden" : "Getrennt"]);
            }
            _prevStatus = status;
        }

        stdout: StdioCollector {
            id: collector
            onStreamFinished: {
                const match = collector.text.match(/Status(?: update)?:\s*(Connected|Disconnected)/i);
                if (!match)
                    statusProc.status = "Unknown";
                else
                    statusProc.status = match[1].toLowerCase() === "connected" ? "Connected" : "Disconnected";
            }
        }
    }

    Process {
        id: nordStatusProc
        command: ["nordvpn", "status"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                root.nordConnected = /Status:\s*Connected/i.test(this.text);
                root.nordStatusReady = true;
                root.applyDetectedProvider();
            }
        }
    }

    Process {
        id: warpStatusProc
        command: ["warp-cli", "status"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                root.warpConnected = /Status update:\s*Connected/i.test(this.text);
                root.warpStatusReady = true;
                root.applyDetectedProvider();
            }
        }
    }

    onProviderChanged: {
        statusProc.status = "Unknown";
        statusProc._prevStatus = "";
        providerRefresh.restart();
    }

    Timer {
        id: providerRefresh
        interval: 100
        onTriggered: statusProc.running = true
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
        onTriggered: {
            statusProc.running = true;
            root.detectProviders();
        }
    }
}
