pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

import qs.modules.services.wallpaper

// Welchen Look fastfetch im Terminal zeigt.
//
// Die Entscheidung trifft ~/.config/fish/functions/fastfetch.fish bei jedem
// Aufruf: Wallpaper im Miku-Ordner -> Vocaloid-HUD aus ~/.config/fastfetch,
// sonst die Schema-Variante aus templates/fastfetch*.jsonc. Hier steht nur
// der Schalter dafuer – eine Modus-Datei, die fish ohne Parser lesen kann:
//   "wallpaper"  (Standard, auch ohne Datei) = folgt dem Wallpaper
//   "miku"       = immer Vocaloid-HUD
Singleton {
    id: root

    readonly property string modePath: Quickshell.env("HOME") + "/.local/state/dynamic-island/fastfetch-mode"

    property bool followWallpaper: true
    // Dieselbe Regel wie im fish-Wrapper (Ordnername, ohne Gross/Klein)
    readonly property bool mikuWallpaper: /\/miku\//i.test(Wallpapers.actualCurrent)
    readonly property bool miku: !root.followWallpaper || root.mikuWallpaper

    function toggle(): void {
        root.followWallpaper = !root.followWallpaper;
        modeFile.setText(root.followWallpaper ? "wallpaper\n" : "miku\n");
    }

    FileView {
        id: modeFile

        path: root.modePath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.followWallpaper = text().trim() !== "miku"
    }
}
