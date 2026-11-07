pragma ComponentBehavior: Bound
import QtQuick

import qs

// Runder Medienknopf im Gehaeuse (oben rechts): gleiche Beleuchtung wie
// die Tasten, Symbol statt Legende.
Item {
    id: btn

    // { id, icon, title } aus KeyLayout.MEDIA
    required property var spec
    required property real unit
    property var info: null
    property color light: "transparent"
    property bool lit: false
    property bool pick: false
    property bool interactive: true

    signal clicked

    readonly property bool occupied: btn.info !== null
    readonly property bool target: btn.pick && !btn.occupied && btn.interactive
    readonly property bool hovered: hover.hovered && btn.interactive
    readonly property bool disabled: btn.occupied && btn.info.disabled === true
    readonly property real glow: btn.lit ? 1 : btn.occupied ? (btn.disabled ? 0.3 : 0.6) : 0
    readonly property color rockBase: Qt.darker(Colors.surfaceBright, 1.6)
    readonly property color topBase: btn.hovered ? Qt.lighter(Colors.surfaceBright, 1.18) : Colors.surfaceBright

    width: btn.unit * 0.56
    height: width
    z: btn.hovered ? 2 : 0

    Rectangle {
        anchors.fill: parent
        anchors.margins: -btn.unit * 0.12
        radius: width / 2
        color: Colors.alpha(btn.light, 0.16 * btn.glow)
        visible: btn.glow > 0

        Behavior on color {
            ColorAnimation { duration: Appearance.fadeDuration }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: btn.glow > 0 ? Qt.tint(btn.rockBase, Colors.alpha(btn.light, 0.38 * btn.glow)) : btn.rockBase

        Behavior on color {
            ColorAnimation { duration: Appearance.fadeDuration }
        }
    }

    Rectangle {
        x: btn.unit * 0.04
        y: btn.unit * 0.02
        width: parent.width - btn.unit * 0.08
        height: width
        radius: width / 2
        color: btn.glow > 0 ? Qt.tint(btn.topBase, Colors.alpha(btn.light, 0.26 * btn.glow)) : btn.topBase
        border.width: btn.target ? 1 : 0
        border.color: Colors.alpha(Colors.primary, btn.hovered ? 0.9 : 0.45)

        Behavior on color {
            ColorAnimation { duration: Appearance.fadeDuration }
        }

        Text {
            anchors.centerIn: parent
            text: btn.spec.icon
            color: btn.glow > 0 ? (btn.lit ? Qt.lighter(btn.light, 1.2) : btn.light) : Colors.alpha(Colors.fgSurfaceVariant, 0.55)
            opacity: btn.disabled ? 0.7 : 1
            font.family: "Material Symbols Outlined"
            font.pixelSize: Math.max(10, Math.round(btn.unit * 0.3))

            Behavior on color {
                ColorAnimation { duration: Appearance.fadeDuration }
            }
        }
    }

    HoverHandler {
        id: hover

        enabled: btn.interactive
        cursorShape: btn.occupied || btn.target ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    TapHandler {
        enabled: btn.interactive && (btn.occupied || btn.target)
        onTapped: btn.clicked()
    }

    KeyTooltip {
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: parent.bottom
            topMargin: 6
        }
        z: 10
        visible: btn.hovered
        title: btn.info ? `${I18n.tr(btn.info.group)} › ${I18n.tr(btn.info.title)}` : I18n.tr(btn.spec.title)
        keys: btn.info?.keys ?? []
        hint: btn.disabled ? I18n.tr("aus") : ""
    }
}
