pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

import qs
import qs.modules.services.config

// Uhr-Label. Positioniert wird von der Notch (bleibt beim Aufklappen im
// oberen Band stehen).
Text {
    id: clock
    font.family: Config.font

    color: Colors.secondary
    text: Qt.formatDateTime(clockSource.date, "HH:mm")
    font.pointSize: 13
    font.weight: Font.Bold

    // Eingebaute Uhr statt externem `date`-Prozess pro Sekunde
    SystemClock {
        id: clockSource
        precision: SystemClock.Minutes
    }
}
