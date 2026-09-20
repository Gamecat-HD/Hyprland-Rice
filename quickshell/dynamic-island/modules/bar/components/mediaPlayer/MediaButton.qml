pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

import "root:/"

// Ein Icon-Knopf der Medien-Pille. Trefferflaeche und Glyph sind entkoppelt:
// das Item ist groesser als das Zeichen, damit man nicht zielen muss (dasselbe
// Muster wie bei den Workspace-Punkten).
Item {
    id: button

    required property string icon
    required property real size
    // false = Player kann das gerade nicht -> ausgegraut und nicht klickbar
    property bool active: true

    signal triggered

    Layout.preferredWidth: button.size + 4
    Layout.preferredHeight: button.size
    Layout.alignment: Qt.AlignVCenter

    opacity: button.active ? 1 : 0.35

    Behavior on opacity {
        NumberAnimation { duration: 140 }
    }

    Text {
        anchors.centerIn: parent

        text: button.icon
        color: hover.hovered && button.active ? Colors.primary : Colors.fgSurfaceVariant
        font.family: "Material Symbols Outlined"
        font.pixelSize: button.size

        Behavior on color {
            ColorAnimation { duration: 140 }
        }
    }

    HoverHandler {
        id: hover

        enabled: button.active
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        enabled: button.active
        onTapped: button.triggered()
    }
}
