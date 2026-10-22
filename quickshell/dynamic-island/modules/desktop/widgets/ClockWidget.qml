pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

import qs
import qs.modules.services.config
import qs.modules.widgets.clock

// Uhr auf dem Desktop: dieselben Zifferblaetter wie die Notch
// (modules/widgets/clock), nur gross. Optional mit Datum darunter.
// Eine SystemClock mit Minuten-Genauigkeit – ein Neuzeichnen pro Minute.
Item {
    id: root

    property real unit: 16
    property bool active: true
    property bool editing: false
    property var opts: ({})
    property color color: Colors.fgBackground
    property color accent: Colors.primary

    implicitWidth: face.implicitWidth
    implicitHeight: face.implicitHeight

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    ClockFace {
        id: face

        anchors.centerIn: parent
        style: root.opts.style ?? "gestapelt"
        date: clock.date
        size: root.unit * 4
        color: root.color
        accent: root.accent
        showDate: root.opts.date ?? true
    }
}
