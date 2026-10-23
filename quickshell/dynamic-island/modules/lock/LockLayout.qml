pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland

import qs.modules.services.config

// Anordnung von Uhr und Medien-Karte auf dem Sperrbildschirm.
//
// Gespeichert in Config.lock.layout (shell.json):
//
//   { "clock": { "x": 0.5, "y": 0.3,  "size": 1 },
//     "media": { "x": 0.5, "y": 0.92, "size": 1 } }
//
// x/y = Mittelpunkt des Elements als Anteil der Bildschirmbreite/-hoehe (wie
// bei den Desktop-Widgets), size = Vergroesserung (0.5 bis 2). Fehlt ein
// Element oder ist das Objekt leer, gilt die Vorgabe – und die ist genau das
// bisherige Bild: Uhr mittig mit der Oberkante bei 20 % der Hoehe, Karte
// mittig 56 px ueber dem unteren Rand. LockScreen fragt darum nicht nach
// Mittelpunkten, sondern nach dem, was es setzt: waagerechter Versatz von
// der Mitte (offsetX), Oberkante (top) und Vergroesserung (scale).
//
// Bearbeiten (LockEditor.qml): `edit()` nimmt eine Kopie als Entwurf, auf
// den set/preview schreiben; LockScreen liest waehrenddessen den Entwurf.
// Jeder Schritt (Loslassen, Pfeiltaste, Zuruecksetzen) landet im Verlauf
// fuer Strg+Z / Strg+Umschalt+Z. Gespeichert wird gesammelt (400 ms),
// `cancel()` stellt den Stand vom Anfang wieder her.
Singleton {
    id: root

    readonly property var names: ["clock", "media"]
    readonly property real minSize: 0.5
    readonly property real maxSize: 2

    // Was gilt: beim Bearbeiten der Entwurf, sonst die Einstellung
    readonly property var layout: root.editing ? root.draft : root.stored
    readonly property var stored: root.plain(Config.lock.layout)
    readonly property bool custom: Object.keys(root.layout).length > 0

    // ---- Aufloesen ----

    function entry(name: string): var {
        const e = root.layout[name];
        return e && typeof e === "object" ? e : null;
    }

    function isCustom(name: string): bool {
        return root.entry(name) !== null;
    }

    function scale(name: string): real {
        const s = Number(root.entry(name)?.size);
        return isFinite(s) && s > 0 ? Math.max(root.minSize, Math.min(root.maxSize, s)) : 1;
    }

    // Versatz des Mittelpunkts von der Bildschirmmitte in px (0 = mittig)
    function offsetX(name: string, width: real): real {
        const x = Number(root.entry(name)?.x);
        return isFinite(x) ? Math.round((x - 0.5) * width) : 0;
    }

    // Oberkante in px; elemHeight = Hoehe des Elements ohne Vergroesserung
    function top(name: string, height: real, elemHeight: real): real {
        const y = Number(root.entry(name)?.y);
        if (isFinite(y))
            return Math.round(y * height - elemHeight / 2);
        return name === "media" ? height - elemHeight - 56 : Math.round(height * 0.2);
    }

    // ---- Bearbeiten ----

    property bool editing: false
    property string editScreen: ""
    property string selected: ""

    property var draft: ({})
    // Stand beim Start (Abbrechen) und zuletzt festgehaltener Stand (Verlauf)
    property string origin: ""
    property string committed: ""
    property var undoStack: []
    property var redoStack: []
    readonly property bool canUndo: root.undoStack.length > 0
    readonly property bool canRedo: root.redoStack.length > 0

    function plain(v: var): var {
        if (!v || typeof v !== "object")
            return {};
        try {
            return JSON.parse(JSON.stringify(v));
        } catch (e) {
            return {};
        }
    }

    function edit(screenName: string): void {
        if (root.editing)
            return;
        root.draft = root.stored;
        root.origin = JSON.stringify(root.draft);
        root.committed = root.origin;
        root.undoStack = [];
        root.redoStack = [];
        root.selected = "";
        root.editScreen = screenName || (Hyprland.focusedMonitor?.name ?? "");
        root.editing = true;
    }

    // Erst speichern, dann umschalten: `layout` springt so direkt auf den
    // neuen Stand, nicht kurz auf den alten
    function done(): void {
        if (!root.editing)
            return;
        root.selected = "";
        root.flush();
        root.editing = false;
    }

    // Alles seit dem Start verwerfen
    function cancel(): void {
        if (!root.editing)
            return;
        root.draft = JSON.parse(root.origin);
        root.selected = "";
        root.flush();
        root.editing = false;
    }

    function toggleEdit(screenName: string): void {
        if (root.editing)
            root.done();
        else
            root.edit(screenName);
    }

    function clean(e: var): var {
        const out = {};
        for (const k of ["x", "y"]) {
            const v = Number(e?.[k]);
            if (isFinite(v))
                out[k] = Number(Math.max(0, Math.min(1, v)).toFixed(4));
        }
        const s = Number(e?.size);
        out.size = isFinite(s) && s > 0 ? Number(Math.max(root.minSize, Math.min(root.maxSize, s)).toFixed(3)) : 1;
        return out;
    }

    // Waehrend des Ziehens: nur anzeigen, nicht festhalten
    function preview(name: string, e: var): void {
        if (!root.editing)
            return;
        root.draft = Object.assign({}, root.draft, { [name]: root.clean(e) });
    }

    // Festhalten: in den Verlauf, gesammelt speichern
    function set(name: string, e: var): void {
        root.apply(Object.assign({}, root.draft, { [name]: root.clean(e) }));
    }

    function reset(): void {
        root.apply({});
    }

    function apply(next: var): void {
        if (!root.editing)
            return;
        const text = JSON.stringify(next);
        if (text === root.committed) {
            root.draft = next;
            return;
        }
        root.undoStack = [...root.undoStack, root.committed];
        root.redoStack = [];
        root.draft = next;
        root.committed = text;
        saveDelay.restart();
    }

    function undo(): void {
        if (!root.canUndo)
            return;
        const text = root.undoStack[root.undoStack.length - 1];
        root.undoStack = root.undoStack.slice(0, -1);
        root.redoStack = [...root.redoStack, root.committed];
        root.restore(text);
    }

    function redo(): void {
        if (!root.canRedo)
            return;
        const text = root.redoStack[root.redoStack.length - 1];
        root.redoStack = root.redoStack.slice(0, -1);
        root.undoStack = [...root.undoStack, root.committed];
        root.restore(text);
    }

    function restore(text: string): void {
        root.draft = JSON.parse(text);
        root.committed = text;
        saveDelay.restart();
    }

    function flush(): void {
        saveDelay.stop();
        if (JSON.stringify(root.draft) !== JSON.stringify(root.stored))
            Config.set("lock", "layout", root.draft);
    }

    Timer {
        id: saveDelay

        interval: 400
        onTriggered: root.flush()
    }
}
