pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

import qs
import qs.modules.services.config

// Eine Taste der Tastatur-Vorschau (VirtualKeyboard). Zeigt, was auf der
// aktuellen Ebene darauf liegt (`info`), ob sie zum gewaehlten Befehl gehoert
// (`lit`) und – bei Modifier-Tasten – ob ihr Bit in der Ebene steht
// (`engaged`). ISO-Enter (spec.iso) ist zwei Zeilen hoch und oben breiter.
Item {
    id: key

    // { id, label, sub, icon, x, y, w, h, mod, iso, lowerX, lowerW } aus KeyLayout.js
    required property var spec
    // Pixel je Tasteneinheit und Luecke zwischen Tasten
    required property real unit
    required property real gap
    // Belegung auf der Ebene: { title, group, disabled, changed, source, unnamed } | null
    property var info: null
    // Gehoert zum gewaehlten Befehl
    property bool lit: false
    // Modifier-Bit in der Ebene gesetzt
    property bool engaged: false
    // "Auf Tastatur waehlen": freie Tasten sind Ziel
    property bool pick: false
    property bool interactive: true
    // Tooltip nach oben statt nach unten (untere Reihen)
    property bool tipAbove: false

    signal clicked

    readonly property bool occupied: key.info !== null
    readonly property bool free: key.info === null && key.spec.mod === 0
    readonly property bool target: key.pick && key.free && key.interactive
    readonly property bool hovered: hover.hovered && key.interactive
    readonly property bool clickable: key.interactive && (key.spec.mod !== 0 || key.occupied || key.target)

    readonly property color fill: key.lit ? Colors.alpha(Colors.primary, key.hovered ? 0.38 : 0.3)
                                : key.engaged ? Colors.alpha(Colors.primary, key.hovered ? 0.28 : 0.2)
                                : key.target && key.hovered ? Colors.alpha(Colors.primary, 0.14)
                                : key.occupied && !key.info.disabled ? Colors.alpha(Colors.fgSurface, key.hovered ? 0.2 : 0.14)
                                : Colors.alpha(Colors.fgSurface, key.hovered && key.clickable ? 0.09 : 0.05)
    readonly property color stroke: key.lit ? Colors.primary
                                  : key.engaged ? Colors.alpha(Colors.primary, 0.65)
                                  : key.target && key.hovered ? Colors.alpha(Colors.primary, 0.8)
                                  : key.target ? Colors.alpha(Colors.primary, 0.4)
                                  : key.occupied ? Colors.alpha(Colors.outline, 0.5)
                                  : Colors.alpha(Colors.outline, 0.22)
    readonly property color ink: key.lit || key.engaged ? Colors.primary
                               : key.occupied && !key.info.disabled ? Colors.fgSurface
                               : Colors.fgSurfaceVariant

    x: key.spec.x * key.unit
    y: key.spec.y * key.unit
    width: key.spec.w * key.unit - key.gap
    height: key.spec.h * key.unit - key.gap
    z: key.hovered ? 2 : 0

    // Flaeche
    Rectangle {
        id: face

        visible: key.spec.iso !== true
        width: parent.width
        height: parent.height
        radius: Math.max(4, key.unit * 0.14)
        color: key.fill
        border.width: 1
        border.color: key.stroke

        Behavior on color {
            ColorAnimation { duration: Appearance.fadeDuration }
        }
        Behavior on border.color {
            ColorAnimation { duration: Appearance.fadeDuration }
        }
    }

    // ISO-Enter: oben breit, unten schmal – eine Kontur mit runden Ecken
    // (zwei Rechtecke zeigten mit halbtransparenter Fuellung ihre Naht)
    Item {
        id: lower

        x: key.spec.iso ? (key.spec.lowerX - key.spec.x) * key.unit : 0
        width: key.spec.iso ? key.spec.lowerW * key.unit - key.gap : parent.width
    }

    Shape {
        id: iso

        readonly property real r: face.radius
        readonly property real topH: key.unit - key.gap
        readonly property real w: key.width
        readonly property real h: key.height
        readonly property real lx: lower.x

        visible: key.spec.iso === true
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: key.fill
            strokeColor: key.stroke
            strokeWidth: 1
            startX: iso.r
            startY: 0.5

            Behavior on fillColor {
                ColorAnimation { duration: Appearance.fadeDuration }
            }
            Behavior on strokeColor {
                ColorAnimation { duration: Appearance.fadeDuration }
            }

            PathLine { x: iso.w - iso.r; y: 0.5 }
            PathArc { x: iso.w - 0.5; y: iso.r; radiusX: iso.r; radiusY: iso.r }
            PathLine { x: iso.w - 0.5; y: iso.h - iso.r }
            PathArc { x: iso.w - iso.r; y: iso.h - 0.5; radiusX: iso.r; radiusY: iso.r }
            PathLine { x: iso.lx + iso.r; y: iso.h - 0.5 }
            PathArc { x: iso.lx + 0.5; y: iso.h - iso.r; radiusX: iso.r; radiusY: iso.r }
            PathLine { x: iso.lx + 0.5; y: iso.topH + iso.r }
            PathArc { x: iso.lx - iso.r; y: iso.topH; radiusX: iso.r; radiusY: iso.r; direction: PathArc.Counterclockwise }
            PathLine { x: iso.r; y: iso.topH }
            PathArc { x: 0.5; y: iso.topH - iso.r; radiusX: iso.r; radiusY: iso.r }
            PathLine { x: 0.5; y: iso.r }
            PathArc { x: iso.r; y: 0.5; radiusX: iso.r; radiusY: iso.r }
        }
    }

    // Beschriftung
    Text {
        id: label

        anchors {
            left: parent.left
            top: parent.top
            leftMargin: key.spec.iso ? lower.x + Math.max(4, key.unit * 0.14) : Math.max(4, key.unit * 0.14)
            topMargin: key.spec.iso ? key.unit * 0.5 : Math.max(3, key.unit * 0.1)
        }
        width: parent.width - anchors.leftMargin - 4
        text: key.spec.icon ? key.spec.icon : key.spec.label
        color: key.ink
        opacity: key.occupied && key.info.disabled ? 0.55 : 1
        font.family: key.spec.icon ? "Material Symbols Outlined" : Config.font
        font.pixelSize: key.spec.icon ? Math.max(12, Math.round(key.unit * 0.42))
                      : key.spec.label.length > 3 ? Math.max(8, Math.round(key.unit * 0.21))
                      : Math.max(10, Math.round(key.unit * 0.3))
        font.weight: Font.Medium
        elide: Text.ElideRight
    }

    // Zweitzeichen der Taste (Shift-Ebene), nur Deko
    Text {
        anchors {
            right: parent.right
            top: parent.top
            rightMargin: Math.max(3, key.unit * 0.1)
            topMargin: Math.max(2, key.unit * 0.08)
        }
        visible: (key.spec.sub ?? "") !== "" && !key.occupied
        text: key.spec.sub ?? ""
        color: Colors.alpha(Colors.fgSurfaceVariant, 0.6)
        font.family: Config.font
        font.pixelSize: Math.max(8, Math.round(key.unit * 0.2))
    }

    // Kennzeichen: woher die Belegung kommt (Plugin / eigenes / geaendert)
    Rectangle {
        anchors {
            right: parent.right
            top: parent.top
            margins: Math.max(3, key.unit * 0.1)
        }
        visible: key.occupied && !key.info.unnamed && (key.info.source !== "config" || key.info.changed)
        width: Math.max(4, key.unit * 0.1)
        height: width
        radius: width / 2
        color: key.info?.source === "plugin" ? Colors.secondary
             : key.info?.source === "config" ? Colors.primary
             : Colors.tertiary
    }

    // Winziger Titel des Befehls
    Text {
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            leftMargin: key.spec.iso ? lower.x + 3 : 3
            rightMargin: 3
            bottomMargin: Math.max(2, key.unit * 0.08)
        }
        visible: key.occupied
        text: key.info ? (key.info.unnamed ? I18n.tr("belegt") : I18n.tr(key.info.title)) : ""
        color: key.lit ? Colors.primary : Colors.fgSurfaceVariant
        opacity: key.info?.disabled ? 0.5 : 0.95
        font.family: Config.font
        font.pixelSize: Math.max(7, Math.round(key.unit * 0.18))
        font.strikeout: key.info?.disabled ?? false
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignLeft
    }

    HoverHandler {
        id: hover

        enabled: key.interactive
        cursorShape: key.clickable ? Qt.PointingHandCursor
                   : key.pick && key.occupied ? Qt.ForbiddenCursor
                   : Qt.ArrowCursor
    }

    TapHandler {
        enabled: key.clickable
        onTapped: key.clicked()
    }

    // Tooltip: Gruppe › Titel (und Zustand)
    Rectangle {
        id: tip

        anchors {
            horizontalCenter: parent.horizontalCenter
            top: key.tipAbove ? undefined : parent.bottom
            bottom: key.tipAbove ? parent.top : undefined
            topMargin: 5
            bottomMargin: 5
        }
        z: 10
        visible: key.hovered && (key.occupied || key.target)
        width: tipText.implicitWidth + 16
        height: tipText.implicitHeight + 10
        radius: 7
        color: Colors.surfaceBright
        border.width: 1
        border.color: Colors.alpha(Colors.outline, 0.45)
        opacity: visible ? 1 : 0

        Text {
            id: tipText

            anchors.centerIn: parent
            text: {
                if (!key.info)
                    return I18n.tr("Hier ablegen");
                if (key.info.unnamed)
                    return I18n.tr("Belegt (ohne Beschreibung)");
                const base = `${I18n.tr(key.info.group)} › ${I18n.tr(key.info.title)}`;
                return key.info.disabled ? `${base} · ${I18n.tr("aus")}` : base;
            }
            color: Colors.fgSurface
            font.family: Config.font
            font.pixelSize: 11
        }
    }
}
