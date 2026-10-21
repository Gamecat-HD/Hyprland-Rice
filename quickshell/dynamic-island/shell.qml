//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
//@ pragma UseQApplication
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

import "modules/bar"
import "modules/osd"
import "modules/settings"
import "modules/window"
import qs.modules.services.system

// Minimaler Startpunkt für den eigenen Rice.
// Start:   qs -c dynamic-island -n -d      Stop: qs -c dynamic-island kill
// Log:     qs -c dynamic-island log        (Hot-Reload ist an: Datei speichern reicht)
//
// Die Komponenten bringen ihre Pro-Monitor-Logik (Variants) selbst mit:
// hier reicht die blanke Instanziierung ohne Argumente (Caelestia-Stil).
ShellRoot {
    settings.watchFiles: true

    // Schreibt die Modus-Datei fuer Prompt/fastfetch, auch ohne offene Kachel
    readonly property string terminalMode: TerminalTheme.mode

    Wallpaper {}
    Bar {}
    Osd {}
    SettingsWindow {}
}
