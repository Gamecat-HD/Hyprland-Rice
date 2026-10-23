# Plugins

Ein Plugin ist ein Ordner `plugins/<id>/` neben `shell.qml`. Die Shell findet
neue Ordner selbst (kein Neustart), Ordner mit `_` oder `.` am Anfang werden
übersprungen (`_example/` ist die Vorlage für `dynamic-island plugin new`).

```
plugins/
  terminal/
    plugin.json     Manifest (Pflicht)
    Main.qml        Dienst, läuft solange das Plugin an ist (optional)
    Tile.qml        Schnellkachel (optional, beliebig viele)
    Section.qml     Sektion in einer Ansicht der Shell (optional, je Ansicht eine)
```

Kern: `modules/services/plugins/Plugins.qml` (Singleton) + `PluginHost.qml`
(je Plugin). Zustand pro Rechner: `~/.config/dynamic-island/plugins.json`
(nicht im Git, wie `shell.json`).

## Manifest `plugin.json`

| Feld | Pflicht | Bedeutung |
|---|---|---|
| `id` | ja | `a-z 0-9 -`, max. 48 Zeichen, **gleich dem Ordnernamen** |
| `name` | ja | Anzeigename |
| `api` | ja | Plugin-API, die das Plugin braucht (aktuell `1`; größere werden nicht geladen) |
| `version` | – | Semver-artig, wird beim Import verglichen |
| `description`, `author`, `homepage` | – | Text für die Verwaltung |
| `icon` | – | Material-Symbols-Name (Standard `extension`) |
| `defaultEnabled` | – | An, solange `plugins.json` nichts anderes sagt. Importierte Plugins sind trotzdem erst einmal **aus**. |
| `main` | – | QML-Datei des Dienstes (relativ) |
| `settings` | – | Einstellungen, s.u. |
| `tiles` | – | Schnellkacheln, s.u. |
| `panels` | – | Sektionen in Ansichten der Shell (bisher: Wallpaper-Auswahl), s.u. |
| `widgets` | – | Desktop-Widgets (Typen für die Szenen je Wallpaper), s.u. |
| `files` | – | Dateien außerhalb des Plugin-Ordners, die dazugehören (für Export/Import) |
| `migrateFrom` | – | Gruppe in `shell.json`, deren Werte einmalig übernommen werden (`enabled: false` dort = Plugin bleibt aus) |
| `parent` | – | Komponente eines anderen Plugins, s.u. |
| `components` | – | Untermenü für die eigenen Komponenten: `{ "title", "icon", "desc" }` |
| `builtin` | – | Gehört zur Shell: in der Verwaltung nur an/aus, `plugin remove` nur mit `--force` |

Schema für Editoren: `plugins/plugin.schema.json` (`"$schema": "../plugin.schema.json"`).

### `settings`

Gleiche Felder wie `Config.meta`, plus `default` (Pflicht – der Typ der
Vorgabe bestimmt das Bedienelement):

```json
"settings": {
    "theme":   { "default": true, "title": "An Theme anpassen", "desc": "…" },
    "style":   { "default": "kurz", "options": ["kurz", "lang"], "title": "Stil" },
    "size":    { "default": 12, "min": 8, "max": 32, "step": 1, "unit": " px", "title": "Größe" },
    "looks":   { "default": true, "title": "…", "requires": "theme" }
}
```

`editor` (`"quick"`, `"desktop"`) setzt statt des Bedienelements einen
eingebauten Editor in die Zeile (so zeigt `desktop` seinen Szenen-Block).

`requires` ohne Punkt meint eine Einstellung desselben Plugins, mit Punkt eine
Shell-Einstellung (`"bar.battery"`) oder ein anderes Plugin
(`"plugin:<id>.<key>"`); als Objekt `{ "theme": true }` für einen bestimmten Wert.

Im Menü erscheint jedes aktive Plugin mit Einstellungen als eigene Gruppe
`plugin:<id>` unter „Plugins“.

### `tiles`

```json
"tiles": {
    "status": { "label": "Status", "icon": "bolt", "kind": "pill", "component": "Tile.qml" }
}
```

`kind`: `pill` (2 Spalten), `circle` (1), `wide` (volle Breite). Die Kachel
heißt im Raster `<plugin>.<kachel>` und taucht nach dem Einschalten im
Kachel-Editor unter „Ausgeblendet“ auf. Vertrag der Komponente: siehe
Abschnitt „Kacheln“ unten.

