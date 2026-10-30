import QtQuick

import qs

// Liegende Batterie, gefuellt nach Ladestand – ein Symbol fuer Notch,
// Settings-Pille und Sperrbildschirm statt der groben Material-Stufen.
//
//   laden / am Kabel   Fuellung im Akzent, Blitz in der Batterie
//   bis 20 %           Fuellung bernstein (Rot zum Gelb hin, passt zu jedem Schema)
//   unter 10 %         Fuellung und Rahmen rot
//
// Die Grenzen sind dieselben wie Power.low/critical; percent und charging
// sind eigene Properties, damit der Sperrbildschirm sie fuer Tests setzen kann.
Item {
    id: glyph

    property int percent: 0
    property bool charging: false
    // Grundfarbe fuer Rahmen und normale Fuellung
    property color fg: Colors.fgBackground
    property real bodyWidth: 20
    property real bodyHeight: 11

    readonly property real level: Math.max(0, Math.min(100, glyph.percent)) / 100
    readonly property bool critical: !glyph.charging && glyph.percent < 10
    readonly property bool low: !glyph.charging && glyph.percent <= 20
    readonly property color fillColor: glyph.charging ? Colors.primary
                                     : glyph.critical ? Colors.error
                                     : glyph.low ? Colors.mix(Colors.error, "#ffb547", 0.55)
                                     : glyph.fg
    readonly property color frameColor: glyph.critical ? Colors.alpha(Colors.error, 0.8)
                                                       : Colors.alpha(glyph.fg, 0.5)

    implicitWidth: glyph.bodyWidth + 3
    implicitHeight: glyph.bodyHeight

    Rectangle {
        id: body

        width: glyph.bodyWidth
        height: glyph.bodyHeight
        radius: height * 0.32
        color: "transparent"
        border.width: 1.5
        border.color: glyph.frameColor

        Behavior on border.color {
            ColorAnimation { duration: Appearance.fadeDuration }
        }

        // Fuellung mit 1 px Luft zum Rahmen; nie ganz weg, damit "leer"
        // noch als Akku lesbar bleibt
        Rectangle {
            id: fill

            x: 2.5
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(2, (body.width - 5) * glyph.level)
            height: body.height - 5
            radius: Math.max(1, body.radius - 2)
            color: glyph.fillColor

            Behavior on width {
                NumberAnimation { duration: Appearance.morphDuration; easing.type: Easing.OutCubic }
            }
            Behavior on color {
                ColorAnimation { duration: Appearance.fadeDuration }
            }
        }

        // Blitz zweifarbig, an der Fuellkante geteilt: ueber der Fuellung
        // ausgestanzt (Hintergrundfarbe), ueber der Leere in Rahmenfarbe.
        // Eine Kontur um den ganzen Blitz war bei 11 px nur noch Brei.
        Repeater {
            model: glyph.charging ? [true, false] : []

            Item {
                id: half

                required property bool modelData   // true = Teil ueber der Fuellung
                readonly property real edge: fill.x + fill.width

                x: half.modelData ? 0 : half.edge
                width: half.modelData ? half.edge : body.width - half.edge
                height: body.height
                clip: true

                Text {
                    x: -half.x
                    width: body.width
                    height: body.height
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: "bolt"
                    color: half.modelData ? Colors.background : glyph.fg
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: body.height
                    font.variableAxes: ({ FILL: 1 })
                }
            }
        }
    }

    // Pluspol
    Rectangle {
        anchors.left: body.right
        anchors.leftMargin: 1
        anchors.verticalCenter: body.verticalCenter
        width: 2
        height: Math.round(glyph.bodyHeight * 0.4)
        radius: 1
        color: glyph.frameColor
    }
}
