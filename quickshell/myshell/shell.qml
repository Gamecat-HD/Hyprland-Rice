//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
//@ pragma UseQApplication
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

import "modules/bar"
import "modules/window"

// Minimaler Startpunkt für den eigenen Rice.
// Start:   qs -c myshell -n -d      Stop: qs -c myshell kill
// Log:     qs -c myshell log        (Hot-Reload ist an: Datei speichern reicht)
//
// Die Komponenten bringen ihre Pro-Monitor-Logik (Variants) selbst mit:
// hier reicht die blanke Instanziierung ohne Argumente (Caelestia-Stil).
ShellRoot {
    settings.watchFiles: true

    Wallpaper {}
    Bar {}
}
