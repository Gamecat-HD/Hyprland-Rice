pragma ComponentBehavior: Bound
import QtQuick

import qs
import qs.modules.services.config
import "KeyLayout.js" as Layout

// Tastatur-Vorschau: ISO-QWERTZ ohne Ziffernblock, darunter eine Leiste fuer
// Tasten ohne Platz (Medientasten, Maus, sonstige gebundene Tasten).
//
// `mask` ist die Modifier-Maske, deren Belegung die Tasten zeigen; ein Klick
// auf eine Modifier-Taste schaltet ihr Bit (modifierToggled). `index` kommt
// vom Editor: Canon "64:q" -> { title, group, disabled, changed, source,
// unnamed } – eine Map fuer alle Ebenen, jede Taste schlaegt einmal nach.
Item {
    id: board

    property int mask: 64
    property var index: ({})
    // Tasten des gewaehlten Befehls: { q: true, super_l: true }
    property var litKeys: ({})
    // Freie Tasten sind anklickbar ("Auf Tastatur wählen")
    property bool pick: false
    property bool interactive: true
    property real maxUnit: 54

    signal keyClicked(string id)
    signal modifierToggled(int bit)

    readonly property real unit: Math.max(24, Math.min(board.maxUnit, board.width / Layout.UNITS_WIDE))
    readonly property real gap: Math.max(3, Math.round(board.unit * 0.1))
    readonly property real boardWidth: board.unit * Layout.UNITS_WIDE - board.gap
    readonly property real boardHeight: board.unit * Layout.UNITS_HIGH - board.gap

    implicitHeight: board.boardHeight + 14 + extras.implicitHeight

    function infoFor(id: string): var {
        return board.index[`${board.mask}:${id}`] ?? null;
    }

    // Gebundene Tasten, die weder auf der Tastatur noch in den festen
    // Extras sitzen (z.B. backslash, code:NN)
    readonly property var others: {
        const seen = {};
        const out = [];
        for (const canon in board.index) {
            const id = canon.slice(canon.indexOf(":") + 1);
            if (seen[id] || Layout.onBoard(id) || Layout.isMouse(id) || Layout.EXTRAS.some(e => e.id === id))
                continue;
            seen[id] = true;
            out.push({ id, label: id.startsWith("code:") ? id : id.replace(/^xf86/, ""), sub: "", x: 0, y: 0, w: 1, h: 1, mod: 0 });
        }
        out.sort((a, b) => a.id.localeCompare(b.id));
        return out;
    }

    readonly property var extraSpecs: Layout.EXTRAS.map(e => ({ id: e.id, label: "", icon: e.icon, sub: "", x: 0, y: 0, w: 1, h: 1, mod: 0 }))
    readonly property var mouseSpecs: Layout.MOUSE.map(e => ({ id: e.id, label: "", icon: e.icon, sub: "", x: 0, y: 0, w: 1, h: 1, mod: 0 }))

    // Die Tastatur steht mittig, wenn die Breite ueber dem Maximum liegt
    Item {
        id: main

        x: Math.round((board.width - board.boardWidth) / 2)
        width: board.boardWidth
        height: board.boardHeight

        Repeater {
            model: Layout.keys()

            KeyboardKey {
                id: k

                required property var modelData

                spec: k.modelData
                unit: board.unit
                gap: board.gap
                info: board.infoFor(k.spec.id)
                lit: board.litKeys[k.spec.id] === true
                engaged: k.spec.mod !== 0 && (board.mask & k.spec.mod) !== 0
                pick: board.pick
                interactive: board.interactive
                tipAbove: k.spec.y >= 3
                // Modifier schalten immer die Ebene – auch wenn auf ihnen
                // etwas liegt (Super allein = App-Menue); den Befehl dazu
                // erreicht man ueber die Liste
                onClicked: {
                    if (k.spec.mod !== 0)
                        board.modifierToggled(k.spec.mod);
                    else
                        board.keyClicked(k.spec.id);
                }
            }
        }
    }

    // ---- Extras: Medientasten, Maus, Sonstiges ----
    Flow {
        id: extras

        anchors {
            top: main.bottom
            topMargin: 14
        }
        x: main.x
        width: board.boardWidth
        spacing: board.gap

        Row {
            spacing: board.gap

            Repeater {
                model: board.extraSpecs

                KeyboardKey {
                    id: ek

                    required property var modelData

                    // Im Flow positioniert die Reihe, nicht x/y der Spezifikation
                    spec: ek.modelData
                    unit: board.unit
                    gap: board.gap
                    x: 0
                    y: 0
                    width: board.unit - board.gap
                    height: board.unit - board.gap
                    info: board.infoFor(ek.spec.id)
                    lit: board.litKeys[ek.spec.id] === true
                    pick: board.pick
                    interactive: board.interactive
                    tipAbove: true
                    onClicked: board.keyClicked(ek.spec.id)
                }
            }
        }

        Item {
            width: board.unit * 0.5 - board.gap
            height: 1
        }

        Row {
            spacing: board.gap

            Repeater {
                model: board.mouseSpecs

                KeyboardKey {
                    id: mk

                    required property var modelData

                    spec: mk.modelData
                    unit: board.unit
                    gap: board.gap
                    x: 0
                    y: 0
                    width: board.unit - board.gap
                    height: board.unit - board.gap
                    info: board.infoFor(mk.spec.id)
                    lit: board.litKeys[mk.spec.id] === true
                    // Maustasten: nur lesen
                    pick: false
                    interactive: board.interactive
                    tipAbove: true
                    onClicked: board.keyClicked(mk.spec.id)
                }
            }
        }

        Item {
            visible: board.others.length > 0
            width: board.unit * 0.5 - board.gap
            height: 1
        }

        Row {
            spacing: board.gap

            Repeater {
                model: board.others

                KeyboardKey {
                    id: ok

                    required property var modelData

                    spec: ok.modelData
                    unit: board.unit
                    gap: board.gap
                    x: 0
                    y: 0
                    width: Math.max(board.unit, otherLabel.implicitWidth + 12) - board.gap
                    height: board.unit - board.gap
                    info: board.infoFor(ok.spec.id)
                    lit: board.litKeys[ok.spec.id] === true
                    pick: board.pick
                    interactive: board.interactive
                    tipAbove: true
                    onClicked: board.keyClicked(ok.spec.id)

                    // Breite nach dem Namen bemessen
                    Text {
                        id: otherLabel

                        visible: false
                        text: ok.spec.label
                        font.family: Config.font
                        font.pixelSize: Math.max(8, Math.round(board.unit * 0.21))
                    }
                }
            }
        }
    }
}
