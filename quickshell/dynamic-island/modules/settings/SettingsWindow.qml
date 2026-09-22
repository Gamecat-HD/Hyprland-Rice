pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.services.config

import qs

// Einstellungs-Fenster, mittig auf dem Bildschirm.
//
// Die Liste baut sich aus ~/.config/dynamic-island/shell.json: jeder
// Abschnitt wird eine Gruppe, jeder Schluessel eine Zeile. Neue Schluessel im
// Adapter (services/config/Config.qml) tauchen hier von selbst auf – Namen und
// Beschreibungen kommen aus der Tabelle unten, fehlt einer, steht der
// Schluessel selbst da.
//
// Bewusst keine Anker: eine Layer-Oberflaeche ohne Anker setzt der Compositor
// mittig – genau das, was hier gebraucht wird.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property ShellScreen modelData

        // Suchtext; leert sich beim Oeffnen
        property string filter: ""

        screen: win.modelData
        visible: SettingsState.open && SettingsState.screen === win.modelData

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "dynamic-island-settings"
        // Fuers Suchfeld. Exclusive, weil das Fenster ueber einen Klick in der
        // Leiste aufgeht – es gibt keinen Klick, der ihm den Fokus gaebe.
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"

        implicitWidth: 640
        implicitHeight: 560

        onVisibleChanged: {
            if (visible) {
                win.filter = "";
                search.forceActiveFocus();
            }
        }

        // ---- Die Karte ----
        Rectangle {
            anchors.fill: parent

            radius: 20
            color: Colors.background
            border.width: 1
            border.color: Colors.outlineVariant

            // Kopfzeile
            Text {
                id: title
                font.family: Config.font

                anchors {
                    left: parent.left
                    leftMargin: 24
                    top: parent.top
                    topMargin: 20
                }
                text: "Einstellungen"
                color: Colors.fgBackground
                font.pixelSize: 17
                font.weight: Font.DemiBold
            }

            Text {
                font.family: Config.font
                anchors {
                    left: title.left
                    top: title.bottom
                    topMargin: 2
                }
                text: "~/.config/dynamic-island/shell.json"
                color: Colors.alpha(Colors.fgSurfaceVariant, 0.8)
                font.pixelSize: 10
            }

            Rectangle {
                id: closeButton

                anchors {
                    right: parent.right
                    rightMargin: 18
                    top: parent.top
                    topMargin: 18
                }
                width: 30
                height: 30
                radius: height / 2
                color: closeArea.containsMouse ? Colors.alpha(Colors.fgSurface, 0.12) : "transparent"

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }

                Text {
                    anchors.centerIn: parent
                    text: "close"
                    color: Colors.fgSurfaceVariant
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 17
                }

                MouseArea {
                    id: closeArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: SettingsState.close()
                }
            }

            // Suchleiste
            Rectangle {
                id: searchBox

                anchors {
                    left: parent.left
                    right: parent.right
                    top: title.bottom
                    leftMargin: 24
                    rightMargin: 24
                    topMargin: 26
                }
                height: 40
                radius: height / 2
                color: Colors.shade(Colors.background, 0.06)

                Text {
                    id: searchIcon

                    anchors {
                        left: parent.left
                        leftMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    text: "search"
                    color: Colors.fgSurfaceVariant
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 17
                }

                TextInput {
                    id: search
                    font.family: Config.font

                    anchors {
                        left: searchIcon.right
                        leftMargin: 10
                        right: parent.right
                        rightMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    text: win.filter
                    onTextChanged: win.filter = text
                    color: Colors.fgSurface
                    font.pixelSize: 13
                    selectionColor: Colors.alpha(Colors.primary, 0.35)
                    clip: true

                    Keys.onEscapePressed: SettingsState.close()

                    Text {
                        anchors.fill: parent
                        visible: search.text === ""
                        text: "Einstellung suchen…"
                        color: Colors.alpha(Colors.fgSurfaceVariant, 0.7)
                        font: search.font
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            // ---- Die Liste, gebaut aus der Datei ----
            ListView {
                id: list

                anchors {
                    left: parent.left
                    right: parent.right
                    top: searchBox.bottom
                    bottom: parent.bottom
                    leftMargin: 24
                    rightMargin: 24
                    topMargin: 14
                    bottomMargin: 18
                }
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds

                model: ScriptModel {
                    values: {
                        const needle = win.filter.trim().toLowerCase();
                        const out = [];

                        for (const section in Config.raw) {
                            const values = Config.raw[section];
                            if (typeof values !== "object" || values === null)
                                continue;

                            for (const key in values) {
                                const id = `${section}.${key}`;
                                const meta = Config.meta[id] ?? null;
                                const entry = {
                                    id,
                                    section,
                                    key,
                                    value: values[key],
                                    title: meta?.title ?? key,
                                    // Feste Auswahl (z. B. Schriften) – sonst null
                                    options: meta?.options ?? null,
                                    // Ohne Eintrag in der Tabelle: ehrlich sagen,
                                    // dass der Schluessel neu ist
                                    desc: meta?.desc ?? `Schlüssel "${key}" aus shell.json`
                                };

                                if (needle === ""
                                    || entry.title.toLowerCase().includes(needle)
                                    || entry.desc.toLowerCase().includes(needle)
                                    || id.toLowerCase().includes(needle))
                                    out.push(entry);
                            }
                        }
                        return out;
                    }
                }

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

                    onWheel: event => {
                        const angle = event.angleDelta.y + event.angleDelta.x;
                        const pixels = event.pixelDelta.y + event.pixelDelta.x;
                        const delta = angle !== 0 ? angle / 120 : pixels / 40;

                        const max = Math.max(0, list.contentHeight - list.height);
                        list.contentY = Math.max(0, Math.min(max, list.contentY - delta * 60));
                        event.accepted = true;
                    }
                }

                delegate: SettingsRow {
                    required property var modelData
                    required property int index

                    width: ListView.view.width
                    entry: modelData
                    // Gruppentitel nur ueber der ersten Zeile eines Abschnitts
                    // Optional-Zugriff: waehrend des Filterns sind Index und
                    // Liste kurz auseinander, dann gibt es den Vorgaenger nicht
                    section: index === 0 || list.model.values[index - 1]?.section !== modelData.section
                             ? modelData.section : ""
                }

                Text {
                    font.family: Config.font
                    anchors.centerIn: parent
                    visible: list.count === 0

                    text: "Nichts gefunden"
                    color: Colors.fgSurfaceVariant
                    font.pixelSize: 12
                }
            }
        }
    }
}
