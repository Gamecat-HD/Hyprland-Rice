import QtQuick

import qs

// Liegende Batterie, gefuellt nach Ladestand – ein Symbol fuer Notch,
// Settings-Pille und Sperrbildschirm statt der groben Material-Stufen.
//
//   laden / am Kabel   Fuellung im Akzent, Blitz in der Batterie, Lichtschimmer
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
    // Ladeschimmer (aus fuer Stellen, die nur kurz zu sehen sind)
    property bool animate: true

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

        // Fuellung buendig an der Innenkante des Rahmens; links rund wie der
        // Rahmen, rechts gerade, nie ganz weg (leer bleibt als Akku lesbar).
        // Ein Kasten mit Clip schneidet die volle, abgerundete Fuellung ab –
        // ein Ueberdeck-Rechteck fuer die gerade Kante gaebe bei
        // halbtransparenter Farbe einen hellen Streifen.
        Item {
            id: fill

            readonly property real inset: body.border.width
            readonly property real full: body.width - 2 * fill.inset

            x: fill.inset
            y: fill.inset
            width: Math.max(2, fill.full * glyph.level)
            height: body.height - 2 * fill.inset
            clip: true

            Behavior on width {
                NumberAnimation { duration: Appearance.morphDuration; easing.type: Easing.OutCubic }
            }

            Rectangle {
                width: fill.full
                height: fill.height
                radius: Math.max(0, body.radius - fill.inset)
                color: glyph.fillColor

                Behavior on color {
                    ColorAnimation { duration: Appearance.fadeDuration }
                }
            }

            // Laden: ein Lichtschimmer wandert durch die Fuellung, dann Pause
            // (zwischen den Durchlaeufen zeichnet die Notch nichts neu)
            Item {
                anchors.fill: parent
                visible: glyph.charging

                Rectangle {
                    id: shimmer

                    width: Math.max(6, body.width * 0.45)
                    height: parent.height
                    x: -width
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: "transparent" }
                        GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.55) }
                        GradientStop { position: 1; color: "transparent" }
                    }

                    SequentialAnimation on x {
                        running: glyph.charging && glyph.visible && glyph.animate
                        loops: Animation.Infinite

                        NumberAnimation {
                            from: -shimmer.width
                            to: fill.width
                            duration: Appearance.morphDuration * 3
                            easing.type: Easing.InOutSine
                        }
                        PauseAnimation { duration: Appearance.morphDuration * 7 }
                    }
                }
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
