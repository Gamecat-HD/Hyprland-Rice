.pragma library

// Tastatur-Vorschau der Einstellungsseite Tastenkürzel: deutsches ISO-QWERTZ
// ohne Ziffernblock (TKL). Jede Taste traegt ihre xkb-ID klein, so wie
// HyprBinds sie in combo.key liefert (escape, f1, dead_circumflex, ssharp,
// udiaeresis, …). Masse in Tasteneinheiten (1u = eine Buchstabentaste).
//
//   { id, label, sub, alt, x, y, w, h, mod }
//   label  Hauptlegende, sub  Shift-Zeichen (oben), alt  AltGr-Zeichen (unten rechts)
//   mod    Modifier-Bit der Hyprland-Modmaske (Shift 1, Strg 4, Alt 8, Super 64)
//
// ISO-Enter ist zwei Zeilen hoch und oben breiter – die Vorschau zeichnet
// ihn als Sonderform (iso: true), hier steht er mit der oberen Breite.

var UNITS_WIDE = 18.5;
var UNITS_HIGH = 6.5;

var MODS = [
    { bit: 64, name: "SUPER", label: "Super" },
    { bit: 4, name: "CTRL", label: "Strg" },
    { bit: 8, name: "ALT", label: "Alt" },
    { bit: 1, name: "SHIFT", label: "Shift" }
];

// xkb-Schreibweise, wie Keybinds.fromEvent sie speichert (Hyprland vergleicht
// Tastennamen ohne Gross/Klein, so bleiben Config und Aufnahme einheitlich)
var XKB = {
    escape: "Escape", print: "Print", scroll_lock: "Scroll_Lock", pause: "Pause",
    dead_circumflex: "dead_circumflex", ssharp: "ssharp", dead_acute: "dead_acute",
    backspace: "BackSpace", insert: "Insert", home: "Home", prior: "Prior",
    tab: "Tab", udiaeresis: "udiaeresis", plus: "plus", "return": "Return",
    "delete": "Delete", end: "End", next: "Next", caps_lock: "Caps_Lock",
    odiaeresis: "odiaeresis", adiaeresis: "adiaeresis", numbersign: "numbersign",
    less: "less", comma: "comma", period: "period", minus: "minus",
    up: "up", down: "down", left: "left", right: "right", space: "space",
    menu: "Menu", super_l: "SUPER_L", super_r: "SUPER_R",
    xf86audiomute: "XF86AudioMute", xf86audiomicmute: "XF86AudioMicMute",
    xf86audiolowervolume: "XF86AudioLowerVolume", xf86audioraisevolume: "XF86AudioRaiseVolume",
    xf86audioprev: "XF86AudioPrev", xf86audioplay: "XF86AudioPlay", xf86audionext: "XF86AudioNext",
    xf86monbrightnessdown: "XF86MonBrightnessDown", xf86monbrightnessup: "XF86MonBrightnessUp"
};

function xkbName(id) {
    if (XKB[id] !== undefined)
        return XKB[id];
    if (/^f\d+$/.test(id))
        return id.toUpperCase();
    return id.length === 1 ? id.toUpperCase() : id;
}

// Tasten, die allein (ohne Super/Strg/Alt) gebunden werden duerfen – wie
// Keybinds.fromEvent
function standalone(id) {
    return /^(f\d+|xf86\w+|print|pause|insert)$/.test(id);
}

// Modmaske + Tasten-ID -> "SUPER + ALT + W" (fuer KeyCapture.saveAs)
function keysText(mask, id) {
    var out = [];
    for (var i = 0; i < MODS.length; i++)
        if (mask & MODS[i].bit)
            out.push(MODS[i].name);
    out.push(xkbName(id));
    return out.join(" + ");
}

// Modmaske -> ["Super", "Alt"] (Anzeige, Beschriftungen gehen durch I18n.tr)
function modLabels(mask) {
    var out = [];
    for (var i = 0; i < MODS.length; i++)
        if (mask & MODS[i].bit)
            out.push(MODS[i].label);
    return out;
}

// AltGr-Zeichen (xkb-Name) -> physische Taste. Binds auf "backslash" leuchten
// so auf ß, der Tooltip nennt die echte Kombination.
var ALTGR = {
    backslash: "ssharp", bar: "less", at: "q", braceleft: "7", bracketleft: "8",
    bracketright: "9", braceright: "0", asciitilde: "plus", eurosign: "e", euro: "e",
    mu: "m", twosuperior: "2", threesuperior: "3"
};

// Umkehrung: physische Taste -> [AltGr-Namen]
var ALTGR_OF = null;

function altgrOf(id) {
    if (!ALTGR_OF) {
        ALTGR_OF = {};
        for (var k in ALTGR) {
            if (!ALTGR_OF[ALTGR[k]])
                ALTGR_OF[ALTGR[k]] = [];
            ALTGR_OF[ALTGR[k]].push(k);
        }
    }
    return ALTGR_OF[id] || [];
}

function key(id, label, x, y, w, extra) {
    var k = { id: id, label: label, sub: "", alt: "", x: x, y: y, w: w === undefined ? 1 : w, h: 1, mod: 0 };
    if (extra)
        for (var p in extra)
            k[p] = extra[p];
    return k;
}

function row(ids, labels, x, y, subs, alts) {
    var out = [];
    for (var i = 0; i < ids.length; i++)
        out.push(key(ids[i], labels[i], x + i, y, 1, { sub: subs ? subs[i] : "", alt: alts ? alts[i] : "" }));
    return out;
}

var _keys = null;

