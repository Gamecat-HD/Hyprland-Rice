pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property real value: 1
    property bool ready: false
    property int pendingPercent: 100
    property int activePercent: -1
    readonly property int percent: Math.round(value * 100)

    function setValue(newValue: real): void {
        const clamped = Math.max(0, Math.min(1, newValue));
        root.value = clamped;
        root.pendingPercent = Math.round(clamped * 100);
        writeTimer.restart();
    }

    function flushWrite(): void {
        if (writeProcess.running)
            return;
        root.activePercent = root.pendingPercent;
        const value = root.activePercent.toString();
        writeProcess.command = ["sh", "-c",
            `ddcutil --bus 6 setvcp 10 ${value} --noverify & `
            + `ddcutil --bus 7 setvcp 10 ${value} --noverify & wait`];
        writeProcess.running = true;
    }

    Process {
        id: queryProcess

        command: ["ddcutil", "--bus", "6", "getvcp", "10", "--brief"]

        stdout: StdioCollector {
            onStreamFinished: {
                const match = this.text.match(/VCP 10 C (\d+) (\d+)/);
                if (!match)
                    return;
                const maximum = parseInt(match[2]);
                if (maximum <= 0)
                    return;
                root.value = parseInt(match[1]) / maximum;
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
        triggeredOnStart: true
        onTriggered: if (!queryProcess.running && !writeProcess.running
                        && !writeTimer.running && !settleTimer.running)
            queryProcess.running = true
    }

    Timer {
        id: writeTimer

        interval: 180
        onTriggered: root.flushWrite()
    }

    Timer {
        id: settleTimer

        interval: 1500
        onTriggered: if (!queryProcess.running)
            queryProcess.running = true
    }
}
