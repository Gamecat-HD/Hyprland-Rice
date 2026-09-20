# dynamic-island

Die CLI zum eigenen Rice (Quickshell-Config `~/.config/quickshell/dynamic-island`).

Abgeleitet von [caelestia-cli](https://github.com/caelestia-dots/cli) 1.1.2 (GPL-3.0-only),
losgelöst vom Caelestia-Repo: eigene Pfade, eigener Name, ohne die Dotfiles-Verwaltung
(`install`/`update`) und ohne Abhängigkeit zur Caelestia-Shell.

## Einrichten

```bash
./install.sh --install-deps    # Pakete, Symlinks, Verzeichnisse, Farbschema
./install.sh --check           # nur pruefen
./install.sh -y                # ohne Rueckfrage
```

Das Skript warnt zuerst, dass es **mit KI erstellt** wurde, listet auf was es
anfasst und fragt nach (Default: nein).

Idempotent: mehrfach ausfuehren schadet nicht. Echte Dateien werden vor dem
Verlinken nach `~/backups/dynamic-island-install-<datum>/` gesichert.

## Benutzung

```
dynamic-island shell -d            # Shell starten (qs -c dynamic-island)
dynamic-island shell launcher toggle   # IPC an die Shell schicken
dynamic-island wallpaper -f BILD   # Wallpaper + Material-You-Schema setzen
dynamic-island wallpaper -r        # zufälliges Wallpaper aus ~/Pictures/Wallpapers
dynamic-island scheme set -n nord -m dark
dynamic-island screenshot [-r] [-f] [-e]   # Region / eingefroren / in swappy
dynamic-island record [-s] [-r]    # Aufnahme starten/stoppen (Ton / Region)
dynamic-island clipboard [-d]      # cliphist über fuzzel
dynamic-island emoji -p            # Emoji-/Glyph-Picker
dynamic-island toggle specialws|music|communication|sysmon|todo
dynamic-island resizer -d          # Fenster-Resizer-Daemon
```

## Ablage

| Zweck | Pfad |
|---|---|
| Code | `~/.config/dynamic-island/src/dynamic_island/` |
| Hilfsskripte | `~/.config/dynamic-island/scripts/` → `~/.local/bin/{hypr-profile,theme-set}` |
| Startskript | `~/.config/dynamic-island/bin/dynamic-island` → `~/.local/bin/dynamic-island` |
| Nutzerconfig | `~/.config/dynamic-island/cli.json` |
| Eigene Templates | `~/.config/dynamic-island/templates/` |
| Status (Schema, Wallpaper, Aufnahme) | `~/.local/state/dynamic-island/` |
| Cache (Thumbnails, Schemata, Screenshots) | `~/.cache/dynamic-island/` |

Kein `pip install` nötig – das Startskript hängt `src/` in den `sys.path`. Änderungen
am Code wirken sofort.

## Abhängigkeiten

Python: `materialyoucolor`, `pillow`. Extern: `grim`, `slurp`, `swappy`, `hyprpicker`,
`wl-clipboard`, `cliphist`, `fuzzel`, `gpu-screen-recorder`, `dart-sass`, `dconf`,
`libnotify`, `hyprctl`, `qs` (Quickshell).

## Unterschiede zur Vorlage

- `install`/`update` und die gesamte Dotfiles-Verwaltung (`utils/dots/`, `utils/version.py`) entfernt.
- `screenshot -r` nutzt `slurp` statt des Caelestia-Pickers; `-f` friert den Bildschirm
  über `hyprpicker -r -z` ein.
- Neues Flag `screenshot -e/--edit`: öffnet den Shot direkt in `swappy`.
- Shell-Name als Konstante in `subcommands/shell.py`, über `cli.json → shell.name` änderbar.
- Theming-Schalter in `cli.json`: `fuzzel` und `chromium` sind aus (der eine überschreibt
  die komplette `fuzzel.ini`, der andere schreibt per `sudo` nach `/etc`).

## Doku

Ausführlich im Obsidian-Vault unter *Dynamic Island Rice* (Übersicht, CLI, Shell-Module,
Hyprland-Profile, Installation, Fallstricke).