function keys() {
    if (_keys)
        return _keys;
    var k = [];
    var y = 0;
    // Funktionsreihe: Esc | 1u | F1–F4 | 0,5u | F5–F8 | 0,5u | F9–F12 || Druck Rollen Pause
    k.push(key("escape", "Esc", 0, y));
    for (var i = 0; i < 12; i++)
        k.push(key("f" + (i + 1), "F" + (i + 1), 2 + i + Math.floor(i / 4) * 0.5, y));
    k.push(key("print", "Druck", 15.5, y));
    k.push(key("scroll_lock", "Rollen", 16.5, y));
    k.push(key("pause", "Pause", 17.5, y));
    // Zahlenreihe
    y = 1.5;
    k = k.concat(row(["dead_circumflex", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "ssharp", "dead_acute"],
                     ["^", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "ß", "´"], 0, y,
                     ["°", "!", "\"", "§", "$", "%", "&", "/", "(", ")", "=", "?", "`"],
                     ["", "", "²", "³", "", "", "", "{", "[", "]", "}", "\\", ""]));
    k.push(key("backspace", "⌫", 13, y, 2));
    k.push(key("insert", "Einfg", 15.5, y));
    k.push(key("home", "Pos1", 16.5, y));
    k.push(key("prior", "Bild↑", 17.5, y));
    // Tab-Reihe
    y = 2.5;
    k.push(key("tab", "Tab", 0, y, 1.5));
    k = k.concat(row(["q", "w", "e", "r", "t", "z", "u", "i", "o", "p", "udiaeresis", "plus"],
                     ["Q", "W", "E", "R", "T", "Z", "U", "I", "O", "P", "Ü", "+"], 1.5, y,
                     ["", "", "", "", "", "", "", "", "", "", "", "*"],
                     ["@", "", "€", "", "", "", "", "", "", "", "", "~"]));
    k.push(key("return", "Enter", 13.5, y, 1.5, { h: 2, iso: true, lowerX: 13.75, lowerW: 1.25 }));
    k.push(key("delete", "Entf", 15.5, y));
    k.push(key("end", "Ende", 16.5, y));
    k.push(key("next", "Bild↓", 17.5, y));
    // Grundreihe
    y = 3.5;
    k.push(key("caps_lock", "Feststell", 0, y, 1.75));
    k = k.concat(row(["a", "s", "d", "f", "g", "h", "j", "k", "l", "odiaeresis", "adiaeresis", "numbersign"],
                     ["A", "S", "D", "F", "G", "H", "J", "K", "L", "Ö", "Ä", "#"], 1.75, y,
                     ["", "", "", "", "", "", "", "", "", "", "", "'"], null));
    // Shift-Reihe
    y = 4.5;
    k.push(key("shift_l", "Shift", 0, y, 1.25, { mod: 1 }));
    k.push(key("less", "<", 1.25, y, 1, { sub: ">", alt: "|" }));
    k = k.concat(row(["y", "x", "c", "v", "b", "n", "m", "comma", "period", "minus"],
                     ["Y", "X", "C", "V", "B", "N", "M", ",", ".", "-"], 2.25, y,
                     ["", "", "", "", "", "", "", ";", ":", "_"],
                     ["", "", "", "", "", "", "µ", "", "", ""]));
    k.push(key("shift_r", "Shift", 12.25, y, 2.75, { mod: 1 }));
    k.push(key("up", "↑", 16.5, y));
    // Untere Reihe
    y = 5.5;
    k.push(key("control_l", "Strg", 0, y, 1.25, { mod: 4 }));
    k.push(key("super_l", "Super", 1.25, y, 1.25, { mod: 64 }));
    k.push(key("alt_l", "Alt", 2.5, y, 1.25, { mod: 8 }));
    k.push(key("space", "", 3.75, y, 6.25));
    k.push(key("iso_level3_shift", "AltGr", 10, y, 1.25));
    k.push(key("super_r", "Super", 11.25, y, 1.25, { mod: 64 }));
    k.push(key("menu", "Menü", 12.5, y, 1.25));
    k.push(key("control_r", "Strg", 13.75, y, 1.25, { mod: 4 }));
    k.push(key("left", "←", 15.5, y));
    k.push(key("down", "↓", 16.5, y));
    k.push(key("right", "→", 17.5, y));
    _keys = k;
    return k;
}

var _ids = null;

// Menge aller IDs auf der Tastatur (fuer "sitzt nirgends")
function onBoard(id) {
    if (!_ids) {
        _ids = {};
        var all = keys();
        for (var i = 0; i < all.length; i++)
            _ids[all[i].id] = true;
    }
    return _ids[id] === true || ALTGR[id] !== undefined;
}

// Medienknoepfe im Gehaeuse (oben rechts), Lautstaerke als Walze
var MEDIA = [
    { id: "xf86audiomicmute", icon: "mic_off", title: "Mikro stumm" },
    { id: "xf86audiomute", icon: "volume_off", title: "Stumm" },
    { id: "xf86audioprev", icon: "skip_previous", title: "Zurück" },
    { id: "xf86audioplay", icon: "play_pause", title: "Play/Pause" },
    { id: "xf86audionext", icon: "skip_next", title: "Weiter" },
    { id: "xf86monbrightnessdown", icon: "brightness_low", title: "Dunkler" },
    { id: "xf86monbrightnessup", icon: "brightness_high", title: "Heller" }
];
var ROLLER = ["xf86audiolowervolume", "xf86audioraisevolume"];

var MOUSE = ["mouse:272", "mouse:273", "mouse:274", "mouse_up", "mouse_down"];

function isMouse(id) {
    return id.indexOf("mouse") === 0;
}

function isMedia(id) {
    if (ROLLER.indexOf(id) >= 0)
        return true;
    for (var i = 0; i < MEDIA.length; i++)
        if (MEDIA[i].id === id)
            return true;
    return false;
}
