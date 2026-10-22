pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

import qs
import qs.modules.services.config
import qs.modules.services.desktop

// Bearbeitungsleiste der Desktop-Widgets (unten mittig, nur auf dem Monitor,
// auf dem bearbeitet wird).
//
// Obere Reihe: wohin die Aenderungen gehen (Dieses Bild / Ordner / Ueberall),
// Widget hinzufuegen, automatisch anordnen, fertig.
// Untere Reihe (mit Auswahl): Optionen des Widgets, Farbe, Monitor,
// duplizieren, loeschen.
Rectangle {
    id: bar

    property string screenName: ""
    property bool adding: false

    readonly property var sel: Scenes.selectedWidget
    readonly property var selInfo: bar.sel ? DesktopWidgets.info(bar.sel.type) : null

    implicitWidth: Math.max(rows.implicitWidth + 28, 420)
    implicitHeight: rows.implicitHeight + 24
    width: implicitWidth
    height: implicitHeight
    radius: 20
    color: Colors.alpha(Colors.background, 0.94)
    border.width: 1
    border.color: Colors.alpha(Colors.outline, 0.5)

    // Klicks auf die Leiste nicht als "Auswahl aufheben" durchreichen
    TapHandler {}

    Behavior on implicitWidth {
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
    }
    Behavior on implicitHeight {
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
    }

    component Chip: Rectangle {
        id: chip

        property string text: ""
        property string icon: ""
        property bool on: false
        property bool danger: false
        property color swatch: "transparent"
        signal clicked

        implicitWidth: chipRow.implicitWidth + (chip.text !== "" ? 22 : 14)
        implicitHeight: 28
        radius: 14
        color: chip.on ? Colors.primary
             : chipHover.hovered ? (chip.danger ? Colors.alpha(Colors.error, 0.25) : Colors.alpha(Colors.fgSurface, 0.14))
             : Colors.alpha(Colors.fgSurface, 0.07)

        Behavior on color {
            ColorAnimation { duration: 120 }
        }

        Row {
            id: chipRow

            anchors.centerIn: parent
            spacing: 5

            Rectangle {
                visible: chip.swatch.a > 0
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                height: 14
                radius: 7
                color: chip.swatch
                border.width: 1
                border.color: Colors.alpha(Colors.fgSurface, 0.3)
            }

            Text {
                visible: chip.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: chip.icon
                color: chip.on ? Colors.fgPrimary : chip.danger ? Colors.error : Colors.fgSurface
                font.family: "Material Symbols Outlined"
                font.pixelSize: 16
            }

            Text {
                visible: chip.text !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: chip.text
                color: chip.on ? Colors.fgPrimary : Colors.fgSurface
                font.family: Config.font
                font.pixelSize: 11
                font.weight: chip.on ? Font.DemiBold : Font.Normal
            }
        }

        HoverHandler {
            id: chipHover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: chip.clicked()
        }
    }

    component Label: Text {
        color: Colors.fgSurfaceVariant
        font.family: Config.font
        font.pixelSize: 9
        font.weight: Font.DemiBold
        font.letterSpacing: 0.8
        font.capitalization: Font.AllUppercase
        Layout.alignment: Qt.AlignVCenter
    }

    ColumnLayout {
        id: rows

        anchors.centerIn: parent
        spacing: 10

        // ---- Ziel und Aktionen ----
        RowLayout {
            spacing: 6
            Layout.alignment: Qt.AlignHCenter

            Label {
                text: "Szene"
            }

            Repeater {
                model: Scenes.targets

                Chip {
                    required property var modelData

                    text: modelData.label + (modelData.own ? "" : " +")
                    on: Scenes.target === modelData.key
                    onClicked: Scenes.setTarget(modelData.key)
                }
            }

            Chip {
                visible: Scenes.target !== "*" && Array.isArray(Scenes.scenes[Scenes.target])
                icon: "layers_clear"
                danger: true
                onClicked: Scenes.dropTarget()
            }

            Item {
                Layout.preferredWidth: 10
            }

            Chip {
                icon: "add"
                text: "Widget"
                on: bar.adding
                onClicked: bar.adding = !bar.adding
            }

            Chip {
                icon: "auto_awesome_mosaic"
                text: "Anordnen"
                visible: Scenes.widgets.length > 0 && Scenes.analysis !== null
                onClicked: Scenes.arrange()
            }

            Chip {
                icon: "check"
                text: "Fertig"
                on: true
                onClicked: Scenes.done()
            }
        }

        // ---- Hinzufuegen ----
        Flow {
            visible: bar.adding
            spacing: 6
            Layout.maximumWidth: 760
            Layout.preferredWidth: implicitWidth
            Layout.alignment: Qt.AlignHCenter

            Repeater {
                model: DesktopWidgets.typeNames

                Chip {
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

        // ---- Auswahl ----
        Rectangle {
            visible: bar.sel !== null
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Colors.alpha(Colors.outline, 0.4)
        }

        // Optionen des Typs, je eine Reihe
        Repeater {
            model: bar.selInfo ? Object.keys(bar.selInfo.options ?? {}) : []

            RowLayout {
                id: optRow

                required property string modelData
                readonly property var option: bar.selInfo.options[optRow.modelData]
                readonly property var value: DesktopWidgets.opt(bar.sel, optRow.modelData)

                spacing: 6
                Layout.alignment: Qt.AlignHCenter

                Label {
                    text: optRow.option.title ?? optRow.modelData
                    Layout.preferredWidth: 80
                }

                Chip {
                    visible: optRow.option.bool === true
                    text: optRow.value ? "an" : "aus"
                    on: !!optRow.value
                    onClicked: Scenes.setOpt(bar.sel.id, optRow.modelData, !optRow.value)
                }

                Repeater {
                    model: optRow.option.values ?? []

                    Chip {
                        required property var modelData

                        text: String(modelData)
                        on: optRow.value === modelData
                        onClicked: Scenes.setOpt(bar.sel.id, optRow.modelData, modelData)
                    }
                }
            }
        }

        // Farben
        Repeater {
            model: bar.sel ? [["color", "Farbe", "hell"], ["accent", "Akzent", "primary"]] : []

            RowLayout {
                id: colorRow

                required property var modelData
                readonly property string current: bar.sel?.opts?.[colorRow.modelData[0]] ?? colorRow.modelData[2]

                spacing: 6
                Layout.alignment: Qt.AlignHCenter

                Label {
                    text: colorRow.modelData[1]
                    Layout.preferredWidth: 80
                }

                Repeater {
                    model: DesktopWidgets.colorNames

                    Chip {
                        required property string modelData

                        swatch: DesktopWidgets.color(modelData, "transparent")
                        on: colorRow.current === modelData
                        onClicked: Scenes.setOpt(bar.sel.id, colorRow.modelData[0], modelData)
                    }
                }

                // Feste Farbe der Szene (z.B. Cyberpunk-Gelb) – nur anzeigen
                Chip {
                    visible: colorRow.current.startsWith("#")
                    swatch: colorRow.current.startsWith("#") ? colorRow.current : "transparent"
                    text: colorRow.current
                    on: true
                }
            }
        }

        // Monitor, Duplizieren, Loeschen
        RowLayout {
            visible: bar.sel !== null
            spacing: 6
            Layout.alignment: Qt.AlignHCenter

            Label {
                text: "Monitor"
                Layout.preferredWidth: 80
            }

            Chip {
                text: "Beide"
                on: !bar.sel?.monitor || bar.sel.monitor === "*"
                onClicked: Scenes.patch(bar.sel.id, { monitor: "*" })
            }

            Chip {
                text: "Nur " + bar.screenName
                on: bar.sel?.monitor === bar.screenName
                onClicked: Scenes.patch(bar.sel.id, { monitor: bar.screenName })
            }

            Item {
                Layout.preferredWidth: 10
            }

            Chip {
                icon: "content_copy"
                onClicked: Scenes.duplicate(bar.sel.id)
            }

            Chip {
                icon: "delete"
                danger: true
                onClicked: Scenes.remove(bar.sel.id)
            }
        }
    }
}
