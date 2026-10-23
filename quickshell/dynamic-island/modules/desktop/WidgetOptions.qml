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
// Inhalt: Kopf (Typ, Duplizieren, Loeschen mit Rueckfrage), je Option eine
// Chip-Reihe (Schalter als "an | aus"), Groesse, Farbe/Akzent (die gewaehlte
// mit Namen), Monitor.
Rectangle {
    id: pop

    required property var widget
    property string screenName: ""

    readonly property var info: pop.widget ? DesktopWidgets.info(pop.widget.type) : null
    readonly property real size: pop.widget?.size ?? 1
    // Breite der Beschriftungsspalte ("Wachsen zeigen" passt gerade so)
    readonly property real labelWidth: 100

    // Loeschen ist zweistufig: erster Klick fragt, 3 s lang
    property bool deleteArmed: false

    readonly property var colorLabels: ({
        "hell": "Hell", "primary": "Primär", "secondary": "Sekundär",
        "tertiary": "Tertiär", "weiss": "Weiß", "dunkel": "Dunkel"
    })

    function setSize(value: real): void {
        Scenes.patch(pop.widget.id, { size: Number(Math.max(0.3, Math.min(8, value)).toFixed(3)) });
    }

    Timer {
        id: disarm

        interval: 3000
        onTriggered: pop.deleteArmed = false
    }

    implicitWidth: Math.max(300, rows.implicitWidth + 28)
    implicitHeight: rows.implicitHeight + 24
    color: Colors.alpha(Colors.background, 0.96)
    border.width: 2
    border.color: Colors.primary

    // Maus ueber dem Feld: Widgets darunter sperren (WidgetHost.blocked)
    readonly property bool hovered: popHover.hovered

    HoverHandler {
        id: popHover
    }

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
                icon: pop.deleteArmed ? "check" : "delete"
                text: pop.deleteArmed ? "Löschen?" : ""
                danger: true
                armed: pop.deleteArmed
                onClicked: {
                    if (pop.deleteArmed) {
                        Scenes.remove(pop.widget.id);
                    } else {
                        pop.deleteArmed = true;
                        disarm.restart();
                    }
                }
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
                    Layout.preferredWidth: pop.labelWidth
                }

                // Schalter: beide Zustaende sichtbar, der aktive hervorgehoben
                Repeater {
                    model: optRow.option.bool === true ? [true, false] : []

                    EditChip {
                        required property bool modelData

                        text: modelData ? "an" : "aus"
                        on: !!optRow.value === modelData
                        onClicked: Scenes.setOpt(pop.widget.id, optRow.modelData, modelData)
                    }
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

        // ---- Groesse (auch: Griff an der Ecke, Tasten + / -) ----
        RowLayout {
            spacing: 6
            visible: pop.widget !== null

            EditLabel {
                text: "Größe"
                Layout.preferredWidth: pop.labelWidth
            }

            EditChip {
                icon: "remove"
                onClicked: pop.setSize(pop.size / 1.1)
            }

            EditChip {
                text: Math.round(pop.size * 100) + " %"
                Layout.preferredWidth: 64
                onClicked: pop.setSize(1)
            }

            EditChip {
                icon: "add"
                onClicked: pop.setSize(pop.size * 1.1)
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
                    Layout.preferredWidth: pop.labelWidth
                }

                Repeater {
                    model: DesktopWidgets.colorNames

                    EditChip {
                        required property string modelData

                        swatch: DesktopWidgets.color(modelData, "transparent")
                        on: colorRow.current === modelData
                        // Name nur an der gewaehlten Farbe, sonst wird die Reihe zu breit
                        text: on ? (pop.colorLabels[modelData] ?? modelData) : ""
                        onClicked: Scenes.setOpt(pop.widget.id, colorRow.modelData[0], modelData)
                    }
                }

                // Feste Farbe der Szene (z.B. Cyberpunk-Gelb)
                EditChip {
                    visible: colorRow.current.startsWith("#")
                    swatch: colorRow.current.startsWith("#") ? colorRow.current : "transparent"
                    text: "Eigene"
                    on: true
                }
            }
        }

        // ---- Monitor ----
        RowLayout {
            spacing: 6

            EditLabel {
                text: "Monitor"
                Layout.preferredWidth: pop.labelWidth
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
