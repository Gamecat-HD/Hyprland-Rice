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
//   property int fps        Obergrenze fuer eigene Animationen (desktop.fps)
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

    width: Math.max(host.editing ? 40 : 0, loader.item?.implicitWidth ?? 0)
    height: Math.max(host.editing ? 24 : 0, loader.item?.implicitHeight ?? 0)
    x: Math.round(host.cx - host.width / 2)
    y: Math.round(host.cy - host.height / 2)
    visible: host.widget !== null && host.info !== null
    z: host.selected ? 2 : 1

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
        value: Config.desktop.fps
        when: loader.item !== null && loader.item.fps !== undefined
    }
    // Plugin-Widgets kommen an ihr Plugin (Einstellungen, Ordner) ueber `plugin`
    Binding {
        target: loader.item
        property: "plugin"
        value: host.info?.plugin ?? null
        when: loader.item !== null && host.info?.plugin !== undefined && loader.item.plugin !== undefined
    }

    // ---- Bearbeiten ----

    Rectangle {
        anchors.fill: parent
        anchors.margins: -8
        visible: host.editing
        radius: 10
        color: host.selected ? Colors.alpha(Colors.primary, 0.08) : "transparent"
        border.width: host.selected ? 2 : 1
        border.color: host.selected ? Colors.primary : Colors.alpha("#ffffff", hoverArea.hovered ? 0.6 : 0.3)

        // Typ als kleines Etikett oben links
        Rectangle {
            visible: host.selected || hoverArea.hovered
            x: 8
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
        cursorShape: dragger.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    }

    TapHandler {
        enabled: host.editing
        onTapped: Scenes.selected = host.widget.id
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

        enabled: host.editing
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
        x: parent.width + 8 - width / 2
        y: parent.height + 8 - height / 2
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

            onActiveChanged: {
                if (sizer.active) {
                    sizer.startSize = host.widget?.size ?? 1;
                    sizer.startW = Math.max(20, host.width);
                    host.liveSize = sizer.startSize;
                    return;
                }
                Scenes.patch(host.widget.id, { size: Number(host.liveSize.toFixed(3)) });
            }

            onTranslationChanged: {
                if (!sizer.active)
                    return;
                // Mittelpunkt bleibt stehen -> die Ecke wandert halb so schnell
                const grow = (sizer.startW / 2 + Math.max(sizer.translation.x, sizer.translation.y)) / (sizer.startW / 2);
                host.liveSize = Math.max(0.3, Math.min(8, sizer.startSize * grow));
            }
        }
    }
}
