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
    readonly property alias notifications: adapter.notifications
    readonly property alias appearance: adapter.appearance
    readonly property alias vpn: adapter.vpn

    // Schrift fuer alle Texte der Shell (Icons behalten Material Symbols)
    readonly property string font: adapter.appearance.font

    // Klartext zu den Schluesseln. Steht hier neben den Vorgaben, damit eine
    // neue Einstellung an einer einzigen Stelle entsteht: Default eintragen,
    // Beschriftung dazu – im Menue erscheint sie von selbst.
    readonly property var meta: ({
        "bar.workspaces": { title: "Workspace-Punkte", desc: "Die Punktreihe links aussen" },
        "bar.stats": { title: "System-Pille", desc: "Akkustand, Energieprofile und Auslastung" },
        "bar.tray": { title: "Systemtray", desc: "Die Icons links neben der Uhr" },
        "bar.settings": { title: "Settings-Karte", desc: "Der Kreis rechts der Uhr mit WLAN, Bluetooth und Co." },
        "bar.media": { title: "Medien-Karte", desc: "Titel, Cover und Steuerung rechts aussen" },
        "bar.notifications": { title: "Benachrichtigungen", desc: "Die Glocke mit Zaehler in der Leiste" },
        "bar.battery": { title: "Akkuanzeige", desc: "Ring um die Uhr und Akkustand in der Settings-Pille" },
        "bar.batteryPulse": { title: "Akku-Ladeimpuls", desc: "Bewegter Impuls im leeren Teil des Akkurings" },
        "notifications.dnd": { title: "Nicht stören", desc: "Nachrichten sammeln, aber nicht von selbst aufklappen" },
        "vpn.provider": {
            title: "VPN-Anbieter",
            desc: "Anbieter der VPN-Kachel",
            options: ["nordvpn", "cloudflare"]
        },
        // `options` macht aus der Zeile eine Auswahl. Nicht installierte
        // Schriften blendet das Menue aus.
        "appearance.font": {
            title: "Schriftart",
            desc: "Für alle Texte der Shell",
            options: ["SF Pro", "SF Pro Rounded", "Inter", "Noto Sans", "Adwaita Sans", "Fira Sans", "Cantarell"]
        }
    })

    readonly property var sectionMeta: ({
        "bar": "Leiste",
        "notifications": "Benachrichtigungen",
        "vpn": "VPN",
        "appearance": "Darstellung"
    })

    // Die Datei als einfaches Objekt – daraus baut das Einstellungs-Fenster
    // seine Liste, ohne dass dort jeder Schluessel einzeln stehen muss.
    // Neue Schluessel im Adapter tauchen dadurch von selbst im Menue auf.
    property var raw: ({})

    function save(): void {
        file.writeAdapter();
    }

    // Wert setzen, ohne den Namen fest zu verdrahten
    function set(section: string, key: string, value: var): void {
        const target = root[section];
        if (!target)
            return;
        target[key] = value;

        // FileView writes asynchronously. Reflect the new value immediately
        // instead of reading the still-old file back into the settings model.
        const next = Object.assign({}, root.raw);
        next[section] = Object.assign({}, next[section] ?? {});
        next[section][key] = value;
        root.raw = next;

        root.save();
    }

    function get(section: string, key: string): var {
        return root[section]?.[key];
    }

    // Einmal pro Start schreiben wir die Datei zurueck. Der Adapter hat dann
    // schon alles aus ihr gelesen, ergaenzt aber fehlende Schluessel mit ihren
    // Vorgaben – so taucht eine neu dazugekommene Einstellung im Menue auf,
    // das sich ja aus der Datei baut. Das Flag verhindert die Schleife
    // Schreiben -> Dateiwaechter -> Schreiben.
    property bool normalised: false

    function reread(): void {
        try {
            root.raw = JSON.parse(file.text());
        } catch (e) {
            // Halb geschriebene Datei o.ae. – beim naechsten Mal wieder
            return;
        }

        if (!root.normalised) {
            root.normalised = true;
            file.writeAdapter();
        }
    }

    FileView {
        id: file

        path: root.path
        watchChanges: true
        onLoaded: root.reread()
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
            // Alles, was hier steht, erscheint automatisch im Menue
            property JsonObject notifications: JsonObject {
                property bool dnd: false
            }

            property JsonObject appearance: JsonObject {
                property string font: "SF Pro"
            }

            property JsonObject vpn: JsonObject {
                property string provider: "nordvpn"
            }

            property JsonObject bar: JsonObject {
                property bool workspaces: true
                property bool tray: true
                property bool settings: true
                property bool media: true
                property bool notifications: true
                // Die System-Pille ist neu und standardmaessig aus
                property bool stats: false
                property bool battery: true
                property bool batteryPulse: true
            }
        }
    }
}