### `panels`

```json
"panels": {
    "wallpaper": { "component": "Section.qml", "icon": "travel_explore" }
}
```

Hängt eine Sektion in eine Ansicht der Shell, je Ansicht höchstens eine pro
Plugin. Bisher einzige Ansicht: `wallpaper`, die Wallpaper-Auswahl der Notch
(aufklappbar unter der lokalen Reihe und der Stil-Reihe). `icon` (Vorgabe:
Plugin-Icon) wird zum Knopf in deren Suchzeile. Hat das Plugin einen Dienst
(`main`), erscheint die Sektion erst, wenn er läuft. Vertrag der Komponente:
Abschnitt „Sektionen“ unten.

### `widgets`

Desktop-Widgets, die in den Szenen (`~/.config/dynamic-island/scenes.json`,
siehe `modules/services/desktop/Scenes.qml`) platziert werden können. Sie
erscheinen nur, solange das Plugin `desktop` an ist – ein Widget-Paket also
als Komponente bauen (`"parent": "desktop"`, s.u.). Je Typ:

```json
"widgets": {
    "matrix": {
        "title": "Matrix",
        "icon": "code",
        "component": "MatrixWidget.qml",
        "size": [30, 20],
        "options": {
            "speed": { "title": "Tempo", "values": ["langsam", "mittel", "schnell"], "default": "mittel" },
            "trails": { "title": "Spuren", "bool": true, "default": true }
        }
    }
}
```

`size` = ungefähre Größe in Grundeinheiten (16 px bei 1440p) für die
automatische Platzierung; `options` erscheinen als Chips in der
Bearbeitungsleiste (`values` = Auswahl, `bool` = Schalter) und landen in
`opts`. Farbe und Akzent hat jedes Widget von selbst.

Die Komponente bekommt vom Host (`modules/desktop/WidgetHost.qml`):

| Property | Bedeutung |
|---|---|
| `unit` | Grundeinheit in px (16 · Monitorhöhe/1440 · Größe des Widgets) |
| `active` | `false` = Desktop verdeckt (Fenster, Vollbild, Game-Mode): nichts rechnen, nichts animieren |
| `editing` | Bearbeitungsmodus läuft |
| `opts` | Optionen aus der Szene, Vorgaben schon eingesetzt |
| `color`, `accent` | Textfarbe und Akzent |
| `fps` | (optional deklarieren) Obergrenze für eigene Animationen, Einstellung `fps` des Plugins `desktop` |
| `plugin` | (optional deklarieren) Kontext des Plugins, wie bei Kacheln |

Größe setzt das Widget selbst über `implicitWidth`/`implicitHeight`. Regeln:
dauerhafte Bewegung nur per `Timer` mit `fps` (eine `Animation` liefe mit der
Monitorrate), bei `active: false` alles anhalten, Bedarf an Diensten
(`Cava.demand`, `Lyrics.demand`) nur solange `active`. `opts` kommt bei jeder
Änderung des Widgets (auch beim Verschieben) als neues Objekt – teure Neuberechnung
nur, wenn sich der Inhalt wirklich ändert. Beispiele: `desktop/widgets/`, `matrix/`, `bonsai/`, `tui/`.

### `parent` – Komponenten

```json
{ "id": "bonsai", "parent": "desktop", "widgets": { … } }
```

Eine Komponente ist ein ganz normales Plugin (eigener Ordner, eigenes
`.dip`, eigener Schalter), das zu einem anderen gehört:

- Sie läuft nur, solange ihr Plugin an ist. Ist sie selbst an, das Plugin
  aber aus, steht sie auf „Wartet“ (`status: "blocked"`).
- In der Verwaltung steht sie nicht oben, sondern im Untermenü ihres Plugins
  (Knopf auf dessen Karte, Titel aus `components.title`). Der Import dort
  nimmt nur Pakete mit passendem `parent` an (`plugin import --parent <id>`).
- Nur eine Ebene: ein Plugin mit eigenem `parent` kann keine Komponenten
  haben. Fehlt das Plugin, bleibt die Komponente aus und steht oben mit
  Hinweis.

