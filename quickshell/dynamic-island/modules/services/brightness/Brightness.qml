pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

// Automatische Helligkeitssteuerung:
//   1. Internes Laptop-Panel ueber brightnessctl/sysfs
//   2. Ohne Backlight-Geraet alle dynamisch erkannten DDC-Monitore
Singleton {
    id: root

    property real value: 1
    property bool ready: false
    property int pendingPercent: 100
    property int activePercent: -1
    property string backend: ""
    property string backlightDevice: ""
    property var ddcBuses: []

    readonly property int percent: Math.round(value * 100)

    function setValue(newValue: real): void {
        if (!root.ready)
            return;
        const clamped = Math.max(0, Math.min(1, newValue));
        root.value = clamped;
        root.pendingPercent = Math.round(clamped * 100);
        writeTimer.restart();
    }

    function startQuery(): void {
        if (queryProcess.running || root.backend === "")
            return;
        if (root.backend === "backlight")
            queryProcess.command = ["brightnessctl", "--device", root.backlightDevice,
                                    "--machine-readable", "info"];
        else
            queryProcess.command = ["ddcutil", "--bus", root.ddcBuses[0],
                                    "getvcp", "10", "--brief"];
        queryProcess.running = true;
    }

    function flushWrite(): void {
        if (writeProcess.running || !root.ready)
            return;

        root.activePercent = root.pendingPercent;
        const percent = root.activePercent.toString() + "%";
        if (root.backend === "backlight") {
            writeProcess.command = ["brightnessctl", "--device", root.backlightDevice,
                                    "set", percent];
        } else {
            // Die Busnummern stammen ausschliesslich aus ddcutil und werden
            // beim Parsen auf Ziffern reduziert.
            const commands = root.ddcBuses.map(bus =>
                `ddcutil --bus ${bus} setvcp 10 ${root.activePercent} --noverify`).join(" & ");
            writeProcess.command = ["sh", "-c", commands + " & wait"];
        }
        writeProcess.running = true;
    }

    // brightnessctl listet auch Tastatur-LEDs. Nur die Klasse "backlight"
    // steuert ein Display; das erste solche Geraet ist das interne Panel.
    Process {
        id: backlightDetect

        command: ["brightnessctl", "--list", "--machine-readable"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of this.text.trim().split("\n")) {
                    const fields = line.split(",");
                    if (fields.length >= 2 && fields[1] === "backlight") {
                        root.backlightDevice = fields[0];
                        break;
                    }
                }
            }
        }

        onExited: {
            if (root.backlightDevice !== "") {
                root.backend = "backlight";
                root.startQuery();
            } else {
                ddcDetect.running = true;
            }
        }
    }

    Process {
        id: ddcDetect

        command: ["ddcutil", "detect", "--brief"]

        stdout: StdioCollector {
            onStreamFinished: {
                const buses = [];
                const pattern = /\/dev\/i2c-(\d+)/g;
                let match;
                while ((match = pattern.exec(this.text)) !== null) {
                    if (!buses.includes(match[1]))
                        buses.push(match[1]);
                }
                root.ddcBuses = buses;
            }
        }

        onExited: {
            if (root.ddcBuses.length > 0) {
                root.backend = "ddc";
                root.startQuery();
            }
        }
    }

    Process {
        id: queryProcess

        stdout: StdioCollector {
            onStreamFinished: {
                let current = -1;
                let maximum = 100;

                if (root.backend === "backlight") {
                    const fields = this.text.trim().split(",");
                    const percentField = fields.find(field => field.endsWith("%"));
                    if (percentField)
                        current = parseInt(percentField);
                } else {
                    const match = this.text.match(/VCP 10 C (\d+) (\d+)/);
                    if (match) {
                        current = parseInt(match[1]);
                        maximum = parseInt(match[2]);
                    }
                }

                if (current < 0 || maximum <= 0)
                    return;
                root.value = root.backend === "backlight" ? current / 100 : current / maximum;
                root.pendingPercent = root.percent;
                root.ready = true;
            }
        }
    }

    Process {
        id: writeProcess

        onExited: {
            if (root.pendingPercent !== root.activePercent)
                writeTimer.restart();
            else
                settleTimer.restart();
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: if (!writeProcess.running && !writeTimer.running && !settleTimer.running)
            root.startQuery()
    }

    Timer {
        id: writeTimer

        interval: 180
        onTriggered: root.flushWrite()
    }

    Timer {
        id: settleTimer

        interval: 1200
        onTriggered: root.startQuery()
    }
}
