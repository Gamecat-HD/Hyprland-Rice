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

    // Fuer Datumsanzeigen daneben (Notch-Layout), ohne zweite SystemClock
    readonly property date date: clockSource.date

    color: Colors.fgBackground
    text: Qt.formatDateTime(clockSource.date, Config.appearance.clock === "12h" ? "h:mm AP" : "HH:mm")
    font.pointSize: 13
    font.weight: Font.Bold
    font.letterSpacing: 0.4

    // Eingebaute Uhr statt externem `date`-Prozess pro Sekunde
    SystemClock {
        id: clockSource
        precision: SystemClock.Minutes
    }
}
