pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Io

import "components/notch"
import "components/settings"
import "components/statusBar"
import "components/workspaceSelector"
import "components/mediaPlayer"
import "root:/modules/launcher"

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
        // Eckenrundung aller Karten (Notch, Workspace-Selektor). Hier einmal
        // setzen – die Komponenten verlangen den Wert und rechnen selbst, wie
        // weit sie ihn ausreizen (die Notch wird flach zur Pille, der Selektor
        // deckelt auf die halbe Breite).
        readonly property real cardRadius: 18

        readonly property real verticalMargin: 10
        readonly property real barHeight: 40

        screen: bar.modelData
        WlrLayershell.namespace: "dynamic-island-bar"
        // Nur wenn der Launcher offen ist, braucht die Leiste Tastatur –
        // der Focus-Grab darunter holt sie sich und meldet Klicks daneben.
        WlrLayershell.keyboardFocus: notch.launcherOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        anchors {
            top: true
            left: true
            right: true
        }

        // Das Fenster ist höher als die sichtbare Leiste, damit die Notch nach
        // unten aufklappen kann (Layer-Surfaces können nicht überzeichnen).
        // Platz reserviert wird trotzdem nur die Leiste, und Eingaben nimmt nur
        // an, was die `mask` abdeckt – der Rest ist klick-durchlässig.
        implicitHeight: bar.barHeight + notch.maxDrop
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: bar.barHeight
        color: "transparent"

        mask: Region {
            Region {
                width: bar.width
                height: bar.barHeight
            }
            Region {
                item: notch
            }
        }

        // Die eigentliche Leiste: feste Höhe, damit die Widgets beim Aufklappen
        // der Notch nicht mitwandern. Die Notch darf hier unten rausragen.
        HyprlandFocusGrab {
            active: notch.launcherOpen
            windows: [bar]
            onCleared: LauncherState.close()
        }

        Item {
            id: row

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            height: bar.barHeight


            /* Workspace Selektor */
            WorkspaceSelector {
                verticalMargin: bar.verticalMargin
                borderWidth: bar.borderWidth
                borderColor: bar.borderColor
                cardRadius: bar.cardRadius
            }


            /* Mittlere Notch */
            StatusBar {
                id: statusBar
                anchors {
                    right: parent.horizontalCenter
                    rightMargin: notch.width / 2 + 15
                }
                verticalMargin: bar.verticalMargin
                borderWidth: bar.borderWidth
            }

            Notch {
                id: notch
                verticalMargin: bar.verticalMargin    // Gesamt-Rand oben+unten; durchs Zentrieren je 10
                borderWidth: bar.borderWidth   // `this` gibt es in QML-Bindings nicht
                borderColor: bar.borderColor   // Quelle: eine Ebene weiter oben definiert
                cardRadius: bar.cardRadius     // dito – teilt sich den Wert mit dem Selektor
            }

            // Beide Nachbarn hängen an der Bildschirmmitte plus der halben
            // *aktuellen* Notch-Breite: klappt die Notch auf, weichen sie
            // animiert zur Seite, statt unter der Karte zu verschwinden.
            Settings {
                id: settings
                anchors {
                    left: parent.horizontalCenter
                    leftMargin: notch.width / 2 + 15
                }
                verticalMargin: bar.verticalMargin
                borderWidth: bar.borderWidth
            }

            MediaPlayer {
                id: media
                verticalMargin: bar.verticalMargin    // Gesamt-Rand oben+unten; durchs Zentrieren je 10
                borderWidth: bar.borderWidth   // `this` gibt es in QML-Bindings nicht
                borderColor: bar.borderColor   // Quelle: eine Ebene weiter oben definiert
                cardRadius: bar.cardRadius     // dito - teilt sich den Wert mit Notch und Selektor
            }
        }
    }
}
