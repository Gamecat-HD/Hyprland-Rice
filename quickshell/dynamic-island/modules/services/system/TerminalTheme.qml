pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

import qs.modules.services.config

// Welchen Look das Terminal zeigt: Starship-Prompt und fastfetch.
//
// Eingestellt wird in shell.json (Gruppe "terminal", im Menue "Terminal"):
//   theme         an = Farben des aktuellen Schemas, aus = immer Vocaloid-Look
//   folderLooks   an = Wallpaper-Ordner mit eigenem Look (~/.config/fastfetch/<ordner>/,
//                 Miku direkt in ~/.config/fastfetch) zeigt diesen statt des Schemas
//
// Entschieden wird in fish (functions/__terminal_look.fish, genutzt von
// fastfetch.fish und conf.d/terminal-theme.fish), bei jedem Aufruf bzw.
// Prompt. fish liest kein JSON, darum schreibt dieser Singleton den Stand
// als ein Wort in eine Modus-Datei:
//   "wallpaper"  Ordner-Look des Wallpapers, sonst Schema (Standard, auch ohne Datei)
//   "theme"      immer Schema
//   "miku"       immer Vocaloid-Look
// shell.qml haelt ihn am Leben, damit die Datei auch ohne offenes Menue stimmt.
Singleton {
    id: root

    readonly property string modePath: Quickshell.env("HOME") + "/.local/state/dynamic-island/terminal-mode"

    readonly property bool followTheme: Config.terminal.theme
    readonly property string mode: !root.followTheme ? "miku" : Config.terminal.folderLooks ? "wallpaper" : "theme"

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