So sind die Desktop-Widgets gebaut: `desktop/` bringt die Ebene und
Uhr/Visualiser/Songtext mit, `bonsai/`, `matrix/`, `tui/` sind Komponenten.

### `files`

```json
"files": [
    { "path": "~/.config/fish/functions/fastfetch.fish" },
    { "path": "~/.config/fastfetch", "optional": true, "note": "Looks + Bilder" }
]
```

Nur Pfade unter `~/`. Ordner werden komplett mitgenommen. Die Shell selbst
fasst diese Dateien nie an – sie sind nur für `export`/`import` da.

## Main.qml

```qml
import QtQuick
import Quickshell
import qs.modules.services.config     // alle qs.*-Module der Shell gehen

QtObject {
    required property var plugin       // Kontext, s.u.

    // optional: Launcher-Aktionen (">" im Launcher), Format wie LauncherActions
    readonly property var actions: [
        { name: "Etwas tun", desc: "…", icon: "bolt", run: () => console.log("hi") }
    ]

    // optional: qs -c dynamic-island ipc call plugins call <id> <cmd> <arg>
    function ipc(cmd: string, arg: string): string { return "ok"; }

    // optional: nur beim echten Ausschalten (nicht bei Shell-Ende/Reload).
    // Hier nach aussen sichtbare Spuren zuruecknehmen (Dateien, Modi …).
    // Das Objekt wird direkt danach zerstoert – nichts Asynchrones anfangen,
    // das es noch braucht (Quickshell.execDetached ist ok).
    function onDisable(): void {}
}
```

Wurzel darf jeder Typ sein (`QtObject`, `Scope`, `Item` …). Das Objekt
entsteht beim Einschalten und wird beim Ausschalten zerstört. Nicht-visuelle
Kinder an einem `QtObject` als `property FileView x: FileView {}` anhängen
(oder `Scope` als Wurzel nehmen).

### Kontext `plugin`

| | |
|---|---|
| `id`, `name`, `version`, `dir`, `manifest`, `enabled` | Infos |
| `settings` | aktuelle Werte (`{ key: value }`), neues Objekt bei jeder Änderung → bindbar |
| `setting(key)` / `set(key, value)` | lesen / schreiben (landet in `plugins.json`) |
| `main` | das Objekt aus `main`, solange es läuft (sonst `null`) – Kacheln und Sektionen greifen so auf den Dienst zu |
| `url(rel)` | Pfad einer Datei im Plugin-Ordner (`.qml` mit `?v=<Ladezeit>` dahinter, damit Qt nach Änderungen nicht den alten Stand aus seinem Komponenten-Cache nimmt – für `Loader.setSource`/`Qt.createComponent` immer diese URL nehmen) |
| `statePath(rel)`, `cachePath(rel)` | `~/.local/state/dynamic-island/plugins/<id>/…`, `~/.cache/…` (nicht angelegt) |
| `log(msg)` | `console.info` mit Präfix |

## Kacheln

Am einfachsten mit dem fertigen Widget `QuickTile` (Optik der eingebauten
Kacheln: aktiv = ganze Kachel in Akzentfarbe, unter 150 px nur das Symbol):

```qml
import qs.modules.widgets

QuickTile {
    id: tile
    active: tile.plugin.settings.lamp === true     // Kachel in Akzentfarbe
    subtitle: tile.active ? "An" : "Aus"
    icon: tile.active ? "lightbulb" : "light_off"  // optional, sonst aus dem Manifest
    onToggled: tile.plugin.set("lamp", !tile.active)
}
```

Die Schnelleinstellungen laden die Datei aus `tiles.<id>.component` mit
`plugin` (Kontext) als Anfangswert und setzen danach `tileId`, wenn die
Wurzel diese Property hat. Ein eigenes Wurzel-Item geht also auch, braucht
dann `required property var plugin`.

`QuickTile`: `plugin`, `tileId`, `meta` (nur lesen: Manifest-Eintrag),
`icon` (Vorgabe meta.icon → Plugin-Icon), `title` (Vorgabe meta.label),
`subtitle`, `active`, `accent`/`onAccent` (Vorgabe primary/fgPrimary),
`tapEnabled` (false = eigener TapHandler); nur lesen: `compact`
(Breite < 150), `fg`, `fgDim`, `controlColor`, `controlHover` (für eigene
Knöpfe); Signal `toggled()`; Kinder landen auf der Kachel. Höhe 54, die
Breite gibt das Raster vor. Lädt die Datei nicht, steht dort eine
Ersatzkachel „Kachel lädt nicht“ (Grund im Log).

