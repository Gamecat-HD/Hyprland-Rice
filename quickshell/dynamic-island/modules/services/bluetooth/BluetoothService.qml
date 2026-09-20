pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Bluetooth as QB
import Quickshell.Io

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
    property string agentBuffer: ""
    property int agentOffset: 0

    function deviceName(device: var): string {
        return device?.name || device?.deviceName || device?.address || "Unbekanntes Gerät";
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
        if (!device)
            return;
        root.pairingDevice = device;
        root.pairingRequest = "waiting";
        root.pairingPasskey = "";
        root.pairingMessage = "Kopplung wird gestartet…";
        if (!agent.running)
            agent.running = true;
        pairDelay.restart();
    }

    function submitPin(pin: string): void {
        if (pin === "")
            return;
        agent.write(pin + "\n");
        root.pairingRequest = "waiting";
        root.pairingMessage = "PIN wird geprüft…";
    }

    function confirmPairing(accept: bool): void {
        agent.write((accept ? "yes" : "no") + "\n");
        if (accept) {
            root.pairingRequest = "waiting";
            root.pairingMessage = "Kopplung wird bestätigt…";
        } else {
            root.clearPairing();
        }
    }

    function cancelPairing(): void {
        agent.write("no\n");
        if (root.pairingDevice) {
            agent.write(`cancel-pairing ${root.pairingDevice.address}\n`);
            root.pairingDevice.cancelPair();
        }
        root.clearPairing();
    }

    function clearPairing(): void {
        root.pairingDevice = null;
        root.pairingRequest = "";
        root.pairingPasskey = "";
        root.pairingMessage = "";
    }

    function handleAgentOutput(chunk: string): void {
        const clean = chunk.replace(/\x1b\[[0-9;?]*[ -/]*[@-~]/g, "");
        root.agentBuffer = (root.agentBuffer + clean).slice(-1500);
        const lower = root.agentBuffer.toLowerCase();

        if (lower.includes("confirm passkey")) {
            const match = root.agentBuffer.match(/confirm passkey\s+([0-9]+)/i);
            root.pairingPasskey = match ? match[1] : "";
            root.pairingRequest = "confirm";
            root.pairingMessage = "Stimmt dieser Code auf beiden Geräten überein?";
            root.agentBuffer = "";
        } else if (lower.includes("enter pin code") || lower.includes("request pin code")
                   || lower.includes("enter passkey") || lower.includes("request passkey")) {
            root.pairingRequest = "pin";
            root.pairingMessage = "PIN oder Passkey eingeben";
            root.agentBuffer = "";
        } else if (lower.includes("authorize service")) {
            root.pairingPasskey = "";
            root.pairingRequest = "confirm";
            root.pairingMessage = "Dienste dieses Geräts autorisieren?";
            root.agentBuffer = "";
        } else if (lower.includes("pairing successful") || lower.includes("pairing successful")) {
            const device = root.pairingDevice;
            if (device) {
                device.trusted = true;
                device.connect();
            }
            root.clearPairing();
            root.agentBuffer = "";
        } else if (lower.includes("failed to pair") || lower.includes("authenticationfailed")
                   || lower.includes("authentication canceled") || lower.includes("authentication rejected")) {
            root.pairingRequest = "error";
            root.pairingMessage = "Kopplung fehlgeschlagen";
            root.agentBuffer = "";
        }
    }

    Process {
        id: agent

        command: ["bluetoothctl", "--agent", "KeyboardDisplay"]
        stdinEnabled: true
        running: true

        onStarted: {
            root.agentOffset = 0;
            root.agentBuffer = "";
            agent.write("agent KeyboardDisplay\n");
            agent.write("default-agent\n");
        }

        onExited: if (root.pairingDevice) {
            root.pairingRequest = "error";
            root.pairingMessage = "Bluetooth-Agent wurde beendet";
        }

        stdout: StdioCollector {
            waitForEnd: false
            onDataChanged: {
                const chunk = text.slice(root.agentOffset);
                root.agentOffset = text.length;
                if (chunk !== "")
                    root.handleAgentOutput(chunk);
            }
        }
    }

    Timer {
        id: pairDelay

        interval: 120
        onTriggered: if (root.pairingDevice)
            agent.write(`pair ${root.pairingDevice.address}\n`)
    }
}
