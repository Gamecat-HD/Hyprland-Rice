pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "components"

import "root:/"

// Leiste oben – enthält selbst die Pro-Monitor-Logik.
// Die `required property modelData` im Delegaten wird von `Variants`
// automatisch mit dem jeweiligen Screen befüllt (Caelestia-Stil).
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: bar

        required property ShellScreen modelData

        screen: bar.modelData
        WlrLayershell.namespace: "myshell-bar"
        anchors {
            top: true
            left: true
            right: true
        }
        implicitHeight: 50
        color: "transparent"

        Notch {
            id: notch
            width: clock.implicitWidth + 15   // nur hier ist `clock` sichtbar

            Text {
                id: clock
                anchors.centerIn: parent

                color: notch.containsMouse ? Colors.secondary : Colors.primary
                text: Qt.formatDateTime(clockSource.date, "ddd dd. MMM HH:mm")
            }

            // Eingebaute Uhr statt externem `date`-Prozess pro Sekunde
            SystemClock {
                id: clockSource
                precision: SystemClock.Minutes
            }
        }

        /*Text {
            anchors.centerIn: parent
            color: Colors.fgSurface
            font.pixelSize: 14
            text: Qt.formatDateTime(clock.date, "ddd dd.MM.  HH:mm")
        }

        SystemClock {
            id: clock
            precision: SystemClock.Minutes
        }*/
    }
}
