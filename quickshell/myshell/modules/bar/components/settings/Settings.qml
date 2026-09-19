pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io

import "root:/"

// Settings-Knopf rechts neben der Notch mit Lautstärke-Ring außenrum.
// Der Ring ist NUR Anzeige (kein Input) – Lautstärke wird über wpctl gelesen.
Item {
    id: settings

    // Schnittstelle (Bar.qml setzt verticalMargin)
    required property real verticalMargin
    property real borderWidth: 1

    // Lautstärke 0..1 (aus wpctl), plus Mute-Flag
    property real volume: 0
    property bool muted: false

    readonly property real ringWidth: 3
    readonly property real ringRadius: (Math.min(width, height) - ringWidth) / 2

    readonly property bool containsMouse: ma.containsMouse

    anchors {
        verticalCenter: parent.verticalCenter
    }
    width: height
    height: parent.height - verticalMargin

    // Innenkreis: der eigentliche Knopf, klein genug, dass der Ring Platz hat
    Rectangle {
        id: circle
        anchors.centerIn: parent
        width: parent.height - settings.ringWidth * 2 - 6
        height: width
        radius: width / 2
        color: settings.containsMouse ? Colors.surfaceBright : Colors.background
        border.width: settings.borderWidth
        border.color: Colors.outlineVariant

        Text {
            anchors.centerIn: parent
            text: "\uf013"                       // nf-fa-gear (Gear exists)
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: parent.height / 2
            color: Colors.fgSurfaceVariant
        }
    }

    // Ring außenrum: Track (voll) + Wert-Arc (Lautstärke)
    Shape {
        anchors.fill: parent
        layer.enabled: true
        layer.samples: 4                  // Antialiasing für weiche Kanten

        ShapePath {
            strokeWidth: settings.ringWidth
            strokeColor: Colors.surfaceBright
            fillColor: "transparent"
            PathAngleArc {
                centerX: settings.width / 2
                centerY: settings.height / 2
                radiusX: settings.ringRadius
                radiusY: settings.ringRadius
                startAngle: 90
                sweepAngle: 360
            }
        }

        ShapePath {
            strokeWidth: settings.ringWidth
            strokeColor: settings.muted ? Colors.error : Colors.primary
            fillColor: "transparent"
            PathAngleArc {
                centerX: settings.width / 2
                centerY: settings.height / 2
                radiusX: settings.ringRadius
                radiusY: settings.ringRadius
                startAngle: 90
                sweepAngle: -360 * settings.volume   // negativ = im Uhrzeigersinn ab 12 Uhr
            }
        }
    }

    // Lautstärke lesen: `wpctl get-volume @DEFAULT_AUDIO_SINK@` -> "Volume: 0.65"
    Process {
        id: volProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim();
                settings.volume = parseFloat(t.split(":")[1]) || 0;
                settings.muted = t.includes("MUTED");
            }
        }
    }

    // 1x pro Sekunde neu lesen (reine Anzeige braucht kein Event-Piping)
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: volProc.running = true
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        onClicked: console.log("settings clicked")
    }
}
