pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Services.Pipewire

import "root:/"

Shape {
    id: slider

    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer   // echte Kurven, nicht "eckig"
    layer.enabled: true
    layer.samples: 8                             // 8x Supersampling -> glatte Kanten
    smooth: true
    antialiasing: true

    required property real arcWidth
    required property real arcGap
    required property real startAngle
    required property real sweepAngle

    // Lautstärke live aus PipeWire (0..1) + Mute-Flag
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false

    readonly property real ringRadius: (Math.min(width, height) - arcWidth) / 2 - arcGap

    ShapePath {
        strokeWidth: slider.arcWidth
        strokeColor: Colors.alpha(Colors.fgBackground, 0.55)   // Track
        fillColor: "transparent"
        PathAngleArc {
            centerX: parent.width / 2
            centerY: parent.height / 2
            radiusX: slider.ringRadius
            radiusY: slider.ringRadius
            startAngle: slider.startAngle
            sweepAngle: slider.sweepAngle
        }
    }

    ShapePath {
        strokeWidth: slider.arcWidth
        strokeColor: slider.muted ? Colors.error : Colors.fgBackground
        fillColor: "transparent"
        PathAngleArc {
            centerX: parent.width / 2
            centerY: parent.height / 2
            radiusX: slider.ringRadius
            radiusY: slider.ringRadius
            startAngle: slider.startAngle
            sweepAngle: slider.sweepAngle * slider.volume
        }
    }

    // Macht die PipeWire-Objekt-Properties live beobachtbar
    PwObjectTracker {
        objects: [slider.sink].filter(n => n)
    }
}