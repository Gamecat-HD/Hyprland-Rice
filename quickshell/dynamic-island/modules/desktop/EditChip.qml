pragma ComponentBehavior: Bound
import QtQuick

import qs
import qs.modules.services.config

// Chip der Bearbeitungs-Oberflaeche (EditBar, WidgetOptions): Text, Symbol
// oder Farbtupfer, `on` = gewaehlt (Akzent), `danger` = Hover rot.
Rectangle {
    id: chip

    property string text: ""
    property string icon: ""
    property bool on: false
    property bool danger: false
    property color swatch: "transparent"
    signal clicked

    implicitWidth: chipRow.implicitWidth + (chip.text !== "" ? 22 : 14)
    implicitHeight: 28
    radius: 14
    color: chip.on ? Colors.primary
         : chipHover.hovered ? (chip.danger ? Colors.alpha(Colors.error, 0.25) : Colors.alpha(Colors.fgSurface, 0.14))
         : Colors.alpha(Colors.fgSurface, 0.07)

    Behavior on color {
        ColorAnimation { duration: 120 }
    }

    Row {
        id: chipRow

        anchors.centerIn: parent
        spacing: 5

        Rectangle {
            visible: chip.swatch.a > 0
            anchors.verticalCenter: parent.verticalCenter
            width: 14
            height: 14
            radius: 7
            color: chip.swatch
            border.width: 1
            border.color: Colors.alpha(Colors.fgSurface, 0.3)
        }

        Text {
            visible: chip.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: chip.icon
            color: chip.on ? Colors.fgPrimary : chip.danger ? Colors.error : Colors.fgSurface
            font.family: "Material Symbols Outlined"
            font.pixelSize: 16
        }

        Text {
            visible: chip.text !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: chip.text
            color: chip.on ? Colors.fgPrimary : Colors.fgSurface
            font.family: Config.font
            font.pixelSize: 11
            font.weight: chip.on ? Font.DemiBold : Font.Normal
        }
    }

    HoverHandler {
        id: chipHover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: chip.clicked()
    }
}
