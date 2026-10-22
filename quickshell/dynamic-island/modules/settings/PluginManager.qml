pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Qt.labs.folderlistmodel
import qs.modules.services.config
import qs.modules.services.plugins
import qs.modules.widgets

import qs

// Plugin-Verwaltung – die Seite hinter "Plugins verwalten" im Einstellungs-
// Fenster (SettingsCard.qml zeigt sie statt der Zeilenliste).
//
// Oben Importieren und Ordner oeffnen, darunter je Plugin eine Karte:
// Symbol, Name, Version, Autor, Beschreibung, Status, was es mitbringt
// (Einstellungen, Kacheln, Launcher-Aktionen, externe Dateien), ein An/Aus-
// Schalter und die Knoepfe Einstellungen / Exportieren / Zuruecksetzen /
// Entfernen (zweistufig, wie "Alles zuruecksetzen" in der Leiste).
//
// Import und Export laufen ueber die CLI (Plugins.importPlugin/exportPlugin/
// removePlugin); das Ergebnis steht in Plugins.lastResult und erscheint hier
// als Banner, solange es nicht weggeklickt ist.
//
// Kein Dateidialog: das Fenster ist eine Layer-Oberflaeche mit exklusivem
// Tastaturfokus, ein zenity/kdialog-Fenster laege darunter und waere nicht
// bedienbar. Stattdessen listet die Import-Ansicht die .dip-Pakete aus
// ~/Downloads, ~ und ~/Documents (FolderListModel) und hat ein Pfadfeld;
// Exporte landen in ~/Downloads/<id>-<version>.dip.
Item {
    id: page

    // Zur Gruppe eines Plugins springen ("plugin:<id>")
    signal openSection(string section)

    readonly property string home: Quickshell.env("HOME")
    readonly property string exportDir: page.home + "/Downloads"

    property bool importOpen: false
    property string importPath: ""
    property bool importEnable: true
    property bool exportWithSettings: true

    readonly property bool busy: Plugins.busy
    // Ergebnis-Banner: das letzte CLI-Ergebnis, bis es weggeklickt wird
    property var dismissed: null
    readonly property var result: Plugins.lastResult !== null && Plugins.lastResult !== page.dismissed
                                  ? Plugins.lastResult : null

    readonly property int activeCount: Plugins.plugins.filter(p => p.enabled).length

    function openFolder(path: string): void {
        Quickshell.execDetached(["xdg-open", path]);
        // Das Fenster laege sonst ueber dem Dateimanager
        SettingsState.close();
    }

    function exportPlugin(info: var): void {
        Plugins.exportPlugin(info.id, `${page.exportDir}/${info.id}-${info.version}.dip`, page.exportWithSettings);
    }

    function expand(path: string): string {
        let p = path.trim();
        if (p.startsWith("file://"))
            p = p.slice(7);
        if (p === "~" || p.startsWith("~/"))
            p = page.home + p.slice(1);
        return p;
    }

    function runImport(): void {
        const p = page.expand(page.importPath);
        if (p === "" || page.busy)
            return;
        Plugins.importPlugin(p, page.importEnable);
    }

    function statusLabel(s: string): string {
        return ({ ready: "Aktiv", off: "Aus", loading: "Lädt", error: "Fehler", invalid: "Ungültig" })[s] ?? s;
    }

    function statusColor(s: string): color {
        return s === "ready" ? Colors.primary
             : s === "loading" ? Colors.secondary
             : s === "off" ? Colors.fgSurfaceVariant
             : Colors.error;
    }

    function opLabel(op: string): string {
        return ({ "import": "Import", "export": "Export", "remove": "Entfernen" })[op] ?? op;
    }

    function formatSize(bytes: real): string {
        if (bytes >= 1048576)
            return (bytes / 1048576).toFixed(1) + " MB";
        if (bytes >= 1024)
            return Math.round(bytes / 1024) + " KB";
        return bytes + " B";
    }

    function shortPath(p: string): string {
        return p.startsWith(page.home) ? "~" + p.slice(page.home.length) : p;
    }

    // Nach einem geglueckten Import die Import-Ansicht zuklappen; ein neues
    // Ergebnis zeigt sich immer, auch wenn das alte weggeklickt war
    Connections {
        target: Plugins

        function onLastResultChanged(): void {
            page.dismissed = null;
            const r = Plugins.lastResult;
            if (r?.ok && r.op === "import") {
                page.importOpen = false;
                page.importPath = "";
            }
        }
    }

    // ---- .dip-Pakete in den ueblichen Ordnern ----
    component DipFolder: FolderListModel {
        nameFilters: ["*.dip"]
        showDirs: false
        showDotAndDotDot: false
        showOnlyReadable: true
        sortField: FolderListModel.Time
        onCountChanged: page.collectFiles()
        onStatusChanged: if (status === FolderListModel.Ready) page.collectFiles()
    }

    DipFolder { id: dlFolder; folder: "file://" + page.home + "/Downloads" }
    DipFolder { id: homeFolder; folder: "file://" + page.home }
    DipFolder { id: docFolder; folder: "file://" + page.home + "/Documents" }

    // [{ name, path, dir, size, modified }], neueste zuerst
    property var files: []

    function collectFiles(): void {
        const out = [];
        for (const f of [dlFolder, homeFolder, docFolder]) {
            for (let i = 0; i < f.count; i++) {
                const path = f.get(i, "filePath");
                out.push({
                    name: f.get(i, "fileName"),
                    path,
                    dir: page.shortPath(path.slice(0, path.lastIndexOf("/"))) || "/",
                    size: f.get(i, "fileSize"),
                    modified: f.get(i, "fileModified")
                });
            }
        }
        out.sort((a, b) => b.modified - a.modified);
        page.files = out;
    }

    // ---- Bausteine ----

    // Knopf im Chip-Stil (wie "Standard" im Kachel-Editor)
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

    // Schalter wie in SettingsRow
    component Toggle: Rectangle {
        id: sw

        property bool checked: false
        signal toggled()

        width: 40
        height: 22
        radius: height / 2
        opacity: enabled ? 1 : 0.4
        color: sw.checked ? Colors.primary : Colors.alpha(Colors.fgSurface, 0.18)

        Behavior on color {
            ColorAnimation { duration: Appearance.fadeDuration }
        }

        Rectangle {
            width: 16
            height: 16
            radius: 8
            y: 3
            x: sw.checked ? parent.width - width - 3 : 3
            color: sw.checked ? Colors.fgPrimary : Colors.fgSurfaceVariant

            Morph on x {}
        }

        HoverHandler {
            cursorShape: sw.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        }

        TapHandler {
            enabled: sw.enabled
            onTapped: sw.toggled()
        }
    }

    // Kleiner Merkmal-Chip ("2 Einstellungen")
    component FeatureChip: Rectangle {
        id: chip

        required property string icon
        required property string label

        implicitWidth: chipRow.implicitWidth + 16
        implicitHeight: 22
        radius: 11
        color: Colors.alpha(Colors.fgSurface, 0.07)

        Row {
            id: chipRow

            anchors.centerIn: parent
            spacing: 4

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.icon
                color: Colors.fgSurfaceVariant
                font.family: "Material Symbols Outlined"
                font.pixelSize: 13
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                font.family: Config.font
                text: chip.label
                color: Colors.fgSurfaceVariant
                font.pixelSize: 10
            }
        }
    }

    // ---- Die Karte eines Plugins ----
    component PluginCard: Rectangle {
        id: pcard

        required property var info
        readonly property string section: Plugins.sectionPrefix + pcard.info.id
        readonly property bool on: pcard.info.enabled
        readonly property bool hasSettings: pcard.info.hasSettings
        // Irgendein Wert weicht von der Vorgabe ab?
        readonly property bool changed: pcard.hasSettings
            && Object.keys(Plugins.raw[pcard.section] ?? {}).some(k => !Plugins.isDefault(pcard.section, k))
        readonly property color statusTint: page.statusColor(pcard.info.status)

        property bool removeArmed: false

        width: parent.width
        implicitHeight: body.implicitHeight + 28
        radius: 14
        color: Colors.alpha(Colors.fgSurface, cardHover.hovered ? 0.07 : 0.045)
        border.width: 1
        border.color: Colors.alpha(Colors.outline, 0.18)

        Behavior on color {
            ColorAnimation { duration: Appearance.fadeDuration }
        }

        HoverHandler {
            id: cardHover
        }

        Timer {
            id: disarmRemove

            interval: 3000
            onTriggered: pcard.removeArmed = false
        }

        ColumnLayout {
            id: body

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 14
            }
            spacing: 10

            // Kopf: Symbol, Name, Status, Schalter
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    Layout.alignment: Qt.AlignTop
                    radius: 13
                    color: pcard.on ? Colors.alpha(Colors.primary, 0.16) : Colors.alpha(Colors.fgSurface, 0.08)

                    Behavior on color {
                        ColorAnimation { duration: Appearance.fadeDuration }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: pcard.info.icon
                        color: pcard.on ? Colors.primary : Colors.fgSurfaceVariant
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 22
                        font.variableAxes: ({ FILL: pcard.on ? 1 : 0 })

                        Behavior on color {
                            ColorAnimation { duration: Appearance.fadeDuration }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    Row {
                        spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            font.family: Config.font
                            text: pcard.info.name
                            color: Colors.fgBackground
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: pcard.info.status !== "invalid"
                            width: versionLabel.implicitWidth + 12
                            height: 18
                            radius: 9
                            color: Colors.alpha(Colors.fgSurface, 0.08)

                            Text {
                                id: versionLabel

                                anchors.centerIn: parent
                                font.family: Config.font
                                text: "v" + pcard.info.version
                                color: Colors.fgSurfaceVariant
                                font.pixelSize: 10
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            font.family: Config.font
                            visible: pcard.info.author !== ""
                            text: "von " + pcard.info.author
                            color: Colors.fgSurfaceVariant
                            font.pixelSize: 10
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        font.family: Config.font
                        visible: text !== ""
                        text: pcard.info.description
                        color: Colors.fgSurfaceVariant
                        font.pixelSize: 10
                        wrapMode: Text.WordWrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }

                    // Fehlermeldung (Manifest kaputt, Main.qml laedt nicht)
                    RowLayout {
                        Layout.fillWidth: true
                        visible: pcard.info.error !== ""
                        spacing: 5

                        Text {
                            Layout.alignment: Qt.AlignTop
                            text: "error"
                            color: Colors.error
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 13
                        }

                        Text {
                            Layout.fillWidth: true
                            font.family: Config.font
                            text: pcard.info.error
                            color: Colors.error
                            font.pixelSize: 10
                            wrapMode: Text.WordWrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                        }
                    }
                }

                // Status-Badge
                Rectangle {
                    Layout.alignment: Qt.AlignTop
                    Layout.topMargin: 2
                    implicitWidth: statusRow.implicitWidth + 18
                    implicitHeight: 22
                    radius: 11
                    color: Colors.alpha(pcard.statusTint, 0.14)

                    Behavior on color {
                        ColorAnimation { duration: Appearance.fadeDuration }
                    }

                    Row {
                        id: statusRow

                        anchors.centerIn: parent
                        spacing: 6

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 6
                            height: 6
                            radius: 3
                            color: pcard.statusTint
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            font.family: Config.font
                            text: page.statusLabel(pcard.info.status)
                            color: pcard.statusTint
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                        }
                    }
                }

                Toggle {
                    Layout.alignment: Qt.AlignTop
                    Layout.topMargin: 2
                    checked: pcard.on
                    enabled: pcard.info.status !== "invalid" && !page.busy
                    onToggled: Plugins.toggle(pcard.info.id)
                }
            }

            // Was das Plugin mitbringt
            Flow {
                Layout.fillWidth: true
                Layout.leftMargin: 52
                spacing: 6
                visible: pcard.info.status !== "invalid"

                FeatureChip {
                    visible: pcard.info.settingsCount > 0
                    icon: "tune"
                    label: pcard.info.settingsCount === 1 ? "1 Einstellung" : `${pcard.info.settingsCount} Einstellungen`
                }

                FeatureChip {
                    visible: pcard.info.tiles.length > 0
                    icon: "dashboard_customize"
                    label: pcard.info.tiles.length === 1 ? "1 Kachel" : `${pcard.info.tiles.length} Kacheln`
                }

                FeatureChip {
                    visible: pcard.info.actions > 0
                    icon: "bolt"
                    label: pcard.info.actions === 1 ? "1 Launcher-Aktion" : `${pcard.info.actions} Launcher-Aktionen`
                }

                FeatureChip {
                    visible: pcard.info.files > 0
                    icon: "folder_copy"
                    label: pcard.info.files === 1 ? "1 externe Datei" : `${pcard.info.files} externe Dateien`
                }

                FeatureChip {
                    visible: pcard.info.main !== ""
                    icon: "memory"
                    label: "Dienst"
                }
            }

            // Knoepfe
            Flow {
                Layout.fillWidth: true
                Layout.leftMargin: 52
                spacing: 6

                ActionButton {
                    visible: pcard.hasSettings
                    enabled: pcard.on
                    icon: "tune"
                    label: "Einstellungen"
                    onClicked: page.openSection(pcard.section)
                }

                ActionButton {
                    enabled: !page.busy && pcard.info.status !== "invalid"
                    icon: "upload"
                    label: "Exportieren"
                    onClicked: page.exportPlugin(pcard.info)
                }

                ActionButton {
                    visible: pcard.hasSettings
                    enabled: pcard.changed
                    icon: "restart_alt"
                    label: "Zurücksetzen"
                    onClicked: Plugins.resetPlugin(pcard.info.id)
                }

                // Zweistufig, wie "Alles zuruecksetzen": erst "Entfernen",
                // dann 3 s lang "Wirklich?"
                ActionButton {
                    enabled: !page.busy
                    icon: pcard.removeArmed ? "check" : "delete"
                    label: pcard.removeArmed ? "Wirklich entfernen?" : "Entfernen"
                    tint: pcard.removeArmed ? Colors.error : Colors.fgSurface
                    onClicked: {
                        if (pcard.removeArmed) {
                            pcard.removeArmed = false;
                            Plugins.removePlugin(pcard.info.id);
                        } else {
                            pcard.removeArmed = true;
                            disarmRemove.restart();
                        }
                    }
                }
            }
        }
    }

    // ================= Die Seite =================
    Flickable {
        id: flick

        anchors.fill: parent
        clip: true
        contentHeight: column.implicitHeight + 8
        boundsBehavior: Flickable.StopAtBounds
        interactive: false

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

            onWheel: event => {
                const angle = event.angleDelta.y + event.angleDelta.x;
                const pixels = event.pixelDelta.y + event.pixelDelta.x;
                const delta = angle !== 0 ? angle / 120 : pixels / 40;
                const max = Math.max(0, flick.contentHeight - flick.height);
                flick.contentY = Math.max(0, Math.min(max, flick.contentY - delta * 60));
                event.accepted = true;
            }
        }

        Column {
            id: column

            anchors {
                left: parent.left
                right: parent.right
                leftMargin: 2
                rightMargin: 2
            }
            spacing: 8

            // ---- Kopfzeile ----
            Item {
                width: parent.width
                height: 36

                Row {
                    anchors {
                        left: parent.left
                        leftMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 6

                    ActionButton {
                        icon: page.importOpen ? "expand_less" : "download"
                        label: "Importieren"
                        filled: page.importOpen
                        onClicked: page.importOpen = !page.importOpen
                    }

                    ActionButton {
                        icon: "folder_open"
                        label: "Ordner öffnen"
                        onClicked: page.openFolder(Plugins.dir)
                    }
                }

                // Rechts: Zaehler oder "laeuft"
                Row {
                    anchors {
                        right: parent.right
                        rightMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 6

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: page.busy
                        text: "progress_activity"
                        color: Colors.primary
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 15

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
                        text: page.busy ? "Bitte warten…"
                            : Plugins.plugins.length === 0 ? ""
                            : `${Plugins.plugins.length} ${Plugins.plugins.length === 1 ? "Plugin" : "Plugins"} · ${page.activeCount} aktiv`
                        color: page.busy ? Colors.primary : Colors.alpha(Colors.fgSurfaceVariant, 0.8)
                        font.pixelSize: 10
                    }
                }
            }

            // ---- Ergebnis-Banner ----
            Rectangle {
                id: banner

                readonly property bool ok: page.result?.ok === true
                readonly property string path: page.result?.data?.path ?? ""
                readonly property color tint: banner.ok ? Colors.primary : Colors.error

                width: parent.width
                height: page.result ? bannerBody.implicitHeight + 20 : 0
                visible: height > 0
                clip: true
                radius: 12
                color: Colors.alpha(banner.tint, 0.1)
                border.width: 1
                border.color: Colors.alpha(banner.tint, 0.35)

                Behavior on height {
                    NumberAnimation { duration: Appearance.fadeDuration; easing.type: Easing.OutCubic }
                }

                RowLayout {
                    id: bannerBody

                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        leftMargin: 14
                        rightMargin: 8
                        topMargin: 10
                    }
                    spacing: 10

                    Text {
                        Layout.alignment: Qt.AlignTop
                        text: banner.ok ? "check_circle" : "error"
                        color: banner.tint
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 18
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            font.family: Config.font
                            text: page.opLabel(page.result?.op ?? "") + (banner.ok ? " erledigt" : " fehlgeschlagen")
                            color: Colors.fgBackground
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }

                        Text {
                            Layout.fillWidth: true
                            font.family: Config.font
                            visible: text !== ""
                            text: page.result?.message ?? ""
                            color: Colors.fgSurfaceVariant
                            font.pixelSize: 10
                            wrapMode: Text.WordWrap
                            maximumLineCount: 4
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            font.family: Config.font
                            visible: banner.path !== ""
                            text: page.shortPath(banner.path)
                            color: Colors.fgSurface
                            font.pixelSize: 10
                            elide: Text.ElideMiddle
                        }
                    }

                    ActionButton {
                        Layout.alignment: Qt.AlignTop
                        visible: banner.ok && banner.path !== ""
                        icon: "folder_open"
                        label: "Im Ordner zeigen"
                        onClicked: page.openFolder(banner.path.slice(0, banner.path.lastIndexOf("/")))
                    }

                    ActionButton {
                        Layout.alignment: Qt.AlignTop
                        visible: banner.ok && page.result?.op === "import" && (page.result?.data?.id ?? "") !== ""
                                 && Plugins.sections.includes(Plugins.sectionPrefix + page.result.data.id)
                        icon: "tune"
                        label: "Einstellungen"
                        onClicked: page.openSection(Plugins.sectionPrefix + page.result.data.id)
                    }

                    Rectangle {
                        Layout.alignment: Qt.AlignTop
                        width: 26
                        height: 26
                        radius: 13
                        color: dismissHover.hovered ? Colors.alpha(Colors.fgSurface, 0.12) : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "close"
                            color: Colors.fgSurfaceVariant
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 15
                        }

                        HoverHandler {
                            id: dismissHover

                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            onTapped: page.dismissed = Plugins.lastResult
                        }
                    }
                }
            }

            // ---- Import-Ansicht ----
            Rectangle {
                id: importPanel

                width: parent.width
                height: page.importOpen ? importBody.implicitHeight + 28 : 0
                visible: height > 0
                clip: true
                radius: 14
                color: Colors.alpha(Colors.fgSurface, 0.045)
                border.width: 1
                border.color: Colors.alpha(Colors.primary, 0.35)

                Behavior on height {
                    NumberAnimation { duration: Appearance.fadeDuration; easing.type: Easing.OutCubic }
                }

                Column {
                    id: importBody

                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: 14
                    }
                    spacing: 8

                    Text {
                        font.family: Config.font
                        text: "Paket importieren"
                        color: Colors.fgBackground
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }

                    Text {
                        width: parent.width
                        font.family: Config.font
                        text: "Ein .dip-Paket aus Downloads, Home oder Dokumenten wählen – oder unten den Pfad eintragen."
                        color: Colors.fgSurfaceVariant
                        font.pixelSize: 10
                        wrapMode: Text.WordWrap
                    }

                    // Gefundene Pakete
                    Column {
                        width: parent.width
                        spacing: 2

                        Repeater {
                            model: page.files

                            Rectangle {
                                id: fileRow

                                required property var modelData
                                readonly property bool selected: page.expand(page.importPath) === fileRow.modelData.path

                                width: parent.width
                                height: 34
                                radius: 10
                                color: fileRow.selected ? Colors.alpha(Colors.primary, 0.16)
                                     : fileHover.hovered ? Colors.alpha(Colors.fgSurface, 0.07)
                                     : "transparent"

                                Behavior on color {
                                    ColorAnimation { duration: Appearance.fadeDuration }
                                }

                                Text {
                                    id: fileIcon

                                    anchors {
                                        left: parent.left
                                        leftMargin: 10
                                        verticalCenter: parent.verticalCenter
                                    }
                                    text: "package_2"
                                    color: fileRow.selected ? Colors.primary : Colors.fgSurfaceVariant
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 17
                                }

                                Text {
                                    id: fileName

                                    font.family: Config.font
                                    anchors {
                                        left: fileIcon.right
                                        leftMargin: 10
                                        verticalCenter: parent.verticalCenter
                                    }
                                    text: fileRow.modelData.name
                                    color: Colors.fgBackground
                                    font.pixelSize: 11
                                    font.weight: fileRow.selected ? Font.DemiBold : Font.Normal
                                }

                                Text {
                                    font.family: Config.font
                                    anchors {
                                        left: fileName.right
                                        leftMargin: 8
                                        right: fileSize.left
                                        rightMargin: 8
                                        verticalCenter: parent.verticalCenter
                                    }
                                    text: fileRow.modelData.dir
                                    color: Colors.fgSurfaceVariant
                                    font.pixelSize: 10
                                    elide: Text.ElideMiddle
                                }

                                Text {
                                    id: fileSize

                                    font.family: Config.font
                                    anchors {
                                        right: parent.right
                                        rightMargin: 12
                                        verticalCenter: parent.verticalCenter
                                    }
                                    text: page.formatSize(fileRow.modelData.size)
                                    color: Colors.fgSurfaceVariant
                                    font.pixelSize: 10
                                }

                                HoverHandler {
                                    id: fileHover

                                    cursorShape: Qt.PointingHandCursor
                                }

                                TapHandler {
                                    onTapped: page.importPath = page.shortPath(fileRow.modelData.path)
                                }
                            }
                        }

                        Row {
                            visible: page.files.length === 0
                            height: 30
                            spacing: 6
                            leftPadding: 10

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "search_off"
                                color: Colors.alpha(Colors.fgSurfaceVariant, 0.7)
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 15
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                font.family: Config.font
                                text: "Keine .dip-Pakete in ~/Downloads, ~ oder ~/Documents"
                                color: Colors.alpha(Colors.fgSurfaceVariant, 0.8)
                                font.pixelSize: 10
                            }
                        }
                    }

                    // Pfadfeld
                    Rectangle {
                        width: parent.width
                        height: 32
                        radius: 10
                        color: Colors.alpha(Colors.fgSurface, pathInput.activeFocus ? 0.09 : 0.06)
                        border.width: 1
                        border.color: pathInput.activeFocus ? Colors.alpha(Colors.primary, 0.5) : "transparent"

                        Behavior on color {
                            ColorAnimation { duration: Appearance.fadeDuration }
                        }
                        Behavior on border.color {
                            ColorAnimation { duration: Appearance.fadeDuration }
                        }

                        Text {
                            id: pathIcon

                            anchors {
                                left: parent.left
                                leftMargin: 10
                                verticalCenter: parent.verticalCenter
                            }
                            text: "draft"
                            color: Colors.fgSurfaceVariant
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 15
                        }

                        TextInput {
                            id: pathInput

                            anchors {
                                left: pathIcon.right
                                leftMargin: 8
                                right: parent.right
                                rightMargin: 10
                                verticalCenter: parent.verticalCenter
                            }
                            font.family: Config.font
                            font.pixelSize: 11
                            color: Colors.fgSurface
                            selectionColor: Colors.alpha(Colors.primary, 0.35)
                            clip: true
                            text: page.importPath
                            onTextEdited: page.importPath = text
                            onAccepted: page.runImport()

                            Text {
                                anchors.fill: parent
                                visible: pathInput.text === ""
                                text: "~/Downloads/mein-plugin-1.0.0.dip"
                                color: Colors.alpha(Colors.fgSurfaceVariant, 0.6)
                                font: pathInput.font
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: 30

                        Row {
                            anchors {
                                left: parent.left
                                leftMargin: 4
                                verticalCenter: parent.verticalCenter
                            }
                            spacing: 8

                            Toggle {
                                anchors.verticalCenter: parent.verticalCenter
                                checked: page.importEnable
                                onToggled: page.importEnable = !page.importEnable
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                font.family: Config.font
                                text: "Nach dem Import einschalten"
                                color: Colors.fgSurface
                                font.pixelSize: 11
                            }
                        }

                        ActionButton {
                            anchors {
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                            }
                            filled: true
                            enabled: page.importPath.trim() !== "" && !page.busy
                            icon: "download"
                            label: "Importieren"
                            onClicked: page.runImport()
                        }
                    }
                }
            }

            // ---- Die Plugins ----
            Repeater {
                model: Plugins.plugins

                PluginCard {
                    required property var modelData

                    info: modelData
                }
            }

            // Kein Plugin da
            Item {
                width: parent.width
                height: 160
                visible: Plugins.plugins.length === 0

                Column {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "extension_off"
                        color: Colors.alpha(Colors.fgSurfaceVariant, 0.6)
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 28
                    }

                    Text {
                        font.family: Config.font
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Keine Plugins gefunden"
                        color: Colors.fgSurfaceVariant
                        font.pixelSize: 12
                    }

                    Text {
                        font.family: Config.font
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Ein Paket importieren oder einen Ordner nach " + page.shortPath(Plugins.dir) + " legen"
                        color: Colors.alpha(Colors.fgSurfaceVariant, 0.7)
                        font.pixelSize: 10
                    }
                }
            }

            // ---- Fuss: wohin Exporte gehen ----
            Item {
                width: parent.width
                height: 30
                visible: Plugins.plugins.length > 0

                Text {
                    anchors {
                        left: parent.left
                        leftMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    font.family: Config.font
                    text: "Exporte landen in " + page.shortPath(page.exportDir) + "/<id>-<version>.dip"
                    color: Colors.alpha(Colors.fgSurfaceVariant, 0.8)
                    font.pixelSize: 10
                }

                Row {
                    anchors {
                        right: parent.right
                        rightMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        font.family: Config.font
                        text: "Einstellungswerte mitnehmen"
                        color: Colors.fgSurfaceVariant
                        font.pixelSize: 10
                    }

                    Toggle {
                        anchors.verticalCenter: parent.verticalCenter
                        checked: page.exportWithSettings
                        onToggled: page.exportWithSettings = !page.exportWithSettings
                    }
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
        }
        height: 24
        visible: flick.contentHeight - flick.contentY - flick.height > 2
        gradient: Gradient {
            GradientStop { position: 0; color: Colors.alpha(Colors.background, 0) }
            GradientStop { position: 1; color: Colors.background }
        }
    }
}
