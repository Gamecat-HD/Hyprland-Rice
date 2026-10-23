pragma ComponentBehavior: Bound
import QtQuick

import qs
import qs.modules.services.config
import qs.modules.services.desktop

// Ein Widget auf dem Desktop: laedt den Typ (DesktopWidgets), setzt ihn auf
// seinen Mittelpunkt (x/y als Anteil des Bildschirms) und reicht Groesse,
// Farben, Optionen und `active` durch.
//
// Beim Bearbeiten: Rahmen, Ziehen mit Einrasten (Drittel, Mitte, Raender),
// Ecke unten rechts = Groesse. Gespeichert wird erst beim Loslassen.
//
// Vertrag fuer Widget-Komponenten (eingebaut wie aus Plugins):
//   property real unit      Grundeinheit in px (16 bei 1440p * size)
//   property bool active    false = Desktop verdeckt: nichts rechnen/animieren
//   property bool editing
//   property var opts       Optionen aus scenes.json (Vorgaben schon eingesetzt)
//   property color color, accent
//   property int fps        Obergrenze fuer eigene Animationen (Einstellung fps des Plugins desktop)
//   implicitWidth/Height    setzt das Widget selbst
Item {
    id: host

    property var widget: null
    property string screenName: ""
    property real unit: 16
    property bool active: true
    property bool editing: false
    property Item guideX
    property Item guideY

    readonly property var info: DesktopWidgets.info(host.widget?.type ?? "")
    readonly property bool selected: host.editing && Scenes.selected === (host.widget?.id ?? "")

    // Waehrend des Ziehens lokale Werte, danach wieder die aus der Szene
    property bool dragging: dragger.active || sizer.active
    property real dragX: 0
    property real dragY: 0
    property real liveSize: 1

    readonly property real size: sizer.active ? host.liveSize : (host.widget?.size ?? 1)
    readonly property real cx: dragger.active ? host.dragX : (host.widget?.x ?? 0.5) * (parent?.width ?? 0)
    readonly property real cy: dragger.active ? host.dragY : (host.widget?.y ?? 0.5) * (parent?.height ?? 0)

    readonly property var opts: Object.assign(DesktopWidgets.defaults(host.widget?.type ?? ""), host.widget?.opts ?? {})

    // Angedockte Widgets (z.B. Visualiser "unten") setzen `dock` und bekommen
    // die volle Breite (`areaWidth`); x/y aus der Szene gelten dann nicht
    readonly property string dock: loader.item?.dock ?? ""
    readonly property real areaW: host.parent?.width ?? 0
    readonly property real areaH: host.parent?.height ?? 0

    width: Math.max(host.editing ? 40 : 0, loader.item?.implicitWidth ?? 0)
    height: Math.max(host.editing ? 24 : 0, loader.item?.implicitHeight ?? 0)
    x: host.dock !== "" ? 0 : Math.round(host.cx - host.width / 2)
    y: host.dock === "unten" ? host.areaH - host.height
     : host.dock === "oben" ? 0
     : Math.round(host.cy - host.height / 2)
    visible: host.widget !== null && host.info !== null
    z: host.selected ? 3 : 1

    function select(): void {
        Scenes.selected = host.widget.id;
    }

    onSelectedChanged: if (host.selected && host.parent && host.parent.selectedHost !== undefined) host.parent.selectedHost = host

    Loader {
        id: loader

        anchors.centerIn: parent
        active: host.info !== null
        source: host.info?.url ?? ""
        asynchronous: false

        onStatusChanged: {
            if (loader.status === Loader.Error)
                console.warn("Desktop: Widget", host.widget?.type, "laedt nicht:", host.info?.url);
        }
    }

    Binding {
        target: loader.item
        property: "unit"
        value: host.unit * host.size
        when: loader.item !== null
    }
    Binding {
        target: loader.item
        property: "active"
        value: host.active
        when: loader.item !== null
    }
    Binding {
        target: loader.item
        property: "editing"
        value: host.editing
        when: loader.item !== null
    }
    Binding {
        target: loader.item
        property: "opts"
        value: host.opts
        when: loader.item !== null
    }
    Binding {
        target: loader.item
        property: "color"
        value: DesktopWidgets.color(host.opts.color ?? "hell", Colors.fgBackground)
        when: loader.item !== null
    }
    Binding {
        target: loader.item
        property: "accent"
        value: DesktopWidgets.color(host.opts.accent ?? "primary", Colors.primary)
        when: loader.item !== null
    }
    Binding {
        target: loader.item
        property: "fps"
        value: DesktopWidgets.settings.fps
        when: loader.item !== null && loader.item.fps !== undefined
    }
    Binding {
        target: loader.item
        property: "areaWidth"
        value: host.areaW
        when: loader.item !== null && loader.item.areaWidth !== undefined
    }
    // Plugin-Widgets kommen an ihr Plugin (Einstellungen, Ordner) ueber `plugin`
    Binding {
        target: loader.item
        property: "plugin"
        value: host.info?.plugin ?? null
        when: loader.item !== null && host.info?.plugin !== undefined && loader.item.plugin !== undefined
    }

    // ---- Bearbeiten ----

    // Auswahlrahmen (8 px um das Widget). Liegt das Optionsfeld buendig an
    // seiner linken Kante an, wird die Ecke dort eckig – Rahmen und Feld
    // lesen sich dann als eine Flaeche.
    readonly property real frame: 8

    Rectangle {
        id: frameRect

        anchors.fill: parent
        anchors.margins: -host.frame
        visible: host.editing
        radius: 12
        bottomLeftRadius: options.item && options.item.flushBelow ? 0 : 12
        topLeftRadius: options.item && options.item.flushAbove ? 0 : 12
        color: host.selected ? Colors.alpha(Colors.primary, 0.08) : "transparent"
        border.width: host.selected ? 2 : 1
        border.color: host.selected ? Colors.primary : Colors.alpha("#ffffff", hoverArea.hovered ? 0.6 : 0.3)

        // Typ als kleines Etikett oben links (nicht, wenn das Feld dort andockt)
        Rectangle {
            visible: (host.selected || hoverArea.hovered) && !(options.item && options.item.flushAbove)
            x: 10
            y: -height / 2
            width: label.implicitWidth + 12
            height: 18
            radius: 9
            color: host.selected ? Colors.primary : Colors.alpha("#000000", 0.6)

            Text {
                id: label

                anchors.centerIn: parent
                text: host.info?.title ?? host.widget?.type ?? ""
                color: host.selected ? Colors.fgPrimary : "#ffffff"
                font.family: Config.font
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }
        }
    }

    HoverHandler {
        id: hoverArea

        enabled: host.editing
        cursorShape: host.dock !== "" ? Qt.PointingHandCursor
                   : dragger.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    }

    // Auswahl schon beim Druecken – das Optionsfeld ist sofort da
    TapHandler {
        enabled: host.editing
        gesturePolicy: TapHandler.DragThreshold
        onPressedChanged: if (pressed) host.select()
    }

    // Optionsfeld: unter dem Rahmen, sonst darueber; linksbuendig mit dem
    // Rahmen, am Bildschirmrand eingefangen. Angedockte (volle Breite) mittig.
    Loader {
        id: options

        active: host.selected && !host.dragging
        z: 10

        sourceComponent: WidgetOptions {
            id: pop

            widget: host.widget
            screenName: host.screenName

            readonly property real fx: host.x - host.frame
            readonly property real fy: host.y - host.frame
            readonly property real fw: host.width + host.frame * 2
            readonly property real fh: host.height + host.frame * 2
            readonly property bool below: pop.fy + pop.fh + pop.height + 16 <= host.areaH
            readonly property real px: host.dock !== "" ? Math.round((host.areaW - pop.width) / 2)
                                     : Math.max(16, Math.min(host.areaW - pop.width - 16, pop.fx))
            readonly property bool aligned: host.dock === "" && pop.px === pop.fx
            readonly property bool flushBelow: pop.aligned && pop.below
            readonly property bool flushAbove: pop.aligned && !pop.below

            width: implicitWidth
            height: implicitHeight
            // 2 px Ueberlappung: Rand von Rahmen und Feld fallen zusammen
            x: pop.px - host.x
            y: (pop.below ? pop.fy + pop.fh - 2 : pop.fy - pop.height + 2) - host.y
            radius: 14
            // Angedockt (volle Breite): sitzt wie ein Reiter auf dem Rahmen
            topLeftRadius: pop.flushBelow || (host.dock !== "" && pop.below) ? 0 : 14
            topRightRadius: host.dock !== "" && pop.below ? 0 : 14
            bottomLeftRadius: pop.flushAbove || (host.dock !== "" && !pop.below) ? 0 : 14
            bottomRightRadius: host.dock !== "" && !pop.below ? 0 : 14
        }
    }

    // Liegt ein Punkt (Koordinaten der Buehne) auf dem Optionsfeld?
    function optionsContain(px: real, py: real): bool {
        const it = options.item;
        if (!it)
            return false;
        const p = it.mapFromItem(host.parent, px, py);
        return p.x >= 0 && p.y >= 0 && p.x <= it.width && p.y <= it.height;
    }

    // Einrasten: Mittelpunkt auf Drittel/Mitte, Kanten an den Rand (mit
    // Abstand; oben mehr wegen der Notch)
    function snap(value: real, extent: real, total: real, top: bool): var {
        const margin = total * (top ? 0.07 : 0.035);
        const cands = [total / 3, total / 2, total * 2 / 3, margin + extent / 2, total - margin - extent / 2];
        const lines = [total / 3, total / 2, total * 2 / 3, margin, total - margin];
        for (let i = 0; i < cands.length; i++)
            if (Math.abs(value - cands[i]) < 14)
                return { v: cands[i], line: lines[i] };
        return { v: value, line: -1 };
    }

    DragHandler {
        id: dragger

        enabled: host.editing && host.dock === ""
        target: null
        dragThreshold: 4

        property real startX: 0
        property real startY: 0

        onActiveChanged: {
            if (dragger.active) {
                Scenes.selected = host.widget.id;
                dragger.startX = host.cx;
                dragger.startY = host.cy;
                host.dragX = host.cx;
                host.dragY = host.cy;
                return;
            }
            host.guideX.at = -1;
            host.guideY.at = -1;
            const pw = host.parent.width, ph = host.parent.height;
            Scenes.patch(host.widget.id, {
                x: Number(Math.max(0, Math.min(1, host.dragX / pw)).toFixed(4)),
                y: Number(Math.max(0, Math.min(1, host.dragY / ph)).toFixed(4))
            });
        }

        onTranslationChanged: {
            if (!dragger.active)
                return;
            const pw = host.parent.width, ph = host.parent.height;
            const sx = host.snap(dragger.startX + dragger.translation.x, host.width, pw, false);
            const sy = host.snap(dragger.startY + dragger.translation.y, host.height, ph, true);
            host.dragX = sx.v;
            host.dragY = sy.v;
            host.guideX.at = sx.line;
            host.guideY.at = sy.line;
        }
    }

    // Groesse: Griff unten rechts
    Rectangle {
        visible: host.selected
        x: parent.width - (host.dock !== "" ? 40 : -8) - width / 2
        y: (host.dock === "unten" ? -8 : parent.height + 8) - height / 2
        width: 16
        height: 16
        radius: 8
        color: Colors.primary
        border.width: 2
        border.color: Colors.fgPrimary

        HoverHandler {
            cursorShape: Qt.SizeFDiagCursor
        }

        DragHandler {
            id: sizer

            target: null
            dragThreshold: 1

            property real startSize: 1
            property real startW: 1
            property real startH: 1

            onActiveChanged: {
                if (sizer.active) {
                    sizer.startSize = host.widget?.size ?? 1;
                    sizer.startW = Math.max(20, host.width);
                    sizer.startH = Math.max(20, host.height);
                    host.liveSize = sizer.startSize;
                    return;
                }
                Scenes.patch(host.widget.id, { size: Number(host.liveSize.toFixed(3)) });
            }

            onTranslationChanged: {
                if (!sizer.active)
                    return;
                // Angedockt unten: nach oben ziehen = hoeher. Sonst bleibt der
                // Mittelpunkt stehen -> die Ecke wandert halb so schnell
                const grow = host.dock === "unten"
                    ? (sizer.startH - sizer.translation.y) / sizer.startH
                    : (sizer.startW / 2 + Math.max(sizer.translation.x, sizer.translation.y)) / (sizer.startW / 2);
                host.liveSize = Math.max(0.3, Math.min(8, sizer.startSize * grow));
            }
        }
    }
}
