pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import qs.modules.services.config
import qs.modules.services.plugins
import qs.modules.services.theme
import qs.modules.services.wallpaper
import qs.modules.widgets

import qs

// Wallpaper-Bibliothek – die Seite hinter "Wallpaper > Bibliothek" im
// Einstellungs-Fenster (SettingsCard.qml zeigt sie statt der Zeilenliste).
//
// Oben die Ordner als Chips (Alle, je Unterordner, "+ Ordner" mit Inline-
// Feld), darunter links das Raster der Vorschaubilder und rechts die
// Details: fuer ein Bild Setzen / Verschieben / Papierkorb, der Material-
// Stil und – wenn das Plugin "terminal" an ist – der Terminal-Look; fuer
// einen Ordner (Chip ohne gewaehltes Bild) Umbenennen und sein Ordner-Look.
//
// Das Raster zeigt nie die Originale, nur die kleinen Vorschaubilder aus
// Wallpapers.thumbFor (Qt dekodiert alle Bilder in einem Thread, ein grosses
// PNG staut sonst die ganze Shell). Klick waehlt aus, Doppelklick setzt.
// Keine Vorschau beim Hovern – die wuerde den Hintergrund umschalten.
//
// Dateien bewegt WallManager (wallmgr.py); nach einem Verschieben zieht
// `finished` die Auswahl auf den neuen Pfad nach. Papierkorb ist zweistufig
// wie "Alles zuruecksetzen" in der Leiste.
Item {
    id: page

    // Suchtext aus dem Kopf des Fensters – filtert die Bilder
    property string filter: ""

    // Gewaehlter Ordner-Chip ("" = alle) und gewaehltes Bild (Pfad, "" = keins)
    property string folder: ""
    property string selected: ""

    property bool newFolderOpen: false
    property bool renameOpen: false
    property bool moveOpen: false
    property bool trashArmed: false
    // Weggeklickte Fehlermeldung
    property string dismissedError: ""

    readonly property bool busy: WallManager.busy
    readonly property string error: WallManager.lastError !== page.dismissedError ? WallManager.lastError : ""

    readonly property bool terminalOn: Plugins.isEnabled("terminal")
    readonly property string terminalSection: Plugins.sectionPrefix + "terminal"
    readonly property bool lookTheme: Plugins.get(page.terminalSection, "theme") === true
    readonly property bool lookFolders: Plugins.get(page.terminalSection, "folderLooks") === true
    // Stil wirkt nur beim dynamischen Schema
    readonly property bool dynamicScheme: Themes.currentName === "dynamic"

    readonly property var styles: [{ name: "auto", icon: "auto_awesome" }].concat(Themes.variants)

    // Bilder des gewaehlten Ordners, durch die Suche gefiltert
    readonly property var images: {
        const needle = page.filter.trim().toLowerCase();
        const base = WallManager.imagesIn(page.folder);
        return needle === "" ? base : base.filter(w => w.name.toLowerCase().includes(needle));
    }
    readonly property int total: Wallpapers.list.length

    readonly property var selectedInfo: page.selected !== ""
        ? Wallpapers.list.find(w => w.path === page.selected) ?? null : null
    readonly property bool hasSelection: page.selectedInfo !== null
    readonly property string selectedFolder: page.hasSelection ? WallManager.folderOf(page.selected) : ""
    readonly property bool selectedIsCurrent: page.hasSelection && page.selected === Wallpapers.actualCurrent

    // Welche Details rechts stehen: "bild", "ordner" oder "uebersicht"
    readonly property string mode: page.hasSelection ? "bild" : page.folder !== "" ? "ordner" : "uebersicht"

    function fileName(name: string): string {
        return name.slice(name.lastIndexOf("/") + 1);
    }

    function folderName(f: string): string {
        return f === "" ? "Oberste Ebene" : f.slice(f.lastIndexOf("/") + 1);
    }

    function countIn(f: string): int {
        return WallManager.imagesIn(f).length;
    }

    function plural(n: int, one: string, many: string): string {
        return n === 1 ? `1 ${one}` : `${n} ${many}`;
    }

    function pickFolder(f: string): void {
        page.folder = f;
        page.selected = "";
        page.closeInline();
        grid.contentY = 0;
    }

    function pickImage(path: string): void {
        page.selected = path;
        page.closeInline();
    }

    function closeInline(): void {
        page.newFolderOpen = false;
        page.renameOpen = false;
        page.moveOpen = false;
        page.trashArmed = false;
    }

    function lookTitle(id: string): string {
        return WallManager.lookInfo(id)?.title ?? id;
    }

    function sourceLabel(source: string): string {
        return ({ bild: "fest für dieses Bild", ordner: "vom Ordner", name: "Ordner heißt wie der Look", schema: "Farbschema" })[source] ?? source;
    }

    Component.onCompleted: WallManager.ensureLoaded()

    // Nach Verschieben/Umbenennen der Auswahl hinterher, nach dem Papierkorb
    // Auswahl leeren
    Connections {
        target: WallManager

        function onFinished(op: string, result: var): void {
            if (!result.ok)
                return;
            if (op === "move" && result.path)
                page.selected = result.path;
            else if (op === "trash")
                page.selected = "";
            else if (op === "rename-folder" && result.folder !== undefined)
                page.folder = result.folder;
            else if (op === "mkdir" && result.folder !== undefined)
                page.pickFolder(result.folder);
        }
    }

    Timer {
        id: disarmTrash

        interval: 3000
        onTriggered: page.trashArmed = false
    }

    // ---- Bausteine ----

    // Knopf im Chip-Stil (wie in PluginManager)
    component ActionButton: Rectangle {
        id: button

        required property string icon
        required property string label
        property color tint: Colors.fgSurface
        property bool filled: false
        signal clicked()

        implicitWidth: buttonRow.implicitWidth + 22
        implicitHeight: 28
        radius: height / 2
        opacity: enabled ? 1 : 0.4
        color: button.filled ? (buttonHover.hovered ? Colors.alpha(Colors.primary, 0.85) : Colors.primary)
             : buttonHover.hovered ? Colors.alpha(Colors.fgSurface, 0.12)
             : Colors.alpha(Colors.fgSurface, 0.06)

        Behavior on color {
            ColorAnimation { duration: Appearance.fadeDuration }
        }
        Fade on opacity {}

        Row {
            id: buttonRow

            anchors.centerIn: parent
            spacing: 5

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: button.icon
                color: button.filled ? Colors.fgPrimary : button.tint
                font.family: "Material Symbols Outlined"
                font.pixelSize: 15

                Behavior on color {
                    ColorAnimation { duration: Appearance.fadeDuration }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                font.family: Config.font
                text: button.label
                color: button.filled ? Colors.fgPrimary : button.tint
                font.pixelSize: 11
                font.weight: button.filled ? Font.DemiBold : Font.Normal

                Behavior on color {
                    ColorAnimation { duration: Appearance.fadeDuration }
                }
            }
        }

        HoverHandler {
            id: buttonHover

            cursorShape: button.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        }

        TapHandler {
            enabled: button.enabled
            onTapped: button.clicked()
        }
    }

    // Auswahl-Chip (Ordner, Stil): markiert = Akzent
    component Chip: Rectangle {
        id: chip

        required property string label
        property string icon: ""
        property int count: -1
        property bool current: false
        // Kleiner (Stil-Reihe in den Details)
        property bool compact: false
        signal clicked()

        implicitWidth: chipRow.implicitWidth + (chip.compact ? 14 : 20)
        implicitHeight: chip.compact ? 22 : 26
        radius: height / 2
        opacity: enabled ? 1 : 0.4
        color: chip.current ? Colors.alpha(Colors.primary, 0.18)
             : chipHover.hovered ? Colors.alpha(Colors.fgSurface, 0.11)
             : Colors.alpha(Colors.fgSurface, 0.06)
        border.width: 1
        border.color: chip.current ? Colors.alpha(Colors.primary, 0.5) : "transparent"

        Behavior on color {
            ColorAnimation { duration: Appearance.fadeDuration }
        }
        Behavior on border.color {
            ColorAnimation { duration: Appearance.fadeDuration }
        }

        Row {
            id: chipRow

            anchors.centerIn: parent
            spacing: 5

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: chip.icon !== ""
                text: chip.icon
                color: chip.current ? Colors.primary : Colors.fgSurfaceVariant
                font.family: "Material Symbols Outlined"
                font.pixelSize: chip.compact ? 12 : 14
                font.variableAxes: ({ FILL: chip.current ? 1 : 0 })
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                font.family: Config.font
                text: chip.label
                color: chip.current ? Colors.fgBackground : Colors.fgSurface
                font.pixelSize: chip.compact ? 10 : 11
                font.weight: chip.current ? Font.DemiBold : Font.Normal
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: chip.count >= 0
                font.family: Config.font
                text: chip.count
                color: Colors.alpha(Colors.fgSurfaceVariant, 0.8)
                font.pixelSize: 10
            }
        }

        HoverHandler {
            id: chipHover

            cursorShape: chip.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        }

        TapHandler {
            enabled: chip.enabled
            onTapped: chip.clicked()
        }
    }

    // Einzeiliges Textfeld (Ordnername) mit Bestaetigen/Abbrechen
    component InlineField: Rectangle {
        id: field

        property string placeholder: ""
        property string text: ""
        property string okIcon: "check"
        signal accepted(string value)
        signal cancelled()

        function focusInput(): void {
            input.text = field.text;
            input.selectAll();
            input.forceActiveFocus();
        }

        implicitHeight: 30
        radius: 10
        color: Colors.alpha(Colors.fgSurface, input.activeFocus ? 0.09 : 0.06)
        border.width: 1
        border.color: input.activeFocus ? Colors.alpha(Colors.primary, 0.5) : "transparent"

        Behavior on color {
            ColorAnimation { duration: Appearance.fadeDuration }
        }
        Behavior on border.color {
            ColorAnimation { duration: Appearance.fadeDuration }
        }

        Component.onCompleted: field.focusInput()

        TextInput {
            id: input

            anchors {
                left: parent.left
                right: okButton.left
                leftMargin: 10
                rightMargin: 4
                verticalCenter: parent.verticalCenter
            }
            font.family: Config.font
            font.pixelSize: 11
            color: Colors.fgSurface
            selectionColor: Colors.alpha(Colors.primary, 0.35)
            clip: true
            onAccepted: if (text.trim() !== "") field.accepted(text.trim())
            Keys.onEscapePressed: event => {
                field.cancelled();
                event.accepted = true;
            }

            Text {
                anchors.fill: parent
                visible: input.text === ""
                text: field.placeholder
                color: Colors.alpha(Colors.fgSurfaceVariant, 0.6)
                font: input.font
                verticalAlignment: Text.AlignVCenter
            }
        }

        Rectangle {
            id: okButton

            anchors {
                right: cancelButton.left
                rightMargin: 2
                verticalCenter: parent.verticalCenter
            }
            width: 24
            height: 24
            radius: 12
            opacity: input.text.trim() !== "" ? 1 : 0.35
            color: okHover.hovered ? Colors.alpha(Colors.primary, 0.25) : Colors.alpha(Colors.primary, 0.14)

            Text {
                anchors.centerIn: parent
                text: field.okIcon
                color: Colors.primary
                font.family: "Material Symbols Outlined"
                font.pixelSize: 15
            }

            HoverHandler {
                id: okHover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: if (input.text.trim() !== "") field.accepted(input.text.trim())
            }
        }

        Rectangle {
            id: cancelButton

            anchors {
                right: parent.right
                rightMargin: 3
                verticalCenter: parent.verticalCenter
            }
            width: 24
            height: 24
            radius: 12
            color: cancelHover.hovered ? Colors.alpha(Colors.fgSurface, 0.12) : "transparent"

            Text {
                anchors.centerIn: parent
                text: "close"
                color: Colors.fgSurfaceVariant
                font.family: "Material Symbols Outlined"
                font.pixelSize: 15
            }

            HoverHandler {
                id: cancelHover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: field.cancelled()
            }
        }
    }

    // Ueberschrift eines Abschnitts in den Details
    component SectionLabel: Text {
        font.family: Config.font
        color: Colors.fgSurfaceVariant
        font.pixelSize: 10
        font.weight: Font.DemiBold
        font.letterSpacing: 0.4
    }

    // Hinweiszeile (Plugin aus, Schema statisch …)
    component Hint: RowLayout {
        id: hint

        required property string text
        property string icon: "info"
        property color tint: Colors.fgSurfaceVariant

        spacing: 5

        Text {
            Layout.alignment: Qt.AlignTop
            text: hint.icon
            color: hint.tint
            font.family: "Material Symbols Outlined"
            font.pixelSize: 13
        }

        Text {
            Layout.fillWidth: true
            font.family: Config.font
            text: hint.text
            color: hint.tint
            font.pixelSize: 10
            wrapMode: Text.WordWrap
        }
    }

    // Vorschaubild mit runden Ecken (nur Thumbs – nie Originale)
    component Thumb: Rectangle {
        id: thumbFrame

        required property string name
        property real cornerRadius: 10

        radius: thumbFrame.cornerRadius
        color: Colors.surfaceContainer

        Image {
            id: thumbImage

            anchors.fill: parent
            source: Wallpapers.thumbFor(thumbFrame.name)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            visible: false
        }

        Item {
            id: thumbMask

            anchors.fill: thumbImage
            layer.enabled: true
            visible: false

            Rectangle {
                anchors.fill: parent
                radius: thumbFrame.cornerRadius
                color: "black"
            }
        }

        // Runde Ecken gehen nur ueber eine Maske – `clip` schneidet rechteckig
        MultiEffect {
            anchors.fill: thumbImage
            visible: thumbImage.status === Image.Ready
            source: thumbImage
            maskEnabled: true
            maskSource: thumbMask
        }

        // Platzhalter, solange das Vorschaubild fehlt oder laedt
        Text {
            anchors.centerIn: parent
            visible: thumbImage.status !== Image.Ready
            text: thumbImage.source.toString() === "" ? "hourglass_empty" : "image"
            color: Colors.alpha(Colors.fgSurfaceVariant, 0.6)
            font.family: "Material Symbols Outlined"
            font.pixelSize: 20
        }
    }

    // Eine Zeile der Look-Auswahl: Karte (3:4) als kleine Vorschau, Titel,
    // Beschreibung; markiert = Akzent
    component LookRow: Rectangle {
        id: lookRow

        required property string title
        required property string desc
        property string card: ""
        property string icon: "palette"
        property bool current: false
        signal clicked()

        width: parent.width
        implicitHeight: 44
        radius: 10
        opacity: enabled ? 1 : 0.5
        color: lookRow.current ? Colors.alpha(Colors.primary, 0.16)
             : lookHover.hovered ? Colors.alpha(Colors.fgSurface, 0.08)
             : "transparent"

        Behavior on color {
            ColorAnimation { duration: Appearance.fadeDuration }
        }

        Rectangle {
            id: cardFrame

            anchors {
                left: parent.left
                leftMargin: 6
                verticalCenter: parent.verticalCenter
            }
            width: 27
            height: 36
            radius: 5
            color: Colors.alpha(Colors.fgSurface, 0.08)

            Image {
                id: cardImage

                anchors.fill: parent
                visible: false
                source: lookRow.card !== "" ? "file://" + lookRow.card : ""
                // Nur eine Briefmarke der 600x800-Karte dekodieren
                sourceSize: Qt.size(54, 72)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
            }

            Item {
                id: cardMask

                anchors.fill: cardImage
                layer.enabled: true
                visible: false

                Rectangle {
                    anchors.fill: parent
                    radius: cardFrame.radius
                    color: "black"
                }
            }

            MultiEffect {
                anchors.fill: cardImage
                visible: cardImage.status === Image.Ready
                source: cardImage
                maskEnabled: true
                maskSource: cardMask
            }

            Text {
                anchors.centerIn: parent
                visible: cardImage.status !== Image.Ready
                text: lookRow.icon
                color: lookRow.current ? Colors.primary : Colors.fgSurfaceVariant
                font.family: "Material Symbols Outlined"
                font.pixelSize: 16
            }
        }

        Column {
            anchors {
                left: cardFrame.right
                right: checkIcon.left
                leftMargin: 9
                rightMargin: 4
                verticalCenter: parent.verticalCenter
            }
            spacing: 1

            Text {
                width: parent.width
                font.family: Config.font
                text: lookRow.title
                color: lookRow.current ? Colors.fgBackground : Colors.fgSurface
                font.pixelSize: 11
                font.weight: lookRow.current ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                visible: text !== ""
                font.family: Config.font
                text: lookRow.desc
                color: Colors.fgSurfaceVariant
                font.pixelSize: 9
                elide: Text.ElideRight
            }
        }

        Text {
            id: checkIcon

            anchors {
                right: parent.right
                rightMargin: 8
                verticalCenter: parent.verticalCenter
            }
            visible: lookRow.current
            text: "check"
            color: Colors.primary
            font.family: "Material Symbols Outlined"
            font.pixelSize: 15
        }

        HoverHandler {
            id: lookHover

            cursorShape: lookRow.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        }

        TapHandler {
            enabled: lookRow.enabled
            onTapped: lookRow.clicked()
        }
    }

    // Look-Auswahl fuer ein Bild (key = Bild-Schluessel) oder einen Ordner
    // (key = "Ordner/"): oben "Automatisch (…)", dann die Looks
    component LookPicker: Column {
        id: picker

        required property string key
        // Was ohne eigene Zuordnung gilt ({ id, source })
        required property var fallback
        readonly property string own: WallManager.assignments[picker.key] ?? ""
        readonly property bool hasOwn: picker.own !== "" && WallManager.exists(picker.own)
        readonly property bool active: page.lookTheme && page.lookFolders

        width: parent.width
        spacing: 2

        LookRow {
            enabled: picker.active
            title: `Automatisch (${page.lookTitle(picker.fallback.id)})`
            desc: page.sourceLabel(picker.fallback.source)
            card: WallManager.lookInfo(picker.fallback.id)?.card ?? ""
            icon: "auto_awesome"
            current: !picker.hasOwn
            onClicked: WallManager.setLook(picker.key, "")
        }

        Repeater {
            model: WallManager.looks

            LookRow {
                required property var modelData

                enabled: picker.active
                title: modelData.title
                desc: modelData.cards > 0 ? page.plural(modelData.cards, "Karte", "Karten") : modelData.desc
                card: modelData.card
                current: picker.hasOwn && picker.own === modelData.id
                onClicked: WallManager.setLook(picker.key, modelData.id)
            }
        }
    }

    // ================= Ordner-Chips =================
    Flow {
        id: folderRow

        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            leftMargin: 4
            rightMargin: 4
        }
        spacing: 6

        Chip {
            label: "Alle"
            icon: "photo_library"
            count: page.total
            current: page.folder === ""
            onClicked: page.pickFolder("")
        }

        Repeater {
            model: WallManager.folders

            Chip {
                required property string modelData

                label: modelData
                icon: page.folder === modelData ? "folder_open" : "folder"
                count: page.countIn(modelData)
                current: page.folder === modelData
                onClicked: page.pickFolder(modelData)
            }
        }

        Chip {
            visible: !page.newFolderOpen
            label: "Ordner"
            icon: "create_new_folder"
            enabled: !page.busy
            onClicked: {
                page.closeInline();
                page.newFolderOpen = true;
            }
        }

        Loader {
            active: page.newFolderOpen
            visible: active
            width: 200

            sourceComponent: InlineField {
                placeholder: "Neuer Ordner…"
                onAccepted: value => {
                    page.newFolderOpen = false;
                    WallManager.makeFolder(value);
                }
                onCancelled: page.newFolderOpen = false
            }
        }
    }

    // ---- Fehler von wallmgr.py ----
    Rectangle {
        id: errorBanner

        anchors {
            left: parent.left
            right: parent.right
            top: folderRow.bottom
            leftMargin: 4
            rightMargin: 4
            topMargin: page.error !== "" ? 8 : 0
        }
        height: page.error !== "" ? errorRow.implicitHeight + 14 : 0
        visible: height > 0
        clip: true
        radius: 10
        color: Colors.alpha(Colors.error, 0.1)
        border.width: 1
        border.color: Colors.alpha(Colors.error, 0.35)

        Behavior on height {
            NumberAnimation { duration: Appearance.fadeDuration; easing.type: Easing.OutCubic }
        }

        RowLayout {
            id: errorRow

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                leftMargin: 10
                rightMargin: 6
                topMargin: 7
            }
            spacing: 8

            Text {
                text: "error"
                color: Colors.error
                font.family: "Material Symbols Outlined"
                font.pixelSize: 15
            }

            Text {
                Layout.fillWidth: true
                font.family: Config.font
                text: page.error
                color: Colors.error
                font.pixelSize: 10
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
            }

            Rectangle {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                radius: 11
                color: dismissHover.hovered ? Colors.alpha(Colors.fgSurface, 0.12) : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "close"
                    color: Colors.fgSurfaceVariant
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 14
                }

                HoverHandler {
                    id: dismissHover

                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: page.dismissedError = WallManager.lastError
                }
            }
        }
    }

    // ================= Raster =================
    GridView {
        id: grid

        readonly property int columns: 3
        readonly property real tileWidth: grid.cellWidth - 8
        readonly property real tileHeight: Math.round(grid.tileWidth * 9 / 16)

        anchors {
            left: parent.left
            right: details.left
            top: errorBanner.bottom
            bottom: parent.bottom
            topMargin: 10
            rightMargin: 10
        }
        clip: true
        cellWidth: Math.floor(width / grid.columns)
        cellHeight: grid.tileHeight + 26
        boundsBehavior: Flickable.StopAtBounds
        // Mausrad statt Ziehen (wie die Zeilenliste)
        interactive: false
        cacheBuffer: grid.cellHeight * 2

        model: ScriptModel {
            values: page.images
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

            onWheel: event => {
                const angle = event.angleDelta.y + event.angleDelta.x;
                const pixels = event.pixelDelta.y + event.pixelDelta.x;
                const delta = angle !== 0 ? angle / 120 : pixels / 40;
                const max = Math.max(0, grid.contentHeight - grid.height);
                grid.contentY = Math.max(0, Math.min(max, grid.contentY - delta * 60));
                event.accepted = true;
            }
        }

        // Klick auf leere Flaeche: Bild abwaehlen (zeigt Ordner / Uebersicht).
        // Der Handler sieht auch Klicks auf Kacheln (beide Handler greifen
        // passiv) – die ueberlaesst er dem Kachel-Handler.
        TapHandler {
            onTapped: point => {
                if (grid.indexAt(point.position.x + grid.contentX, point.position.y + grid.contentY) >= 0)
                    return;
                page.selected = "";
                page.closeInline();
            }
        }

        delegate: Item {
            id: tile

            required property var modelData

            readonly property bool chosen: tile.modelData.path === page.selected
            readonly property bool isCurrent: tile.modelData.path === Wallpapers.actualCurrent

            width: grid.cellWidth
            height: grid.cellHeight

            Thumb {
                id: frame

                anchors {
                    top: parent.top
                    horizontalCenter: parent.horizontalCenter
                    topMargin: 4
                }
                width: grid.tileWidth
                height: grid.tileHeight
                name: tile.modelData.name
                border.width: tile.chosen ? 2 : tileHover.hovered ? 1 : 0
                border.color: tile.chosen ? Colors.primary : Colors.alpha(Colors.fgSurface, 0.35)

                Behavior on border.color {
                    ColorAnimation { duration: Appearance.fadeDuration }
                }

                // Das gesetzte Bild
                Rectangle {
                    anchors {
                        right: parent.right
                        top: parent.top
                        margins: 5
                    }
                    visible: tile.isCurrent
                    width: 18
                    height: 18
                    radius: 9
                    color: Colors.primary

                    Text {
                        anchors.centerIn: parent
                        text: "check"
                        color: Colors.fgPrimary
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 13
                        font.weight: Font.Bold
                    }
                }
            }

            Text {
                anchors {
                    top: frame.bottom
                    topMargin: 4
                    left: frame.left
                    right: frame.right
                }
                font.family: Config.font
                text: page.folder === "" ? tile.modelData.name : page.fileName(tile.modelData.name)
                color: tile.chosen ? Colors.fgBackground : Colors.fgSurfaceVariant
                font.pixelSize: 10
                font.weight: tile.chosen ? Font.DemiBold : Font.Normal
                elide: Text.ElideMiddle
                horizontalAlignment: Text.AlignHCenter
            }

            HoverHandler {
                id: tileHover

                cursorShape: Qt.PointingHandCursor
            }

            // Klick waehlt (auch der erste des Doppelklicks), Doppelklick setzt
            TapHandler {
                onTapped: page.pickImage(tile.modelData.path)
                onDoubleTapped: Wallpapers.set(tile.modelData.path)
            }
        }

        // Weiche Kante unten, solange noch Reihen folgen
        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            height: 24
            visible: grid.contentHeight - grid.contentY - grid.height > 2
            gradient: Gradient {
                GradientStop { position: 0; color: Colors.alpha(Colors.background, 0) }
                GradientStop { position: 1; color: Colors.background }
            }
        }

        // Leer: nichts gefunden / Ordner leer / noch nicht geladen
        Column {
            anchors.centerIn: parent
            width: parent.width - 40
            visible: grid.count === 0
            spacing: 6

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Wallpapers.loading && page.total === 0 ? "hourglass_empty"
                    : page.filter.trim() !== "" ? "search_off"
                    : "folder_off"
                color: Colors.alpha(Colors.fgSurfaceVariant, 0.6)
                font.family: "Material Symbols Outlined"
                font.pixelSize: 28
            }

            Text {
                width: parent.width
                font.family: Config.font
                text: Wallpapers.loading && page.total === 0 ? "Bilder werden gesucht…"
                    : page.filter.trim() !== "" ? "Nichts gefunden"
                    : page.folder !== "" ? "Ordner ist leer"
                    : "Keine Wallpaper gefunden"
                color: Colors.fgSurfaceVariant
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            Text {
                width: parent.width
                visible: !Wallpapers.loading && page.filter.trim() === ""
                font.family: Config.font
                text: page.folder !== "" ? "Bilder aus anderen Ordnern hierher verschieben: Bild wählen, „Verschieben“"
                    : "Bilder nach " + Wallpapers.wallsDir.replace(Quickshell.env("HOME"), "~") + " legen"
                color: Colors.alpha(Colors.fgSurfaceVariant, 0.7)
                font.pixelSize: 10
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
        }
    }

    // ================= Details rechts =================
    Rectangle {
        id: details

        anchors {
            right: parent.right
            top: errorBanner.bottom
            bottom: parent.bottom
            topMargin: 10
        }
        width: 216
        radius: 14
        color: Colors.alpha(Colors.fgSurface, 0.045)
        border.width: 1
        border.color: Colors.alpha(Colors.outline, 0.18)
        clip: true

        Flickable {
            id: detailFlick

            anchors.fill: parent
            anchors.margins: 1
            clip: true
            contentHeight: detailColumn.implicitHeight + 24
            boundsBehavior: Flickable.StopAtBounds
            interactive: false

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

                onWheel: event => {
                    const angle = event.angleDelta.y + event.angleDelta.x;
                    const pixels = event.pixelDelta.y + event.pixelDelta.x;
                    const delta = angle !== 0 ? angle / 120 : pixels / 40;
                    const max = Math.max(0, detailFlick.contentHeight - detailFlick.height);
                    detailFlick.contentY = Math.max(0, Math.min(max, detailFlick.contentY - delta * 60));
                    event.accepted = true;
                }
            }

            Column {
                id: detailColumn

                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 11
                }
                spacing: 10

                // ---------- Bild ----------
                Thumb {
                    visible: page.mode === "bild"
                    width: parent.width
                    height: Math.round(width * 9 / 16)
                    name: page.selectedInfo?.name ?? ""
                    cornerRadius: 10
                }

                Column {
                    visible: page.mode === "bild"
                    width: parent.width
                    spacing: 2

                    Text {
                        width: parent.width
                        font.family: Config.font
                        text: page.fileName(page.selectedInfo?.name ?? "")
                        color: Colors.fgBackground
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        elide: Text.ElideMiddle
                    }

                    Row {
                        spacing: 4

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "folder"
                            color: Colors.fgSurfaceVariant
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 12
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            font.family: Config.font
                            text: page.selectedFolder === "" ? "Oberste Ebene" : page.selectedFolder
                            color: Colors.fgSurfaceVariant
                            font.pixelSize: 10
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: page.selectedIsCurrent
                            width: currentLabel.implicitWidth + 12
                            height: 16
                            radius: 8
                            color: Colors.alpha(Colors.primary, 0.16)

                            Text {
                                id: currentLabel

                                anchors.centerIn: parent
                                font.family: Config.font
                                text: "Aktuell"
                                color: Colors.primary
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                            }
                        }
                    }
                }

                Flow {
                    visible: page.mode === "bild"
                    width: parent.width
                    spacing: 6

                    ActionButton {
                        filled: true
                        enabled: !page.selectedIsCurrent
                        icon: "wallpaper"
                        label: page.selectedIsCurrent ? "Gesetzt" : "Setzen"
                        onClicked: Wallpapers.set(page.selected)
                    }

                    ActionButton {
                        enabled: !page.busy
                        filled: page.moveOpen
                        icon: page.moveOpen ? "expand_less" : "drive_file_move"
                        label: "Verschieben"
                        onClicked: {
                            const open = !page.moveOpen;
                            page.closeInline();
                            page.moveOpen = open;
                        }
                    }

                    // Zweistufig: erst "Papierkorb", dann 3 s lang "Wirklich?"
                    ActionButton {
                        enabled: !page.busy
                        icon: page.trashArmed ? "check" : "delete"
                        label: page.trashArmed ? "Wirklich?" : "Papierkorb"
                        tint: page.trashArmed ? Colors.error : Colors.fgSurface
                        onClicked: {
                            if (page.trashArmed) {
                                page.trashArmed = false;
                                WallManager.trash(page.selected);
                            } else {
                                page.closeInline();
                                page.trashArmed = true;
                                disarmTrash.restart();
                            }
                        }
                    }
                }

                // Ziel-Ordner zum Verschieben
                Rectangle {
                    visible: page.mode === "bild" && page.moveOpen
                    width: parent.width
                    implicitHeight: moveColumn.implicitHeight + 12
                    radius: 10
                    color: Colors.alpha(Colors.fgSurface, 0.05)
                    border.width: 1
                    border.color: Colors.alpha(Colors.primary, 0.3)

                    Column {
                        id: moveColumn

                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            margins: 6
                        }
                        spacing: 1

                        SectionLabel {
                            leftPadding: 6
                            bottomPadding: 3
                            text: "VERSCHIEBEN NACH"
                        }

                        Repeater {
                            model: [""].concat(WallManager.folders).filter(f => f !== page.selectedFolder)

                            Rectangle {
                                id: target

                                required property string modelData

                                width: parent.width
                                height: 26
                                radius: 8
                                color: targetHover.hovered ? Colors.alpha(Colors.fgSurface, 0.1) : "transparent"

                                Behavior on color {
                                    ColorAnimation { duration: Appearance.fadeDuration }
                                }

                                Text {
                                    id: targetIcon

                                    anchors {
                                        left: parent.left
                                        leftMargin: 6
                                        verticalCenter: parent.verticalCenter
                                    }
                                    text: target.modelData === "" ? "home" : "folder"
                                    color: Colors.fgSurfaceVariant
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 14
                                }

                                Text {
                                    anchors {
                                        left: targetIcon.right
                                        right: parent.right
                                        leftMargin: 7
                                        rightMargin: 6
                                        verticalCenter: parent.verticalCenter
                                    }
                                    font.family: Config.font
                                    text: target.modelData === "" ? "Oberste Ebene" : target.modelData
                                    color: Colors.fgSurface
                                    font.pixelSize: 11
                                    elide: Text.ElideMiddle
                                }

                                HoverHandler {
                                    id: targetHover

                                    cursorShape: Qt.PointingHandCursor
                                }

                                TapHandler {
                                    onTapped: {
                                        page.moveOpen = false;
                                        WallManager.move(page.selected, target.modelData);
                                    }
                                }
                            }
                        }

                        Text {
                            visible: WallManager.folders.length === 0
                            leftPadding: 6
                            font.family: Config.font
                            text: "Noch keine Ordner – oben „Ordner“ anlegen"
                            color: Colors.fgSurfaceVariant
                            font.pixelSize: 10
                        }
                    }
                }

                // Stil (Material-Variante) fuer dieses Bild
                Column {
                    visible: page.mode === "bild"
                    width: parent.width
                    spacing: 6

                    SectionLabel {
                        text: "STIL"
                    }

                    Hint {
                        visible: !page.dynamicScheme
                        width: parent.width
                        text: `Wirkt nur beim dynamischen Schema – gerade ist „${Themes.currentName}“ gewählt.`
                    }

                    Flow {
                        width: parent.width
                        spacing: 4
                        opacity: page.dynamicScheme ? 1 : 0.45

                        Repeater {
                            model: page.styles

                            Chip {
                                required property var modelData

                                readonly property string pinned: Wallpapers.variantFor(page.selected) || "auto"

                                compact: true
                                label: modelData.name
                                icon: modelData.icon
                                current: pinned === modelData.name
                                onClicked: Wallpapers.setVariant(page.selected, modelData.name)
                            }
                        }
                    }
                }

                // Terminal-Look fuer dieses Bild
                Column {
                    visible: page.mode === "bild"
                    width: parent.width
                    spacing: 6

                    SectionLabel {
                        text: "TERMINAL-LOOK"
                    }

                    Hint {
                        visible: !page.terminalOn
                        width: parent.width
                        icon: "extension_off"
                        text: "Das Plugin „Terminal-Looks“ ist aus."
                    }

                    Hint {
                        visible: page.terminalOn && !page.lookTheme
                        width: parent.width
                        icon: "block"
                        text: "„An Theme anpassen“ ist in Terminal-Looks aus – das Terminal zeigt immer Vocaloid."
                    }

                    Hint {
                        visible: page.terminalOn && page.lookTheme && !page.lookFolders
                        width: parent.width
                        icon: "block"
                        text: "Ordner-Looks sind in Terminal-Looks ausgeschaltet – Zuordnungen gelten nicht."
                    }

                    Hint {
                        visible: page.terminalOn && page.lookTheme && page.lookFolders && page.hasSelection
                        width: parent.width
                        icon: "terminal"
                        text: `Gilt: ${page.lookTitle(WallManager.lookFor(page.selected).id)} (${page.sourceLabel(WallManager.lookFor(page.selected).source)})`
                    }

                    Loader {
                        active: page.terminalOn && page.hasSelection
                        visible: active
                        width: parent.width

                        sourceComponent: LookPicker {
                            key: WallManager.keyFor(page.selected)
                            fallback: WallManager.folderLookFor(page.selectedFolder)
                        }
                    }
                }

                // ---------- Ordner ----------
                Row {
                    visible: page.mode === "ordner"
                    width: parent.width
                    spacing: 10

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 40
                        radius: 13
                        color: Colors.alpha(Colors.primary, 0.16)

                        Text {
                            anchors.centerIn: parent
                            text: "folder_open"
                            color: Colors.primary
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 22
                            font.variableAxes: ({ FILL: 1 })
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 50
                        spacing: 2

                        Text {
                            width: parent.width
                            font.family: Config.font
                            text: page.folderName(page.folder)
                            color: Colors.fgBackground
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            elide: Text.ElideMiddle
                        }

                        Text {
                            width: parent.width
                            font.family: Config.font
                            text: page.plural(page.countIn(page.folder), "Bild", "Bilder")
                                  + (page.folder.includes("/") ? " · in " + page.folder.slice(0, page.folder.lastIndexOf("/")) : "")
                            color: Colors.fgSurfaceVariant
                            font.pixelSize: 10
                            elide: Text.ElideRight
                        }
                    }
                }

                Flow {
                    visible: page.mode === "ordner" && !page.renameOpen
                    width: parent.width
                    spacing: 6

                    ActionButton {
                        enabled: !page.busy
                        icon: "edit"
                        label: "Umbenennen"
                        onClicked: {
                            page.closeInline();
                            page.renameOpen = true;
                        }
                    }

                    ActionButton {
                        icon: "folder_open"
                        label: "Im Dateimanager"
                        onClicked: {
                            Quickshell.execDetached(["xdg-open", Wallpapers.wallsDir + "/" + page.folder]);
                            // Das Fenster laege sonst ueber dem Dateimanager
                            SettingsState.close();
                        }
                    }
                }

                Loader {
                    active: page.mode === "ordner" && page.renameOpen
                    visible: active
                    width: parent.width

                    sourceComponent: InlineField {
                        placeholder: "Neuer Name…"
                        text: page.folder
                        onAccepted: value => {
                            page.renameOpen = false;
                            if (value !== page.folder)
                                WallManager.renameFolder(page.folder, value);
                        }
                        onCancelled: page.renameOpen = false
                    }
                }

                Hint {
                    visible: page.mode === "ordner"
                    width: parent.width
                    icon: "info"
                    text: "Bilder in diesem Ordner anklicken, um sie zu setzen oder zu verschieben."
                }

                // Terminal-Look des Ordners
                Column {
                    visible: page.mode === "ordner"
                    width: parent.width
                    spacing: 6

                    SectionLabel {
                        text: "ORDNER-LOOK"
                    }

                    Hint {
                        visible: !page.terminalOn
                        width: parent.width
                        icon: "extension_off"
                        text: "Das Plugin „Terminal-Looks“ ist aus."
                    }

                    Hint {
                        visible: page.terminalOn && !page.lookTheme
                        width: parent.width
                        icon: "block"
                        text: "„An Theme anpassen“ ist in Terminal-Looks aus – das Terminal zeigt immer Vocaloid."
                    }

                    Hint {
                        visible: page.terminalOn && page.lookTheme && !page.lookFolders
                        width: parent.width
                        icon: "block"
                        text: "Ordner-Looks sind in Terminal-Looks ausgeschaltet – Zuordnungen gelten nicht."
                    }

                    Hint {
                        visible: page.terminalOn && page.lookTheme && page.lookFolders
                        width: parent.width
                        icon: "terminal"
                        text: "Gilt für alle Bilder des Ordners ohne eigenen Look."
                    }

                    Loader {
                        active: page.terminalOn && page.mode === "ordner"
                        visible: active
                        width: parent.width

                        sourceComponent: LookPicker {
                            key: WallManager.folderKey(page.folder)
                            // Ohne eigene Zuordnung: Ordnername oder Schema
                            fallback: {
                                const named = WallManager.conventionLook(page.folder);
                                return named !== "" ? { id: named, source: "name" } : { id: "scheme", source: "schema" };
                            }
                        }
                    }
                }

                // ---------- Uebersicht ----------
                Column {
                    visible: page.mode === "uebersicht"
                    width: parent.width
                    spacing: 10

                    Row {
                        spacing: 10

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 40
                            height: 40
                            radius: 13
                            color: Colors.alpha(Colors.primary, 0.16)

                            Text {
                                anchors.centerIn: parent
                                text: "photo_library"
                                color: Colors.primary
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 22
                                font.variableAxes: ({ FILL: 1 })
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Text {
                                font.family: Config.font
                                text: "Bibliothek"
                                color: Colors.fgBackground
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }

                            Text {
                                font.family: Config.font
                                text: page.plural(page.total, "Bild", "Bilder") + " · " + page.plural(WallManager.folders.length, "Ordner", "Ordner")
                                color: Colors.fgSurfaceVariant
                                font.pixelSize: 10
                            }
                        }
                    }

                    Hint {
                        width: parent.width
                        icon: "touch_app"
                        text: "Bild anklicken für Details, Doppelklick setzt es als Hintergrund."
                    }

                    Hint {
                        width: parent.width
                        icon: "folder"
                        text: "Ein Ordner-Chip oben zeigt dessen Bilder, Umbenennen und Ordner-Look."
                    }

                    Hint {
                        visible: page.terminalOn
                        width: parent.width
                        icon: "terminal"
                        text: "Terminal-Look: fest je Bild, sonst je Ordner, sonst nach Ordnername, sonst Farbschema."
                    }

                    Hint {
                        visible: !page.terminalOn
                        width: parent.width
                        icon: "extension_off"
                        text: "Das Plugin „Terminal-Looks“ ist aus – Looks je Bild und Ordner stehen dann nicht zur Wahl."
                    }

                    ActionButton {
                        icon: "folder_open"
                        label: "Ordner im Dateimanager"
                        onClicked: {
                            Quickshell.execDetached(["xdg-open", Wallpapers.wallsDir]);
                            SettingsState.close();
                        }
                    }
                }

                // Laeuft gerade etwas?
                Row {
                    visible: page.busy
                    spacing: 6

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "progress_activity"
                        color: Colors.primary
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 14

                        // Nur solange etwas laeuft – nicht endlos
                        RotationAnimation on rotation {
                            running: page.busy
                            from: 0
                            to: 360
                            loops: Animation.Infinite
                            duration: Appearance.morphDuration * 3
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        font.family: Config.font
                        text: "Bitte warten…"
                        color: Colors.primary
                        font.pixelSize: 10
                    }
                }
            }
        }

        // Weiche Kante unten, solange noch etwas folgt
        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                margins: 1
            }
            height: 24
            radius: 13
            visible: detailFlick.contentHeight - detailFlick.contentY - detailFlick.height > 2
            gradient: Gradient {
                GradientStop { position: 0; color: Colors.alpha(Colors.background, 0) }
                GradientStop { position: 1; color: Colors.mix(Colors.background, Colors.fgSurface, 0.045) }
            }
        }
    }
}
