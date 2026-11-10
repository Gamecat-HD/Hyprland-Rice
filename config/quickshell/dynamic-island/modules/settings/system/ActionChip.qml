pragma ComponentBehavior: Bound
import QtQuick

import qs
import qs.modules.services.config
import qs.modules.widgets

// Knopf im Chip-Stil (wie ActionButton in PluginManager / MonitorsEditor)
// fuer die Systemseite. Eigene Datei: eine Inline-`component` in einer schon
// geladenen Datei loest erst nach einem Neustart der Shell auf.
Rectangle {
    id: button

    required property string icon
    required property string label
    property color tint: Colors.fgSurface
    property bool filled: false
    signal clicked()

    implicitWidth: buttonRow.implicitWidth + 22
    implicitHeight: 28
    radius: height / 2
    opacity: enabled ? 1 : 0.4
    color: button.filled ? (buttonHover.hovered ? Colors.alpha(Colors.primary, 0.85) : Colors.primary)
         : buttonHover.hovered ? Colors.alpha(Colors.fgSurface, 0.12)
         : Colors.alpha(Colors.fgSurface, 0.06)

    Behavior on color {
        ColorAnimation { duration: Appearance.fadeDuration }
    }
    Fade on opacity {}

    Row {
        id: buttonRow

        anchors.centerIn: parent
        spacing: 5

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: button.icon
            color: button.filled ? Colors.fgPrimary : button.tint
            font.family: "Material Symbols Outlined"
            font.pixelSize: 15

            Behavior on color {
                ColorAnimation { duration: Appearance.fadeDuration }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            font.family: Config.font
            text: button.label
            color: button.filled ? Colors.fgPrimary : button.tint
            font.pixelSize: 11
            font.weight: button.filled ? Font.DemiBold : Font.Normal

            Behavior on color {
                ColorAnimation { duration: Appearance.fadeDuration }
            }
        }
    }

    HoverHandler {
        id: buttonHover

        cursorShape: button.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    TapHandler {
        enabled: button.enabled
        onTapped: button.clicked()
    }
}
