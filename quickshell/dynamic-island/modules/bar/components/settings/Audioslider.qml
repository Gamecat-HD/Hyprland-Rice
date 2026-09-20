pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

import qs.modules.services.audio

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

    property real value: Audio.volume
    property bool muted: Audio.muted
    property color activeColor: muted ? Colors.error : Colors.fgBackground

    readonly property real ringRadius: (Math.min(width, height) - arcWidth) / 2 - arcGap

    ShapePath {
        strokeWidth: slider.arcWidth
        strokeColor: Colors.alpha(slider.activeColor, 0.55)   // Track
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
        strokeColor: slider.activeColor
        fillColor: "transparent"
        PathAngleArc {
            centerX: parent.width / 2
            centerY: parent.height / 2
            radiusX: slider.ringRadius
            radiusY: slider.ringRadius
            startAngle: slider.startAngle
            sweepAngle: slider.sweepAngle * Math.max(0, Math.min(1, slider.value))
        }
    }
}
