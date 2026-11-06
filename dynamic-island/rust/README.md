# Rust-Helfer

Rust-Fassungen von Shell-Helfern, die vorher in Python liefen. Die QML-Dateien
starten das Binary aus `~/.local/bin`, wenn es dort liegt, sonst das Python-Skript.
Beide sprechen dasselbe Protokoll. `install.sh` baut und installiert die Binaries.

| Binary | Python-Fassung | Aufrufer |
|---|---|---|
| `dynamic-island-idle` | `modules/services/idle/idlehelper.py` | `Idle.qml` |
| `dynamic-island-bluetooth-agent` | `modules/services/bluetooth/agent.py` | `BluetoothService.qml` |

## Zurueck zu Python

Binary loeschen und die Shell neu starten:

```sh
rm ~/.local/bin/dynamic-island-idle ~/.local/bin/dynamic-island-bluetooth-agent
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
```
