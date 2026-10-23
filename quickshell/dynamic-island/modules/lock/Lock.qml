pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

import qs

// Sperrbildschirm der Shell (ext-session-lock). Ersetzt hyprlock, das als
// Rueckfall bleibt: ~/.config/hypr/scripts/lock.sh nimmt hyprlock, wenn die
// Shell nicht laeuft, und SUPER+ALT+L holt es auch dann, wenn die Shell bei
// gesperrter Sitzung abstuerzt (Hyprland: allow_session_lock_restore).
//
// Sperren:   qs -c dynamic-island ipc call lock lock
//            hl.dsp.global("dynamic-island:lock")
// Entsperren geht bewusst nur ueber das Passwort – kein IPC-Befehl dafuer.
Scope {
    id: root

    readonly property alias locked: sessionLock.locked
    // Die Oberflaeche spielt gerade ihren Abgang (nach richtigem Passwort)
    property bool leaving: false
    // Monitor, der beim Sperren fokussiert war: dort steht die Medien-Karte
    property string primaryName: ""

    function lock(): void {
        if (sessionLock.locked)
            return;
        root.primaryName = Hyprland.focusedMonitor?.name ?? "";
        root.leaving = false;
        context.reset();
        sessionLock.locked = true;
    }

    WlSessionLock {
        id: sessionLock

        LockSurface {
            context: context
            lock: root
        }
    }

    LockContext {
        id: context

        onUnlocked: {
            root.leaving = true;
            leaveDelay.restart();
        }
    }

    // So lange, wie die Notch zum Einklappen und das Wallpaper zum
    // Scharfwerden brauchen. Danach liegt darunter der echte Desktop.
    Timer {
        id: leaveDelay

        interval: Appearance.morphDuration + 220
        onTriggered: {
            sessionLock.locked = false;
            root.leaving = false;
            context.reset();
        }
    }

    IpcHandler {
        target: "lock"

        function lock(): void {
            root.lock();
        }

        function isLocked(): bool {
            return sessionLock.locked;
        }
    }

    GlobalShortcut {
        appid: "dynamic-island"
        name: "lock"
        description: "Sitzung sperren"

        onPressed: root.lock()
    }
}
