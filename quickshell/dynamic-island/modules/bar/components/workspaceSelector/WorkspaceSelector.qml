pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.modules.services.hypr

import "root:/"

// Karte links in der Leiste. Rundung, Randstärke und Randfarbe kommen aus
// Bar.qml, damit sie sich nichts mit der Notch ausdenken muss.
Item {
    id: root
    anchors {
        left: parent.left
        leftMargin: HyprGaps.left
    }

    required property real verticalMargin // margin über bzw unter der notch
    required property real borderWidth   // von außen überschreibbar (Bar.qml macht das)
    required property color borderColor
    required property real cardRadius

    width: 200
    height: parent.height - verticalMargin
    y: verticalMargin / 2

    Rectangle {
        id: card
        anchors.fill: parent

        // Bei flacher Karte greift die halbe Breite, sonst bliebe die Rundung
        // an den kurzen Kanten hängen – dasselbe Muster wie in der Notch.
        radius: Math.min(width / 2, root.cardRadius)
        border.width: root.borderWidth
        border.color: root.borderColor
        color: Colors.background
    
        Text {
            id: testtext
            anchors.horizontalCenter: parent.horizontalCenter
            color: Colors.primary
            text: "AAAAA"
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent

        onClicked: HyprGaps.reload()
        onWheel: console.log("C")
    }
}
