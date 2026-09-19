pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Services.Pipewire

import "root:/"

// Settings-Knopf rechts neben der Notch. Lautstärke-Ring INNERHALB des Kreises,
// live aus PipeWire (kein Polling – Updates kommen sofort bei Volume-Änderung).
Rectangle {
    id: settings

    // Schnittstelle (Bar.qml setzt verticalMargin)
    required property real verticalMargin
    property real borderWidth: 1   // (Außenrand aktuell aus – siehe border.width unten)

    // Lautstärke live aus PipeWire (0..1) + Mute-Flag
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false

    readonly property real arcWidth: borderWidth                 // gleiche Dicke wie Notch-Border
    readonly property real arcGap: 3                             // kleiner Abstand Arc -> Border
    readonly property real ringRadius: (Math.min(width, height) - arcWidth) / 2 - arcGap

    readonly property bool containsMouse: ma.containsMouse

    anchors {
        verticalCenter: parent.verticalCenter
    }
    width: height
    height: parent.height - verticalMargin
    radius: width / 2                    // gleiche Rundung wie die Notch
    color: Colors.background
    border.width: borderWidth            // exakt wie die Notch (kommt aus Bar.qml)
    border.color: Colors.outlineVariant

    // Track + Wert-Arc. Unten bleibt immer eine Lücke (±10° um 90° – Qt-Shapes
    // drehen im Uhrzeigersinn, 90° = unten!). Start bei 80° (rechte Lücken-Kante),
    // negativer Sweep = gegen den Uhrzeigersinn -> rechts füllt zuerst.
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer   // echte Kurven, nicht "eckig"

        ShapePath {
            strokeWidth: settings.arcWidth
            strokeColor: Colors.alpha(Colors.fgBackground, 0.55)   // Track
            fillColor: "transparent"
            PathAngleArc {
                centerX: settings.width / 2
                centerY: settings.height / 2
                radiusX: settings.ringRadius
                radiusY: settings.ringRadius
                startAngle: 0
                sweepAngle: -340
            }
        }

        ShapePath {
            strokeWidth: settings.arcWidth
            strokeColor: settings.muted ? Colors.error : Colors.fgBackground
            fillColor: "transparent"
            PathAngleArc {
                centerX: settings.width / 2
                centerY: settings.height / 2
                radiusX: settings.ringRadius
                radiusY: settings.ringRadius
                startAngle: 120
                sweepAngle: 295 * settings.volume
            }
        }
    }

    // Macht die PipeWire-Objekt-Properties live beobachtbar
    PwObjectTracker {
        objects: [settings.sink].filter(n => n)
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        onClicked: console.log("settings clicked")
    }
}
