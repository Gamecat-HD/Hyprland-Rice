pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Io

import "components/notch"
import "components/notifications"
import "components/stats"
import "components/settings"
import "components/statusBar"
import "components/workspaceSelector"
import "components/mediaPlayer"
import "root:/modules/launcher"
import qs.modules.services.config
import qs.modules.services.hypr

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

        // Solange der Launcher offen ist, zieht sich das Fenster ueber den
        // ganzen Bildschirm und faengt Klicks daneben ab – damit geht er zu,
        // wie man es erwartet. Frueher machte das ein HyprlandFocusGrab; der
        // nahm der Leiste aber JEDE Zeigereingabe (in der Trefferliste und in
        // den Karussells liess sich nichts anklicken). Ein eigenes
        // Backdrop-Fenster wiederum wurde von Hyprland zwar gemappt, aber
        // weder gezeichnet noch mit Eingaben beliefert – deshalb hier, im
        // Fenster, das beides nachweislich bekommt.
        readonly property bool catching: notch.launcherOpen

        screen: bar.modelData
        WlrLayershell.namespace: "dynamic-island-bar"
        // Tastatur holt sich die Leiste nur, wenn wirklich getippt wird:
        // Launcher-Suchfeld oder WLAN-Passwort. Exclusive statt OnDemand, weil
        // der Launcher per Tastenkuerzel aufgeht – da ist kein Klick, der ihm
        // den Fokus geben koennte.
        WlrLayershell.keyboardFocus: notch.launcherOpen || settings.typingPassword || settings.typingPin
                                     ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        anchors {
            top: true
            left: true
            right: true
        }

        // Die Layer-Surface bleibt immer gleich hoch. Ein Resize von Kartenhoehe
        // auf Bildschirmhoehe beim Launcher-Start liess den Compositor die
        // gesamte Leiste kurz neu skalieren. Die Maske macht den transparenten
        // Rest weiterhin klick-durchlaessig; reserviert werden nur 40 px.
        implicitHeight: bar.modelData.height
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: bar.barHeight
        color: "transparent"

        mask: Region {
            Region {
                width: bar.width
                // Beim Fangen gilt das ganze Fenster als Eingabeflaeche
                height: bar.catching ? bar.height : bar.barHeight
            }
            Region {
                item: notch
            }
            // Ohne die eigene Region kaemen Klicks in der ausgeklappten
            // Medien-Karte nicht an – die Maske ist die Eingabeflaeche.
            Region {
                item: media
            }
            Region {
                item: settings   // aufgeklappte Settings-Karte klickbar halten
            }
            Region {
                item: settings.sleepMenu   // No-Sleep-Dropdown, solange offen
            }
            Region {
                item: notifications        // aufgeklappte Benachrichtigungs-Karte
            }
            Region {
                item: stats                // aufgeklappte System-Karte
            }
        }

        // Die Fangflaeche. Zuerst deklariert, damit sie unter allem liegt:
        // Klicks auf Notch, Karten und Leiste gehoeren denen.
        MouseArea {
            anchors.fill: parent
            enabled: bar.catching
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onPressed: LauncherState.close()
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
                id: workspaces
                visible: Config.bar.workspaces
                verticalMargin: bar.verticalMargin
                borderWidth: bar.borderWidth
                borderColor: bar.borderColor
                cardRadius: bar.cardRadius
            }


            /* System-Pille – haengt rechts am Selektor und wandert mit, wenn
               der breiter wird (Special-Workspaces). Anker deshalb hier und
               nicht in der Komponente. */
            StatsPill {
                id: stats
                visible: Config.bar.stats
                // Ohne Workspace-Punkte rueckt sie an den linken Rand
                anchors {
                    left: Config.bar.workspaces ? workspaces.right : parent.left
                    leftMargin: Config.bar.workspaces ? 10 : HyprGaps.left
                }
                verticalMargin: bar.verticalMargin
                borderWidth: bar.borderWidth
                borderColor: bar.borderColor
                cardRadius: bar.cardRadius
            }


            /* Mittlere Notch */
            StatusBar {
                id: statusBar
                visible: Config.bar.tray
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
                visible: Config.bar.settings
                anchors {
                    left: parent.horizontalCenter
                    leftMargin: notch.width / 2 + 15
                }
                verticalMargin: bar.verticalMargin
                borderWidth: bar.borderWidth
                cardRadius: bar.cardRadius
            }

            MediaPlayer {
                id: media
                visible: Config.bar.media
                verticalMargin: bar.verticalMargin    // Gesamt-Rand oben+unten; durchs Zentrieren je 10
                borderWidth: bar.borderWidth   // `this` gibt es in QML-Bindings nicht
                borderColor: bar.borderColor   // Quelle: eine Ebene weiter oben definiert
                cardRadius: bar.cardRadius     // dito - teilt sich den Wert mit Notch und Selektor
            }


            /* Benachrichtigungen – haengen links an der Medien-Karte und
               wachsen in die freie Luecke daneben hinein. Die Anker stehen
               hier und nicht in der Komponente, damit sie der Medien-Karte
               folgen, wenn die ihre Breite aendert. */
            NotificationPill {
                id: notifications
                visible: Config.bar.notifications
                // Ohne Medien-Karte rueckt sie an den rechten Rand
                anchors {
                    right: Config.bar.media ? media.left : parent.right
                    rightMargin: Config.bar.media ? 10 : HyprGaps.right
                }
                verticalMargin: bar.verticalMargin
                borderWidth: bar.borderWidth
                borderColor: bar.borderColor
                cardRadius: bar.cardRadius
            }
        }
    }
}
