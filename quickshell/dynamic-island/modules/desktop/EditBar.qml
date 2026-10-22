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
Rectangle {
    id: bar

    property string screenName: ""
    property bool adding: false

    implicitWidth: rows.implicitWidth + 24
    implicitHeight: rows.implicitHeight + 20
    width: implicitWidth
    height: implicitHeight
    radius: 20
    color: Colors.alpha(Colors.background, 0.94)
    border.width: 1
    border.color: Colors.alpha(Colors.outline, 0.5)

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

        // ---- Hinzufuegen (klappt ueber der Leiste auf) ----
        Flow {
            visible: bar.adding
            spacing: 6
            Layout.maximumWidth: 720
            Layout.preferredWidth: implicitWidth
            Layout.alignment: Qt.AlignHCenter

            Repeater {
                model: DesktopWidgets.typeNames

                EditChip {
                    required property string modelData

                    icon: DesktopWidgets.info(modelData)?.icon ?? "widgets"
                    text: DesktopWidgets.info(modelData)?.title ?? modelData
                    onClicked: {
                        Scenes.add(modelData);
                        bar.adding = false;
                    }
                }
            }
        }

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

                    text: modelData.label + (modelData.own ? "" : " +")
                    on: Scenes.target === modelData.key
                    onClicked: Scenes.setTarget(modelData.key)
                }
            }

            EditChip {
                visible: Scenes.target !== "*" && Array.isArray(Scenes.scenes[Scenes.target])
                icon: "layers_clear"
                danger: true
                onClicked: Scenes.dropTarget()
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
                onClicked: bar.adding = !bar.adding
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
    }
}
