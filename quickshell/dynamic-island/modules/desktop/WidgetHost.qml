pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

import qs
import qs.modules.services.config
import qs.modules.services.desktop

// Ein Widget auf dem Desktop: laedt den Typ (DesktopWidgets), setzt ihn auf
// seinen Mittelpunkt (x/y als Anteil des Bildschirms) und reicht Groesse,
// Farben, Optionen und `active` durch.
//
// Beim Bearbeiten: Rahmen, Ziehen mit Einrasten (Drittel, Mitte, Raender),
// Ecke unten rechts = Groesse. Gespeichert wird erst beim Loslassen.
// Ein auf einen Monitor festgelegtes Widget laesst sich ueber den Rand auf
// den anderen Monitor ziehen (Vorschau dort, s. Scenes.crossing).
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
    property ShellScreen shellScreen: null
    property real unit: 16
    property bool active: true
    property bool editing: false
    property Item guideX
    // Maus liegt ueber Optionsfeld oder Leiste (DesktopScreen): Qt 6 reicht
    // einen Druck auch an die Handler darunterliegender Elemente weiter,
    // obwohl oben schon eine MouseArea ihn angenommen hat – ohne Sperre
    // waehlte ein Klick ins Optionsfeld das Widget darunter aus (das Feld
    // war weg) und der Bonsai darunter wuchs neu
    property bool blocked: false
    property Item guideY

    readonly property var info: DesktopWidgets.info(host.widget?.type ?? "")
    readonly property bool selected: host.editing && Scenes.selected === (host.widget?.id ?? "")
    // Nur auf einem Monitor ("Nur <name>") – darf auf einen anderen wechseln
    readonly property bool pinned: (host.widget?.monitor ?? "*") !== "*"

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
        // Eigene Handler der Widgets ebenfalls – und beim Bearbeiten nur am
        // ausgewaehlten Widget, sonst reagierte ein Widget schon beim
        // Auswaehlen oder unter einem anderen
        enabled: !host.blocked && (!host.editing || host.selected)
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

    // Rahmen (host.frame) gehoert zum Widget: Hover, Antippen und Ziehen
    // greifen auch dort, nicht nur auf dem Widget selbst
    HoverHandler {
        id: hoverArea

        enabled: host.editing && !host.blocked
        margin: host.frame
        cursorShape: host.dock !== "" ? Qt.PointingHandCursor
                   : dragger.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    }

    // Auswahl schon beim Druecken – das Optionsfeld ist sofort da
    TapHandler {
        id: tap

        enabled: host.editing && (!host.blocked || tap.pressed)
        margin: host.frame
        gesturePolicy: TapHandler.DragThreshold
        // Ueberlappen sich Widgets, bekommen alle den Druck – waehlen darf
        // sich nur das, das an der Stelle oben liegt (DesktopScreen.hostAt)
        onPressedChanged: {
            if (!tap.pressed)
                return;
            const p = host.mapToItem(host.parent, tap.point.position.x, tap.point.position.y);
            const top = typeof host.parent?.hostAt === "function" ? host.parent.hostAt(p.x, p.y) : host;
            if (top === null || top === host)
                host.select();
        }
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
            readonly property bool fits: pop.fy + pop.fh + pop.height + 16 <= host.areaH

            // Angedockte Lage (am Rahmen, unten wenn Platz ist)
            readonly property real dockX: host.dock !== "" ? Math.round((host.areaW - pop.width) / 2)
                                        : Math.max(16, Math.min(host.areaW - pop.width - 16, pop.fx))
            function dockY(below: bool): real {
                return below ? pop.fy + pop.fh - 2 : pop.fy - pop.height + 2;
            }

            // Lage festhalten, solange das Widget ausgewaehlt bleibt: aendert
            // eine Option seine Groesse (Stil, Zeilen …), bliebe das Feld sonst
            // nicht unter der Maus, sondern sprang mit oder auf die andere
            // Seite. Neu angedockt wird nach dem Ziehen (das Feld entsteht dann
            // neu), wenn das Widget ins Feld waechst, sich weit entfernt oder
            // das Feld aus dem Bild ragt.
            property real heldX: NaN
            property real heldY: NaN
            property bool heldBelow: true
            readonly property bool holding: !isNaN(pop.heldY)
            readonly property bool below: pop.holding ? pop.heldBelow : pop.fits
            readonly property real sx: pop.holding ? pop.heldX : pop.dockX
            readonly property real sy: pop.holding ? pop.heldY : pop.dockY(pop.below)

            // Beim Neu-Andocken bleibt das Feld auf seiner Seite, solange es
            // dort noch Platz hat – sonst wechselte es bei jedem Wachsen
            property bool sideKnown: false

            function hold(): void {
                const fitsAbove = pop.fy - pop.height - 16 >= 0;
                pop.heldBelow = !pop.sideKnown ? pop.fits
                              : pop.heldBelow ? (pop.fits || !fitsAbove)
                              : (!fitsAbove && pop.fits);
                pop.sideKnown = true;
                pop.heldX = pop.dockX;
                pop.heldY = pop.dockY(pop.heldBelow);
            }
            function redock(): void {
                pop.heldX = NaN;
                pop.heldY = NaN;
                Qt.callLater(pop.hold);
            }

            readonly property bool misplaced: {
                if (!pop.holding)
                    return false;
                // Ueberlappt den Rahmen (4 px Toleranz fuer das Andocken)
                const overlap = pop.sx < pop.fx + pop.fw && pop.sx + pop.width > pop.fx
                                && pop.sy + 4 < pop.fy + pop.fh && pop.sy + pop.height - 4 > pop.fy;
                // Weit weg vom Rahmen
                const gap = pop.below ? pop.sy - (pop.fy + pop.fh) : pop.fy - (pop.sy + pop.height);
                const apart = gap > 80 || pop.sx > pop.fx + pop.fw - 40 || pop.sx + pop.width < pop.fx + 40;
                // Ragt aus dem Bild
                const outside = pop.sy < 8 || pop.sy + pop.height > host.areaH - 8;
                return overlap || (host.dock === "" && apart) || outside;
            }
            // Erst nach der Auswertung umsetzen: redock aendert, wovon
            // `misplaced` abhaengt (sonst Binding-Schleife)
            onMisplacedChanged: if (pop.misplaced) Qt.callLater(pop.redock)
            Component.onCompleted: Qt.callLater(pop.hold)
            Connections {
                target: host

                function onDockChanged(): void {
                    pop.redock();
                }
            }

            // Liegt das Feld buendig am Rahmen, verschmelzen die Ecken
            readonly property bool touching: Math.abs(pop.sy - pop.dockY(pop.below)) < 1
            readonly property bool aligned: host.dock === "" && pop.touching && Math.abs(pop.sx - pop.fx) < 1
            readonly property bool flushBelow: pop.aligned && pop.below
            readonly property bool flushAbove: pop.aligned && !pop.below

            width: implicitWidth
            height: implicitHeight
            // 2 px Ueberlappung: Rand von Rahmen und Feld fallen zusammen
            x: pop.sx - host.x
            y: pop.sy - host.y
            radius: 14
            // Angedockt (volle Breite): sitzt wie ein Reiter auf dem Rahmen
            topLeftRadius: pop.flushBelow || (host.dock !== "" && pop.touching && pop.below) ? 0 : 14
            topRightRadius: host.dock !== "" && pop.touching && pop.below ? 0 : 14
            bottomLeftRadius: pop.flushAbove || (host.dock !== "" && pop.touching && !pop.below) ? 0 : 14
            bottomRightRadius: host.dock !== "" && pop.touching && !pop.below ? 0 : 14
        }
    }

    // Gehoert ein Punkt (Koordinaten der Buehne) zu diesem Widget – Rahmen,
    // Groessen-Griff oder Optionsfeld? Dann ist ein Klick dort kein Klick ins
    // Leere (DesktopScreen hebt sonst die Auswahl auf)
    function owns(px: real, py: real): bool {
        if (!host.visible || !host.editing)
            return false;
        // Rahmen plus Platz fuer den Griff, der aussen an der Ecke sitzt
        const m = host.frame + (host.selected ? 16 : 0);
        if (px >= host.x - m && py >= host.y - m && px <= host.x + host.width + m && py <= host.y + host.height + m)
            return true;
        return host.optionsContain(px, py);
    }

    readonly property bool panelHovered: options.item?.hovered ?? false

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

    // Anderer Monitor unter dem Punkt (lokale Koordinaten), sonst null
    function otherScreenAt(lx: real, ly: real): var {
        const own = host.shellScreen;
        if (!own || (lx >= 0 && ly >= 0 && lx < host.areaW && ly < host.areaH))
            return null;
        const gx = own.x + lx, gy = own.y + ly;
        for (const s of Quickshell.screens)
            if (s.name !== own.name && gx >= s.x && gx < s.x + s.width && gy >= s.y && gy < s.y + s.height)
                return s;
        return null;
    }

    DragHandler {
        id: dragger

        // Ein laufendes Ziehen nicht abbrechen, wenn es ueber die Leiste geht
        enabled: host.editing && host.dock === "" && (!host.blocked || dragger.active)
        margin: host.frame
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
            const cross = Scenes.crossing;
            if (cross && cross.id === host.widget.id) {
                // Erst nach dem Handler umziehen: der Host verschwindet dabei
                Qt.callLater(() => Scenes.moveTo(cross.id, cross.screen, cross.x, cross.y));
                return;
            }
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
            const other = host.pinned ? host.otherScreenAt(dragger.startX + dragger.translation.x,
                                                           dragger.startY + dragger.translation.y) : null;
            if (other) {
                // Auf dem anderen Monitor: hier ungerastet weiter (wird am
                // Rand abgeschnitten), dort die Vorschau
                host.dragX = dragger.startX + dragger.translation.x;
                host.dragY = dragger.startY + dragger.translation.y;
                host.guideX.at = -1;
                host.guideY.at = -1;
                const gx = host.shellScreen.x + host.dragX - other.x;
                const gy = host.shellScreen.y + host.dragY - other.y;
                Scenes.crossing = {
                    id: host.widget.id,
                    title: host.info?.title ?? host.widget.type,
                    screen: other.name,
                    x: gx / other.width,
                    y: gy / other.height,
                    w: host.width,
                    h: host.height
                };
                return;
            }
            if (Scenes.crossing)
                Scenes.crossing = null;
            const sx = host.snap(dragger.startX + dragger.translation.x, host.width, pw, false);
            const sy = host.snap(dragger.startY + dragger.translation.y, host.height, ph, true);
            host.dragX = sx.v;
            host.dragY = sy.v;
            host.guideX.at = sx.line;
            host.guideY.at = sy.line;
        }
    }

    // Groesse: Griff unten rechts – ueber dem angedockten Optionsfeld (z 10),
    // sonst deckt dessen Kante den Griff halb zu
    Rectangle {
        visible: host.selected
        z: 11
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
