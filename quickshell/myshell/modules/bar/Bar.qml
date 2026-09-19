pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "components/notch"
import "components/settings"

import "root:/"

// Leiste oben – enthält selbst die Pro-Monitor-Logik.
// Die `required property modelData` im Delegaten wird von `Variants`
// automatisch mit dem jeweiligen Screen befüllt (Caelestia-Stil).
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: bar

        required property ShellScreen modelData

        readonly property real borderWidth: 0.5
        readonly property color borderColor: Colors.outlineVariant   // M3-Neutralfarbe, passt zu jedem Scheme
        
        readonly property real verticalMargin: 10

        screen: bar.modelData
        WlrLayershell.namespace: "myshell-bar"
        anchors {
            top: true
            left: true
            right: true
        }
        implicitHeight: 45
        color: "transparent"

        Notch {
            id: notch
            verticalMargin: bar.verticalMargin    // Gesamt-Rand oben+unten; durchs Zentrieren je 10
            borderWidth: bar.borderWidth   // `this` gibt es in QML-Bindings nicht
            borderColor: bar.borderColor   // Quelle: eine Ebene weiter oben definiert

            width: clock.implicitWidth + 50   // `clock` = die Clock-Instanz unten
        }
        
        Settings {
            id: settings
            anchors {
                left: notch.right
                leftMargin: 15
            }
            verticalMargin: bar.verticalMargin
            borderWidth: bar.borderWidth
        }

        Settings {
            id: test
            anchors {
                right: notch.left
                rightMargin: 15
            }
            verticalMargin: bar.verticalMargin
            borderWidth: bar.borderWidth
        }
    }
}
