pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

import qs
import qs.modules.services.config

// Eine Taste der Tastatur-Vorschau (VirtualKeyboard): Kappe mit Profil
// (dunkler Rock, hellere Oberseite, die bei gedrueckten Modifiern nach unten
// rutscht) und Beleuchtung je Taste wie Per-Key-RGB: belegte Tasten leuchten
// in `light` (Legende, Oberseite, Schein um den Rock), der gewaehlte Befehl
// (`lit`) heller, freie Tasten bleiben dunkel mit gedimmter Legende.
// Beschriftung wie deutsche Kappen: Shift-Zeichen oben, Hauptlegende
// darunter, AltGr-Zeichen unten rechts. ISO-Enter (spec.iso) als Kontur.
Item {
    id: key

    // { id, label, sub, alt, icon, x, y, w, h, mod, iso, lowerX, lowerW } aus KeyLayout.js
    required property var spec
    // Pixel je Tasteneinheit und Luecke zwischen Tasten
    required property real unit
    required property real gap
    // Belegung auf der Ebene: { title, group, disabled, changed, source, unnamed, keys, via } | null
    property var info: null
    // Lichtfarbe der Belegung (VirtualKeyboard.lightOf)
    property color light: "transparent"
    // Gehoert zum gewaehlten Befehl
    property bool lit: false
    // Modifier-Bit in der Ebene gesetzt: Kappe gedrueckt
    property bool pressed: false
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
    readonly property bool disabled: key.occupied && key.info.disabled === true

    // Lichtstaerke 0..1
    readonly property real glow: key.lit ? 1 : key.occupied ? (key.disabled ? 0.3 : 0.6) : key.pressed ? 0.45 : 0
    // Unbelegte Tasten leuchten (gedrueckt / Teil des gewaehlten Befehls) in Primaer
    readonly property color beam: key.occupied ? key.light : Colors.primary

    readonly property color rockBase: Qt.darker(Colors.surfaceBright, 1.6)
    readonly property color topBase: key.hovered && key.clickable ? Qt.lighter(Colors.surfaceBright, 1.18) : Colors.surfaceBright
    readonly property color rockColor: key.glow > 0 ? Qt.tint(key.rockBase, Colors.alpha(key.beam, 0.38 * key.glow)) : key.rockBase
    readonly property color topColor: key.glow > 0 ? Qt.tint(key.topBase, Colors.alpha(key.beam, 0.26 * key.glow)) : key.topBase
    readonly property color legend: key.glow > 0 ? (key.lit ? Qt.lighter(key.beam, 1.2) : key.beam)
                                  : Colors.alpha(Colors.fgSurfaceVariant, 0.55)
    readonly property color legendDim: key.glow > 0 ? Colors.alpha(key.beam, 0.6) : Colors.alpha(Colors.fgSurfaceVariant, 0.32)

    // Geometrie der Kappe
    readonly property real inset: key.unit * 0.07
    readonly property real travel: key.unit * 0.1
    readonly property real topY: key.pressed ? key.inset * 0.5 + key.travel : key.inset * 0.5
    readonly property real topH: key.height - key.inset * 2 - key.travel
    readonly property real capRadius: Math.max(3, key.unit * 0.13)
    readonly property real pad: Math.max(3, key.unit * 0.1)
    readonly property bool iso: key.spec.iso === true
    readonly property real lowerX: key.iso ? (key.spec.lowerX - key.spec.x) * key.unit : 0
    readonly property real lowerW: key.iso ? key.spec.lowerW * key.unit - key.gap : key.width

    x: key.spec.x * key.unit
    y: key.spec.y * key.unit
    width: key.spec.w * key.unit - key.gap
    height: key.spec.h * key.unit - key.gap
    z: key.hovered ? 2 : 0

    // ---- Schein (zwei weiche Stufen statt Blur) ----
    Rectangle {
        anchors.fill: parent
        anchors.margins: -key.unit * 0.16
        radius: key.capRadius * 2.2
        color: Colors.alpha(key.beam, 0.07 * key.glow)
        visible: key.glow > 0

        Behavior on color {
            ColorAnimation { duration: Appearance.fadeDuration }
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -key.unit * 0.07
        radius: key.capRadius * 1.6
        color: Colors.alpha(key.beam, 0.2 * key.glow)
        visible: key.glow > 0

        Behavior on color {
            ColorAnimation { duration: Appearance.fadeDuration }
        }
    }

    // ---- Rock (Seite) ----
    Rectangle {
        visible: !key.iso
        anchors.fill: parent
        radius: key.capRadius + 1
        color: key.rockColor

        Behavior on color {
            ColorAnimation { duration: Appearance.fadeDuration }
        }
    }

    // ---- Oberseite ----
    Rectangle {
        id: top

        visible: !key.iso
        x: key.inset
        y: key.topY
        width: key.width - key.inset * 2
        height: key.topH
        radius: key.capRadius
        color: key.topColor
        border.width: key.target ? 1 : 0
        border.color: Colors.alpha(Colors.primary, key.hovered ? 0.9 : 0.45)

        Behavior on y {
            NumberAnimation { duration: Appearance.fadeDuration; easing.type: Easing.OutCubic }
        }
        Behavior on color {
            ColorAnimation { duration: Appearance.fadeDuration }
        }

        // Highlight an der Oberkante
        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                leftMargin: parent.radius
                rightMargin: parent.radius
            }
            height: 1
            color: Colors.alpha(Colors.fgSurface, 0.08)
        }
    }

    // ISO-Enter: Rock und Oberseite als Konturen
    Shape {
        visible: key.iso
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        IsoEnterPath {
            fillColor: key.rockColor
            w: key.width
            h: key.height
            topH: key.unit - key.gap
            lowerX: key.lowerX
            lowerW: key.lowerW
            r: key.capRadius + 1

            Behavior on fillColor {
                ColorAnimation { duration: Appearance.fadeDuration }
            }
        }

        IsoEnterPath {
            fillColor: key.topColor
            ox: key.inset
            oy: key.topY
            w: key.width - key.inset * 2
            h: key.topH
            topH: key.unit - key.gap - key.inset - key.travel * 0.5
            lowerX: key.lowerX
            lowerW: key.lowerW - key.inset * 2
            r: key.capRadius

            Behavior on fillColor {
                ColorAnimation { duration: Appearance.fadeDuration }
            }
        }
    }

    // Flaeche fuer die Legenden (bei ISO-Enter der untere Teil)
    Item {
        id: face

        x: (key.iso ? key.lowerX : 0) + key.inset
        y: key.topY + (key.iso ? key.unit - key.gap - key.inset : 0)
        width: (key.iso ? key.lowerW : key.width) - key.inset * 2
        height: key.topH - (key.iso ? key.unit - key.gap - key.inset : 0)

        Behavior on y {
            NumberAnimation { duration: Appearance.fadeDuration; easing.type: Easing.OutCubic }
        }

        // Shift-Zeichen oben links
        Text {
            id: subText

            anchors {
                left: parent.left
                top: parent.top
                leftMargin: key.pad
                topMargin: key.pad * 0.7
            }
            visible: (key.spec.sub ?? "") !== ""
            text: key.spec.sub ?? ""
            color: key.legendDim
            font.family: Config.font
            font.pixelSize: Math.max(8, Math.round(key.unit * 0.2))
            font.weight: Font.Medium
        }

        // Hauptlegende: mit Shift-Zeichen unten links, sonst oben links;
        // Symbol (Pfeile, Rueck) mittig
        Text {
            anchors {
                left: parent.left
                leftMargin: key.pad
                top: subText.visible ? undefined : parent.top
                topMargin: key.pad * 0.7
                bottom: subText.visible ? parent.bottom : undefined
                bottomMargin: key.pad * 0.7
            }
            visible: !key.spec.icon && !key.centered
            width: parent.width - key.pad - 2
            text: key.spec.label
            color: key.legend
            opacity: key.disabled ? 0.7 : 1
            font.family: Config.font
            // F10–F12 wie F1–F9, nicht wie Esc/Druck
            font.pixelSize: key.spec.label.length > 2 && !/^F\d+$/.test(key.spec.label) ? Math.max(8, Math.round(key.unit * 0.19))
                          : Math.max(10, Math.round(key.unit * 0.3))
            font.weight: Font.Medium
            font.strikeout: key.disabled
            elide: Text.ElideRight

            Behavior on color {
                ColorAnimation { duration: Appearance.fadeDuration }
            }
        }

        // Pfeile und Symbol-Tasten stehen mittig
        Text {
            anchors.centerIn: parent
            visible: key.spec.icon || key.centered
            text: key.spec.icon ? key.spec.icon : key.spec.label
            color: key.legend
            opacity: key.disabled ? 0.7 : 1
            font.family: key.spec.icon ? "Material Symbols Outlined" : Config.font
            font.pixelSize: Math.max(11, Math.round(key.unit * (key.spec.icon ? 0.4 : 0.34)))
            font.weight: Font.Medium

            Behavior on color {
                ColorAnimation { duration: Appearance.fadeDuration }
            }
        }

        // AltGr-Zeichen unten rechts
        Text {
            anchors {
                right: parent.right
                bottom: parent.bottom
                rightMargin: key.pad
                bottomMargin: key.pad * 0.6
            }
            visible: (key.spec.alt ?? "") !== ""
            text: key.spec.alt ?? ""
            // Belegung ueber AltGr: dieses Zeichen leuchtet
            color: key.info?.via ? key.legend : key.legendDim
            font.family: Config.font
            font.pixelSize: Math.max(8, Math.round(key.unit * 0.19))
        }
    }

    readonly property bool centered: /^[←→↑↓⌫]$/.test(key.spec.label)

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

    KeyTooltip {
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: key.tipAbove ? undefined : parent.bottom
            bottom: key.tipAbove ? parent.top : undefined
            topMargin: 6
            bottomMargin: 6
        }
        z: 10
        visible: key.hovered && (key.occupied || key.target)
        title: {
            if (!key.info)
                return I18n.tr("Hier ablegen");
            if (key.info.unnamed)
                return I18n.tr("Belegt (ohne Beschreibung)");
            return `${I18n.tr(key.info.group)} › ${I18n.tr(key.info.title)}`;
        }
        keys: key.info?.keys ?? []
        hint: key.disabled ? I18n.tr("aus") : ""
    }
}
