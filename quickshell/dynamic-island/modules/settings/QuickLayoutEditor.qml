pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.services.config

import qs

// Drag-and-Drop-Editor fuer den Aufbau der Schnelleinstellungen – ein Raster
// mit QuickLayout.columns Spalten, wie im Android-Tray. Sitzt als
// `editor: "quick"` im Einstellungs-Menue.
//
// Oben die Reihen, so wie die Karte sie zeigt: jede Kachel als Chip, so
// breit wie ihre Spalten; freie Zellen sind als leere Felder zu sehen.
// Darunter eine Zone fuer eine neue Reihe (nur ein "+", beim Ziehen deutlich)
// und die Ablage "Ausgeblendet".
//
//   Chip ziehen                 umsortieren, umziehen, neue Reihe, ausblenden
//   Am rechten Rand ziehen      breiter oder schmaler (in Spalten rastend)
//   Chip in der Ablage klicken  wieder einblenden
//
// Beide Gesten sind DragHandler ohne Ziel: beim Verschieben folgt ein
// "Geist" dem Zeiger und beim Loslassen rechnet hitTest das Ziel aus der
// Position; beim Breitenziehen zeigt der Chip die neue Breite live und
// QuickLayout.resize schreibt sie beim Loslassen. Die Regeln (Mindest-
// breiten, freier Platz in der Reihe) kennt QuickLayout.
Item {
    id: editor

    implicitHeight: column.implicitHeight

    // ---- Verschieben ----
    property string dragId: ""
    readonly property bool dragging: editor.dragId !== ""
    property point dragPos: Qt.point(0, 0)
    // { rowIndex, index, newRow } | { hide: true } | null
    property var target: null

    // ---- Breite ziehen ----
    property string resizeId: ""
    property int resizeSpan: 0
    readonly property bool resizing: editor.resizeId !== ""

    readonly property real rowHeight: 48
    readonly property real gap: 8            // Abstand zwischen Reihen = Zone "neue Reihe"
    readonly property real cellGap: 6
    readonly property real cellInset: 4
    // Breite einer Rasterspalte in den Reihen
    readonly property real unit: (column.width - editor.cellInset * 2
                                  - editor.cellGap * (QuickLayout.columns - 1)) / QuickLayout.columns

    function cellWidth(span: int): real {
        return editor.unit * span + editor.cellGap * (span - 1);
    }

    function beginDrag(id: string): void {
        editor.dragId = id;
        editor.target = null;
    }

    function updateDrag(p: point): void {
        editor.dragPos = p;
        editor.target = editor.hitTest(p);
    }

    function endDrag(): void {
        const t = editor.target;
        const id = editor.dragId;
        editor.dragId = "";
        editor.target = null;
        if (!t || id === "")
            return;
        if (t.hide)
            QuickLayout.hide(id);
        else
            QuickLayout.place(id, t.rowIndex, t.index ?? 0, t.newRow ?? false);
    }

    function inside(item: Item, p: point, slack: real): bool {
        const q = editor.mapToItem(item, p);
        return q.x >= -slack && q.x <= item.width + slack && q.y >= -slack && q.y <= item.height + slack;
    }

    function hitTest(p: point): var {
        if (editor.inside(tray, p, 0))
            return ({ hide: true });
        if (editor.inside(newRowZone, p, 0))
            return ({ rowIndex: QuickLayout.rows.length, index: 0, newRow: true });

        for (let i = 0; i < rowsRepeater.count; i++) {
            const rowItem = rowsRepeater.itemAt(i);
            if (!rowItem)
                continue;
            const q = editor.mapToItem(rowItem, p);
            if (q.x < -4 || q.x > rowItem.width + 4)
                continue;
            // Luecke oberhalb der Reihe: neue Reihe davor
            if (q.y < 0 && q.y >= -editor.gap)
                return ({ rowIndex: i, index: 0, newRow: true });
            if (q.y >= 0 && q.y <= rowItem.height) {
                const chips = rowItem.chips;
                let index = chips.count;
                for (let j = 0; j < chips.count; j++) {
                    const c = chips.itemAt(j);
                    if (!c)
                        continue;
                    const cq = editor.mapToItem(c, p);
                    if (cq.x < c.width / 2) {
                        index = j;
                        break;
                    }
                }
                return ({ rowIndex: i, index, newRow: false });
            }
        }
        return null;
    }

    // Ein Chip – in den Reihen und in der Ablage derselbe
    component Chip: Rectangle {
        id: chip

        required property string tileId
        property int span: 1
        // true in den Reihen: Breite ziehen moeglich
        property bool sizable: false

        readonly property var info: QuickLayout.tiles[chip.tileId] ?? ({})
        readonly property string kind: chip.info.kind ?? "pill"
        readonly property bool lifted: editor.dragId === chip.tileId
        readonly property bool stretching: editor.resizeId === chip.tileId
        readonly property int shownSpan: chip.stretching ? editor.resizeSpan : chip.span
        readonly property bool narrow: chip.width < 70

        implicitWidth: chip.sizable ? editor.cellWidth(chip.shownSpan) : chipLabel.implicitWidth + 52
        implicitHeight: 40
        radius: 12
        color: chip.stretching ? Colors.alpha(Colors.primary, 0.18)
             : chipHover.hovered && !editor.dragging ? Colors.alpha(Colors.fgSurface, 0.14)
             : Colors.alpha(Colors.fgSurface, 0.09)
        border.width: 1
        border.color: chip.stretching ? Colors.alpha(Colors.primary, 0.7) : Colors.alpha(Colors.outline, 0.3)
        opacity: chip.lifted ? 0.3 : 1
        clip: true

        Behavior on color {
            ColorAnimation { duration: 120 }
        }
        Behavior on opacity {
            NumberAnimation { duration: 120 }
        }
        // Beim Ziehen am Rand sofort folgen, sonst weich
        Behavior on implicitWidth {
            enabled: !chip.stretching
            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
        }

        Text {
            id: chipIcon

            // Schmal: mittig. Sonst links mit Rand. (left UND horizontalCenter
            // zugleich waere ein Anker-Konflikt – das Icon klebte links.)
            anchors {
                left: chip.narrow ? undefined : parent.left
                leftMargin: 12
                horizontalCenter: chip.narrow ? parent.horizontalCenter : undefined
                verticalCenter: parent.verticalCenter
            }
            text: chip.info.icon ?? "help"
            color: Colors.fgSurface
            font.family: "Material Symbols Outlined"
            font.pixelSize: 17
        }

        Text {
            id: chipLabel

            font.family: Config.font
            anchors {
                left: chipIcon.right
                leftMargin: 8
                right: parent.right
                rightMargin: chip.sizable ? 30 : 12
                verticalCenter: parent.verticalCenter
            }
            visible: !chip.narrow
            text: chip.info.label ? I18n.tr(chip.info.label) : chip.tileId
            color: Colors.fgSurface
            font.pixelSize: 11
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        // Breite als Zahl, solange gezogen wird
        Rectangle {
            anchors {
                right: handle.left
                rightMargin: 2
                verticalCenter: parent.verticalCenter
            }
            width: spanLabel.implicitWidth + 10
            height: 18
            radius: 9
            color: Colors.primary
            visible: chip.stretching

            Text {
                id: spanLabel

                anchors.centerIn: parent
                font.family: Config.font
                text: chip.shownSpan
                color: Colors.fgPrimary
                font.pixelSize: 10
                font.weight: Font.Bold
            }
        }

        HoverHandler {
            id: chipHover

            cursorShape: editor.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        }

        // Verschieben – nicht, wenn der Zeiger auf dem Griff steht
        DragHandler {
            id: drag

            target: null
            enabled: !handleHover.hovered && !editor.resizing
            onActiveChanged: {
                if (drag.active)
                    editor.beginDrag(chip.tileId);
                else
                    editor.endDrag();
            }
            onCentroidChanged: {
                if (drag.active)
                    editor.updateDrag(editor.mapFromItem(null, drag.centroid.scenePosition));
            }
        }

        // ---- Griff am rechten Rand: Breite ziehen ----
        Item {
            id: handle

            anchors {
                right: parent.right
                top: parent.top
                bottom: parent.bottom
            }
            width: 22
            visible: chip.sizable

            Rectangle {
                anchors.centerIn: parent
                width: 4
                height: 16
                radius: 2
                color: handleHover.hovered || chip.stretching ? Colors.primary : Colors.alpha(Colors.fgSurfaceVariant, 0.5)

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }
            }

            HoverHandler {
                id: handleHover

                cursorShape: Qt.SizeHorCursor
            }

            DragHandler {
                id: stretch

                target: null
                xAxis.enabled: true
                yAxis.enabled: false

                property int startSpan: 0

                onActiveChanged: {
                    if (stretch.active) {
                        stretch.startSpan = chip.span;
                        editor.resizeId = chip.tileId;
                        editor.resizeSpan = chip.span;
                    } else {
                        const next = editor.resizeSpan;
                        editor.resizeId = "";
                        QuickLayout.resize(chip.tileId, next);
                    }
                }
                onTranslationChanged: {
                    if (!stretch.active)
                        return;
                    const stepWidth = editor.unit + editor.cellGap;
                    const wanted = stretch.startSpan + Math.round(stretch.activeTranslation.x / stepWidth);
                    editor.resizeSpan = Math.max(QuickLayout.minSpan(chip.tileId),
                                                 Math.min(QuickLayout.maxSpan(chip.tileId), wanted));
                }
            }
        }
    }

    Column {
        id: column

        anchors {
            left: parent.left
            right: parent.right
        }
        spacing: editor.gap

        // ---- Die Reihen ----
        Repeater {
            id: rowsRepeater

            model: QuickLayout.rows

            Rectangle {
                id: rowItem

                required property var modelData     // Array von { id, span }
                required property int index

                readonly property alias chips: chipRepeater
                readonly property bool isTarget: editor.target !== null && !editor.target.hide
                                                 && !editor.target.newRow && editor.target.rowIndex === rowItem.index
                // Zone "neue Reihe davor" markieren
                readonly property bool isGapTarget: editor.target !== null && editor.target.newRow === true
                                                    && editor.target.rowIndex === rowItem.index

                width: column.width
                height: editor.rowHeight
                radius: 14
                color: rowItem.isTarget ? Colors.alpha(Colors.primary, 0.12) : Colors.alpha(Colors.fgSurface, 0.04)
                border.width: 1
                border.color: rowItem.isTarget ? Colors.alpha(Colors.primary, 0.6) : Colors.alpha(Colors.outline, 0.18)

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }
                Behavior on border.color {
                    ColorAnimation { duration: 120 }
                }

                // Das Raster: eine leere Zelle je Spalte, die Chips liegen darueber
                Row {
                    anchors {
                        fill: parent
                        margins: editor.cellInset
                    }
                    spacing: editor.cellGap

                    Repeater {
                        model: QuickLayout.columns

                        Rectangle {
                            width: editor.unit
                            // Beim Umbau des Repeaters ist parent kurz null
                            height: parent?.height ?? 0
                            radius: 12
                            color: "transparent"
                            border.width: 1
                            border.color: Colors.alpha(Colors.outline, editor.dragging || editor.resizing ? 0.35 : 0.14)

                            Behavior on border.color {
                                ColorAnimation { duration: 120 }
                            }
                        }
                    }
                }

                // Linie oberhalb: hier entstuende eine neue Reihe
                Rectangle {
                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.top
                        bottomMargin: editor.gap / 2 - 1
                        leftMargin: 6
                        rightMargin: 6
                    }
                    height: 2
                    radius: 1
                    color: Colors.primary
                    visible: rowItem.isGapTarget
                }

                Row {
                    id: chipRow

                    anchors {
                        fill: parent
                        margins: editor.cellInset
                    }
                    spacing: editor.cellGap

                    Repeater {
                        id: chipRepeater

                        model: rowItem.modelData

                        Chip {
                            required property var modelData

                            tileId: modelData.id
                            span: modelData.span
                            sizable: true
                            height: chipRow.height
                        }
                    }
                }

                // Einfuege-Markierung zwischen den Chips
                Rectangle {
                    readonly property real markerX: {
                        if (!rowItem.isTarget)
                            return 0;
                        const idx = editor.target.index ?? 0;
                        if (idx < chipRepeater.count) {
                            const c = chipRepeater.itemAt(idx);
                            return c ? chipRow.x + c.x - chipRow.spacing / 2 - 1 : 0;
                        }
                        const last = chipRepeater.itemAt(chipRepeater.count - 1);
                        return last ? chipRow.x + last.x + last.width + chipRow.spacing / 2 - 1 : chipRow.x;
                    }

                    x: markerX
                    y: 6
                    width: 2
                    height: parent.height - 12
                    radius: 1
                    color: Colors.primary
                    visible: rowItem.isTarget
                }
            }
        }

        // ---- Neue Reihe (hinten) ----
        Rectangle {
            id: newRowZone

            readonly property bool isTarget: editor.target !== null && editor.target.newRow === true
                                             && editor.target.rowIndex === QuickLayout.rows.length

            width: column.width
            height: 34
            radius: 12
            color: newRowZone.isTarget ? Colors.alpha(Colors.primary, 0.12) : "transparent"
            border.width: 1
            border.color: newRowZone.isTarget ? Colors.alpha(Colors.primary, 0.6) : Colors.alpha(Colors.outline, 0.3)
            opacity: editor.dragging ? 1 : 0.5

            Behavior on color {
                ColorAnimation { duration: 120 }
            }
            Behavior on opacity {
                NumberAnimation { duration: 140 }
            }

            Text {
                anchors.centerIn: parent
                text: "add"
                color: Colors.fgSurfaceVariant
                font.family: "Material Symbols Outlined"
                font.pixelSize: 15
            }
        }

        // ---- Ablage: ausgeblendete Kacheln ----
        Item {
            width: column.width
            height: 26

            Text {
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                }
                font.family: Config.font
                text: I18n.tr("Ausgeblendet")
                color: Colors.fgSurfaceVariant
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }

            // Zuruecksetzen auf den Standard-Aufbau
            Rectangle {
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                width: resetLabel.implicitWidth + 22
                height: 24
                radius: 12
                visible: !Config.isDefault("quick", "rows")
                color: resetHover.hovered ? Colors.alpha(Colors.fgSurface, 0.12) : Colors.alpha(Colors.fgSurface, 0.06)

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }

                Row {
                    id: resetLabel

                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "restart_alt"
                        color: Colors.fgSurfaceVariant
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 14
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        font.family: Config.font
                        text: I18n.tr("Standard")
                        color: Colors.fgSurface
                        font.pixelSize: 10
                    }
                }

                HoverHandler {
                    id: resetHover

                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: QuickLayout.reset()
                }
            }
        }

        Rectangle {
            id: tray

            readonly property bool isTarget: editor.target !== null && editor.target.hide === true

            width: column.width
            height: Math.max(48, trayFlow.implicitHeight + 8)
            radius: 14
            color: tray.isTarget ? Colors.alpha(Colors.error, 0.12) : Colors.alpha(Colors.fgSurface, 0.04)
            border.width: 1
            border.color: tray.isTarget ? Colors.alpha(Colors.error, 0.6) : Colors.alpha(Colors.outline, 0.18)

            Behavior on color {
                ColorAnimation { duration: 120 }
            }
            Behavior on border.color {
                ColorAnimation { duration: 120 }
            }

            Flow {
                id: trayFlow

                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 4
                }
                spacing: 6

                Repeater {
                    model: QuickLayout.hidden

                    Chip {
                        id: hiddenChip

                        required property string modelData

                        tileId: hiddenChip.modelData

                        // Klick blendet wieder ein (hinten als eigene Reihe)
                        TapHandler {
                            onTapped: QuickLayout.show(hiddenChip.modelData)
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: QuickLayout.hidden.length === 0
                text: "visibility_off"
                color: Colors.alpha(Colors.fgSurfaceVariant, 0.7)
                font.family: "Material Symbols Outlined"
                font.pixelSize: 15
            }
        }
    }

    // ---- Der Geist, der dem Zeiger folgt ----
    Rectangle {
        id: ghost

        readonly property var info: QuickLayout.tiles[editor.dragId] ?? ({})

        visible: editor.dragging
        x: editor.dragPos.x - width / 2
        y: editor.dragPos.y - height / 2
        z: 10
        width: ghostLabel.implicitWidth + 50
        height: 40
        radius: 12
        color: Colors.alpha(Colors.primary, 0.9)
        scale: 1.05

        Text {
            id: ghostIcon

            anchors {
                left: parent.left
                leftMargin: 12
                verticalCenter: parent.verticalCenter
            }
            text: ghost.info.icon ?? ""
            color: Colors.fgPrimary
            font.family: "Material Symbols Outlined"
            font.pixelSize: 17
        }

        Text {
            id: ghostLabel

            font.family: Config.font
            anchors {
                left: ghostIcon.right
                leftMargin: 8
                verticalCenter: parent.verticalCenter
            }
            text: I18n.tr(ghost.info.label ?? "")
            color: Colors.fgPrimary
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }
    }
}
