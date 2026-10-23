pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

import qs
import qs.modules.services.config
import qs.modules.services.desktop

// Leiste unten mittig beim Bearbeiten der Desktop-Widgets (nur auf dem
// Monitor, auf dem bearbeitet wird): wohin die Aenderungen gehen (Dieses
// Bild / Ordner / Ueberall), Widget hinzufuegen, automatisch anordnen,
// Abbrechen (alles seit dem Start zurueck), Fertig.
//
// Die Optionen eines Widgets haengen nicht hier, sondern angedockt am
// Widget selbst (WidgetOptions.qml).
//
// Ziele ohne eigene Szene tragen ein "+" (Klick legt sie als Kopie des
// Sichtbaren an); darunter sagt eine Zeile, wofuer die Aenderungen gelten,
// und welche Tasten es gibt. "Szene loeschen" fragt einmal nach.
Rectangle {
    id: bar

    property string screenName: ""
    readonly property bool adding: Scenes.adding
    property bool dropArmed: false

    readonly property var target: Scenes.targets.find(t => t.key === Scenes.target) ?? null
    readonly property string scope: {
        const t = Scenes.target;
        if (t === "*")
            return "Änderungen gelten überall, wo nichts Eigenes eingestellt ist";
        if (t.endsWith("/"))
            return `Änderungen gelten für alle Bilder im Ordner ${t.slice(0, -1).split("/").pop()}`;
        return "Änderungen gelten nur für dieses Bild";
    }

    Timer {
        id: disarmDrop

        interval: 3000
        onTriggered: bar.dropArmed = false
    }

    implicitWidth: rows.implicitWidth + 24
    implicitHeight: rows.implicitHeight + 20
    width: implicitWidth
    height: implicitHeight
    radius: 20
    color: Colors.alpha(Colors.background, 0.94)
    border.width: 1
    border.color: Colors.alpha(Colors.outline, 0.5)

    // Maus ueber der Leiste: Widgets darunter sperren (WidgetHost.blocked)
    readonly property bool hovered: barHover.hovered

    HoverHandler {
        id: barHover
    }

    // Klicks bleiben auf der Leiste
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
    }

    Behavior on implicitWidth {
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
    }
    Behavior on implicitHeight {
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
    }

    ColumnLayout {
        id: rows

        anchors.centerIn: parent
        spacing: 10

        RowLayout {
            spacing: 6
            Layout.alignment: Qt.AlignHCenter

            EditLabel {
                text: "Szene"
            }

            Repeater {
                model: Scenes.targets

                EditChip {
                    required property var modelData

                    text: modelData.label
                    // Noch keine eigene Szene: "+" = beim Klick anlegen
                    icon: modelData.own ? "" : "add"
                    dim: !modelData.own
                    on: Scenes.target === modelData.key
                    onClicked: Scenes.setTarget(modelData.key)
                }
            }

            EditChip {
                visible: Scenes.target !== "*" && Array.isArray(Scenes.scenes[Scenes.target])
                icon: bar.dropArmed ? "check" : "layers_clear"
                text: bar.dropArmed ? "Szene löschen?" : ""
                danger: true
                armed: bar.dropArmed
                onClicked: {
                    if (bar.dropArmed) {
                        bar.dropArmed = false;
                        Scenes.dropTarget();
                    } else {
                        bar.dropArmed = true;
                        disarmDrop.restart();
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: 18
                Layout.leftMargin: 4
                Layout.rightMargin: 4
                color: Colors.alpha(Colors.outline, 0.5)
            }

            EditChip {
                icon: "add"
                text: "Widget"
                on: bar.adding
                // Auswahl ueber der Leiste (WidgetPicker, DesktopScreen)
                onClicked: {
                    if (Scenes.adding)
                        Scenes.adding = false;
                    else
                        Scenes.openPicker(null);
                }
            }

            EditChip {
                icon: "auto_awesome_mosaic"
                text: "Anordnen"
                visible: Scenes.widgets.length > 0 && Scenes.analysis !== null
                onClicked: Scenes.arrange()
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: 18
                Layout.leftMargin: 4
                Layout.rightMargin: 4
                color: Colors.alpha(Colors.outline, 0.5)
            }

            EditChip {
                icon: "close"
                text: "Abbrechen"
                onClicked: Scenes.cancel()
            }

            EditChip {
                icon: "check"
                text: "Fertig"
                on: true
                onClicked: Scenes.done()
            }
        }

        // Wofuer die Aenderungen gelten + Tasten
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: 760
            text: `${bar.scope}  ·  Ziehen verschiebt, Ecke = Größe  ·  `
                  + (Scenes.adding ? "Tippen filtert · Pfeile wählen · Enter fügt hinzu · Esc schließt"
                     : Scenes.selected !== "" ? "Pfeile (+Shift) · + / − · Entf · Esc Auswahl aufheben"
                     : "Rechtsklick: Widget hier einfügen · Enter fertig · Esc bricht ab")
            color: Colors.fgSurfaceVariant
            font.family: Config.font
            font.pixelSize: 10
            elide: Text.ElideRight
        }
    }
}