**Imports:** Plugin-QML kann alle `qs.*`-Module importieren, die die Shell
selbst schon lädt (config, widgets, services/…, `qs` für Colors/Appearance).
Ein Modul, das nirgends in der Shell importiert wird, gilt als „not installed“.
Dateien im Plugin-Ordner sehen sich untereinander **nicht** als Typen („X is
not a type“ – die Shell lädt sie über ihr `qs:`-Schema, das keinen
Verzeichnis-Import kennt). Eine zweite QML-Datei des Plugins also über den
Pfad laden: `Loader { Component.onCompleted: setSource(plugin.url("Liste.qml"),
{ wert: 1 }) }` und Bindungen in `onLoaded` nachziehen (so macht es
`plugins/wallhaven/Section.qml` mit `WallhavenList.qml`).

**Neue Dateien:** Die Shell sieht Dateien, die nach ihrem Start in den
Plugin-Ordner kommen, erst nach einem Neustart (`dynamic-island shell -k`,
`-d`) – „File not found“ im Log, obwohl die Datei da ist. Importierte Plugins
sind davon nicht betroffen, sie liegen vor dem Einschalten komplett da.

## Sektionen

Eine Sektion (Manifest `panels.<ansicht>`) ist ein `Item`, das die Ansicht
beim Aufklappen lädt und beim Zuklappen wieder zerstört – zugeklappt gibt es
also keine Sektion, keine Timer, keine Prozesse. Was das Zuklappen überleben
soll (Suchtext, Treffer), gehört in den Dienst (`plugin.main`). Vorbild:
`plugins/wallhaven/Section.qml`.

```qml
Item {
    id: section

    required property var plugin        // Kontext, s.o.
    required property var host          // was die Ansicht anbietet, s.u.

    implicitHeight: 190                 // so weit wächst die Karte

    // Die Tastatur kommt – kann beim Erzeugen schon so sein
    readonly property bool focused: section.host.focused
    onFocusedChanged: if (focused) input.forceActiveFocus()
    Component.onCompleted: if (focused) input.forceActiveFocus()

    TextInput {
        id: input
        Keys.onEscapePressed: section.host.close()
        Keys.onUpPressed: section.host.leaveFocus()
        Keys.onDownPressed: section.host.leaveFocus()
        Keys.onPressed: event => {
            if (event.key === Qt.Key_W && (event.modifiers & Qt.ControlModifier)) {
                section.host.toggle();
                event.accepted = true;
            }
        }
    }
}
```

Ansicht `wallpaper` (`modules/launcher/WallpaperPanel.qml`): offen ist
höchstens eine Sektion, welche, merkt sich `LauncherState.wallpaperSection`
(Plugin-id, bleibt über das Schließen der Auswahl hinweg). Auf/zu geht über
den Knopf in der Suchzeile, Strg+W (erste auf, dann die nächste, nach der
letzten zu) und `LauncherState.showWallpaperSection(screen, id)` bzw.
`toggleWallpaperSection` (öffnet die Auswahl mit aufgeklappter Sektion und
der Tastatur darin – so macht es `ipc("open")` des Wallhaven-Plugins). Die
Tastatur hat entweder die lokale Reihe oder die Sektion; Hoch/Runter
wechseln. Die Sektion belegt die Tasten in ihrem Suchfeld selbst.

`host` der Wallpaper-Auswahl:

| | |
|---|---|
| `listHeight`, `imageWidth` | Maße der lokalen Reihe (Karussellhöhe, Kachelbreite) |
| `focused` | die Sektion hat die Tastatur → Suchfeld fokussieren, eigene Vorschau zeigen |
| `takeFocus()` | die Sektion will die Tastatur (Klick/Rad auf eine Kachel) |
| `leaveFocus()` | Tastatur zurück in die lokale Reihe (Hoch/Runter) |
| `toggle()` | Strg+W: nächste Sektion bzw. zu |
| `close()` | Auswahl schließen (Esc) |
| `cycleStyle(delta)` | Strg+Links/Rechts: Stil des markierten lokalen Bilds |

