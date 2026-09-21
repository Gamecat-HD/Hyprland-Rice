pragma ComponentBehavior: Bound
import QtQuick

import "root:/"

Rectangle {
    id: root

    required property string title
    required property string icon
    property real value: 0
    property color accent: Colors.primary
    property color foreground: Colors.fgPrimary
    property bool detailsAvailable: false

    signal adjusted(real value)
    signal detailsRequested()

    implicitHeight: 58
    radius: 14
    color: cardHover.hovered ? Colors.shade(Colors.background, 0.075)
                             : Colors.shade(Colors.background, 0.05)
    border.width: 1
    border.color: cardHover.hovered ? Colors.alpha(root.accent, 0.45)
                                    : Colors.alpha(Colors.outlineVariant, 0.55)

    Behavior on color {
        ColorAnimation { duration: 120 }
    }

    Behavior on border.color {
        ColorAnimation { duration: 120 }
    }

    function adjustAt(x: real): void {
        root.adjusted(Math.max(0, Math.min(1, x / sliderArea.width)));
    }

    HoverHandler {
        id: cardHover
    }

    Text {
        anchors {
            top: parent.top
            topMargin: 7
            left: parent.left
            leftMargin: 12
        }
        text: root.title
        font.pixelSize: 12
        font.weight: Font.DemiBold
        color: Colors.fgBackground
    }

    Text {
        id: percentText

        anchors {
            top: parent.top
            topMargin: 7
            right: parent.right
            rightMargin: root.detailsAvailable ? 36 : 12
        }
        text: `${Math.round(root.value * 100)}%`
        font.pixelSize: 11
        color: Colors.fgSurfaceVariant
    }

    Rectangle {
        anchors {
            right: parent.right
            rightMargin: 6
            top: parent.top
            topMargin: 3
        }
        width: 26
        height: 26
        radius: 13
        visible: root.detailsAvailable
        color: detailsArea.containsMouse ? Colors.alpha(root.accent, 0.16) : "transparent"

        Text {
            anchors.centerIn: parent
            text: "chevron_right"
            color: detailsArea.containsMouse ? root.accent : Colors.fgSurfaceVariant
            font.family: "Material Symbols Outlined"
            font.pixelSize: 18
        }

        MouseArea {
            id: detailsArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.detailsRequested()
        }
    }

    Item {
        id: sliderArea

        anchors {
            left: parent.left
            leftMargin: 10
            right: parent.right
            rightMargin: 10
            bottom: parent.bottom
            bottomMargin: 7
        }
        height: 18

        Rectangle {
            id: track

            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            height: 16
            radius: height / 2
            color: Colors.alpha(Colors.fgSurface, 0.16)

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, root.value))
                height: parent.height
                radius: parent.radius
                color: root.accent
            }

            Text {
                anchors {
                    left: parent.left
                    leftMargin: 7
                    verticalCenter: parent.verticalCenter
                }
                text: root.icon
                font.family: "Material Symbols Outlined"
                font.pixelSize: 12
                color: root.value >= 0.08 ? root.foreground : Colors.fgSurfaceVariant
            }
        }

        MouseArea {
            id: inputArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed: mouse => root.adjustAt(mouse.x)
            onPositionChanged: mouse => {
                if (pressed)
                    root.adjustAt(mouse.x);
            }
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                root.adjusted(Math.max(0, Math.min(1,
                    root.value + (event.angleDelta.y >= 0 ? 0.05 : -0.05))));
                event.accepted = true;
            }
        }
    }
}
