pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Gemeinsamer Zustand des Launchers. Die Notch (im Bar-Fenster) schaltet ihn
// an, das Launcher-Fenster hängt seine Sichtbarkeit daran – die beiden leben
// in verschiedenen Fenstern und können sich sonst nicht sehen.
Singleton {
    id: root

    property bool open: false
    property ShellScreen screen: null   // auf welchem Monitor er aufgeht

    function show(target: ShellScreen): void {
        root.screen = target;
        root.open = true;
    }

    function close(): void {
        root.open = false;
    }

    function toggle(target: ShellScreen): void {
        if (root.open)
            root.close();
        else
            root.show(target);
    }

    // Für Aufrufe von außen (Tastenkürzel): Monitor unter dem Fokus nehmen
    function focusedScreen(): ShellScreen {
        const name = Hyprland.focusedMonitor?.name ?? "";
        return Quickshell.screens.find(s => s.name === name) ?? Quickshell.screens[0] ?? null;
    }

    function toggleOnFocused(): void {
        root.toggle(root.focusedScreen());
    }

    // Erreichbar über:  qs -c myshell ipc call launcher toggle
    IpcHandler {
        target: "launcher"

        function toggle(): void {
            root.toggleOnFocused();
        }

        function open(): void {
            root.show(root.focusedScreen());
        }

        function close(): void {
            root.close();
        }
    }
}
