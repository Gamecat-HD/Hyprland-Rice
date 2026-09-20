# Hyprland-Rice — Dynamic Island

Meine Hyprland-Konfiguration mit eigener Quickshell-Oberflaeche
("dynamic-island"): Leiste mit Notch, Medien-Karte, Wallpaper- und
Theme-Auswahl, WLAN-Einstellungen — dazu die CLI `dynamic-island`
(Farbschemata, Wallpaper, Screenshots, Aufnahmen).

## Installieren

```sh
git clone https://github.com/Gamecat-HD/Hyprland-Rice.git
cd Hyprland-Rice
./dynamic-island/install.sh --install-deps
```

Das Skript verteilt `hypr/`, `quickshell/dynamic-island/` und
`dynamic-island/` nach `~/.config` — standardmaessig als Symlinks, damit ein
`git pull` im Klon sofort gilt. Was dort schon liegt, wandert vorher nach
`~/backups/`, nichts wird geloescht.

Danach:

```sh
hyprctl reload            # Hyprland liest die neue Config
dynamic-island shell -d   # Shell starten
```

Wo der Klon liegt, ist egal. Wer den Klon lieber *als* `~/.config` haben will,
kann das auch — dann faellt das Verteilen weg.

### Optionen

| Option | Wirkung |
| --- | --- |
| `--install-deps` | fehlende Pakete per `paru`/`yay` mitinstallieren |
| `--copy` | kopieren statt verlinken (nach `git pull` erneut ausfuehren) |
| `--check` | nur pruefen, nichts aendern |
| `--dry-run` | zeigen, was passieren wuerde |
| `-y` | ohne Rueckfrage durchlaufen |

## Voraussetzungen

Hyprland **mit Lua-Konfiguration** (getestet mit 0.56) — die Config ist
`hypr/hyprland.lua`, keine `hyprland.conf`. Dazu Quickshell (getestet mit
0.3.1), Python mit `pillow` und `materialyoucolor`, die Material-Symbols-
Schrift und die ueblichen Wayland-Werkzeuge.

Mehrere Anzeigen haengen an Systemdiensten, mit denen die Shell ueber DBus
redet: **NetworkManager** (WLAN), **bluez** (Bluetooth), **upower** (Akku) und
**power-profiles-daemon** (Energieprofile). Optional sind `cava` (Balken im
Medien-Player), `ddcutil` (Helligkeit ueber DDC/CI) und `nordvpn` (VPN-Kachel) —
ohne sie faellt nur die jeweilige Einzelheit aus.

Benachrichtigungen bringt die Shell selbst mit; ein zweiter Daemon (mako, dunst,
swaync) muss aus sein, sonst belegt er den DBus-Namen.

`./dynamic-island/install.sh --check` sagt, was davon fehlt.

## Profile

`~/.config/hypr/profile` entscheidet, welches Profil Hyprland laedt:

* `simple` — diese Rice mit der dynamic-island-Shell
* `caelestia` — die volle Config mit der Caelestia-Shell (die liegt nicht in
  diesem Repo)

Umschalten: `hypr-profile toggle` oder `CTRL + SUPER + SHIFT + P`.

## Hinweis

Das Installationsskript wurde mit KI erstellt und fasst dein System an
(Symlinks, Verzeichnisse, Farbschema-Dateien fuer GTK/Qt/btop/Discord).
Lies es durch, bevor du es laufen laesst.
