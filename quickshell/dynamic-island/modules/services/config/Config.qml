pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

// Einstellungen der Shell, als Datei neben der CLI-Konfiguration:
//
//     ~/.config/dynamic-island/shell.json
//
// Dieselbe Idee wie caelestias shell.json, nur mit Bordmitteln: FileView +
// JsonAdapter (dasselbe Gespann wie in LauncherFavorites.qml). Die Defaults
// stehen unten im Adapter – fehlt ein Schluessel in der Datei, gilt der
// Default, und die Datei wird beim ersten Start angelegt.
//
// Geaendert wird ueber die Einstellungs-Ansicht (`>einstellungen` im
// Launcher), die nach jeder Aenderung `save()` ruft. Wer lieber tippt, kann
// die Datei auch von Hand bearbeiten – `watchChanges` liest sie sofort neu.
//
// Benutzung:  import qs.modules.services.config
Singleton {
    id: root

    readonly property string path: Quickshell.env("HOME") + "/.config/dynamic-island/shell.json"

    readonly property alias bar: adapter.bar

    function save(): void {
        file.writeAdapter();
    }

    FileView {
        id: file

        path: root.path
        watchChanges: true
        // Beim allerersten Start gibt es die Datei noch nicht – das ist kein
        // Fehler, den man melden muesste (angelegt wird sie unten)
        printErrors: false
        onFileChanged: reload()
        // Beim ersten Start gibt es die Datei noch nicht – dann einmal anlegen
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                file.writeAdapter();
        }

        adapter: JsonAdapter {
            id: adapter

            // Was in der Leiste sichtbar ist. Die Notch selbst steht nicht zur
            // Wahl – ohne sie gaebe es weder Uhr noch Launcher.
            property JsonObject bar: JsonObject {
                property bool workspaces: true
                property bool tray: true
                property bool settings: true
                property bool media: true
                property bool notifications: true
                // Die System-Pille ist neu und standardmaessig aus
                property bool stats: false
            }
        }
    }
}
