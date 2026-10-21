pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

import qs.modules.services.config
import qs.modules.services.wallpaper

// Welchen Look das Terminal zeigt: Starship-Prompt und fastfetch.
//
// Eingestellt wird in shell.json (Gruppe "terminal", im Menue "Terminal"):
//   theme         an = Farben des aktuellen Schemas, aus = immer Vocaloid-Look
//   mikuWallpaper an = Wallpaper im Miku-Ordner behaelt trotzdem den Vocaloid-Look
//
// Entschieden wird in fish (~/.config/fish/functions/fastfetch.fish und
// conf.d/terminal-theme.fish), bei jedem Aufruf bzw. Prompt. fish liest kein
// JSON, darum schreibt dieser Singleton den Stand als ein Wort in eine
// Modus-Datei:
//   "wallpaper"  Schema, ausser bei Miku-Wallpaper (Standard, auch ohne Datei)
//   "theme"      immer Schema
//   "miku"       immer Vocaloid-Look
// shell.qml haelt ihn am Leben, damit die Datei auch ohne offene Kachel stimmt.
Singleton {
    id: root

    readonly property string modePath: Quickshell.env("HOME") + "/.local/state/dynamic-island/terminal-mode"

    readonly property bool followTheme: Config.terminal.theme
    // Dieselbe Regel wie im fish-Wrapper (Ordnername, ohne Gross/Klein)
    readonly property bool mikuWallpaper: /\/miku\//i.test(Wallpapers.actualCurrent)
    readonly property bool miku: !root.followTheme || (Config.terminal.mikuWallpaper && root.mikuWallpaper)
    readonly property string mode: !root.followTheme ? "miku" : Config.terminal.mikuWallpaper ? "wallpaper" : "theme"

    function toggle(): void {
        Config.set("terminal", "theme", !root.followTheme);
    }

    function write(): void {
        if (modeFile.text().trim() !== root.mode)
            modeFile.setText(root.mode + "\n");
    }

    onModeChanged: write()

    FileView {
        id: modeFile

        path: root.modePath
        printErrors: false
        blockLoading: true
        // Fehlt die Datei (erster Start), trotzdem schreiben
        onLoaded: root.write()
        onLoadFailed: root.write()
    }
}
