pragma ComponentBehavior: Bound
import QtQuick

import "root:/"

Item {
    id: root

    required property string title
    required property string icon
    property real value: 0
    property color accent: Colors.primary

    signal adjusted(real value)

    implicitHeight: 42

    function adjustAt(x: real): void {
        root.adjusted(Math.max(0, Math.min(1, x / sliderArea.width)));
    }

    Text {
        id: sliderIcon

        anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
        }
        width: 28
        text: root.icon
        horizontalAlignment: Text.AlignHCenter
        font.family: "Material Symbols Outlined"
        font.pixelSize: 20
        color: root.accent
    }

    Text {
        anchors {
            top: parent.top
            left: sliderIcon.right
            leftMargin: 10
        }
        text: root.title
        font.pixelSize: 12
        font.weight: Font.DemiBold
        color: Colors.fgBackground
    }

    Text {
        anchors {
            top: parent.top
            right: parent.right
        }
        text: `${Math.round(root.value * 100)}%`
        font.pixelSize: 11
        color: Colors.fgSurfaceVariant
    }

    Item {
        id: sliderArea

        anchors {
            left: sliderIcon.right
            leftMargin: 10
            right: parent.right
            bottom: parent.bottom
        }
        height: 20

        Rectangle {
            id: track

            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            height: 6
            radius: height / 2
            color: Colors.alpha(Colors.fgSurface, 0.16)

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, root.value))
                height: parent.height
                radius: parent.radius
                color: root.accent
            }
        }

        Rectangle {
            width: 14
            height: 14
            radius: 7
            x: Math.max(0, Math.min(parent.width - width,
                                    root.value * parent.width - width / 2))
            anchors.verticalCenter: parent.verticalCenter
            color: root.accent
        }

        MouseArea {
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
