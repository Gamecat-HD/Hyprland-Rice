# Rust-Helfer

Rust-Fassungen von Shell-Helfern, die vorher in Python liefen. Die QML-Dateien
starten das Binary aus `~/.local/bin`, wenn es dort liegt, sonst das Python-Skript.
Beide sprechen dasselbe Protokoll. `install.sh` baut und installiert die Binaries.

| Binary | Python-Fassung | Aufrufer |
|---|---|---|
| `dynamic-island-idle` | `modules/services/idle/idlehelper.py` | `Idle.qml` |
| `dynamic-island-bluetooth-agent` | `modules/services/bluetooth/agent.py` | `BluetoothService.qml` |
| `dynamic-island-looks` | `plugins/terminal/looks.py` | `plugins/terminal/Main.qml` |

`dynamic-island-rs` ist das neue Frontend von `dynamic-island`. Es macht `plugin`
selbst. Alles andere, jede Hilfe und jede Eingabe, die es nicht versteht, reicht es
unveraendert an `bin/dynamic-island` (Python) weiter. Es muss neben diesem Skript
liegen, und `~/.local/bin/dynamic-island` muss ein Symlink bleiben: `Themes.qml`
findet darueber die Farbschemata.

## Zurueck zu Python

Binary loeschen und die Shell neu starten, fuer die CLI den Symlink umstellen:

```sh
rm ~/.local/bin/dynamic-island-idle ~/.local/bin/dynamic-island-bluetooth-agent ~/.local/bin/dynamic-island-looks
ln -sfn ~/.config/dynamic-island/bin/dynamic-island ~/.local/bin/dynamic-island
```

## Vergleichstests

`compare/` laesst beide Fassungen dieselben Szenarien gegen nachgebaute Dienste
(logind, BlueZ) durchlaufen und vergleicht die Protokolle. Alles laeuft in einer
`bwrap`-Sandbox ohne Zugriff auf Hyprland, Shell, echte Busse, Terminals und Netz.
Ein Lauf dauert rund anderthalb Minuten, weil die Wartezeiten echt sind.

```sh
cargo build --release
compare/run.sh            # Python gegen Rust
compare/run.sh baseline   # Python gegen sich selbst: Sind die Protokolle stabil?
compare/run.sh fallback   # die echten QML-Befehle, mit und ohne Binary im PATH
compare/run.sh plugin     # dynamic-island plugin, auch mit boesartigen Paketen
compare/run.sh looks      # Terminal-Looks, mit Zufallsdaten und deinen echten Looks
```
