pragma ComponentBehavior: Bound
import QtQuick

import qs
import qs.modules.services.config

// Knopf der Bearbeitungs-Leisten der Steuerung (Entfernen, Zuruecksetzen,
// Fertig): Symbol + Text als Pille. `accent` = Akzent-Fuellung (Fertig),
// `danger` = rot (Entfernen), sonst neutral.
Rectangle {
    id: button

    property string icon: ""
    property string text: ""
    property bool accent: false
    property bool danger: false
    signal clicked()

    implicitWidth: row.implicitWidth + (button.text !== "" ? 24 : 14)
    implicitHeight: 30
    radius: 15
    color: button.accent ? Colors.alpha(Colors.primary, hover.hovered ? 0.3 : 0.18)
         : button.danger ? Colors.alpha(Colors.error, hover.hovered ? 0.26 : 0.14)
         : Colors.alpha(Colors.fgSurface, hover.hovered ? 0.14 : 0.07)
    border.width: 1
    border.color: button.accent ? Colors.alpha(Colors.primary, 0.5)
                : button.danger ? Colors.alpha(Colors.error, 0.45)
                : Colors.alpha(Colors.outline, 0.3)

    readonly property color fg: button.accent ? Colors.primary : button.danger ? Colors.error : Colors.fgSurface

    Behavior on color {
        ColorAnimation { duration: 120 }
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 5

        Text {
            visible: button.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: button.icon
            color: button.fg
            font.family: "Material Symbols Outlined"
            font.pixelSize: 16
        }

        Text {
            visible: button.text !== ""
            anchors.verticalCenter: parent.verticalCenter
            font.family: Config.font
            text: button.text
            color: button.fg
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }
    }

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: button.clicked()
    }
}
