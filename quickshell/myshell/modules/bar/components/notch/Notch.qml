pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

import "root:/"

Item {
    id: notch
    anchors.centerIn: parent
    height: parent.height - verticalMargin
    
    required property real verticalMargin // margin über bzw unter der notch
    required property real borderWidth   // von außen überschreibbar (Bar.qml macht das)
    required property color borderColor
    
    readonly property bool containsMouse: ma.containsMouse
    readonly property alias clock: pill.clock
    readonly property alias ma: ma

    readonly property real borderRad: height / 2

    Rectangle {
        id: pill
        anchors.fill: parent

        radius: borderRad
        border.width: borderWidth
        border.color: notch.borderColor   // vom Aufrufer, z.B. Colors.outlineVariant

        height: parent.height
        color: Colors.background

        readonly property alias clock: clock

        Clock {
            id: clock
            containsMouse: notch.containsMouse
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        onClicked: console.log("clicked")
    }
}