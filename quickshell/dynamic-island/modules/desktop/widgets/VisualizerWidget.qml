pragma ComponentBehavior: Bound
import QtQuick

import qs
import qs.modules.services.audio
import qs.modules.services.core
import qs.modules.services.media
import qs.modules.widgets

// Grosser Visualiser auf dem Desktop. Haengt am selben cava wie die Notch
// (Cava.demand) – es laeuft nie ein zweiter Prozess. Bedarf nur, solange der
// Desktop zu sehen ist und Musik spielt; ohne Musik blendet er aus oder
// bleibt als ruhige Linie stehen (opts.idle).
Item {
    id: root

    property real unit: 16
    property bool active: true
    property bool editing: false
    property var opts: ({})
    property color color: Colors.fgBackground
    property color accent: Colors.primary

    readonly property bool live: root.active && Media.playing
    readonly property int bars: Number(root.opts.bars ?? 32)

    implicitWidth: vis.implicitWidth
    implicitHeight: vis.height
    opacity: root.live || root.editing || root.opts.idle === "ruhig" ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
        NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
    }

    DemandRequest {
        demand: Cava.demand
        active: root.live && root.visible
    }

    Visualizer {
        id: vis

        anchors.centerIn: parent
        style: root.opts.style ?? "saeulen"
        count: root.bars
        barWidth: Math.max(2, Math.round(root.unit * 24 / root.bars * 0.6))
        spacing: Math.max(1, Math.round(root.unit * 24 / root.bars * 0.4))
        height: Math.round(root.unit * 6)
        color: root.accent
        active: root.live
    }
}
