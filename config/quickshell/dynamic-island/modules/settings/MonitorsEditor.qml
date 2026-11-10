pragma ComponentBehavior: Bound
import QtQuick

import qs
import qs.modules.services.config
import qs.modules.services.hypr
import qs.modules.widgets

// Einstellungsseite Monitore (Config.meta editor "monitors").
//
// Oben die Anordnung: jeder Monitor als Kaertchen in seiner logischen
// Groesse (Pixel / Skalierung, gedreht bei 90/270), ziehbar; beim Loslassen
// rastet er an den Kanten der Nachbarn ein und liegt nie auf einem anderen.
// Klick waehlt. Darunter die Werte des gewaehlten Monitors: Aktiv,
// Aufloesung, Bildwiederholrate, Skalierung, Drehung, VRR, Spiegeln.
// Unten die Leiste: ausstehende Aenderungen, Verwerfen, Uebernehmen – nach
// dem Uebernehmen fragt sie 15 s lang "Einstellungen behalten?"
// (Monitors.qml dreht sonst zurueck).
//
// Aenderungen sammeln sich in `pending` je Portname und werden erst mit
// Uebernehmen als Regeln (hl.monitor) an Hyprland gegeben.
Item {
    id: editor

    implicitHeight: content.implicitHeight

    // ---- Zustand ----
    property string selectedName: ""
    // { [name]: { w, h, hz, x, y, scale, transform, vrr, disabled, mirror } }
    // – nur die Felder, die vom gemeldeten Stand abweichen
    property var pending: ({})

    readonly property var monitors: Monitors.monitors
    readonly property var selected: editor.monitors.find(m => m.name === editor.selectedName)
                                    ?? editor.monitors.find(m => m.focused)
                                    ?? editor.monitors[0] ?? null
    readonly property var current: editor.selected ? editor.effective(editor.selected) : null
    readonly property int changeCount: Object.keys(editor.pending).length
    readonly property bool dirty: editor.changeCount > 0
    readonly property bool narrow: editor.width < 760
    readonly property bool locked: Monitors.confirming || Monitors.busy

    readonly property var scaleChoices: [1, 1.25, 1.5, 1.6, 2]
    readonly property var transformChoices: [
        { value: 0, label: "0°", icon: "crop_landscape" },
        { value: 1, label: "90°", icon: "crop_portrait" },
        { value: 2, label: "180°", icon: "crop_landscape" },
        { value: 3, label: "270°", icon: "crop_portrait" }
    ]

    // Nach dem Behalten/Zuruecksetzen ist alles im gemeldeten Stand
    Connections {
        target: Monitors

        function onAppliedChanged(): void {
            editor.pending = {};
        }
    }

    Component.onCompleted: Monitors.refresh()

    // ---- Werte ----

    // Gemeldeter Stand + ausstehende Aenderungen eines Monitors
    function effective(m: var): var {
        const p = editor.pending[m.name] ?? {};
        const out = {
            name: m.name,
            w: p.w ?? m.width,
            h: p.h ?? m.height,
            hz: p.hz ?? m.refresh,
            x: p.x ?? m.x,
            y: p.y ?? m.y,
            scale: p.scale ?? m.scale,
            transform: p.transform ?? m.transform,
            vrr: p.vrr ?? m.vrrMode,
            disabled: p.disabled ?? m.disabled,
            mirror: p.mirror ?? m.mirrorOf
        };
        const rot = out.transform % 2 === 1;
        out.lw = Math.round((rot ? out.h : out.w) / out.scale);
        out.lh = Math.round((rot ? out.w : out.h) / out.scale);
        return out;
    }

    function set(name: string, patch: var): void {
        const m = editor.monitors.find(x => x.name === name);
        if (!m)
            return;
        const base = { w: m.width, h: m.height, hz: m.refresh, x: m.x, y: m.y, scale: m.scale, transform: m.transform, vrr: m.vrrMode, disabled: m.disabled, mirror: m.mirrorOf };
        const next = Object.assign({}, editor.pending);
        const entry = Object.assign({}, next[name] ?? {}, patch);
        for (const k of Object.keys(entry))
            if (entry[k] === base[k])
                delete entry[k];
        if (Object.keys(entry).length === 0)
            delete next[name];
        else
            next[name] = entry;
        editor.pending = next;
    }

    function discard(): void {
        editor.pending = {};
    }

    // Hyprland will ganzzahlige logische Groessen – sonst nimmt es den
    // naechsten Wert in 1/120-Schritten
    function cleanScale(w: int, h: int, s: real): bool {
        return Math.abs(w / s - Math.round(w / s)) < 0.0001 && Math.abs(h / s - Math.round(h / s)) < 0.0001;
    }

    function nearestScale(w: int, h: int, s: real): real {
        if (editor.cleanScale(w, h, s))
            return s;
        const base = Math.round(s * 120);
        for (let i = 1; i < 120; i++) {
            for (const k of [base + i, base - i]) {
                if (k < 60)
                    continue;
                if (editor.cleanScale(w, h, k / 120))
                    return Math.round(k / 120 * 1000) / 1000;
            }
        }
        return s;
    }

    function scaleLabel(s: real): string {
        return (Math.round(s * 100) / 100).toString().replace(".", ",") + "×";
    }

    // Wie viele Monitore nach den Aenderungen an sind
    readonly property int enabledCount: editor.monitors.filter(m => !editor.effective(m).disabled).length

    // ---- Uebernehmen ----

    function applyPending(): void {
        const specs = [];
        const previous = [];
        for (const name of Object.keys(editor.pending)) {
            const m = editor.monitors.find(x => x.name === name);
            if (!m)
                continue;
            const v = editor.effective(m);
            previous.push(Monitors.snapshot(m));
            if (v.disabled) {
                specs.push({ output: m.key, disabled: true });
                continue;
            }
            const p = editor.pending[name];
            const spec = {
                output: m.key,
                mode: Monitors.modeLabel(v.w, v.h, v.hz),
                // Frisch eingeschaltet ohne Platz: Hyprland setzt ihn daneben
                position: m.disabled && p.x === undefined && p.y === undefined ? "auto" : `${v.x}x${v.y}`,
                scale: v.scale,
                transform: v.transform,
                vrr: v.vrr
            };
            if (v.mirror !== "")
                spec.mirror = v.mirror;
            specs.push(spec);
        }
        Monitors.apply(specs, [], previous);
    }

    function resetSelected(): void {
        const m = editor.selected;
        if (!m)
            return;
        const next = Object.assign({}, editor.pending);
        delete next[m.name];
        editor.pending = next;
        Monitors.apply([], [m.key], [Monitors.snapshot(m)]);
    }

    // ---- Anordnung (logische Pixel) ----

    readonly property var rects: {
        const out = [];
        for (const m of editor.monitors) {
            const v = editor.effective(m);
            if (v.disabled)
                continue;
            out.push({ name: m.name, x: v.x, y: v.y, w: v.lw, h: v.lh });
        }
        return out;
    }

    // Einrasten an Nachbarkanten, Ueberlappung aufloesen, Kontakt halten
    function place(name: string, lx: real, ly: real, snap: real): point {
        const me = editor.rects.find(r => r.name === name);
        if (!me)
            return Qt.point(Math.round(lx), Math.round(ly));
        const others = editor.rects.filter(r => r.name !== name);
        let x = lx, y = ly;
        let bestX = snap, bestY = snap, sx = null, sy = null;
        for (const o of others) {
            for (const cx of [o.x - me.w, o.x + o.w, o.x, o.x + o.w - me.w]) {
                const d = Math.abs(cx - x);
                if (d < bestX) {
                    bestX = d;
                    sx = cx;
                }
            }
            for (const cy of [o.y - me.h, o.y + o.h, o.y, o.y + o.h - me.h]) {
                const d = Math.abs(cy - y);
                if (d < bestY) {
                    bestY = d;
                    sy = cy;
                }
            }
        }
        if (sx !== null)
            x = sx;
        if (sy !== null)
            y = sy;
        // Aus Nachbarn herausschieben, immer die kuerzeste Strecke
        for (let i = 0; i < 6; i++) {
            let moved = false;
            for (const o of others) {
                const ox = Math.min(x + me.w, o.x + o.w) - Math.max(x, o.x);
                const oy = Math.min(y + me.h, o.y + o.h) - Math.max(y, o.y);
                if (ox <= 0 || oy <= 0)
                    continue;
                const left = x + me.w - o.x, right = o.x + o.w - x, up = y + me.h - o.y, down = o.y + o.h - y;
                const min = Math.min(left, right, up, down);
                if (min === left)
                    x = o.x - me.w;
                else if (min === right)
                    x = o.x + o.w;
                else if (min === up)
                    y = o.y - me.h;
                else
                    y = o.y + o.h;
                moved = true;
            }
            if (!moved)
                break;
        }
        // Ohne Kontakt kaeme der Zeiger nicht hinueber: an die naechste Kante
        if (others.length > 0 && !editor.touching(x, y, me, others)) {
            let best = null, bestD = Infinity;
            const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));
            for (const o of others) {
                const cands = [
                    { x: o.x - me.w, y: clamp(y, o.y - me.h + 1, o.y + o.h - 1) },
                    { x: o.x + o.w, y: clamp(y, o.y - me.h + 1, o.y + o.h - 1) },
                    { x: clamp(x, o.x - me.w + 1, o.x + o.w - 1), y: o.y - me.h },
                    { x: clamp(x, o.x - me.w + 1, o.x + o.w - 1), y: o.y + o.h }
                ];
                for (const c of cands) {
                    const d = Math.hypot(c.x - x, c.y - y);
                    if (d < bestD && !others.some(p => p !== o && editor.overlaps(c.x, c.y, me, p))) {
                        bestD = d;
                        best = c;
                    }
                }
            }
            if (best) {
                x = best.x;
                y = best.y;
            }
        }
        return Qt.point(Math.round(x), Math.round(y));
    }

    function overlaps(x: real, y: real, me: var, o: var): bool {
        return Math.min(x + me.w, o.x + o.w) - Math.max(x, o.x) > 0 && Math.min(y + me.h, o.y + o.h) - Math.max(y, o.y) > 0;
    }

    function touching(x: real, y: real, me: var, others: var): bool {
        for (const o of others) {
            const vo = Math.min(y + me.h, o.y + o.h) - Math.max(y, o.y) > 0;
            const ho = Math.min(x + me.w, o.x + o.w) - Math.max(x, o.x) > 0;
            if (vo && (x + me.w === o.x || o.x + o.w === x))
                return true;
            if (ho && (y + me.h === o.y || o.y + o.h === y))
                return true;
        }
        return false;
    }

    // ---- Bausteine ----

    component Chip: Rectangle {
        id: chip

        property string label: ""
        property string icon: ""
        property bool selected: false
        property string hint: ""
        signal clicked()

        implicitWidth: chipRow.implicitWidth + (chip.icon !== "" ? 20 : 24)
        implicitHeight: 28
        radius: height / 2
        opacity: enabled ? 1 : 0.4
        color: chip.selected ? Colors.primary
             : chipHover.hovered ? Colors.alpha(Colors.fgSurface, 0.12)
             : Colors.alpha(Colors.fgSurface, 0.06)

        Behavior on color {
            ColorAnimation { duration: Appearance.fadeDuration }
        }
        Fade on opacity {}

        Row {
            id: chipRow

            anchors.centerIn: parent
            spacing: 5

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: chip.icon !== ""
                text: chip.icon
                color: chip.selected ? Colors.fgPrimary : Colors.fgSurface
                font.family: "Material Symbols Outlined"
                font.pixelSize: 15
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.label
                color: chip.selected ? Colors.fgPrimary : Colors.fgSurface
                font.family: Config.font
                font.pixelSize: 11
                font.weight: chip.selected ? Font.DemiBold : Font.Normal
            }
        }

        HoverHandler {
            id: chipHover

            cursorShape: chip.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        }

        TapHandler {
            enabled: chip.enabled
            onTapped: chip.clicked()
        }
    }

    // Knopf im Chip-Stil (wie PluginManager.ActionButton)
    component ActionButton: Rectangle {
        id: button

        required property string icon
        required property string label
        property color tint: Colors.fgSurface
        property bool filled: false
        signal clicked()

        implicitWidth: buttonRow.implicitWidth + 22
        implicitHeight: 28
        radius: height / 2
        opacity: enabled ? 1 : 0.4
        color: button.filled ? (buttonHover.hovered ? Colors.alpha(Colors.primary, 0.85) : Colors.primary)
             : buttonHover.hovered ? Colors.alpha(Colors.fgSurface, 0.12)
             : Colors.alpha(Colors.fgSurface, 0.06)

        Behavior on color {
            ColorAnimation { duration: Appearance.fadeDuration }
        }
        Fade on opacity {}

        Row {
            id: buttonRow

            anchors.centerIn: parent
            spacing: 5

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: button.icon
                color: button.filled ? Colors.fgPrimary : button.tint
                font.family: "Material Symbols Outlined"
                font.pixelSize: 15
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: button.label
                color: button.filled ? Colors.fgPrimary : button.tint
                font.family: Config.font
                font.pixelSize: 11
                font.weight: button.filled ? Font.DemiBold : Font.Normal
            }
        }

        HoverHandler {
            id: buttonHover

            cursorShape: button.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        }

        TapHandler {
            enabled: button.enabled
            onTapped: button.clicked()
        }
    }

    // Schalter wie in SettingsRow
    component Toggle: Rectangle {
        id: sw

        property bool checked: false
        signal toggled()

        width: 40
        height: 22
        radius: height / 2
        opacity: enabled ? 1 : 0.4
        color: sw.checked ? Colors.primary : Colors.alpha(Colors.fgSurface, 0.18)

        Behavior on color {
            ColorAnimation { duration: Appearance.fadeDuration }
        }

        Rectangle {
            width: 16
            height: 16
            radius: 8
            y: 3
            x: sw.checked ? parent.width - width - 3 : 3
            color: sw.checked ? Colors.fgPrimary : Colors.fgSurfaceVariant

            Morph on x {}
        }

        HoverHandler {
            cursorShape: sw.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        }

        TapHandler {
            enabled: sw.enabled
            onTapped: sw.toggled()
        }
    }

    // Karte wie GroupCard
    component Card: Rectangle {
        id: cardItem

        property string title: ""
        default property alias content: cardColumn.data

        implicitHeight: cardColumn.anchors.topMargin + cardColumn.implicitHeight + 12
        radius: 16
        color: Colors.alpha(Colors.fgSurface, 0.035)
        border.width: 1
        border.color: Colors.alpha(Colors.outline, 0.14)

        Text {
            id: cardTitle

            anchors {
                left: parent.left
                top: parent.top
                leftMargin: 14
                topMargin: 10
            }
            text: cardItem.title
            color: Colors.fgSurfaceVariant
            font.family: Config.font
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }

        Column {
            id: cardColumn

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                leftMargin: 14
                rightMargin: 14
                topMargin: cardItem.title !== "" ? 30 : 12
            }
            spacing: 12
        }
    }

    // Eine Zeile der Karte: Titel links, Inhalt (Chips) darunter oder daneben
    component Field: Item {
        id: field

        property string title: ""
        property string note: ""
        default property alias content: fieldFlow.data

        width: parent.width
        implicitHeight: fieldTitle.implicitHeight + 6 + fieldFlow.implicitHeight + (fieldNote.visible ? fieldNote.implicitHeight + 4 : 0)

        Text {
            id: fieldTitle

            text: field.title
            color: Colors.fgSurface
            font.family: Config.font
            font.pixelSize: 12
        }

        Flow {
            id: fieldFlow

            anchors {
                left: parent.left
                right: parent.right
                top: fieldTitle.bottom
                topMargin: 6
            }
            spacing: 6
        }

        Text {
            id: fieldNote

            anchors {
                left: parent.left
                right: parent.right
                top: fieldFlow.bottom
                topMargin: 4
            }
            visible: field.note !== ""
            text: field.note
            color: Colors.fgSurfaceVariant
            font.family: Config.font
            font.pixelSize: 10
            wrapMode: Text.WordWrap
        }
    }

    // ---- Seite ----

    Column {
        id: content

        width: parent.width
        spacing: 12

        // ---- Anordnung ----
        Rectangle {
            id: canvasCard

            width: parent.width
            height: 270
            radius: 16
            color: Colors.alpha(Colors.fgSurface, 0.035)
            border.width: 1
            border.color: Colors.alpha(Colors.outline, 0.14)
            clip: true

            Text {
                anchors {
                    left: parent.left
                    top: parent.top
                    leftMargin: 14
                    topMargin: 10
                }
                text: I18n.tr("Anordnung")
                color: Colors.fgSurfaceVariant
                font.family: Config.font
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }

            Text {
                anchors {
                    right: parent.right
                    top: parent.top
                    rightMargin: 14
                    topMargin: 10
                }
                text: editor.rects.length > 1 ? I18n.tr("Ziehen ordnet an, Klick wählt") : I18n.tr("Klick wählt")
                color: Colors.fgSurfaceVariant
                font.family: Config.font
                font.pixelSize: 10
            }

            // Leer: nichts gemeldet
            Text {
                anchors.centerIn: parent
                visible: editor.monitors.length === 0
                text: Monitors.loaded ? I18n.tr("Keine Monitore gemeldet") : I18n.tr("Lese Monitore …")
                color: Colors.fgSurfaceVariant
                font.family: Config.font
                font.pixelSize: 12
            }

            Item {
                id: canvas

                anchors {
                    fill: parent
                    topMargin: 36
                    bottomMargin: 16
                    leftMargin: 24
                    rightMargin: 24
                }

                // Massstab: alle Monitore in die Flaeche, Ursprung = Rand der Gesamtflaeche
                readonly property var bounds: {
                    const rs = editor.rects;
                    if (rs.length === 0)
                        return { x: 0, y: 0, w: 1, h: 1 };
                    let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
                    for (const r of rs) {
                        x0 = Math.min(x0, r.x);
                        y0 = Math.min(y0, r.y);
                        x1 = Math.max(x1, r.x + r.w);
                        y1 = Math.max(y1, r.y + r.h);
                    }
                    return { x: x0, y: y0, w: Math.max(1, x1 - x0), h: Math.max(1, y1 - y0) };
                }
                // Etwas Luft, damit Ziehen ueber den Rand hinaus sichtbar bleibt
                readonly property real factor: Math.min((canvas.width - 40) / (canvas.bounds.w + canvas.bounds.w * 0.25),
                                                        (canvas.height - 20) / (canvas.bounds.h + canvas.bounds.h * 0.25))
                readonly property real ox: (canvas.width - canvas.bounds.w * canvas.factor) / 2 - canvas.bounds.x * canvas.factor
                readonly property real oy: (canvas.height - canvas.bounds.h * canvas.factor) / 2 - canvas.bounds.y * canvas.factor

                // Logische Zielposition eines Monitors aus seinem Zug (eingerastet)
                function dropPoint(name: string, baseX: real, baseY: real, tx: real, ty: real): point {
                    return editor.place(name, baseX + tx / canvas.factor, baseY + ty / canvas.factor, 18 / canvas.factor);
                }

                Repeater {
                    model: editor.rects

                    Item {
                        id: block

                        required property var modelData
                        readonly property string name: block.modelData.name
                        readonly property var mon: editor.monitors.find(m => m.name === block.name) ?? null
                        readonly property var vals: block.mon ? editor.effective(block.mon) : null
                        readonly property bool selected: editor.selected?.name === block.name
                        readonly property bool dragging: drag.active
                        // Logische Zielposition waehrend des Ziehens (schon eingerastet)
                        readonly property point live: block.dragging
                            ? canvas.dropPoint(block.name, block.modelData.x, block.modelData.y, drag.translation.x, drag.translation.y)
                            : Qt.point(block.modelData.x, block.modelData.y)

                        x: canvas.ox + block.live.x * canvas.factor
                        y: canvas.oy + block.live.y * canvas.factor
                        width: Math.max(8, block.modelData.w * canvas.factor)
                        height: Math.max(8, block.modelData.h * canvas.factor)
                        z: block.dragging ? 2 : block.selected ? 1 : 0

                        Behavior on x {
                            enabled: !block.dragging
                            NumberAnimation { duration: Appearance.fadeDuration; easing.type: Easing.OutCubic }
                        }
                        Behavior on y {
                            enabled: !block.dragging
                            NumberAnimation { duration: Appearance.fadeDuration; easing.type: Easing.OutCubic }
                        }

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: 10
                            color: block.selected ? Colors.alpha(Colors.primary, block.dragging ? 0.32 : 0.22)
                                 : blockHover.hovered ? Colors.alpha(Colors.fgSurface, 0.14)
                                 : Colors.alpha(Colors.fgSurface, 0.08)
                            border.width: block.selected ? 2 : 1
                            border.color: block.selected ? Colors.primary : Colors.alpha(Colors.outline, 0.5)

                            Behavior on color {
                                ColorAnimation { duration: Appearance.fadeDuration }
                            }
                            Behavior on border.color {
                                ColorAnimation { duration: Appearance.fadeDuration }
                            }

                            Column {
                                anchors.centerIn: parent
                                width: parent.width - 12
                                spacing: 1

                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 4

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: block.mon?.focused ?? false
                                        text: "star"
                                        color: block.selected ? Colors.primary : Colors.fgSurface
                                        font.family: "Material Symbols Outlined"
                                        font.pixelSize: 12
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: block.name
                                        color: block.selected ? Colors.primary : Colors.fgSurface
                                        font.family: Config.font
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: (block.vals?.transform ?? 0) % 2 === 1
                                        text: "screen_rotation"
                                        color: Colors.fgSurfaceVariant
                                        font.family: "Material Symbols Outlined"
                                        font.pixelSize: 11
                                    }
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: Math.min(implicitWidth, parent.width)
                                    visible: block.height > 54
                                    text: block.mon?.short ?? ""
                                    color: Colors.fgSurfaceVariant
                                    font.family: Config.font
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    visible: block.height > 70
                                    text: block.vals ? `${block.vals.lw} × ${block.vals.lh}` : ""
                                    color: Colors.fgSurfaceVariant
                                    font.family: Config.font
                                    font.pixelSize: 10
                                }
                            }

                            // Punkt: Aenderung ausstehend
                            Rectangle {
                                anchors {
                                    right: parent.right
                                    top: parent.top
                                    margins: 7
                                }
                                width: 7
                                height: 7
                                radius: 3.5
                                visible: editor.pending[block.name] !== undefined
                                color: Colors.tertiary
                            }
                        }

                        HoverHandler {
                            id: blockHover

                            cursorShape: block.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        }

                        TapHandler {
                            onTapped: editor.selectedName = block.name
                        }

                        DragHandler {
                            id: drag

                            // Letzter Zug – beim Loslassen ist `translation`
                            // je nach Qt-Stand schon zurueckgesetzt
                            property point last: Qt.point(0, 0)

                            target: null
                            onTranslationChanged: if (drag.active) drag.last = Qt.point(drag.translation.x, drag.translation.y)
                            onActiveChanged: {
                                if (drag.active) {
                                    drag.last = Qt.point(0, 0);
                                    editor.selectedName = block.name;
                                    return;
                                }
                                // Nicht ueber `live`: das zeigt nach dem Loslassen
                                // schon wieder den alten Platz
                                const p = canvas.dropPoint(block.name, block.modelData.x, block.modelData.y, drag.last.x, drag.last.y);
                                editor.set(block.name, { x: p.x, y: p.y });
                            }
                        }
                    }
                }
            }
        }

        // ---- Auswahl der Monitore ----
        Flow {
            width: parent.width
            spacing: 6

            Repeater {
                model: editor.monitors

                Chip {
                    required property var modelData

                    readonly property bool off: editor.effective(modelData).disabled

                    label: modelData.name + (off ? " · " + I18n.tr("aus") : "")
                    icon: modelData.focused ? "star" : /^(eDP|LVDS|DSI)-/.test(modelData.name) ? "laptop" : "desktop_windows"
                    selected: editor.selected?.name === modelData.name
                    opacity: off && !selected ? 0.6 : 1
                    onClicked: editor.selectedName = modelData.name
                }
            }
        }

        // ---- Details ----
        Item {
            id: details

            width: parent.width
            visible: editor.selected !== null
            implicitHeight: editor.narrow ? leftCard.implicitHeight + 12 + rightCard.implicitHeight
                                          : Math.max(leftCard.implicitHeight, rightCard.implicitHeight)

            readonly property real colWidth: editor.narrow ? details.width : (details.width - 12) / 2

            Card {
                id: leftCard

                width: details.colWidth
                title: editor.selected ? editor.selected.name + (editor.selected.description !== "" ? " · " + editor.selected.description : "") : ""

                // Kopf: Aktiv + Standard
                Item {
                    width: parent.width
                    implicitHeight: 28

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.tr("Aktiv")
                        color: Colors.fgSurface
                        font.family: Config.font
                        font.pixelSize: 12
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        ActionButton {
                            icon: "restart_alt"
                            label: I18n.tr("Standard wiederherstellen")
                            enabled: !editor.locked
                            onClicked: editor.resetSelected()
                        }

                        Toggle {
                            anchors.verticalCenter: parent.verticalCenter
                            checked: !(editor.current?.disabled ?? false)
                            // Der letzte aktive Monitor bleibt an
                            enabled: !editor.locked && (checked ? editor.enabledCount > 1 : true)
                            onToggled: editor.set(editor.selected.name, { disabled: !editor.current.disabled })
                        }
                    }
                }

                Field {
                    title: I18n.tr("Auflösung")
                    enabled: !editor.locked && !(editor.current?.disabled ?? false)
                    note: editor.current ? I18n.tr("Logisch %1 × %2").arg(editor.current.lw).arg(editor.current.lh) : ""

                    Repeater {
                        model: editor.selected?.resolutions ?? []

                        Chip {
                            required property var modelData

                            label: modelData.label
                            selected: editor.current?.w === modelData.w && editor.current?.h === modelData.h
                            onClicked: {
                                // Rate behalten, wenn die Aufloesung sie bietet, sonst die hoechste
                                const hz = modelData.rates.includes(editor.current.hz) ? editor.current.hz : modelData.rates[0];
                                editor.set(editor.selected.name, { w: modelData.w, h: modelData.h, hz });
                            }
                        }
                    }
                }

                Field {
                    title: I18n.tr("Bildwiederholrate")
                    enabled: !editor.locked && !(editor.current?.disabled ?? false)

                    Repeater {
                        model: {
                            const r = editor.selected?.resolutions.find(x => x.w === editor.current?.w && x.h === editor.current?.h);
                            return r ? r.rates : (editor.current ? [editor.current.hz] : []);
                        }

                        Chip {
                            required property var modelData

                            label: Monitors.hzLabel(modelData) + " Hz"
                            selected: Math.abs((editor.current?.hz ?? 0) - modelData) < 0.5
                            onClicked: editor.set(editor.selected.name, { hz: modelData })
                        }
                    }
                }
            }

            Card {
                id: rightCard

                x: editor.narrow ? 0 : details.colWidth + 12
                y: editor.narrow ? leftCard.implicitHeight + 12 : 0
                width: details.colWidth
                title: I18n.tr("Darstellung")

                Field {
                    id: scaleField

                    title: I18n.tr("Skalierung") + "  ·  " + (editor.current ? editor.scaleLabel(editor.current.scale) : "")
                    enabled: !editor.locked && !(editor.current?.disabled ?? false)

                    readonly property bool clean: editor.current ? editor.cleanScale(editor.current.w, editor.current.h, editor.current.scale) : true
                    note: !scaleField.clean && editor.current
                          ? I18n.tr("Ergibt keine ganzen Pixel – Hyprland nimmt %1").arg(editor.scaleLabel(editor.nearestScale(editor.current.w, editor.current.h, editor.current.scale)))
                          : ""

                    Repeater {
                        model: editor.scaleChoices

                        Chip {
                            required property real modelData

                            label: editor.scaleLabel(modelData)
                            selected: Math.abs((editor.current?.scale ?? 1) - modelData) < 0.001
                            onClicked: editor.set(editor.selected.name, { scale: modelData })
                        }
                    }

                    Chip {
                        icon: "remove"
                        label: "0,05"
                        onClicked: editor.set(editor.selected.name, { scale: Math.max(0.5, Math.round((editor.current.scale - 0.05) * 100) / 100) })
                    }

                    Chip {
                        icon: "add"
                        label: "0,05"
                        onClicked: editor.set(editor.selected.name, { scale: Math.min(4, Math.round((editor.current.scale + 0.05) * 100) / 100) })
                    }
                }

                Field {
                    title: I18n.tr("Drehung")
                    enabled: !editor.locked && !(editor.current?.disabled ?? false)

                    Repeater {
                        model: editor.transformChoices

                        Chip {
                            required property var modelData

                            label: modelData.label
                            icon: modelData.icon
                            selected: ((editor.current?.transform ?? 0) % 4) === modelData.value
                            onClicked: editor.set(editor.selected.name, { transform: modelData.value + (editor.current.transform >= 4 ? 4 : 0) })
                        }
                    }

                    Chip {
                        icon: "flip"
                        label: I18n.tr("Gespiegelt")
                        selected: (editor.current?.transform ?? 0) >= 4
                        onClicked: editor.set(editor.selected.name, { transform: (editor.current.transform + 4) % 8 })
                    }
                }

                Field {
                    title: I18n.tr("Variable Bildrate (VRR)")
                    enabled: !editor.locked && !(editor.current?.disabled ?? false)

                    Repeater {
                        model: [
                            { value: 0, label: I18n.tr("Aus") },
                            { value: 1, label: I18n.tr("An") },
                            { value: 2, label: I18n.tr("Nur Vollbild") }
                        ]

                        Chip {
                            required property var modelData

                            label: modelData.label
                            selected: (editor.current?.vrr ?? 0) === modelData.value
                            onClicked: editor.set(editor.selected.name, { vrr: modelData.value })
                        }
                    }
                }

                Field {
                    title: I18n.tr("Spiegeln")
                    visible: editor.monitors.length > 1
                    enabled: !editor.locked && !(editor.current?.disabled ?? false)

                    Chip {
                        label: I18n.tr("Nein")
                        selected: (editor.current?.mirror ?? "") === ""
                        onClicked: editor.set(editor.selected.name, { mirror: "" })
                    }

                    Repeater {
                        model: editor.monitors.filter(m => m.name !== editor.selected?.name)

                        Chip {
                            required property var modelData

                            label: modelData.name
                            icon: "splitscreen"
                            selected: (editor.current?.mirror ?? "") === modelData.name
                            onClicked: editor.set(editor.selected.name, { mirror: modelData.name })
                        }
                    }
                }
            }
        }

        // ---- Leiste: Aenderungen / Behalten? ----
        Rectangle {
            id: bar

            width: parent.width
            height: 48
            radius: 14
            color: Monitors.confirming ? Colors.alpha(Colors.primary, 0.12)
                 : Monitors.lastError !== "" ? Colors.alpha(Colors.error, 0.1)
                 : Colors.alpha(Colors.fgSurface, 0.035)
            border.width: 1
            border.color: Monitors.confirming ? Colors.alpha(Colors.primary, 0.4)
                        : Monitors.lastError !== "" ? Colors.alpha(Colors.error, 0.4)
                        : Colors.alpha(Colors.outline, 0.14)

            Behavior on color {
                ColorAnimation { duration: Appearance.fadeDuration }
            }
            Behavior on border.color {
                ColorAnimation { duration: Appearance.fadeDuration }
            }

            Row {
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                    leftMargin: 14
                }
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Monitors.confirming ? "schedule" : Monitors.lastError !== "" ? "error" : editor.dirty ? "pending" : "check_circle"
                    color: Monitors.confirming ? Colors.primary : Monitors.lastError !== "" ? Colors.error : editor.dirty ? Colors.tertiary : Colors.fgSurfaceVariant
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 18
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, bar.width - buttons.width - 60)
                    elide: Text.ElideRight
                    text: Monitors.confirming
                        ? I18n.tr("Einstellungen behalten? Zurück in %1 s").arg(Monitors.countdown)
                        : Monitors.lastError !== "" ? Monitors.lastError
                        : Monitors.busy ? I18n.tr("Wird angewendet …")
                        : editor.changeCount === 0 ? I18n.tr("Keine ausstehenden Änderungen")
                        : editor.changeCount === 1 ? I18n.tr("1 Monitor geändert")
                        : I18n.tr("%1 Monitore geändert").arg(editor.changeCount)
                    color: Monitors.lastError !== "" && !Monitors.confirming ? Colors.error : Colors.fgSurface
                    font.family: Config.font
                    font.pixelSize: 12
                    font.weight: Monitors.confirming ? Font.DemiBold : Font.Normal
                }
            }

            Row {
                id: buttons

                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    rightMargin: 10
                }
                spacing: 8

                ActionButton {
                    visible: !Monitors.confirming
                    icon: "refresh"
                    label: I18n.tr("Neu lesen")
                    enabled: !Monitors.busy
                    onClicked: Monitors.refresh()
                }

                ActionButton {
                    visible: !Monitors.confirming
                    icon: "undo"
                    label: I18n.tr("Verwerfen")
                    enabled: editor.dirty && !Monitors.busy
                    onClicked: editor.discard()
                }

                ActionButton {
                    visible: !Monitors.confirming
                    icon: "check"
                    label: I18n.tr("Übernehmen")
                    filled: true
                    enabled: editor.dirty && !Monitors.busy
                    onClicked: editor.applyPending()
                }

                ActionButton {
                    visible: Monitors.confirming
                    icon: "undo"
                    label: I18n.tr("Zurücksetzen")
                    onClicked: Monitors.revert()
                }

                ActionButton {
                    visible: Monitors.confirming
                    icon: "check"
                    label: I18n.tr("Behalten")
                    filled: true
                    onClicked: Monitors.keep()
                }
            }

            // Restzeit als Linie am unteren Rand
            Rectangle {
                anchors {
                    left: parent.left
                    bottom: parent.bottom
                    leftMargin: 14
                    bottomMargin: 4
                }
                height: 2
                radius: 1
                visible: Monitors.confirming
                width: (bar.width - 28) * Monitors.countdown / Monitors.confirmSeconds
                color: Colors.primary

                Behavior on width {
                    NumberAnimation { duration: 900 }
                }
            }
        }

        Text {
            width: parent.width
            text: I18n.tr("Regeln werden je Monitor über seine EDID-Beschreibung gespeichert (~/.local/state/dynamic-island/monitors.lua) und gelten auf diesem Rechner auch nach einem Neustart. Ein Monitor ohne Regel bekommt seinen bevorzugten Modus.")
            color: Colors.fgSurfaceVariant
            font.family: Config.font
            font.pixelSize: 10
            wrapMode: Text.WordWrap
        }
    }
}
