pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Monitore (Einstellungen > Monitore, settings/MonitorsEditor): liest
// `hyprctl -j monitors all`, wendet Aenderungen live per `hyprctl eval`
// an und merkt sich bestaetigte Regeln je Rechner:
//
//   ~/.local/state/dynamic-island/monitors.json   Quelle (format 1)
//     { format: 1, rules: { <key>: { mode, position, scale, transform,
//                                    vrr, disabled, mirror } } }
//   ~/.local/state/dynamic-island/monitors.lua    daraus erzeugt: ein
//     hl.monitor({…}) je Regel. hypr/hyprland.lua laedt die Datei nach
//     seinen festen Vorgaben (pcall(dofile)) – Hyprland nimmt fuer einen
//     Monitor die zuletzt passende Regel, die Shell gewinnt also.
//
// <key> ist `desc:<EDID-Beschreibung>` (Hersteller, Modell, Seriennummer):
// der Port wechselt mit Kabel und Dock, die Beschreibung nicht. Interne
// Panels (eDP-*, LVDS-*, DSI-*) laufen ueber den Portnamen – es gibt nur
// eines je Rechner, und die Vorgabe in hyprland.lua heisst genauso.
//
// Uebernehmen wie bei GNOME: anwenden, dann 15 s "Einstellungen behalten?";
// ohne Antwort oder bei Zuruecksetzen kommt der alte Stand zurueck. Erst
// Behalten schreibt die Dateien. "Standard wiederherstellen" loescht die
// Regel und ruft monitor_default() aus hyprland.lua (Vorgabe von dort,
// sonst bevorzugter Modus + automatische Position) – ebenfalls mit Frage.
Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/.local/state/dynamic-island"
    readonly property string jsonPath: Quickshell.env("DYNAMIC_ISLAND_MONITORS_FILE") || root.dir + "/monitors.json"
    readonly property string luaPath: Quickshell.env("DYNAMIC_ISLAND_MONITORS_LUA") || root.dir + "/monitors.lua"
    // Wie Keybinds.qml: nur die installierte Shell schreibt nach Hyprland
    readonly property bool writesHypr: !!Quickshell.env("DYNAMIC_ISLAND_MONITORS_LUA")
                                       || Quickshell.shellPath("shell.qml") === Quickshell.env("HOME") + "/.config/quickshell/dynamic-island/shell.qml"

    // [{ id, name, key, description, make, model, serial, short,
    //    width, height, refresh, x, y, scale, transform, vrr, vrrMode,
    //    disabled, focused, dpms, mirrorOf, format,
    //    modes: [{ w, h, hz, label }],
    //    resolutions: [{ w, h, label, rates: [hz] }],
    //    rule: {…} | null }]
    property var monitors: []
    property bool loaded: false
    readonly property bool busy: readProc.running || applyProc.running
    property string lastError: ""

    // Gespeicherte Regeln je key (monitors.json)
    property var rules: ({})
    property bool rulesLoaded: false

    // ---- Frage "Einstellungen behalten?" ----
    // Sekunden bis zum automatischen Zuruecksetzen, 0 = keine Frage offen
    property int countdown: 0
    readonly property bool confirming: root.countdown > 0
    readonly property int confirmSeconds: 15
    // Was gerade probeweise gilt und was davor galt
    property var pendingSpecs: []
    property var pendingResets: []
    property var previousSpecs: []
    // Zaehlt jede abgeschlossene Anwendung hoch (Editor verwirft dann seine
    // ausstehenden Aenderungen)
    property int applied: 0

    // ---- Lesen ------------------------------------------------------------

    function refresh(): void {
        if (readProc.running)
            return;
        readProc.running = true;
    }

    function keyOf(name: string, description: string): string {
        if (/^(eDP|LVDS|DSI)-/.test(name) || description === "")
            return name;
        return "desc:" + description;
    }

    function parseMode(s: string): var {
        const m = /^(\d+)x(\d+)@([\d.]+)/.exec(s);
        if (!m)
            return null;
        const hz = Math.round(parseFloat(m[3]) * 100) / 100;
        return { w: Number(m[1]), h: Number(m[2]), hz, label: root.modeLabel(Number(m[1]), Number(m[2]), hz) };
    }

    function hzLabel(hz: real): string {
        return Number.isInteger(hz) ? String(hz) : hz.toFixed(2).replace(/\.?0+$/, "");
    }

    function modeLabel(w: int, h: int, hz: real): string {
        return `${w}x${h}@${root.hzLabel(hz)}`;
    }

    function parse(text: string): var {
        let list;
        try {
            list = JSON.parse(text);
        } catch (e) {
            root.lastError = "hyprctl monitors: " + e;
            return root.monitors;
        }
        if (!Array.isArray(list))
            return root.monitors;
        const out = [];
        for (const j of list) {
            const modes = [];
            const seen = {};
            for (const s of (j.availableModes ?? [])) {
                const m = root.parseMode(String(s));
                if (!m || seen[m.label])
                    continue;
                seen[m.label] = true;
                modes.push(m);
            }
            // Nach Aufloesung gruppiert, groesste zuerst, Raten absteigend
            const byRes = {};
            const resolutions = [];
            for (const m of modes) {
                const k = `${m.w}x${m.h}`;
                if (!byRes[k]) {
                    byRes[k] = { w: m.w, h: m.h, label: k, rates: [] };
                    resolutions.push(byRes[k]);
                }
                byRes[k].rates.push(m.hz);
            }
            resolutions.sort((a, b) => b.w * b.h - a.w * a.h || b.w - a.w);
            for (const r of resolutions)
                r.rates.sort((a, b) => b - a);

            const name = String(j.name ?? "");
            const description = String(j.description ?? "");
            const key = root.keyOf(name, description);
            const rule = root.rules[key] ?? null;
            const disabled = !!j.disabled;
            // Abgeschaltete Monitore melden 0x0 – fuers Bild den ersten Modus
            const first = modes[0] ?? { w: 1920, h: 1080, hz: 60 };
            const width = Number(j.width) || first.w;
            const height = Number(j.height) || first.h;
            const refresh = Math.round((Number(j.refreshRate) || first.hz) * 100) / 100;
            const make = String(j.make ?? "").trim();
            const model = String(j.model ?? "").trim();
            out.push({
                id: Number(j.id ?? 0),
                name,
                key,
                description,
                make,
                model,
                serial: String(j.serial ?? "").trim(),
                // Kurzname fuers Bild: Modell, sonst Hersteller, sonst Port
                short: model !== "" && !/^0x/i.test(model) ? model : make !== "" ? make : name,
                width,
                height,
                refresh,
                x: Number(j.x ?? 0),
                y: Number(j.y ?? 0),
                scale: Number(j.scale ?? 1) || 1,
                transform: Number(j.transform ?? 0) || 0,
                vrr: !!j.vrr,
                // Regelwert 0/1/2, sonst der gemeldete Zustand
                vrrMode: rule && rule.vrr !== undefined ? Number(rule.vrr) : (j.vrr ? 1 : 0),
                disabled,
                focused: !!j.focused,
                dpms: j.dpmsStatus !== false,
                mirrorOf: j.mirrorOf && j.mirrorOf !== "none" ? String(j.mirrorOf) : "",
                format: String(j.currentFormat ?? ""),
                modes,
                resolutions,
                rule
            });
        }
        out.sort((a, b) => a.id - b.id);
        // mirrorOf meldet hyprctl je nach Stand als ID ("1") statt Port –
        // Regeln (mirror = …) und die Chips brauchen den Portnamen
        for (const o of out) {
            if (/^\d+$/.test(o.mirrorOf))
                o.mirrorOf = out.find(x => x.id === Number(o.mirrorOf))?.name ?? "";
        }
        return out;
    }

    Process {
        id: readProc

        command: ["hyprctl", "-j", "monitors", "all"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.monitors = root.parse(text);
                root.loaded = true;
            }
        }
    }

    // Nach Stecken/Ziehen und nach dem Umschalten erst einmal setzen lassen
    Timer {
        id: refreshDelay

        interval: 500
        onTriggered: root.refresh()
    }

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            const n = event.name;
            if (n === "monitoradded" || n === "monitorremoved" || n === "configreloaded")
                refreshDelay.restart();
        }
    }

    // ---- Regeln als Lua ----------------------------------------------------

    function luaString(s: string): string {
        return '"' + String(s).replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\n/g, "\\n") + '"';
    }

    // spec: { output, mode, position, scale, transform, vrr, disabled, mirror }
    function luaOf(spec: var): string {
        const f = [`output = ${root.luaString(spec.output)}`];
        if (spec.disabled) {
            f.push("disabled = true");
            return `hl.monitor({ ${f.join(", ")} })`;
        }
        if (spec.mode !== undefined && spec.mode !== "")
            f.push(`mode = ${root.luaString(spec.mode)}`);
        if (spec.position !== undefined && spec.position !== "")
            f.push(`position = ${root.luaString(spec.position)}`);
        if (spec.scale !== undefined && spec.scale !== null)
            f.push(typeof spec.scale === "number" ? `scale = ${spec.scale}` : `scale = ${root.luaString(spec.scale)}`);
        if (spec.transform !== undefined)
            f.push(`transform = ${Number(spec.transform) || 0}`);
        if (spec.vrr !== undefined)
            f.push(`vrr = ${Number(spec.vrr) || 0}`);
        if (spec.mirror)
            f.push(`mirror = ${root.luaString(spec.mirror)}`);
        return `hl.monitor({ ${f.join(", ")} })`;
    }

    readonly property string luaText: {
        const lines = [
            "-- Von der Shell erzeugt (Einstellungen > Monitore), nicht von Hand",
            "-- bearbeiten: modules/services/hypr/Monitors.qml schreibt die Datei",
            "-- aus monitors.json neu.",
            ""
        ];
        const keys = Object.keys(root.rules).sort();
        for (const k of keys)
            lines.push(root.luaOf(Object.assign({ output: k }, root.rules[k])));
        lines.push("");
        return lines.join("\n");
    }

    // Aktueller Stand eines Monitors als Regel (zum Zurueckdrehen)
    function snapshot(m: var): var {
        if (m.disabled)
            return { output: m.key, disabled: true };
        const spec = {
            output: m.key,
            mode: root.modeLabel(m.width, m.height, m.refresh),
            position: `${m.x}x${m.y}`,
            scale: m.scale,
            transform: m.transform,
            vrr: m.vrrMode
        };
        if (m.mirrorOf !== "")
            spec.mirror = m.mirrorOf;
        return spec;
    }

    // ---- Anwenden ------------------------------------------------------------

    // specs: Regeln, die probeweise gelten sollen; resets: keys, deren Regel
    // auf die Vorgabe zurueck soll (monitor_default in hyprland.lua).
    // previous: der Stand davor (snapshot je betroffenem Monitor).
    function apply(specs: var, resets: var, previous: var): void {
        if (applyProc.running)
            return;
        const chunk = [];
        for (const s of specs)
            chunk.push(root.luaOf(s));
        for (const r of resets) {
            const m = root.monitors.find(x => x.key === r);
            chunk.push(`monitor_default(${root.luaString(r)}, ${root.luaString(m?.name ?? r)})`);
        }
        if (chunk.length === 0)
            return;
        root.lastError = "";
        root.pendingSpecs = specs;
        root.pendingResets = resets;
        root.previousSpecs = previous;
        applyProc.ask = true;
        applyProc.command = ["hyprctl", "eval", chunk.join("\n")];
        applyProc.running = true;
    }

    // Nur den alten Stand wiederherstellen, ohne Frage
    function restore(specs: var): void {
        const chunk = specs.map(s => root.luaOf(s));
        if (chunk.length === 0)
            return;
        applyProc.ask = false;
        applyProc.command = ["hyprctl", "eval", chunk.join("\n")];
        applyProc.running = true;
    }

    function keep(): void {
        if (!root.confirming)
            return;
        root.countdown = 0;
        const next = Object.assign({}, root.rules);
        for (const s of root.pendingSpecs) {
            const r = Object.assign({}, s);
            delete r.output;
            next[s.output] = r;
        }
        for (const k of root.pendingResets)
            delete next[k];
        root.pendingSpecs = [];
        root.pendingResets = [];
        root.previousSpecs = [];
        root.commit(next);
        root.applied++;
        refreshDelay.restart();
    }

    function revert(): void {
        if (!root.confirming)
            return;
        root.countdown = 0;
        const prev = root.previousSpecs;
        root.pendingSpecs = [];
        root.pendingResets = [];
        root.previousSpecs = [];
        root.restore(prev);
    }

    Process {
        id: applyProc

        property bool ask: true

        // Ausgabe erst beim Exit auswerten (die Sammler sind dann komplett):
        // ueber onStreamFinished kaeme ein Fehler womoeglich erst nach dem
        // Start der Frage an
        stdout: StdioCollector {
            id: applyOut
        }
        stderr: StdioCollector {
            id: applyErr
        }
        onExited: (code, status) => {
            const out = applyOut.text.trim();
            const err = applyErr.text.trim();
            if (err !== "")
                root.lastError = err;
            else if (out !== "" && out !== "ok")
                root.lastError = out;
            if (code !== 0 && root.lastError === "")
                root.lastError = "hyprctl eval: Code " + code;
            if (applyProc.ask && root.lastError === "")
                root.countdown = root.confirmSeconds;
            else if (applyProc.ask) {
                // Nichts gilt – nichts zu fragen
                root.pendingSpecs = [];
                root.pendingResets = [];
                root.previousSpecs = [];
            }
            refreshDelay.restart();
        }
    }

    Timer {
        running: root.confirming
        interval: 1000
        repeat: true
        onTriggered: {
            if (root.countdown <= 1)
                root.revert();
            else
                root.countdown--;
        }
    }

    // ---- monitors.json / monitors.lua --------------------------------------

    function commit(next: var): void {
        root.rules = next;
        saveGuard.restart();
        jsonFile.setText(JSON.stringify({ format: 1, rules: next }, null, 2) + "\n");
        if (root.writesHypr)
            luaFile.setText(root.luaText);
    }

    function readRules(): void {
        let parsed;
        try {
            parsed = JSON.parse(jsonFile.text() || "{}");
        } catch (e) {
            return;
        }
        root.rules = parsed.rules && typeof parsed.rules === "object" ? parsed.rules : {};
        root.rulesLoaded = true;
        // Regelwerte (vrr) haengen an den Monitoren
        if (root.loaded)
            root.refresh();
    }

    Timer {
        id: saveGuard

        interval: 400
    }

    FileView {
        id: jsonFile

        path: root.jsonPath
        watchChanges: true
        blockLoading: true
        printErrors: false
        atomicWrites: true
        onLoaded: if (!saveGuard.running) root.readRules()
        onLoadFailed: root.rulesLoaded = true
        onFileChanged: if (!saveGuard.running) reload()
    }

    FileView {
        id: luaFile

        path: root.luaPath
        blockLoading: true
        blockWrites: true
        printErrors: false
        atomicWrites: true
    }

    // qs -c dynamic-island ipc call monitors list
    IpcHandler {
        target: "monitors"

        function list(): string {
            return JSON.stringify(root.monitors.map(m => ({ name: m.name, key: m.key, mode: root.modeLabel(m.width, m.height, m.refresh), position: `${m.x}x${m.y}`, scale: m.scale, transform: m.transform, vrr: m.vrrMode, disabled: m.disabled, rule: m.rule })), null, 2);
        }
        function rules(): string {
            return root.luaText;
        }
        function refresh(): void {
            root.refresh();
        }
        function keep(): void {
            root.keep();
        }
        function revert(): void {
            root.revert();
        }
    }

    Component.onCompleted: root.refresh()
}
