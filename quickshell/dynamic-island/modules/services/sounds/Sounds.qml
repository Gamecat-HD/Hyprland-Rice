pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

import qs.modules.services.config
import qs.modules.services.notifications
import qs.modules.services.screenshot

// Kurze Systemklaenge, eigene Synthese passend zum Rice (sounds/*.wav,
// erzeugt von gen.py: message, shutter, plug, unplug, lock, unlock),
// abgespielt mit pw-play als Benachrichtigung, damit sie in pavucontrol eine
// eigene Lautstaerke haben. Alles aus, solange sounds.enabled false ist.
//
// Probehoeren (auch wenn aus):  qs -c dynamic-island ipc call sounds play message
//
// Benutzung:  import qs.modules.services.sounds   ->  Sounds.play("message")
Singleton {
    id: root

    readonly property string dir: Quickshell.shellPath("modules/services/sounds/sounds/")
    readonly property var names: ["message", "shutter", "plug", "unplug", "lock", "unlock"]

    function play(name: string): void {
        if (Config.sounds.enabled)
            root.playNow(name);
    }

    function playNow(name: string): void {
        if (!root.names.includes(name))
            return;
        Quickshell.execDetached(["pw-play", "--volume", String(Config.sounds.volume / 100),
            "-P", "{ media.role = \"Notification\", application.name = \"dynamic-island\" }",
            root.dir + name + ".wav"]);
    }

    function locked(on: bool): void {
        if (Config.sounds.lock)
            root.play(on ? "lock" : "unlock");
    }

    IpcHandler {
        target: "sounds"

        function play(name: string): void {
            root.playNow(name);
        }
    }

    Connections {
        target: Notifications
        function onArrived(entry: var): void {
            if (Config.sounds.notifications)
                root.play("message");
        }
    }

    Connections {
        target: Screenshot
        function onDone(action: string, result: var): void {
            if (Config.sounds.screenshot && result.ok && (action === "copy" || action === "save"))
                root.play("shutter");
        }
    }

    // Ladekabel: nur Wechsel melden, nicht den Zustand beim Start
    property bool onBattery: UPower.onBattery
    property bool powerKnown: false
    Component.onCompleted: Qt.callLater(() => root.powerKnown = true)
    onOnBatteryChanged: if (root.powerKnown && Config.sounds.power) root.play(root.onBattery ? "unplug" : "plug")
}