Hintergrund-Vorschau: `Wallpapers.preview(pfad)` wie die lokale Reihe,
`Wallpapers.previewThumb(pfad)` für ein kleines Bild (wird nur hochgezogen,
nicht auf Bildschirmgröße dekodiert). Verliert die Sektion die Tastatur,
stellt die Ansicht die Vorschau der lokalen Reihe selbst wieder her; beim
Schließen der Auswahl nimmt die lokale Reihe die Vorschau zurück. Eine
Sektion ruft `Wallpapers.stopPreview()` deshalb nicht selbst – höchstens der
Dienst in `onDisable()`, wenn der Hintergrund gerade eines seiner Bilder
zeigt. Setzt die Sektion ein Wallpaper, schließt sie die Auswahl mit
`LauncherState.close()` (bzw. `host.close()`).

## Austauschformate

### Plugin-Paket `<id>-<version>.dip`

tar.gz mit:

```
dip.json          Paketkopf
plugin/…          der Plugin-Ordner (ohne __pycache__, .qmlls.ini, .git)
files/<n>[/…]     externe Dateien aus manifest.files (Ordner als Unterbaum)
```

`dip.json`:

```json
{
  "format": "dynamic-island-plugin",
  "formatVersion": 1,
  "plugin": { "id": "terminal", "name": "Terminal-Looks", "version": "1.0.0", "api": 1 },
  "created": "2026-10-22T11:44:48+02:00",
  "generator": "dynamic-island plugin export (rechner)",
  "enabled": true,
  "settings": { "theme": true, "folderLooks": true },
  "files": [ { "path": "~/.config/starship.toml", "archive": "files/9", "type": "file", "optional": false } ],
  "checksums": { "plugin/plugin.json": "<sha256>", "files/9": "<sha256>" }
}
```

Beim Import geprüft: nur relative Pfade unter `dip.json`/`plugin/`/`files/`,
nur Dateien und Ordner (keine Links/Geräte), ≤ 5000 Einträge, ≤ 512 MB,
jede Datei mit stimmender SHA-256, Manifest nach denselben Regeln wie in der
Shell, Zielpfade nur unter `~/`.

### Einstellungen `<id>-settings.json`

```json
{
  "format": "dynamic-island-plugin-settings",
  "formatVersion": 1,
  "plugin": { "id": "terminal", "version": "1.0.0" },
  "created": "…",
  "settings": { "theme": false }
}
```

Unbekannte Schlüssel werden beim Import ignoriert.

## CLI

```
dynamic-island plugin list                     ● an  ○ aus  ✗ kaputt, Komponenten mit └ darunter
dynamic-island plugin info <id>
dynamic-island plugin enable|disable <id>
dynamic-island plugin new <id> [--name N]      aus plugins/_example
dynamic-island plugin validate <ordner|.dip>
dynamic-island plugin export <id> [-o pfad] [--no-settings] [--no-files] [--skip-optional]
dynamic-island plugin export <id> --settings-only [-o pfad]
dynamic-island plugin import <datei.dip|.json> [--enable] [--files] [--settings|--no-settings]
                                               [--force] [--overwrite-files] [--parent <id>] [-y]
dynamic-island plugin remove <id> [--keep-settings] [--force] [-y]
```

Alle Befehle können `--json` (eine Zeile `{ ok, message, … }`, so ruft die
Shell sie auf). Standardziel beim Export ist `~/Downloads`.

Import-Regeln: Fremder Code läuft nie ungefragt – ein neu importiertes Plugin
ist aus, außer mit `--enable`. Gleiche oder ältere Version über eine
installierte nur mit `--force`. Mitgelieferte Einstellungen gelten nur, wenn
für das Plugin noch keine gespeichert sind (`--settings` erzwingt). Externe
Dateien nur mit `--files`; abweichende vorhandene Dateien bleiben, außer mit
`--overwrite-files`. Ersetzte Plugins/Dateien landen in
`~/.cache/dynamic-island/plugin-backups/`.

## IPC

```
qs -c dynamic-island ipc call plugins list
qs -c dynamic-island ipc call plugins enable|disable|toggle|reload <id>
qs -c dynamic-island ipc call plugins rescan
qs -c dynamic-island ipc call plugins call <id> <cmd> <arg>
```
