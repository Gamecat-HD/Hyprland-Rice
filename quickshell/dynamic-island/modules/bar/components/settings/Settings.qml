pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import Quickshell
import qs.modules.services.vpn

import "root:/"

// Settings-Knopf rechts neben der Notch. Lautstärke-Ring INNERHALB des Kreises,
// live aus PipeWire (kein Polling – Updates kommen sofort bei Volume-Änderung).
Rectangle {
    id: settings

    // Schnittstelle (Bar.qml setzt verticalMargin)
    required property real verticalMargin
    property real borderWidth: 1   // (Außenrand aktuell aus – siehe border.width unten)


    anchors {
        verticalCenter: parent.verticalCenter
    }
    width: height
    height: parent.height - verticalMargin
    radius: width / 2                    // gleiche Rundung wie die Notch
    color: Colors.background
    border.width: borderWidth            // exakt wie die Notch (kommt aus Bar.qml)
    border.color: Colors.outlineVariant

    Audioslider {
        id: slider
        arcWidth: 2
        arcGap: 3
        startAngle: 130
        sweepAngle: 280
    }

    Wifi {}

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        onClicked: Vpn.toggle()
        onWheel: event => {
            if (!slider.sink.ready || !slider.sink.audio)
                return;
            const step = event.angleDelta.y > 0 ? 0.01 : -0.01;
            slider.sink.audio.volume = Math.max(0, Math.min(1, slider.volume + step));
        }
    }

    // ZULETZT deklariert = liegt oben und bekommt seine Klicks
    VpnIcon {}
}