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
    // Welche Ansicht die Karte gerade zeigt. Beide teilen sich Fenster und
    // Fokus-Grab (siehe Bar.qml), deshalb ein gemeinsamer Zustand statt zweier
    // Singletons: offen ist immer genau eine davon.
    //   "apps"       Suchfeld + Trefferliste (LauncherPanel)
    //   "wallpaper"  eigenes Suchfeld + Bild-Karussell (WallpaperPanel)
    //   "theme"      eigenes Suchfeld + Farb-Karussell (ThemePanel)
    //   "power"      Sitzungs- und Energieaktionen (PowerPanel)
    property string mode: "apps"

    function show(target: ShellScreen): void {
        root.showMode(target, "apps");
    }

    function showMode(target: ShellScreen, mode: string): void {
        root.mode = mode;
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

    // Direkt in die Wallpaper-Auswahl (Knopf in der Notch, IPC, Tastenkuerzel)
    function showWallpapers(target: ShellScreen): void {
        root.showMode(target, "wallpaper");
    }

    function toggleWallpapers(target: ShellScreen): void {
        if (root.open && root.mode === "wallpaper")
            root.close();
        else
            root.showWallpapers(target);
    }

    // Farbschema-Auswahl. Anders als die Wallpaper hat sie keinen Knopf in der
    // Leiste – nur den Launcher-Befehl und diesen Weg hier.
    function showThemes(target: ShellScreen): void {
        root.showMode(target, "theme");
    }

    function showPower(target: ShellScreen): void {
        root.showMode(target, "power");
    }

    // Für Aufrufe von außen (Tastenkürzel): Monitor unter dem Fokus nehmen
    function focusedScreen(): ShellScreen {
        const name = Hyprland.focusedMonitor?.name ?? "";
        return Quickshell.screens.find(s => s.name === name) ?? Quickshell.screens[0] ?? null;
    }

    function toggleOnFocused(): void {
        root.toggle(root.focusedScreen());
    }

    // Erreichbar über:  qs -c dynamic-island ipc call launcher toggle
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

        function wallpaper(): void {
            root.showWallpapers(root.focusedScreen());
        }

        function theme(): void {
            root.showThemes(root.focusedScreen());
        }

        function power(): void {
            root.showPower(root.focusedScreen());
        }
    }
}
