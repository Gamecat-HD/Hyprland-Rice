pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property real value: 1
    property bool ready: false
    readonly property int percent: Math.round(value * 100)

    function setValue(newValue: real): void {
        const clamped = Math.max(0.01, Math.min(1, newValue));
        root.value = clamped;
        writeTimer.restart();
    }

    Process {
        id: queryProcess

        command: ["ddcutil", "getvcp", "10", "--brief", "--display", "1"]

        stdout: StdioCollector {
            onStreamFinished: {
                const match = this.text.match(/VCP 10 C (\d+) (\d+)/);
                if (!match)
                    return;
                const maximum = parseInt(match[2]);
                if (maximum <= 0)
                    return;
                root.value = parseInt(match[1]) / maximum;
                root.ready = true;
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!queryProcess.running && !writeTimer.running && !settleTimer.running)
            queryProcess.running = true
    }

    Timer {
        id: writeTimer

        interval: 120
        onTriggered: {
            const value = root.percent.toString();
            Quickshell.execDetached(["ddcutil", "setvcp", "10", value, "--display", "1", "--noverify"]);
            Quickshell.execDetached(["ddcutil", "setvcp", "10", value, "--display", "2", "--noverify"]);
            settleTimer.restart();
        }
    }

    Timer {
        id: settleTimer

        interval: 1500
        onTriggered: if (!queryProcess.running)
            queryProcess.running = true
    }
}
