pragma ComponentBehavior: Bound
import QtQuick

import qs
import qs.modules.services.config

// Zeile in den Karten der Systemseite (SystemEditor): Beschriftung links,
// Wert rechts, dazwischen Platz; unter jeder Zeile ausser der letzten eine
// feine Linie. Solange die Daten noch geladen werden, steht "…", fehlt
// ein Wert danach, "–". Eigene Datei: eine Inline-`component` in einer
// schon geladenen Datei loest erst nach einem Neustart der Shell auf.
Item {
    id: line

    required property string label
    property string value: ""
    // Daten noch unterwegs (SystemInfo.loaded / ShellUpdate.loaded)
    property bool pending: false
    property bool last: false
    // Wert in Primaerfarbe hervorheben (z. B. Zahl der neuen Commits)
    property bool accent: false

    width: parent?.width ?? 200
    height: 30

    Text {
        id: labelText

        anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
        }
        text: line.label
        color: Colors.fgSurfaceVariant
        font.family: Config.font
        font.pixelSize: 11
    }

    Text {
        anchors {
            left: labelText.right
            leftMargin: 16
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        text: line.value !== "" ? line.value : line.pending ? "…" : "–"
        color: line.accent && line.value !== "" ? Colors.primary : Colors.fgBackground
        font.family: Config.font
        font.pixelSize: 11
        font.weight: Font.DemiBold
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideRight
    }

    Rectangle {
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        visible: !line.last
        height: 1
        color: Colors.alpha(Colors.outline, 0.1)
    }
}
