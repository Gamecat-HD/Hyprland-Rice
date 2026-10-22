//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
//@ pragma UseQApplication
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

import "modules/bar"
import "modules/osd"
import "modules/settings"
import "modules/window"
import qs.modules.services.plugins

// Minimaler Startpunkt für den eigenen Rice.
// Start:   qs -c dynamic-island -n -d      Stop: qs -c dynamic-island kill
// Log:     qs -c dynamic-island log        (Hot-Reload ist an: Datei speichern reicht)
//
// Die Komponenten bringen ihre Pro-Monitor-Logik (Variants) selbst mit:
// hier reicht die blanke Instanziierung ohne Argumente (Caelestia-Stil).
ShellRoot {
    settings.watchFiles: true

    // Plugins (plugins/<id>/) laufen auch ohne offenes Menue
    readonly property int pluginCount: Plugins.hosts.length

    Wallpaper {}
    Bar {}
    Osd {}
    SettingsWindow {}
}
