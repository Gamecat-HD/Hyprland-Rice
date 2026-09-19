pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

import "root:/"

// Uhr-Label. Der Hover-Status kommt von außen (der Notch) als Property rein –
// Ids sind pro Datei unsichtbar, deshalb nicht `notch.containsMouse` hier.
Text {
    id: clock

    required property bool containsMouse

    anchors.centerIn: parent
    color: containsMouse ? Colors.primary : Colors.secondary
    text: Qt.formatDateTime(clockSource.date, "HH:mm")

    // Eingebaute Uhr statt externem `date`-Prozess pro Sekunde
    SystemClock {
        id: clockSource
        precision: SystemClock.Minutes
        
    }
}
