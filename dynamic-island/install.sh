#!/usr/bin/env bash
# install.sh — richtet den Dynamic-Island-Rice auf diesem Rechner ein.
#
# Setzt voraus, dass dieses Repo bereits unter ~/.config liegt (das Repo IST
# ~/.config). Das Skript ist idempotent: mehrfach ausfuehren schadet nicht.
#
# ACHTUNG: Dieses Skript wurde mit KI erstellt. Vor dem Ausfuehren durchlesen.
#
#   ./install.sh                 einrichten (fragt vorher nach)
#   ./install.sh --install-deps  fehlende Pakete gleich mitinstallieren
#   ./install.sh --check         nur pruefen, nichts aendern
#   ./install.sh --dry-run       zeigen was passieren wuerde
#   ./install.sh -y              ohne Rueckfrage durchlaufen
set -uo pipefail

DI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}"
BIN_DIR="$HOME/.local/bin"
BACKUP_DIR="$HOME/backups/dynamic-island-install-$(date +%Y%m%d-%H%M%S)"

SHELL_NAME="dynamic-island"
CHECK_ONLY=0
DRY_RUN=0
INSTALL_DEPS=0
ASSUME_YES=0
FAILED=0

# ---------------------------------------------------------------- Ausgabe ---
c_reset=$'\033[0m'; c_blue=$'\033[1;34m'; c_green=$'\033[1;32m'
c_yellow=$'\033[1;33m'; c_red=$'\033[1;31m'; c_dim=$'\033[2m'

step() { printf '\n%s==>%s %s\n' "$c_blue" "$c_reset" "$1"; }
ok()   { printf '  %s✓%s %s\n' "$c_green" "$c_reset" "$1"; }
skip() { printf '  %s·%s %s\n' "$c_dim" "$c_reset" "$1"; }
warn() { printf '  %s!%s %s\n' "$c_yellow" "$c_reset" "$1"; }
fail() { printf '  %s✗%s %s\n' "$c_red" "$c_reset" "$1"; FAILED=1; }
run()  { if [ "$DRY_RUN" = 1 ]; then printf '  %s[dry-run]%s %s\n' "$c_dim" "$c_reset" "$*"; else "$@"; fi; }

usage() { sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
    case "$1" in
        --check) CHECK_ONLY=1 ;;
        --dry-run) DRY_RUN=1 ;;
        --install-deps) INSTALL_DEPS=1 ;;
        -y|--yes) ASSUME_YES=1 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unbekannte Option: $1" >&2; usage; exit 1 ;;
    esac
    shift
done
[ "$CHECK_ONLY" = 1 ] && DRY_RUN=1

# --------------------------------------------------------------- Warnung ---
ki_warnung() {
    printf '\n'
    printf '%s┌────────────────────────────────────────────────────────────────┐%s\n' "$c_yellow" "$c_reset"
    printf '%s│  ACHTUNG: Dieses Skript wurde mit KI erstellt.                 │%s\n' "$c_yellow" "$c_reset"
    printf '%s│  Lies es durch, bevor du es laufen laesst.                     │%s\n' "$c_yellow" "$c_reset"
    printf '%s│  Es fasst dein System an.                                      │%s\n' "$c_yellow" "$c_reset"
    printf '%s└────────────────────────────────────────────────────────────────┘%s\n' "$c_yellow" "$c_reset"
    cat <<EOF

  Was es aendert:
    - Symlinks in ~/.local/bin (dynamic-island, hypr-profile, theme-set)
      und in ~/.config/fish/completions
    - legt Verzeichnisse an (~/.local/state/$SHELL_NAME, ~/.cache/$SHELL_NAME,
      ~/Pictures/{Wallpapers,Screenshots})
    - kopiert vorhandenen Caelestia-Status (Caelestia bleibt unberuehrt)
    - erzeugt ein Farbschema, falls keines da ist — das schreibt auch
      Farben nach Hyprland, GTK, Qt, btop, cava und Discord
    - legt ~/.config/hypr/profile an, falls es fehlt
EOF
    [ "$INSTALL_DEPS" = 1 ] && printf '    - installiert fehlende Pakete per paru/yay (fragt selbst nochmal)\n'
    printf '\n  Echte Dateien werden vorher nach ~/backups/ gesichert.\n'

    if [ "$DRY_RUN" = 1 ]; then
        printf '\n  %sNur Pruefung — es wird nichts geaendert.%s\n' "$c_dim" "$c_reset"
        return 0
    fi
    if [ "$ASSUME_YES" = 1 ]; then
        printf '\n  %s-y angegeben — laeuft ohne Rueckfrage durch.%s\n' "$c_dim" "$c_reset"
        return 0
    fi
    printf '\n  Fortfahren? [j/N] '
    local answer=""
    # Kein Eingabekanal (Cron, Pipe ohne Inhalt) -> leere Antwort -> Abbruch
    read -r answer || answer=""
    case "$answer" in
        [jJyY]|[jJ][aA]|[yY][eE][sS]) printf '\n' ;;
        *) printf '\n  Abgebrochen.\n'; exit 0 ;;
    esac
}

