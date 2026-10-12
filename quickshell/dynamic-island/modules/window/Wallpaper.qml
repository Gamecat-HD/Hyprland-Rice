pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.services.wallpaper

import qs

// Hintergrund-Layer (Wallpaper) – enthält selbst die Pro-Monitor-Logik.
// Die `required property modelData` im Delegaten wird von `Variants`
// automatisch mit dem jeweiligen Screen befüllt (Caelestia-Stil).
// Bewusst nicht "Window.qml" genannt – der Name würde den QML-Typ `Window`
// aus QtQuick überdecken.
//
// Welches Bild gilt, sagt der Wallpapers-Dienst: entweder das gesetzte oder –
// waehrend man im Launcher durch die Auswahl blaettert – das vorgeschaute.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property ShellScreen modelData

        screen: win.modelData
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "dynamic-island-background"
        exclusionMode: ExclusionMode.Ignore
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: Colors.background

        // Zwei Bilder im Wechsel: das neue laedt unsichtbar und wird erst
        // eingeblendet, wenn es fertig ist. Mit nur einem Image waere beim
        // Wechsel (und bei jedem Vorschau-Schritt) kurz der blanke Hintergrund
        // zu sehen.
        Item {
            id: stage

            anchors.fill: parent

            readonly property string path: Wallpapers.current
            property bool showA: true

            // Nach dem Ueberblenden das verdeckte Bild freigeben – es blieb
            // sonst bis zum naechsten Wechsel decodiert im Speicher
            onShowAChanged: releaseTimer.restart()

            Timer {
                id: releaseTimer

                interval: 400
                onTriggered: {
                    const hidden = stage.showA ? imgB : imgA;
                    if (hidden.status === Image.Ready)
                        hidden.source = "";
                }
            }

            onPathChanged: {
                const next = stage.showA ? imgB : imgA;
                next.source = stage.path !== "" ? `file://${stage.path}` : "";
            }

            Image {
                id: imgA

                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                // Nur in Bildschirmgroesse decodieren (statt z. B. 6K voll) und
                // ueber den Cache teilen – beide Monitore zeigen dasselbe Bild
                sourceSize: Qt.size(win.modelData.width, win.modelData.height)
                cache: true
                opacity: stage.showA ? 1 : 0

                onStatusChanged: {
                    if (status === Image.Ready && !stage.showA)
                        stage.showA = true;
                }

                Behavior on opacity {
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }
            }

            Image {
                id: imgB

                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                // Nur in Bildschirmgroesse decodieren (statt z. B. 6K voll) und
                // ueber den Cache teilen – beide Monitore zeigen dasselbe Bild
                sourceSize: Qt.size(win.modelData.width, win.modelData.height)
                cache: true
                opacity: stage.showA ? 0 : 1

                onStatusChanged: {
                    if (status === Image.Ready && stage.showA)
                        stage.showA = false;
                }

                Behavior on opacity {
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }
            }
        }
    }
}
