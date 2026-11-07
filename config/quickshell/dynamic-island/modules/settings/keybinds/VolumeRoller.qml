pragma ComponentBehavior: Bound
import QtQuick

import qs

// Lautstaerke-Walze im Gehaeuse: linke Haelfte leiser, rechte lauter.
// Jede Haelfte leuchtet fuer sich (Belegung aus der Ebene).
Item {
    id: roller

    required property real unit
    // Belegung/Licht je Haelfte: [leiser, lauter]
    property var infos: [null, null]
    property var lights: ["transparent", "transparent"]
    property var lits: [false, false]
    property var ids: ["xf86audiolowervolume", "xf86audioraisevolume"]
    property bool pick: false
    property bool interactive: true

    signal clicked(string id)

    readonly property color rockBase: Qt.darker(Colors.surfaceBright, 1.6)

    width: roller.unit * 1.7
    height: roller.unit * 0.5
    z: leftHalf.hovered || rightHalf.hovered ? 2 : 0

    // Rock
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: roller.rockBase
    }

    // Walze mit Rillen
    Rectangle {
        id: drum

        x: roller.unit * 0.04
        y: roller.unit * 0.02
        width: parent.width - roller.unit * 0.08
        height: parent.height - roller.unit * 0.08
        radius: height / 2
        color: Qt.lighter(Colors.surfaceBright, 1.05)
        clip: true

        Row {
            anchors.centerIn: parent
            spacing: Math.max(3, roller.unit * 0.07)

            Repeater {
                model: 14

                Rectangle {
                    width: 1
                    height: drum.height - roller.unit * 0.12
                    color: Colors.alpha(Colors.background, 0.55)
                }
            }
        }

        // Licht je Haelfte
        Rectangle {
            x: 0
            width: parent.width / 2
            height: parent.height
            color: Colors.alpha(roller.lights[0], (roller.lits[0] ? 0.5 : roller.infos[0] ? 0.3 : 0) * (roller.infos[0]?.disabled ? 0.5 : 1))

            Behavior on color {
                ColorAnimation { duration: Appearance.fadeDuration }
            }
        }

        Rectangle {
            x: parent.width / 2
            width: parent.width / 2
            height: parent.height
            color: Colors.alpha(roller.lights[1], (roller.lits[1] ? 0.5 : roller.infos[1] ? 0.3 : 0) * (roller.infos[1]?.disabled ? 0.5 : 1))

            Behavior on color {
                ColorAnimation { duration: Appearance.fadeDuration }
            }
        }

        // Hover-Aufhellung
        Rectangle {
            x: leftHalf.hovered ? 0 : parent.width / 2
            width: parent.width / 2
            height: parent.height
            visible: roller.interactive && (leftHalf.hovered || rightHalf.hovered)
            color: Colors.alpha(Colors.fgSurface, 0.08)
        }
    }

    // Symbole an den Enden
    Text {
        anchors {
            left: parent.left
            leftMargin: roller.unit * 0.12
            verticalCenter: parent.verticalCenter
        }
        text: "remove"
        color: roller.infos[0] ? roller.lights[0] : Colors.alpha(Colors.fgSurfaceVariant, 0.5)
        font.family: "Material Symbols Outlined"
        font.pixelSize: Math.max(9, Math.round(roller.unit * 0.22))
    }

    Text {
        anchors {
            right: parent.right
            rightMargin: roller.unit * 0.12
            verticalCenter: parent.verticalCenter
        }
        text: "add"
        color: roller.infos[1] ? roller.lights[1] : Colors.alpha(Colors.fgSurfaceVariant, 0.5)
        font.family: "Material Symbols Outlined"
        font.pixelSize: Math.max(9, Math.round(roller.unit * 0.22))
    }

    Item {
        id: leftHalf

        readonly property bool hovered: lh.hovered && roller.interactive

        width: parent.width / 2
        height: parent.height

        HoverHandler {
            id: lh

            cursorShape: roller.infos[0] || roller.pick ? Qt.PointingHandCursor : Qt.ArrowCursor
        }

        TapHandler {
            enabled: roller.interactive && (roller.infos[0] !== null || roller.pick)
            onTapped: roller.clicked(roller.ids[0])
        }
    }

    Item {
        id: rightHalf

        readonly property bool hovered: rh.hovered && roller.interactive

        x: parent.width / 2
        width: parent.width / 2
        height: parent.height

        HoverHandler {
            id: rh

            cursorShape: roller.infos[1] || roller.pick ? Qt.PointingHandCursor : Qt.ArrowCursor
        }

        TapHandler {
            enabled: roller.interactive && (roller.infos[1] !== null || roller.pick)
            onTapped: roller.clicked(roller.ids[1])
        }
    }

    KeyTooltip {
        readonly property int side: leftHalf.hovered ? 0 : 1
        readonly property var info: roller.infos[side]

        anchors {
            horizontalCenter: parent.horizontalCenter
            top: parent.bottom
            topMargin: 6
        }
        z: 10
        visible: leftHalf.hovered || rightHalf.hovered
        title: info ? `${I18n.tr(info.group)} › ${I18n.tr(info.title)}` : I18n.tr(side === 0 ? "Leiser" : "Lauter")
        keys: info?.keys ?? []
        hint: info?.disabled ? I18n.tr("aus") : ""
    }
}
