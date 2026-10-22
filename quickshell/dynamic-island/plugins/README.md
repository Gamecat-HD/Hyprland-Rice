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
| `files` | – | Dateien außerhalb des Plugin-Ordners, die dazugehören (für Export/Import) |
| `migrateFrom` | – | Gruppe in `shell.json`, deren Werte einmalig übernommen werden |

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
| `url(rel)` | Pfad einer Datei im Plugin-Ordner |
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
dynamic-island plugin list                     ● an  ○ aus  ✗ kaputt
dynamic-island plugin info <id>
dynamic-island plugin enable|disable <id>
dynamic-island plugin new <id> [--name N]      aus plugins/_example
dynamic-island plugin validate <ordner|.dip>
dynamic-island plugin export <id> [-o pfad] [--no-settings] [--no-files] [--skip-optional]
dynamic-island plugin export <id> --settings-only [-o pfad]
dynamic-island plugin import <datei.dip|.json> [--enable] [--files] [--settings|--no-settings]
                                               [--force] [--overwrite-files] [-y]
dynamic-island plugin remove <id> [--keep-settings] [-y]
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