backup() {  # backup <datei> — echte Datei (kein Symlink) wegsichern
    local target="$1"
    [ -e "$target" ] && [ ! -L "$target" ] || return 0
    run mkdir -p "$BACKUP_DIR"
    run cp -a "$target" "$BACKUP_DIR/"
    warn "$(basename "$target") gesichert nach ~${BACKUP_DIR#$HOME}"
}

link() {  # link <ziel> <linkname>
    local src="$1" dst="$2"
    if [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$(readlink -f "$src")" ]; then
        skip "~${dst#$HOME} zeigt schon richtig"
        return 0
    fi
    backup "$dst"
    run mkdir -p "$(dirname "$dst")"
    run ln -sfn "$src" "$dst"
    ok "~${dst#$HOME} -> ~${src#$HOME}"
}

# ------------------------------------------------------------ 1. Pakete ---
PKGS=(
    hyprland quickshell python python-pillow python-materialyoucolor
    grim slurp swappy hyprpicker wl-clipboard cliphist fuzzel
    gpu-screen-recorder dart-sass dconf libnotify
    ttf-material-symbols-variable-git otf-material-symbols
)
# Binary -> Paket (nur was wirklich gebraucht wird; Schriften separat geprueft)
declare -A NEEDED=(
    [qs]=quickshell [python]=python [grim]=grim [slurp]=slurp [swappy]=swappy
    [hyprpicker]=hyprpicker [wl-copy]=wl-clipboard [cliphist]=cliphist
    [fuzzel]=fuzzel [gpu-screen-recorder]=gpu-screen-recorder [sass]=dart-sass
    [dconf]=dconf [notify-send]=libnotify [hyprctl]=hyprland
)

check_deps() {
    step "Abhaengigkeiten"
    local missing=()
    for bin in "${!NEEDED[@]}"; do
        if command -v "$bin" >/dev/null 2>&1; then
            ok "$bin"
        else
            fail "$bin fehlt (Paket: ${NEEDED[$bin]})"
            missing+=("${NEEDED[$bin]}")
        fi
    done

    for mod in PIL materialyoucolor; do
        if python -c "import $mod" >/dev/null 2>&1; then
            ok "python: $mod"
        else
            fail "python-Modul $mod fehlt"
            [ "$mod" = PIL ] && missing+=(python-pillow) || missing+=(python-materialyoucolor)
        fi
    done

    if [ -n "$(fc-list 2>/dev/null | grep -i "material symbols")" ]; then
        ok "Schrift: Material Symbols"
    else
        warn "Material Symbols nicht gefunden — die Bar zeigt sonst leere Kaestchen"
        missing+=(ttf-material-symbols-variable-git)
    fi

    if [ ${#missing[@]} -gt 0 ] && [ "$INSTALL_DEPS" = 1 ] && [ "$CHECK_ONLY" = 0 ]; then
        local helper=""
        for h in paru yay; do command -v "$h" >/dev/null 2>&1 && { helper="$h"; break; }; done
        if [ -n "$helper" ]; then
            step "Installiere: ${missing[*]}"
            run "$helper" -S --needed "${missing[@]}"
            FAILED=0
        else
            warn "Kein paru/yay gefunden — bitte von Hand: sudo pacman -S ${missing[*]}"
        fi
    elif [ ${#missing[@]} -gt 0 ]; then
        warn "Nachinstallieren mit: ./install.sh --install-deps   (oder pacman -S ${missing[*]})"
    fi
}

# ------------------------------------------------------------- 2. Links ---
link_files() {
    step "Befehle und Completions verlinken"
    link "$DI_DIR/bin/dynamic-island" "$BIN_DIR/dynamic-island"
    link "$DI_DIR/scripts/hypr-profile" "$BIN_DIR/hypr-profile"
    link "$DI_DIR/scripts/theme-set" "$BIN_DIR/theme-set"
    link "$DI_DIR/completions/dynamic-island.fish" "$CONFIG_DIR/fish/completions/dynamic-island.fish"

    case ":$PATH:" in
        *":$BIN_DIR:"*) ok "~/.local/bin liegt im PATH" ;;
        *) warn "~/.local/bin fehlt im PATH — in die Shell-Config aufnehmen" ;;
    esac
}

# ----------------------------------------------------- 3. Verzeichnisse ---
make_dirs() {
    step "Verzeichnisse"
    for d in "$STATE_DIR/$SHELL_NAME/wallpaper" "$STATE_DIR/$SHELL_NAME/record" \
             "$CACHE_DIR/$SHELL_NAME" "$HOME/Pictures/Wallpapers" "$HOME/Pictures/Screenshots"; do
        if [ -d "$d" ]; then
            skip "~${d#$HOME}"
        else
            run mkdir -p "$d"
            [ "$DRY_RUN" = 1 ] || ok "~${d#$HOME} angelegt"
        fi
    done
}

# -------------------------------------------------------- 4. Migration ---
migrate_state() {
    local old="$STATE_DIR/caelestia" new="$STATE_DIR/$SHELL_NAME"
    [ -d "$old" ] || return 0
    step "Uebernahme aus dem Caelestia-Status (wird nur kopiert, nie verschoben)"
    for f in scheme.json sequences.txt wallpaper/path.txt; do
        if [ -e "$new/$f" ]; then
            skip "$f vorhanden"
        elif [ -e "$old/$f" ]; then
            run mkdir -p "$(dirname "$new/$f")"
            run cp "$old/$f" "$new/$f"
            ok "$f uebernommen"
        fi
    done
    if [ -e "$new/wallpaper/path.txt" ] && [ ! -e "$new/wallpaper/current" ]; then
        run ln -sfn "$(cat "$new/wallpaper/path.txt")" "$new/wallpaper/current"
        ok "wallpaper/current gesetzt"
    fi
}

# ------------------------------------------------- 5. Farbschema setzen ---
seed_scheme() {
    step "Farbschema"
    if [ -s "$STATE_DIR/$SHELL_NAME/scheme.json" ]; then
        skip "scheme.json vorhanden ($("$BIN_DIR/dynamic-island" scheme get -n 2>/dev/null || echo '?'))"
        return 0
    fi
    [ "$DRY_RUN" = 1 ] && { warn "wuerde ein Schema erzeugen"; return 0; }

    local wp
    wp="$(find "$HOME/Pictures/Wallpapers" -maxdepth 1 -type f \
         \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) 2>/dev/null | head -1)"
    if [ -n "$wp" ]; then
        "$BIN_DIR/dynamic-island" wallpaper -f "$wp" && ok "Schema aus $(basename "$wp") erzeugt"
    else
        "$BIN_DIR/dynamic-island" scheme set -n island -m dark && ok "Statisches Schema 'island' gesetzt"
        warn "Keine Wallpaper in ~/Pictures/Wallpapers — spaeter: dynamic-island wallpaper -f BILD"
    fi
}

# ------------------------------------------------------- 6. Hypr-Profil ---
hypr_profile() {
    step "Hyprland-Profil"
    local pf="$CONFIG_DIR/hypr/profile"
    if [ ! -d "$CONFIG_DIR/hypr" ]; then
        fail "~/.config/hypr fehlt — liegt das Repo wirklich unter ~/.config?"
        return 0
    fi
    if [ -f "$pf" ]; then
        skip "aktives Profil: $(cat "$pf")"
    else
        run sh -c "printf simple > '$pf'"
        ok "Profil auf 'simple' gesetzt (= Dynamic Island)"
    fi
    [ -d "$CONFIG_DIR/quickshell/$SHELL_NAME" ] \
        && ok "Shell-Config ~/.config/quickshell/$SHELL_NAME gefunden" \
        || fail "Shell-Config ~/.config/quickshell/$SHELL_NAME fehlt"
}

# --------------------------------------------------- 7. Fish-Sequenzen ---
fish_hook() {
    local cf="$CONFIG_DIR/fish/config.fish"
    step "Terminalfarben (fish)"
    [ -f "$cf" ] || { skip "keine fish-Config"; return 0; }
    if grep -q "state/$SHELL_NAME/sequences.txt" "$cf"; then
        skip "sequences.txt wird schon eingelesen"
    else
        warn "In $cf ergaenzen:  cat ~/.local/state/$SHELL_NAME/sequences.txt 2> /dev/null"
    fi
}

# ------------------------------------------------------------- Abschluss ---
summary() {
    step "Ergebnis"
    if [ "$FAILED" = 1 ]; then
        printf '  %sEs fehlt noch etwas (siehe oben).%s\n' "$c_yellow" "$c_reset"
    else
        printf '  %sAlles eingerichtet.%s\n' "$c_green" "$c_reset"
    fi
    [ "$CHECK_ONLY" = 1 ] && return 0
    cat <<EOF

  Weiter geht es mit:
    dynamic-island shell -d        Shell starten
    hypr-profile status            Profil und Shell pruefen
    hyprctl reload                 Hyprland-Config neu laden
    dynamic-island wallpaper -r    zufaelliges Wallpaper + Farbschema

  Profile wechseln:  CTRL + SUPER + SHIFT + P   (oder hypr-profile toggle)
EOF
}

check_links() {
    step "Befehle und Completions"
    local f short
    for f in "$BIN_DIR/dynamic-island" "$BIN_DIR/hypr-profile" "$BIN_DIR/theme-set" \
             "$CONFIG_DIR/fish/completions/dynamic-island.fish"; do
        short="~${f#$HOME}"
        if [ -e "$f" ]; then ok "$short"; else fail "$short fehlt"; fi
    done
}

ki_warnung

check_deps
if [ "$CHECK_ONLY" = 1 ]; then check_links; else link_files; fi
make_dirs
migrate_state
seed_scheme
hypr_profile
fish_hook
summary
exit $FAILED
