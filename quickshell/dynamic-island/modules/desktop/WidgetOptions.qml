pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

import qs
import qs.modules.services.config
import qs.modules.services.desktop

// Optionen eines Widgets, angedockt an seinen Auswahlrahmen (WidgetHost
// setzt Lage und die Ecke, die am Rahmen anliegt). Gleicher Rand wie der
// Rahmen, damit beides als eine Flaeche liest.
//
// Inhalt: Kopf (Typ, Duplizieren, Loeschen), je Option eine Chip-Reihe,
// Farbe/Akzent, Monitor.
Rectangle {
    id: pop

    required property var widget
    property string screenName: ""

    readonly property var info: pop.widget ? DesktopWidgets.info(pop.widget.type) : null

    implicitWidth: Math.max(300, rows.implicitWidth + 28)
    implicitHeight: rows.implicitHeight + 24
    color: Colors.alpha(Colors.background, 0.96)
    border.width: 2
    border.color: Colors.primary

    // Klicks bleiben hier (nicht zum Desktop durch = Auswahl aufheben)
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onWheel: wheel => wheel.accepted = true
    }

    ColumnLayout {
        id: rows

        x: 14
        y: 12
        spacing: 8

        // ---- Kopf ----
        RowLayout {
            spacing: 8
            Layout.fillWidth: true

            Text {
                text: pop.info?.icon ?? "widgets"
                color: Colors.primary
                font.family: "Material Symbols Outlined"
                font.pixelSize: 18
            }

            Text {
                text: pop.info?.title ?? pop.widget?.type ?? ""
                color: Colors.fgBackground
                font.family: Config.font
                font.pixelSize: 12
                font.weight: Font.DemiBold
                Layout.fillWidth: true
            }

            EditChip {
                icon: "content_copy"
                onClicked: Scenes.duplicate(pop.widget.id)
            }

            EditChip {
                icon: "delete"
                danger: true
                onClicked: Scenes.remove(pop.widget.id)
            }
        }

        // ---- Optionen des Typs ----
        Repeater {
            model: pop.info ? Object.keys(pop.info.options ?? {}) : []

            RowLayout {
                id: optRow

                required property string modelData
                readonly property var option: pop.info.options[optRow.modelData]
                readonly property var value: DesktopWidgets.opt(pop.widget, optRow.modelData)

                spacing: 6

                EditLabel {
                    text: optRow.option.title ?? optRow.modelData
                    Layout.preferredWidth: 72
                }

                EditChip {
                    visible: optRow.option.bool === true
                    text: optRow.value ? "an" : "aus"
                    on: !!optRow.value
                    onClicked: Scenes.setOpt(pop.widget.id, optRow.modelData, !optRow.value)
                }

                Flow {
                    visible: (optRow.option.values ?? []).length > 0
                    spacing: 6
                    Layout.maximumWidth: 420
                    Layout.preferredWidth: implicitWidth

                    Repeater {
                        model: optRow.option.values ?? []

                        EditChip {
                            required property var modelData

                            text: String(modelData)
                            on: optRow.value === modelData
                            onClicked: Scenes.setOpt(pop.widget.id, optRow.modelData, modelData)
                        }
                    }
                }
            }
        }

        // ---- Farben ----
        Repeater {
            model: [["color", "Farbe", "hell"], ["accent", "Akzent", "primary"]]

            RowLayout {
                id: colorRow

                required property var modelData
                readonly property string current: pop.widget?.opts?.[colorRow.modelData[0]] ?? colorRow.modelData[2]

                spacing: 6

                EditLabel {
                    text: colorRow.modelData[1]
                    Layout.preferredWidth: 72
                }

                Repeater {
                    model: DesktopWidgets.colorNames

                    EditChip {
                        required property string modelData

                        swatch: DesktopWidgets.color(modelData, "transparent")
                        on: colorRow.current === modelData
                        onClicked: Scenes.setOpt(pop.widget.id, colorRow.modelData[0], modelData)
                    }
                }

                // Feste Farbe der Szene (z.B. Cyberpunk-Gelb)
                EditChip {
                    visible: colorRow.current.startsWith("#")
                    swatch: colorRow.current.startsWith("#") ? colorRow.current : "transparent"
                    on: true
                }
            }
        }

        // ---- Monitor ----
        RowLayout {
            spacing: 6

            EditLabel {
                text: "Monitor"
                Layout.preferredWidth: 72
            }

            EditChip {
                text: "Beide"
                on: !pop.widget?.monitor || pop.widget.monitor === "*"
                onClicked: Scenes.patch(pop.widget.id, { monitor: "*" })
            }

            EditChip {
                text: "Nur " + pop.screenName
                on: pop.widget?.monitor === pop.screenName
                onClicked: Scenes.patch(pop.widget.id, { monitor: pop.screenName })
            }
        }
    }
}
