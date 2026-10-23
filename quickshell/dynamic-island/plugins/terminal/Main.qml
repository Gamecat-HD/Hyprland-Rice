pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

import qs

// Welchen Look das Terminal zeigt: Starship-Prompt und fastfetch.
// (Frueher modules/services/system/TerminalTheme.qml, jetzt ein Plugin.)
//
// Einstellungen (plugin.json, im Menue unter "Terminal-Looks"):
//   theme         an = Farben des aktuellen Schemas, aus = immer Vocaloid-Look
//   folderLooks   an = Wallpaper-Ordner mit eigenem Look (~/.config/fastfetch/<ordner>/,
//                 Miku direkt in ~/.config/fastfetch) zeigt diesen statt des Schemas;
//                 feste Looks je Bild/Ordner (terminal-looks.tsv) setzt die
//                 Wallpaper-Bibliothek in den Einstellungen (WallManager.qml)
//
// Entschieden wird in fish (functions/__terminal_look.fish, genutzt von
// fastfetch.fish und conf.d/terminal-theme.fish), bei jedem Aufruf bzw.
// Prompt. fish liest kein JSON, darum schreibt das Plugin den Stand als ein
// Wort in eine Modus-Datei (Plugin aus = "miku", siehe onDisable):
//   "wallpaper"  Ordner-Look des Wallpapers, sonst Schema (Standard, auch ohne Datei)
//   "theme"      immer Schema
//   "miku"       immer Vocaloid-Look
QtObject {
    id: root

    required property var plugin

    readonly property string modePath: Quickshell.env("HOME") + "/.local/state/dynamic-island/terminal-mode"
    readonly property string mode: !root.plugin.settings.theme ? "miku"
                                   : root.plugin.settings.folderLooks ? "wallpaper" : "theme"

    readonly property var labels: ({ wallpaper: I18n.tr("Wallpaper-Ordner"), theme: I18n.tr("Farbschema"), miku: "Vocaloid" })

    // Im Launcher unter ">" – schaltet zwischen den drei Modi durch
    readonly property var actions: [
        {
            name: I18n.tr("Terminal-Look wechseln"),
            desc: I18n.tr("Jetzt: %1").arg(root.labels[root.mode]),
            keepOpen: true,
            run: () => root.cycle()
        }
    ]

    function cycle(): void {
        // wallpaper -> theme -> miku -> wallpaper
        if (root.mode === "wallpaper")
            root.plugin.set("folderLooks", false);
        else if (root.mode === "theme")
            root.plugin.set("theme", false);
        else {
            root.plugin.set("theme", true);
            root.plugin.set("folderLooks", true);
        }
    }

    // qs -c dynamic-island ipc call plugins call terminal mode ""
    function ipc(cmd: string, arg: string): string {
        if (cmd === "mode")
            return root.mode;
        if (cmd === "cycle") {
            root.cycle();
            return "ok";
        }
        return "unbekannt: mode | cycle";
    }

    function write(): void {
        if (modeFile.text().trim() !== root.mode)
            modeFile.setText(root.mode + "\n");
    }

    onModeChanged: write()

    // Plugin aus = Funktion aus: fester Vocaloid-Look statt Wechsel je
    // Wallpaper. Ohne das bliebe die Datei auf dem letzten Stand stehen und
    // fish wechselte weiter. Per sh, weil das Objekt gleich danach zerstoert
    // wird (ein FileView-Schreiben koennte dabei verloren gehen).
    function onDisable(): void {
        Quickshell.execDetached(["sh", "-c", 'printf "%s\\n" "$1" > "$2"', "sh", "miku", root.modePath]);
    }

    property FileView modeFile: FileView {
        path: root.modePath
        printErrors: false
        blockLoading: true
        // Fehlt die Datei (erster Start), trotzdem schreiben
        onLoaded: root.write()
        onLoadFailed: root.write()
    }
}
