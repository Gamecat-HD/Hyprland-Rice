pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland

import qs
import qs.modules.services.config
import qs.modules.services.desktop

// Block in der Gruppe des Plugins `desktop` (Einstellung `scenes`, editor "desktop"): welche
// Szene gerade gilt, was darin steht, und der Knopf zum Bearbeiten. Das
// eigentliche Anordnen passiert direkt auf dem Desktop (EditBar.qml).
Column {
    id: root

    spacing: 8
    bottomPadding: 8

    readonly property string sceneLabel: {
        const key = Scenes.currentKey;
        if (key === "")
            return "Keine Szene – der Desktop ist leer";
        if (key === "*")
            return "Standard-Szene (gilt überall)";
        return key.endsWith("/") ? `Ordner ${key.slice(0, -1)}` : `Bild ${key.split("/").pop()}`;
    }

    Text {
        width: parent.width
        text: root.sceneLabel + (Scenes.widgets.length > 0
            ? " · " + Scenes.widgets.map(w => DesktopWidgets.info(w.type)?.title ?? w.type).join(", ")
            : "")
        color: Colors.fgSurfaceVariant
        font.family: Config.font
        font.pixelSize: 10
        wrapMode: Text.Wrap
    }

    Row {
        spacing: 8

        Rectangle {
            width: editLabel.implicitWidth + 40
            height: 30
            radius: 15
            color: editHover.hovered ? Qt.lighter(Colors.primary, 1.1) : Colors.primary

            Row {
                anchors.centerIn: parent
                spacing: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "edit"
                    color: Colors.fgPrimary
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 15
                }

                Text {
                    id: editLabel

                    anchors.verticalCenter: parent.verticalCenter
                    text: "Auf dem Desktop anordnen"
                    color: Colors.fgPrimary
                    font.family: Config.font
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
            }

            HoverHandler {
                id: editHover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: Scenes.edit(Hyprland.focusedMonitor?.name ?? "")
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "oder SUPER+ALT+D"
            color: Colors.fgSurfaceVariant
            font.family: Config.font
            font.pixelSize: 10
        }
    }
}
