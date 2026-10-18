pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Tastenkuerzel aus Hyprland fuer die Uebersicht (KeybindsPanel).
//
// Quelle ist `hyprctl binds -j`, nicht eine eigene Liste: die Binds tragen in
// hypr/profiles/simple.lua eine Beschreibung "Gruppe|Text" (optional
// "|Anzeige" statt der echten Taste, z.B. "1 … 0"). Nur beschriebene Binds
// erscheinen. Gleicher Text in derselben Gruppe wird eine Zeile mit mehreren
// Kuerzeln (Medientaste + Ersatzkuerzel).
//
// Gelesen wird beim Oeffnen der Uebersicht (refresh) und nach jedem
// `hyprctl reload`, solange schon einmal gelesen wurde.
//
// Ausfuehren (run): hypr/hyprland.lua legt die Aktion jedes beschriebenen
// Binds unter seiner Beschreibung ab, `hyprctl eval` ruft sie im laufenden
// Hyprland auf. Nicht anklickbar sind Maus-Binds (Ziehen/Groesse) und
// Sammelzeilen mit eigener Anzeige ("1 … 0", "Pfeile") – ein Klick wuerde
// dort nur einen der Binds ausloesen.
Singleton {
    id: root

    // [{ name, entries: [{ text, id, clickable, combos: [["Super", "Q"], ...] }] }]
    property var groups: []
    property bool loaded: false

    function refresh(): void {
        if (!proc.running)
            proc.running = true;
    }

    function run(entry: var): void {
        if (!entry?.clickable)
            return;
        // Lange Lua-Klammern: die Beschreibung darf so jedes Zeichen enthalten
        // ausser der schliessenden Folge selbst
        Quickshell.execDetached(["hyprctl", "eval", `run_keybind([==[${entry.id}]==])`]);
    }

    // Reihenfolge wie auf der Tastatur ueblich
    readonly property var modBits: [
        { bit: 64, name: "Super" },
        { bit: 4, name: "Strg" },
        { bit: 8, name: "Alt" },
        { bit: 1, name: "Shift" }
    ]

    readonly property var keyNames: ({
        left: "←", right: "→", up: "↑", down: "↓",
        comma: ",", period: ".", backslash: "\\", minus: "-", plus: "+",
        space: "Leertaste", tab: "Tab", escape: "Esc", return: "Enter",
        print: "Druck", delete: "Entf",
        "mouse:272": "Linksklick", "mouse:273": "Rechtsklick", "mouse:274": "Mittelklick",
        mouse_down: "Rad ↓", mouse_up: "Rad ↑",
        xf86audiomute: "Stumm-Taste", xf86audiomicmute: "Mikro-Taste",
        xf86audioraisevolume: "Lauter-Taste", xf86audiolowervolume: "Leiser-Taste",
        xf86monbrightnessup: "Heller-Taste", xf86monbrightnessdown: "Dunkler-Taste",
        xf86audioplay: "Play-Taste", xf86audionext: "Weiter-Taste", xf86audioprev: "Zurück-Taste"
    })

    function keyLabel(key: string): string {
        const known = root.keyNames[key.toLowerCase()];
        if (known)
            return known;
        // Modifier allein (SUPER loslassen): die Modmaske nennt ihn schon
        if (/^(super|control|alt|shift)_[lr]$/i.test(key))
            return "";
        return key.length === 1 ? key.toUpperCase() : key;
    }

    function combo(bind: var, label: string): var {
        const keys = root.modBits.filter(m => bind.modmask & m.bit).map(m => m.name);
        const key = label || root.keyLabel(bind.key);
        if (key)
            keys.push(key);
        return keys;
    }

    function parse(text: string): void {
        let binds = [];
        try {
            binds = JSON.parse(text);
        } catch (e) {
            console.warn("HyprBinds: hyprctl binds -j nicht lesbar:", e);
            return;
        }

        const order = [];
        const byName = {};
        for (const bind of binds) {
            if (!bind.description)
                continue;
            const parts = bind.description.split("|");
            if (parts.length < 2)
                continue;
            const [groupName, text, label] = parts;

            let group = byName[groupName];
            if (!group) {
                group = byName[groupName] = { name: groupName, entries: [] };
                order.push(group);
            }

            const keys = root.combo(bind, label ?? "");
            const entry = group.entries.find(e => e.text === text);
            if (entry)
                entry.combos.push(keys);
            else
                group.entries.push({
                    text,
                    id: bind.description,
                    clickable: !label && !bind.mouse,
                    combos: [keys]
                });
        }

        root.groups = order;
        root.loaded = true;
    }

    Process {
        id: proc

        command: ["hyprctl", "binds", "-j"]

        stdout: StdioCollector {
            onStreamFinished: root.parse(this.text)
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            if (event.name === "configreloaded" && root.loaded)
                root.refresh();
        }
    }
}
