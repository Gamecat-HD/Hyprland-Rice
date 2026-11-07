pragma ComponentBehavior: Bound
import QtQuick

import qs
import qs.modules.services.config
import "KeyLayout.js" as Layout

// Tastatur-Vorschau: ein TKL-Gehaeuse (ISO-QWERTZ) mit Platte, oben links
// ein Display (Ebene, gehoverter/gewaehlter Befehl), oben rechts Medien-
// knoepfe und Lautstaerke-Walze; rechts daneben eine Maus fuer Maus-Binds.
//
// `mask` ist die Modifier-Maske, deren Belegung die Tasten zeigen; Klick auf
// eine Modifier-Taste schaltet ihr Bit (modifierToggled). `index` kommt vom
// Editor: Canon "64:q" -> { title, group, disabled, changed, source, unnamed,
// keys } – eine Map fuer alle Ebenen, jede Taste schlaegt einmal nach.
// AltGr-Zeichen (backslash, at, …) landen auf ihrer physischen Taste.
Item {
    id: board

    property int mask: 64
    property var index: ({})
    // Tasten des gewaehlten Befehls: { q: true, super_l: true }
    property var litKeys: ({})
    // Freie Tasten sind anklickbar ("Auf Tastatur wählen")
    property bool pick: false
    property bool interactive: true
    property real maxUnit: 56
    // Gewaehlter Befehl fuers Display, wenn nichts gehovert ist
    property string statusTitle: ""
    property var statusKeys: []

    signal keyClicked(string id)
    signal modifierToggled(int bit)

    // ---- Masse ----
    readonly property real bezelSide: 0.45
    readonly property real bezelTop: 1.35
    readonly property real bezelBottom: 0.45
    readonly property real padGap: 0.5
    readonly property real padUnits: 3
    readonly property real unitsTotal: Layout.UNITS_WIDE + board.bezelSide * 2 + board.padGap + board.padUnits

    readonly property real unit: Math.max(22, Math.min(board.maxUnit, board.width / board.unitsTotal))
    readonly property real gap: Math.max(3, Math.round(board.unit * 0.08))
    readonly property real caseW: board.unit * (Layout.UNITS_WIDE + board.bezelSide * 2) - board.gap
    readonly property real caseH: board.unit * (board.bezelTop + Layout.UNITS_HIGH + board.bezelBottom) - board.gap
    readonly property real totalW: board.caseW + board.unit * (board.padGap + board.padUnits)
    readonly property real x0: Math.round((board.width - board.totalW) / 2)

    implicitHeight: board.caseH + (others.visible ? others.implicitHeight + 10 : 0)

    // ---- Farben ----
    readonly property color caseColor: Colors.surfaceContainer
    readonly property color plateColor: Qt.darker(Colors.surface, 1.35)

    // Belegung einer Taste auf der Ebene, AltGr-Zeichen eingerechnet
    function infoFor(id: string): var {
        const direct = board.index[`${board.mask}:${id}`];
        if (direct)
            return direct;
        for (const alias of Layout.altgrOf(id)) {
            const via = board.index[`${board.mask}:${alias}`];
            if (via)
                return Object.assign({ via: alias }, via);
        }
        return null;
    }

    // Lichtfarbe der Belegung
    function lightOf(info: var): color {
        if (!info)
            return "transparent";
        if (info.disabled)
            return Colors.error;
        if (info.unnamed)
            return Colors.fgSurfaceVariant;
        if (info.changed)
            return Colors.fgSurface;
        if (info.source === "plugin")
            return Colors.secondary;
        if (info.source === "custom" || info.source === "extra")
            return Colors.tertiary;
        return Colors.primary;
    }

    function litOf(id: string): bool {
        if (board.litKeys[id] === true)
            return true;
        for (const alias of Layout.altgrOf(id))
            if (board.litKeys[alias] === true)
                return true;
        return false;
    }

    // Gehoverte Taste fuers Display
    property var hoverInfo: null

    function setHover(on: bool, info: var): void {
        if (on)
            board.hoverInfo = info;
        else if (board.hoverInfo === info)
            board.hoverInfo = null;
    }

    // Gebundene Tasten ohne Platz (z.B. code:NN)
    readonly property var otherKeys: {
        const seen = {};
        const out = [];
        for (const canon in board.index) {
            const id = canon.slice(canon.indexOf(":") + 1);
            if (seen[id] || Layout.onBoard(id) || Layout.isMouse(id) || Layout.isMedia(id))
                continue;
            seen[id] = true;
            out.push(id);
        }
        return out.sort();
    }

    // Infos fuer Maus/Walze als Maps (einmal je Ebene)
    readonly property var mouseInfos: {
        const out = {};
        for (const id of Layout.MOUSE)
            out[id] = board.infoFor(id);
        return out;
    }
    readonly property var mouseLights: {
        const out = {};
        for (const id of Layout.MOUSE)
            out[id] = board.lightOf(board.mouseInfos[id]);
        return out;
    }
    readonly property var mouseLits: {
        const out = {};
        for (const id of Layout.MOUSE)
            out[id] = board.litOf(id);
        return out;
    }
    readonly property var rollerInfos: Layout.ROLLER.map(id => board.infoFor(id))

    // ================= Gehaeuse =================
    Rectangle {
        id: shell

        x: board.x0
        width: board.caseW
        height: board.caseH
        radius: board.unit * 0.42
        color: board.caseColor
        border.width: 1
        border.color: Colors.alpha(Colors.fgSurface, 0.07)

        // Kante oben: leichtes Highlight
        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                leftMargin: parent.radius
                rightMargin: parent.radius
                topMargin: 1
            }
            height: 1
            color: Colors.alpha(Colors.fgSurface, 0.1)
        }

        // Platte
        Rectangle {
            x: board.unit * board.bezelSide - board.gap * 0.5 - board.unit * 0.1
            y: board.unit * board.bezelTop - board.gap * 0.5 - board.unit * 0.1
            width: board.unit * Layout.UNITS_WIDE - board.gap + board.unit * 0.2
            height: board.unit * Layout.UNITS_HIGH - board.gap + board.unit * 0.2
            radius: board.unit * 0.22
            color: board.plateColor
            border.width: 1
            border.color: Colors.alpha(Colors.background, 0.6)
        }

        // ---- Display (oben links) ----
        Rectangle {
            id: display

            x: board.unit * board.bezelSide
            y: board.unit * 0.3
            width: board.unit * 6.2
            height: board.unit * 0.8
            radius: board.unit * 0.14
            color: board.plateColor
            border.width: 1
            border.color: Colors.alpha(Colors.background, 0.7)

            readonly property var shown: board.hoverInfo ?? null
            readonly property string line: {
                if (display.shown) {
                    if (display.shown.unnamed)
                        return I18n.tr("Belegt (ohne Beschreibung)");
                    return `${I18n.tr(display.shown.group)} › ${I18n.tr(display.shown.title)}`;
                }
                return board.statusTitle;
            }
            readonly property var lineKeys: display.shown ? (display.shown.keys ?? []) : board.statusKeys

            Column {
                anchors {
                    left: parent.left
                    right: parent.right
                    leftMargin: board.unit * 0.2
                    rightMargin: board.unit * 0.2
                    verticalCenter: parent.verticalCenter
                }
                spacing: Math.max(1, board.unit * 0.04)

                // Ebene
                Row {
                    spacing: 4

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.tr("Ebene")
                        color: Colors.alpha(Colors.primary, 0.6)
                        font.family: Config.font
                        font.pixelSize: Math.max(8, Math.round(board.unit * 0.17))
                        font.weight: Font.DemiBold
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 1
                        rightPadding: 4
                    }

                    Repeater {
                        model: Layout.modLabels(board.mask)

                        Text {
                            required property string modelData
                            required property int index

                            anchors.verticalCenter: parent.verticalCenter
                            text: (index > 0 ? "+ " : "") + I18n.tr(modelData)
                            color: Colors.primary
                            font.family: Config.font
                            font.pixelSize: Math.max(9, Math.round(board.unit * 0.19))
                            font.weight: Font.DemiBold
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: board.mask === 0
                        text: I18n.tr("ohne Modifier")
                        color: Colors.primary
                        font.family: Config.font
                        font.pixelSize: Math.max(9, Math.round(board.unit * 0.19))
                        font.weight: Font.DemiBold
                    }
                }

                // Gehoverter / gewaehlter Befehl mit Kombination
                Row {
                    spacing: 6

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, display.width - board.unit * 0.4 - keysRow.width - 6)
                        text: display.line !== "" ? display.line : "—"
                        color: display.line !== "" ? Colors.fgSurface : Colors.alpha(Colors.fgSurfaceVariant, 0.5)
                        font.family: Config.font
                        font.pixelSize: Math.max(9, Math.round(board.unit * 0.19))
                        elide: Text.ElideRight
                    }

                    Row {
                        id: keysRow

                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Repeater {
                            model: display.lineKeys

                            Keycap {
                                required property string modelData

                                anchors.verticalCenter: parent?.verticalCenter
                                text: modelData
                                size: Math.max(12, Math.round(board.unit * 0.27))
                            }
                        }
                    }
                }
            }
        }

        // ---- Medien (oben rechts, ueber dem Nav-Block) ----
        Row {
            id: media

            anchors {
                right: parent.right
                rightMargin: board.unit * board.bezelSide + board.gap
            }
            y: board.unit * 0.3 + (board.unit * 0.8 - board.unit * 0.56) / 2
            spacing: board.unit * 0.14

            Repeater {
                model: Layout.MEDIA

                MediaButton {
                    id: mb

                    required property var modelData

                    spec: mb.modelData
                    unit: board.unit
                    info: board.infoFor(mb.spec.id)
                    light: board.lightOf(mb.info)
                    lit: board.litOf(mb.spec.id)
                    pick: board.pick
                    interactive: board.interactive
                    onClicked: board.keyClicked(mb.spec.id)
                    onHoveredChanged: board.setHover(mb.hovered, mb.info)
                }
            }

            Item {
                width: board.unit * 0.1
                height: 1
            }

            VolumeRoller {
                id: roller

                anchors.verticalCenter: parent.verticalCenter
                unit: board.unit
                infos: board.rollerInfos
                lights: board.rollerInfos.map(i => board.lightOf(i))
                lits: Layout.ROLLER.map(id => board.litOf(id))
                pick: board.pick
                interactive: board.interactive
                onClicked: id => board.keyClicked(id)
            }
        }

        // ---- Tasten ----
        Item {
            id: keys

            x: board.unit * board.bezelSide
            y: board.unit * board.bezelTop
            width: board.unit * Layout.UNITS_WIDE
            height: board.unit * Layout.UNITS_HIGH

            Repeater {
                model: Layout.keys()

                KeyboardKey {
                    id: k

                    required property var modelData

                    spec: k.modelData
                    unit: board.unit
                    gap: board.gap
                    info: board.infoFor(k.spec.id)
                    light: board.lightOf(k.info)
                    lit: board.litOf(k.spec.id)
                    pressed: k.spec.mod !== 0 && (board.mask & k.spec.mod) !== 0
                    pick: board.pick
                    interactive: board.interactive
                    tipAbove: k.spec.y >= 3
                    onHoveredChanged: board.setHover(k.hovered, k.info)
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
    }

    // ================= Mauspad =================
    Rectangle {
        id: pad

        x: shell.x + shell.width + board.unit * board.padGap
        // Buendig mit der Unterkante des Gehaeuses, nicht so hoch wie dieses
        y: board.caseH - height
        width: board.unit * board.padUnits
        height: board.unit * 4.4
        radius: board.unit * 0.3
        color: Qt.darker(board.caseColor, 1.12)
        border.width: 1
        border.color: Colors.alpha(Colors.fgSurface, 0.05)

        MouseView {
            anchors.centerIn: parent
            unit: board.unit
            infos: board.mouseInfos
            lights: board.mouseLights
            lits: board.mouseLits
            interactive: board.interactive
            onClicked: id => board.keyClicked(id)
            onHoverIdChanged: board.setHover(hoverId !== "", hoverId !== "" ? (board.mouseInfos[hoverId] ?? null) : board.hoverInfo)
        }
    }

    // ================= Sonstige gebundene Tasten =================
    Flow {
        id: others

        anchors {
            top: shell.bottom
            topMargin: 10
        }
        x: board.x0
        width: board.totalW
        visible: board.otherKeys.length > 0
        spacing: 10

        Repeater {
            model: board.otherKeys

            Row {
                id: other

                required property string modelData
                readonly property var info: board.infoFor(other.modelData)

                spacing: 5

                Keycap {
                    anchors.verticalCenter: parent.verticalCenter
                    text: other.modelData
                    size: 18
                    accent: other.info !== null
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: other.info ? (other.info.unnamed ? I18n.tr("belegt") : I18n.tr(other.info.title)) : ""
                    color: Colors.fgSurfaceVariant
                    font.family: Config.font
                    font.pixelSize: 10
                }

                TapHandler {
                    enabled: other.info !== null
                    onTapped: board.keyClicked(other.modelData)
                }
            }
        }
    }
}
