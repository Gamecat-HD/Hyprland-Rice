pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Bluetooth as QB
import Quickshell.Io

import qs

Singleton {
    id: root

    readonly property var adapter: QB.Bluetooth.defaultAdapter
    readonly property bool enabled: adapter?.enabled ?? false
    readonly property bool discovering: adapter?.discovering ?? false
    readonly property bool discoverable: adapter?.discoverable ?? false
    readonly property var devices: {
        const values = adapter?.devices?.values ?? [];
        return values.filter(device => device.paired || root.discovering)
            .slice()
            .sort((a, b) => (root.isRareDevice(a) ? 1 : 0) - (root.isRareDevice(b) ? 1 : 0)
                || (b.connected ? 1 : 0) - (a.connected ? 1 : 0)
                || (b.paired ? 1 : 0) - (a.paired ? 1 : 0)
                || root.deviceName(a).localeCompare(root.deviceName(b)));
    }

    property var pairingDevice: null
    property string pairingRequest: ""
    property string pairingPasskey: ""
    property string pairingMessage: ""
    property bool agentReady: false
    readonly property bool pairingInputRequired: pairingRequest === "pin" || pairingRequest === "passkey"
    readonly property bool pairingActive: pairingDevice !== null
    property int pairingEntered: 0
    property bool pairingLocallyStarted: false

    function deviceName(device: var): string {
        return device?.name || device?.deviceName || device?.address || I18n.tr("Unbekanntes Gerät");
    }

    function isRareDevice(device: var): bool {
        if (!device || device.connected || device.paired || device.bonded || device.trusted || device.pairing)
            return false;

        const name = String(device.name || device.deviceName || "").trim();
        if (name === "")
            return true;

        const lower = name.toLowerCase();
        const address = String(device.address || "").toLowerCase();
        const dashedAddress = address.replace(/:/g, "-");
        const isAddress = lower === address || lower === dashedAddress
            || /^([0-9a-f]{2}[:-]){5}[0-9a-f]{2}$/i.test(name);
        const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(name);
        return isAddress || isUuid || lower === "unknown" || lower === "unbekannt";
    }

    function deviceIcon(device: var): string {
        const icon = (device?.icon ?? "").toLowerCase();
        if (icon.includes("head") || icon.includes("audio"))
            return "headphones";
        if (icon.includes("mouse"))
            return "mouse";
        if (icon.includes("keyboard"))
            return "keyboard";
        if (icon.includes("phone"))
            return "smartphone";
        if (icon.includes("computer"))
            return "computer";
        if (icon.includes("game"))
            return "sports_esports";
        return "bluetooth";
    }

    function setEnabled(on: bool): void {
        if (root.adapter)
            root.adapter.enabled = on;
    }

    function setDiscovering(on: bool): void {
        if (!root.adapter)
            return;
        if (on && !root.adapter.enabled)
            root.adapter.enabled = true;
        root.adapter.discovering = on;
    }

    function setDiscoverable(on: bool): void {
        if (!root.adapter)
            return;
        if (on && !root.adapter.enabled)
            root.adapter.enabled = true;
        root.adapter.pairable = on;
        root.adapter.pairableTimeout = on ? 180 : 0;
        root.adapter.discoverableTimeout = on ? 180 : 0;
        root.adapter.discoverable = on;
    }

    function connectDevice(device: var): void {
        if (device)
            device.connect();
    }

    function disconnectDevice(device: var): void {
        if (device)
            device.disconnect();
    }

    function toggleTrusted(device: var): void {
        if (device)
            device.trusted = !device.trusted;
    }

    function forget(device: var): void {
        if (device)
            device.forget();
    }

    function beginPairing(device: var): void {
        if (!device || root.pairingActive)
            return;
        root.pairingDevice = device;
        root.pairingLocallyStarted = true;
        root.pairingRequest = "waiting";
        root.pairingPasskey = "";
        root.pairingMessage = I18n.tr("Kopplung wird gestartet…");
        if (!root.agentReady) {
            root.pairingRequest = "error";
            root.pairingMessage = I18n.tr("Bluetooth-Agent ist noch nicht bereit");
            return;
        }
        sendAgent({ action: "pair", path: device.dbusPath });
    }

    function submitPin(pin: string): void {
        if (!root.pairingInputRequired || pin === "")
            return;
        sendAgent({ action: "respond", value: pin });
        root.pairingRequest = "waiting";
        root.pairingMessage = I18n.tr("PIN wird geprüft…");
    }

    function confirmPairing(accept: bool): void {
        if (root.pairingRequest !== "confirm" && root.pairingRequest !== "authorize")
            return;
        sendAgent({ action: "respond", accept: accept });
        if (accept) {
            root.pairingRequest = "waiting";
            root.pairingMessage = I18n.tr("Kopplung wird bestätigt…");
            if (root.pairingDevice?.paired && !root.pairingLocallyStarted)
                root.clearPairing();
        } else {
            root.clearPairing();
        }
    }

    function cancelPairing(): void {
        if (root.pairingDevice && root.pairingRequest !== "error")
            sendAgent({ action: "cancel", path: root.pairingDevice.dbusPath });
        root.clearPairing();
    }

    function clearPairing(): void {
        root.pairingDevice = null;
        root.pairingRequest = "";
        root.pairingPasskey = "";
        root.pairingMessage = "";
        root.pairingEntered = 0;
        root.pairingLocallyStarted = false;
    }

    function sendAgent(message: var): void {
        agent.write(JSON.stringify(message) + "\n");
    }

    function handleAgentOutput(line: string): void {
        let event;
        try {
            event = JSON.parse(line);
        } catch (error) {
            console.warn("Bluetooth-Agent: ungültige Antwort", error);
            return;
        }
        if (event.event === "ready") {
            root.agentReady = event.ready;
            if (!event.ready && root.pairingActive) {
                root.pairingRequest = "error";
                root.pairingMessage = I18n.tr("Bluetooth-Agent ist nicht verfügbar");
            }
        } else if (event.event === "request") {
            const device = QB.Bluetooth.devices.values.find(device => device.dbusPath === event.path);
            if (!device) {
                sendAgent({ action: "respond", accept: false });
                return;
            }
            root.pairingDevice = device;
            root.pairingPasskey = event.passkey || "";
            root.pairingEntered = event.entered || 0;
            root.pairingMessage = event.kind === "pin" ? I18n.tr("PIN des Geräts eingeben")
                : event.kind === "passkey" ? I18n.tr("Passkey des Geräts eingeben (1–6 Ziffern)")
                : event.kind === "confirm" ? I18n.tr("Stimmt dieser Code auf beiden Geräten überein?")
                : event.kind === "display" ? I18n.tr("Diesen Code am anderen Gerät eingeben")
                : I18n.tr("Verbindung bzw. Dienste dieses Geräts erlauben?");
            root.pairingRequest = event.kind;
        } else if (event.event === "paired") {
            if (root.pairingDevice?.dbusPath === event.path) {
                root.pairingDevice.trusted = true;
                root.pairingDevice.connect();
                root.clearPairing();
            }
        } else if (event.event === "canceled") {
            root.clearPairing();
        } else if (event.event === "input-error") {
            root.pairingRequest = event.kind;
            root.pairingMessage = event.message;
        } else if (event.event === "error") {
            if (event.path && event.path !== root.pairingDevice?.dbusPath)
                return;
            console.warn("Bluetooth-Agent:", event.message);
            if (root.pairingActive) {
                root.pairingRequest = "error";
                root.pairingMessage = I18n.tr("Kopplung fehlgeschlagen: %1").arg(event.message);
            }
        }
    }

    Connections {
        target: root.pairingDevice

        function onPairedChanged(): void {
            // Vom Handy gestartete Kopplungen haben keinen eigenen Pair-Aufruf.
            if (root.pairingDevice?.paired && !root.pairingLocallyStarted)
                root.clearPairing();
        }

        function onConnectedChanged(): void {
            if (root.pairingDevice?.connected && root.pairingRequest === "waiting" && !root.pairingLocallyStarted)
                root.clearPairing();
        }
    }

    Process {
        id: agent

        command: ["python", Quickshell.shellPath("modules/services/bluetooth/agent.py")]
        stdinEnabled: true
        running: true

        onExited: {
            root.agentReady = false;
            if (root.pairingDevice) {
                root.pairingRequest = "error";
                root.pairingMessage = I18n.tr("Bluetooth-Agent wurde beendet");
            }
        }

        stdout: SplitParser {
            onRead: line => root.handleAgentOutput(line)
        }
        stderr: SplitParser {
            onRead: line => console.warn("Bluetooth-Agent:", line)
        }
    }
}
