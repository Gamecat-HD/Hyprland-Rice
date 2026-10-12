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
import qs.modules.launcher
import qs.modules.services.config
import qs.modules.services.hypr
import qs.modules.services.bluetooth
import qs.modules.services.media
import qs.modules.services.audio

import qs

// Leiste oben – enthält selbst die Pro-Monitor-Logik.
// Die `required property modelData` im Delegaten wird von `Variants`
// automatisch mit dem jeweiligen Screen befüllt (Caelestia-Stil).
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: bar

        required property ShellScreen modelData

        Connections {
            target: BluetoothService

            function onPairingActiveChanged(): void {
                if (BluetoothService.pairingActive && Hyprland.focusedMonitor?.name === bar.modelData.name) {
                    settings.expanded = true;
                    settings.wifiOpen = false;
                    settings.audioOpen = false;
                    settings.bluetoothOpen = true;
                }
            }
        }

        // Optik der Karten kommt zentral aus Appearance.qml
        readonly property real borderWidth: Appearance.borderWidth
        readonly property color borderColor: Appearance.borderColor
        // Eckenrundung aller Karten (Notch, Workspace-Selektor). Hier einmal
        // setzen – die Komponenten verlangen den Wert und rechnen selbst, wie
        // weit sie ihn ausreizen (die Notch wird flach zur Pille, der Selektor
        // deckelt auf die halbe Breite).
        readonly property real cardRadius: Appearance.radius

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

        // Notch-Layout (Config.appearance.layout, umschaltbar im Menue): die
        // anderen Pillen parken im Hub der Notch (`parent: notch.hub`) und
        // erscheinen dort, wenn sie aufklappt. Es sind dieselben Instanzen –
        // alle Referenzen unten (Maske, Tastaturfokus) gelten weiter.
        readonly property bool notchMode: Config.appearance.layout === "notch"
        // Wo der Pillen-Wrapper haengt: in der Leiste oder im Hub der Notch
        readonly property Item pillParent: bar.notchMode ? notch.hub : row
        // Linkes Ende der Kette im Hub, an das Tray und Settings anschliessen
        readonly property Item hubChainLeft: Config.bar.stats ? stats
                                           : Config.bar.workspaces ? workspaces
                                           : null

        // Der Visualiser ist ein eigener Prozess – er laeuft nur, solange
        // wirklich etwas spielt UND jemand die Pegel zeigt: die Medien-Karte
        // oder die Live-Activity der Notch. Ein Binding fuer beide, sonst
        // wuerden sich zwei Bindings an Cava.enabled gegenseitig ueberschreiben.
        Binding {
            target: Cava
            property: "enabled"
            value: Media.playing && (Config.bar.media || (bar.notchMode && Config.notch.media))
        }

        screen: bar.modelData
        WlrLayershell.namespace: "dynamic-island-bar"
        // Authentifizierung muss auch ueber echten Vollbild-Fenstern liegen.
        WlrLayershell.layer: notch.authOpen ? WlrLayer.Overlay : WlrLayer.Top
        // Tastatur holt sich die Leiste nur, wenn wirklich getippt wird:
        // Launcher-Suchfeld oder WLAN-Passwort. Exclusive statt OnDemand, weil
        // der Launcher per Tastenkuerzel aufgeht – da ist kein Klick, der ihm
        // den Fokus geben koennte.
        // Das Power-Menue braucht keinen Tastaturfokus. Exclusive wuerde den
        // gesamten Wayland-Seat binden und damit Klicks auf anderen Monitoren
        // blockieren, bis das Menue wieder geschlossen wird.
        WlrLayershell.keyboardFocus: notch.authOpen
                                     || (notch.launcherOpen && !notch.powerOpen)
                                     || settings.typingPassword || settings.typingPin
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
                item: settings.vpnMenu     // VPN-Anbieter-Dropdown
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


            // Alle Pillen ausser der Notch leben in diesem Wrapper. Er ist es,
            // der im Notch-Layout als Ganzes in den Hub der Notch umzieht –
            // so bleiben die Pillen immer Geschwister und ihre Anker
            // untereinander (stats -> workspaces, notifications -> media)
            // reissen beim Umparken nicht ab. Er fuellt seinen Elter (Leiste
            // bzw. Hub, beide 40 px hoch), die Pillen merken keinen Unterschied.
            Item {
                id: pills

                parent: bar.pillParent
                anchors.fill: parent

                /* Workspace Selektor */
                WorkspaceSelector {
                    id: workspaces
                    visible: Config.bar.workspaces
                    anchors.leftMargin: bar.notchMode ? 12 : HyprGaps.left
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
                    // Leiste: links der Notch. Hub: rechts an der Kette.
                    anchors {
                        right: bar.notchMode ? undefined : parent.horizontalCenter
                        rightMargin: notch.width / 2 + 15
                        left: !bar.notchMode ? undefined
                            : bar.hubChainLeft ? bar.hubChainLeft.right : parent.left
                        leftMargin: bar.hubChainLeft ? 10 : 12
                    }
                    verticalMargin: bar.verticalMargin
                    borderWidth: bar.borderWidth
                }

                Settings {
                    id: settings
                    visible: Config.bar.settings
                    // Aufgeklappt ueber den Nachbarn im Hub liegen
                    z: settings.expanded ? 2 : 0
                    anchors {
                        left: !bar.notchMode ? parent.horizontalCenter
                            : Config.bar.tray ? statusBar.right
                            : bar.hubChainLeft ? bar.hubChainLeft.right
                            : parent.left
                        leftMargin: !bar.notchMode ? notch.width / 2 + 15
                                  : Config.bar.tray || bar.hubChainLeft ? 10 : 12
                    }
                    verticalMargin: bar.verticalMargin
                    borderWidth: bar.borderWidth
                    cardRadius: bar.cardRadius
                }

                MediaPlayer {
                    id: media
                    visible: Config.bar.media
                    anchors.rightMargin: bar.notchMode ? 12 : HyprGaps.right
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

            Notch {
                id: notch
                // Im Hub darf die Settings-Karte (520 px) rechts herausragen:
                // dann wird der Hub – und damit die Notch – so breit
                hubContentWidth: bar.notchMode && Config.bar.settings ? settings.x + settings.width + 12 : 0
                verticalMargin: bar.verticalMargin    // Gesamt-Rand oben+unten; durchs Zentrieren je 10
                borderWidth: bar.borderWidth   // `this` gibt es in QML-Bindings nicht
                borderColor: bar.borderColor   // Quelle: eine Ebene weiter oben definiert
                cardRadius: bar.cardRadius     // dito – teilt sich den Wert mit dem Selektor
            }

            // Beide Nachbarn hängen an der Bildschirmmitte plus der halben
            // *aktuellen* Notch-Breite: klappt die Notch auf, weichen sie
            // animiert zur Seite, statt unter der Karte zu verschwinden.
        }
    }
}
