pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.UPower

import qs.modules.services.config
import qs.modules.services.notifications
import qs.modules.services.screenshot

// Kurze Systemklaenge aus dem freedesktop-Klangthema (sound-theme-freedesktop),
// abgespielt mit pw-play als "event", damit sie in pavucontrol eine eigene
// Lautstaerke haben. Alles aus, solange sounds.enabled false ist.
//
// Benutzung:  import qs.modules.services.sounds   ->  Sounds.play("bell")
Singleton {
    id: root

    readonly property string dir: "/usr/share/sounds/freedesktop/stereo/"

    function play(name: string): void {
        if (!Config.sounds.enabled)
            return;
        Quickshell.execDetached(["pw-play", "--volume", String(Config.sounds.volume / 100),
            "-P", "{ media.role = \"Notification\", application.name = \"dynamic-island\" }",
            root.dir + name + ".oga"]);
    }

    function locked(on: bool): void {
        if (Config.sounds.lock)
            root.play(on ? "service-logout" : "service-login");
    }

    Connections {
        target: Notifications
        function onArrived(entry: var): void {
            if (Config.sounds.notifications)
                root.play("message-new-instant");
        }
    }

    Connections {
        target: Screenshot
        function onDone(action: string, result: var): void {
            if (Config.sounds.screenshot && result.ok && (action === "copy" || action === "save"))
                root.play("camera-shutter");
        }
    }

    // Ladekabel: nur Wechsel melden, nicht den Zustand beim Start
    property bool onBattery: UPower.onBattery
    property bool powerKnown: false
    Component.onCompleted: Qt.callLater(() => root.powerKnown = true)
    onOnBatteryChanged: if (root.powerKnown && Config.sounds.power) root.play(root.onBattery ? "power-unplug" : "power-plug")
}
