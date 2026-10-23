pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.modules.services.config
import qs.modules.services.plugins
import qs.modules.services.wallpaper
import qs.modules.widgets

import qs

// Die Karte des Einstellungs-Fensters – SettingsWindow.qml haengt sie in eine
// Layer-Oberflaeche. Als eigenes Item, damit sie sich auch ohne Fenster
// bauen laesst (Vorschau-Screenshots, Tests).
//
// Links eine Gruppenleiste (Leiste, Notch-Layout, Darstellung, …), rechts
// die Zeilen der gewaehlten Gruppe. Die Liste baut sich aus
// ~/.config/dynamic-island/shell.json: jeder Abschnitt wird eine Gruppe,
// jeder Schluessel eine Zeile. Neue Schluessel im Adapter
// (services/config/Config.qml) tauchen hier von selbst auf – Namen,
// Beschreibungen und Bedienelemente kommen aus Config.meta, fehlt ein
// Eintrag, steht der Schluessel selbst da.
//
// Unter einem Trenner "Plugins" folgen die Plugin-Verwaltung (eine eigene
// Seite statt der Zeilenliste, PluginManager.qml) und je aktives Plugin mit
// Einstellungen eine Gruppe "plugin:<id>". Gelesen und geschrieben wird
// ueber die Plugins-Bruecke (Plugins.get/set/...), die normale Gruppen an
// Config weiterreicht – fuer die Zeilen sind beide gleich.
//
// Die Suche geht ueber alle Gruppen, die Gruppenleiste ist dann aus.
Surface {
    id: card

    // Suchtext; leert sich beim Oeffnen
    property string filter: ""
    // Gewaehlte Gruppe in der Leiste; "" = alle, managerKey = Plugin-Verwaltung
    property string section: Config.sectionOrder[0] ?? ""
    readonly property bool searching: card.filter.trim() !== ""
    // Sichtbar? Steuert das Heranwachsen beim Oeffnen
    property bool shown: true

    readonly property string managerKey: "@plugins"
    readonly property bool managing: !card.searching && card.section === card.managerKey
    // Wallpaper-Bibliothek (WallpaperManager.qml) – dort filtert die Suche
    // die Bilder statt die Einstellungen, die Seite bleibt also stehen
    readonly property string wallsKey: "@wallpapers"
    readonly property bool browsing: card.section === card.wallsKey

    // Gruppen aus shell.json in Menue-Reihenfolge, unbekannte hinten dran
    readonly property var sections: {
        const raw = Config.raw;
        const isGroup = s => typeof raw[s] === "object" && raw[s] !== null;
        const known = Config.sectionOrder.filter(isGroup);
        const extra = Object.keys(raw).filter(s => !known.includes(s) && isGroup(s));
        return known.concat(extra);
    }
    // Dahinter die Gruppen der aktiven Plugins
    readonly property var allSections: card.sections.concat(Plugins.sections)

    // Die gewaehlte Plugin-Gruppe verschwindet (Plugin aus oder entfernt):
    // zur Verwaltung. Nur, wenn sie vorher da war – beim Einlesen der
    // Plugins (die Hosts entstehen einzeln) fehlt sie sonst nur kurz.
    property bool sectionSeen: false

    onSectionChanged: card.sectionSeen = card.allSections.includes(card.section)
    onAllSectionsChanged: {
        if (card.allSections.includes(card.section)) {
            card.sectionSeen = true;
            return;
        }
        if (card.sectionSeen && Plugins.isPluginSection(card.section))
            card.section = card.managerKey;
    }

    function sectionTitle(s: string): string {
        if (s === card.managerKey)
            return "Plugins";
        if (s === card.wallsKey)
            return I18n.tr("Bibliothek");
        if (Plugins.isPluginSection(s))
            return I18n.tr(Plugins.sectionTitle(s));
        return I18n.tr(Config.sectionMeta[s] ?? s);
    }

    function valuesOf(s: string): var {
        return Plugins.isPluginSection(s) ? Plugins.raw[s] : Config.raw[s];
    }

    // Anzahl Zeilen je Gruppe (fuer die Leiste)
    function countIn(s: string): int {
        const values = card.valuesOf(s);
        return typeof values === "object" && values !== null ? Object.keys(values).length : 0;
    }

    function select(s: string): void {
        card.section = s;
        if (card.searching) {
            search.text = "";
            card.filter = "";
        }
        list.contentY = 0;
    }

    // Beim Oeffnen: Suche leeren, Suchfeld fokussieren
    function reset(): void {
        card.filter = "";
        search.text = "";
        search.forceActiveFocus();
    }

    maxRadius: 24

    // Kommt beim Oeffnen leicht herangewachsen
    scale: card.shown ? 1 : 0.96
    opacity: card.shown ? 1 : 0
    Morph on scale {}
    Fade on opacity {}

    // Escape schliesst – auch, wenn das Suchfeld den Fokus verloren hat
    Keys.onEscapePressed: SettingsState.close()

    // Zaehler der Bibliothek in der Leiste (die Liste ist sonst erst da,
    // wenn die Auswahl oder die Bibliothek einmal offen war)
    Component.onCompleted: Wallpapers.ensureLoaded()

    // ================= Linke Leiste =================
    Item {
        id: sidebar

        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
        }
        width: 236

        Rectangle {
            anchors.fill: parent
            topLeftRadius: card.radius
            bottomLeftRadius: card.radius
            color: Colors.alpha(Colors.fgSurface, 0.035)
        }

        // Trennlinie
        Rectangle {
            anchors {
                right: parent.right
                top: parent.top
                bottom: parent.bottom
            }
            width: 1
            color: Colors.alpha(Colors.outline, 0.25)
        }

        Text {
            id: title
            font.family: Config.font

            anchors {
                left: parent.left
                leftMargin: 22
                top: parent.top
                topMargin: 24
            }
            text: I18n.tr("Einstellungen")
            color: Colors.fgBackground
            font.pixelSize: 17
            font.weight: Font.DemiBold
        }

        Text {
            font.family: Config.font
            anchors {
                left: title.left
                top: title.bottom
                topMargin: 2
            }
            text: Colors.name
            color: Colors.alpha(Colors.fgSurfaceVariant, 0.8)
            font.pixelSize: 10
        }

        // Die Gruppen – scrollbar, falls viele Plugins ihre eigene haben
        Flickable {
            id: sidebarFlick

            anchors {
                left: parent.left
                right: parent.right
                top: title.bottom
                bottom: footer.top
                topMargin: 30
                bottomMargin: 6
            }
            clip: true
            contentHeight: sidebarColumn.implicitHeight + 8
            boundsBehavior: Flickable.StopAtBounds
            interactive: false

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

                onWheel: event => {
                    const delta = event.angleDelta.y !== 0 ? event.angleDelta.y / 120 : event.pixelDelta.y / 40;
                    const max = Math.max(0, sidebarFlick.contentHeight - sidebarFlick.height);
                    sidebarFlick.contentY = Math.max(0, Math.min(max, sidebarFlick.contentY - delta * 40));
                    event.accepted = true;
                }
            }

            Column {
                id: sidebarColumn

                anchors {
                    left: parent.left
                    right: parent.right
                    leftMargin: 12
                    rightMargin: 12
                }
                topPadding: 4
                spacing: 2

                component SectionButton: Rectangle {
                    id: button

                    required property string key
                    required property string label
                    required property string icon
                    property int count: 0
                    // Plugin-Gruppe: etwas kleiner und eingerueckt, unter der Verwaltung
                    property bool sub: false

                    // In der Bibliothek sucht man Bilder – die Leiste bleibt scharf
                    readonly property bool current: (!card.searching || card.browsing) && card.section === button.key

                    width: parent.width
                    height: button.sub ? 32 : 38
                    radius: 12
                    color: button.current ? Colors.alpha(Colors.primary, 0.16)
                         : buttonHover.hovered ? Colors.alpha(Colors.fgSurface, 0.07)
                         : "transparent"
                    opacity: card.searching && !card.browsing ? 0.5 : 1

                    Behavior on color {
                        ColorAnimation { duration: Appearance.fadeDuration }
                    }
                    Fade on opacity {}

                    Text {
                        id: buttonIcon

                        anchors {
                            left: parent.left
                            leftMargin: button.sub ? 22 : 12
                            verticalCenter: parent.verticalCenter
                        }
                        text: button.icon
                        color: button.current ? Colors.primary : Colors.fgSurfaceVariant
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: button.sub ? 15 : 17
                        font.variableAxes: ({ FILL: button.current ? 1 : 0 })

                        Behavior on color {
                            ColorAnimation { duration: Appearance.fadeDuration }
                        }
                    }

                    Text {
                        font.family: Config.font
                        anchors {
                            left: buttonIcon.right
                            leftMargin: 10
                            right: countLabel.left
                            rightMargin: 6
                            verticalCenter: parent.verticalCenter
                        }
                        text: button.label
                        color: button.current ? Colors.fgBackground : Colors.fgSurface
                        font.pixelSize: button.sub ? 11 : 12
                        font.weight: button.current ? Font.DemiBold : Font.Normal
                        elide: Text.ElideRight
                    }

                    Text {
                        id: countLabel

                        font.family: Config.font
                        anchors {
                            right: parent.right
                            rightMargin: 12
                            verticalCenter: parent.verticalCenter
                        }
                        visible: button.count > 0
                        text: button.count
                        color: Colors.alpha(Colors.fgSurfaceVariant, 0.7)
                        font.pixelSize: 10
                    }

                    HoverHandler {
                        id: buttonHover

                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: card.select(button.key)
                    }
                }

                SectionButton {
                    key: ""
                    label: I18n.tr("Alle")
                    icon: "tune"
                }

                Repeater {
                    model: card.sections

                    // Unter "Wallpaper" haengt als Unterpunkt die Bibliothek
                    Column {
                        id: sectionEntry

                        required property string modelData

                        width: parent.width
                        spacing: 2

                        SectionButton {
                            key: sectionEntry.modelData
                            label: card.sectionTitle(sectionEntry.modelData)
                            icon: Config.sectionIcons[sectionEntry.modelData] ?? "folder_open"
                            count: card.countIn(sectionEntry.modelData)
                        }

                        SectionButton {
                            visible: sectionEntry.modelData === "wallpaper"
                            key: card.wallsKey
                            label: I18n.tr("Bibliothek")
                            icon: "photo_library"
                            count: Wallpapers.list.length
                            sub: true
                        }
                    }
                }

                // ---- Trenner: Plugins ----
                Text {
                    font.family: Config.font
                    width: parent.width
                    height: 26
                    leftPadding: 14
                    verticalAlignment: Text.AlignBottom
                    bottomPadding: 5
                    text: "PLUGINS"
                    color: Colors.fgSurfaceVariant
                    font.pixelSize: 9
                    font.weight: Font.Medium
                    font.letterSpacing: 0.8
                }

                SectionButton {
                    key: card.managerKey
                    label: I18n.tr("Plugins verwalten")
                    icon: "extension"
                    count: Plugins.plugins.length
                }

                Repeater {
                    model: Plugins.sections

                    SectionButton {
                        required property string modelData

                        key: modelData
                        label: I18n.tr(Plugins.sectionTitle(modelData))
                        icon: Plugins.sectionIcon(modelData)
                        count: card.countIn(modelData)
                        sub: true
                    }
                }
            }
        }

        // Weiche Kante unten, solange noch Gruppen folgen
        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                rightMargin: 1
                bottom: sidebarFlick.bottom
            }
            height: 20
            visible: sidebarFlick.contentHeight - sidebarFlick.contentY - sidebarFlick.height > 2
            gradient: Gradient {
                GradientStop { position: 0; color: Colors.alpha(Colors.background, 0) }
                GradientStop { position: 1; color: Colors.mix(Colors.background, Colors.fgSurface, 0.035) }
            }
        }

        // ---- Fuss: Datei und Zuruecksetzen ----
        Column {
            id: footer

            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                leftMargin: 12
                rightMargin: 12
                bottomMargin: 14
            }
            spacing: 2

            component FootButton: Rectangle {
                id: foot

                required property string icon
                required property string label
                property color tint: Colors.fgSurfaceVariant
                signal clicked()

                width: parent.width
                height: 32
                radius: 10
                color: footHover.hovered ? Colors.alpha(Colors.fgSurface, 0.07) : "transparent"

                Behavior on color {
                    ColorAnimation { duration: Appearance.fadeDuration }
                }

                Text {
                    id: footIcon

                    anchors {
                        left: parent.left
                        leftMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    text: foot.icon
                    color: foot.tint
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 15

                    Behavior on color {
                        ColorAnimation { duration: Appearance.fadeDuration }
                    }
                }

                Text {
                    font.family: Config.font
                    anchors {
                        left: footIcon.right
                        leftMargin: 10
                        right: parent.right
                        rightMargin: 10
                        verticalCenter: parent.verticalCenter
                    }
                    text: foot.label
                    color: foot.tint
                    font.pixelSize: 11
                    elide: Text.ElideRight

                    Behavior on color {
                        ColorAnimation { duration: Appearance.fadeDuration }
                    }
                }

                HoverHandler {
                    id: footHover

                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: foot.clicked()
                }
            }

            FootButton {
                icon: "open_in_new"
                label: I18n.tr("shell.json öffnen")
                onClicked: {
                    Quickshell.execDetached(["xdg-open", Config.path]);
                    SettingsState.close();
                }
            }

            // Zweistufig: erst "Alles zuruecksetzen", dann 3 s lang
            // "Wirklich?" – ein Fehlklick setzt sonst alles platt.
            // Betrifft shell.json; Plugin-Werte setzt die Verwaltung je Plugin.
            FootButton {
                id: resetAll

                property bool armed: false

                icon: armed ? "check" : "settings_backup_restore"
                label: armed ? I18n.tr("Wirklich alles zurücksetzen?") : I18n.tr("Alles zurücksetzen")
                tint: armed ? Colors.error : Colors.fgSurfaceVariant
                onClicked: {
                    if (resetAll.armed) {
                        Config.resetAll();
                        resetAll.armed = false;
                    } else {
                        resetAll.armed = true;
                        disarm.restart();
                    }
                }

                Timer {
                    id: disarm

                    interval: 3000
                    onTriggered: resetAll.armed = false
                }
            }
        }
    }

    // ================= Rechte Seite =================
    Item {
        id: content

        anchors {
            left: sidebar.right
            right: parent.right
            top: parent.top
            bottom: parent.bottom
        }

        // Kopf: Gruppentitel + Suche
        Text {
            id: heading
            font.family: Config.font

            anchors {
                left: parent.left
                leftMargin: 24
                verticalCenter: searchBox.verticalCenter
            }
            width: 160
            text: card.browsing ? I18n.tr("Bibliothek")
                : card.searching ? I18n.tr("Suche")
                : card.section === "" ? I18n.tr("Alle")
                : card.sectionTitle(card.section)
            color: Colors.fgBackground
            font.pixelSize: 15
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        Rectangle {
            id: searchBox

            anchors {
                left: heading.right
                right: closeButton.left
                top: parent.top
                leftMargin: 12
                rightMargin: 10
                topMargin: 22
            }
            height: 38
            radius: height / 2
            color: Colors.alpha(Colors.fgSurface, search.activeFocus ? 0.09 : 0.06)
            border.width: 1
            border.color: search.activeFocus ? Colors.alpha(Colors.primary, 0.5) : "transparent"

            Behavior on color {
                ColorAnimation { duration: Appearance.fadeDuration }
            }
            Behavior on border.color {
                ColorAnimation { duration: Appearance.fadeDuration }
            }

            Text {
                id: searchIcon

                anchors {
                    left: parent.left
                    leftMargin: 14
                    verticalCenter: parent.verticalCenter
                }
                text: "search"
                color: Colors.fgSurfaceVariant
                font.family: "Material Symbols Outlined"
                font.pixelSize: 17
            }

            TextInput {
                id: search
                font.family: Config.font

                anchors {
                    left: searchIcon.right
                    leftMargin: 10
                    right: clearSearch.left
                    rightMargin: 6
                    verticalCenter: parent.verticalCenter
                }
                onTextChanged: card.filter = text
                color: Colors.fgSurface
                font.pixelSize: 13
                selectionColor: Colors.alpha(Colors.primary, 0.35)
                clip: true

                Keys.onEscapePressed: {
                    if (search.text !== "")
                        search.text = "";
                    else
                        SettingsState.close();
                }

                Text {
                    anchors.fill: parent
                    visible: search.text === ""
                    text: card.browsing ? I18n.tr("Bild suchen…") : I18n.tr("Einstellung suchen…")
                    color: Colors.alpha(Colors.fgSurfaceVariant, 0.7)
                    font: search.font
                    verticalAlignment: Text.AlignVCenter
                }
            }

            // Suchtext leeren
            Item {
                id: clearSearch

                anchors {
                    right: parent.right
                    rightMargin: 6
                    verticalCenter: parent.verticalCenter
                }
                width: search.text !== "" ? 26 : 0
                height: 26
                opacity: search.text !== "" ? 1 : 0
                visible: width > 0

                Behavior on width {
                    NumberAnimation { duration: Appearance.fadeDuration; easing.type: Easing.OutCubic }
                }
                Fade on opacity {}

                Text {
                    anchors.centerIn: parent
                    text: "close"
                    color: Colors.fgSurfaceVariant
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 15
                }

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: search.text = ""
                }
            }
        }

        Rectangle {
            id: closeButton

            anchors {
                right: parent.right
                rightMargin: 20
                verticalCenter: searchBox.verticalCenter
            }
            width: 32
            height: 32
            radius: height / 2
            color: closeHover.hovered ? Colors.alpha(Colors.fgSurface, 0.12) : "transparent"

            Behavior on color {
                ColorAnimation { duration: Appearance.fadeDuration }
            }

            Text {
                anchors.centerIn: parent
                text: "close"
                color: Colors.fgSurfaceVariant
                font.family: "Material Symbols Outlined"
                font.pixelSize: 17
            }

            HoverHandler {
                id: closeHover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: SettingsState.close()
            }
        }

        // ---- Plugin-Verwaltung statt der Liste ----
        Loader {
            id: manager

            anchors {
                left: parent.left
                right: parent.right
                top: searchBox.bottom
                bottom: parent.bottom
                leftMargin: 12
                rightMargin: 12
                topMargin: 12
                bottomMargin: 16
            }
            active: card.managing
            visible: active

            sourceComponent: PluginManager {
                onOpenSection: s => card.select(s)
            }
        }

        // ---- Wallpaper-Bibliothek statt der Liste ----
        Loader {
            id: walls

            anchors {
                left: parent.left
                right: parent.right
                top: searchBox.bottom
                bottom: parent.bottom
                leftMargin: 12
                rightMargin: 12
                topMargin: 12
                bottomMargin: 16
            }
            active: card.browsing
            visible: active

            sourceComponent: WallpaperManager {
                filter: card.filter
            }
        }

        // ---- Die Liste, gebaut aus der Datei ----
        ListView {
            id: list

            anchors {
                left: parent.left
                right: parent.right
                top: searchBox.bottom
                bottom: parent.bottom
                leftMargin: 12
                rightMargin: 12
                topMargin: 12
                bottomMargin: 16
            }
            visible: !card.managing && !card.browsing
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            // Nicht per Ziehen scrollen: sonst klaut die Liste den
            // Drag-and-Drop-Editoren ihre Geste. Das Mausrad reicht.
            interactive: false

            model: ScriptModel {
                values: {
                    const needle = card.filter.trim().toLowerCase();
                    const out = [];
                    // shell.json kommt alphabetisch zurueck (QJsonObject
                    // sortiert beim Schreiben) – die Reihenfolge im Menue
                    // gibt deshalb die meta-Tabelle vor, Unbekanntes hinten.
                    // Plugin-Gruppen: Reihenfolge wie im Manifest (Plugins.meta)
                    const order = Object.keys(Config.meta).concat(Object.keys(Plugins.meta));
                    const rank = id => {
                        const i = order.indexOf(id);
                        return i < 0 ? order.length : i;
                    };

                    for (const section of card.allSections) {
                        if (needle === "" && card.section !== "" && section !== card.section)
                            continue;

                        const values = card.valuesOf(section) ?? {};
                        const keys = Object.keys(values).sort((a, b) =>
                            rank(`${section}.${a}`) - rank(`${section}.${b}`) || a.localeCompare(b));
                        for (const key of keys) {
                            const id = `${section}.${key}`;
                            const meta = Plugins.metaFor(id);
                            const entry = {
                                id,
                                section,
                                key,
                                value: values[key],
                                title: meta?.title ? I18n.tr(meta.title) : key,
                                // Ohne Eintrag in der Tabelle: ehrlich sagen,
                                // dass der Schluessel neu ist
                                desc: meta?.desc ? I18n.tr(meta.desc) : I18n.tr("Schlüssel \"%1\" aus shell.json").arg(key),
                                options: meta?.options ?? null,
                                labels: meta?.labels ?? null,
                                min: meta?.min,
                                max: meta?.max,
                                step: meta?.step,
                                unit: meta?.unit ?? "",
                                requires: meta?.requires ?? null,
                                editor: meta?.editor ?? "",
                                preview: meta?.preview ?? ""
                            };

                            if (needle === ""
                                || entry.title.toLowerCase().includes(needle)
                                || entry.desc.toLowerCase().includes(needle)
                                || id.toLowerCase().includes(needle)
                                || card.sectionTitle(section).toLowerCase().includes(needle))
                                out.push(entry);
                        }
                    }
                    return out;
                }
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

                onWheel: event => {
                    const angle = event.angleDelta.y + event.angleDelta.x;
                    const pixels = event.pixelDelta.y + event.pixelDelta.x;
                    const delta = angle !== 0 ? angle / 120 : pixels / 40;

                    const max = Math.max(0, list.contentHeight - list.height);
                    list.contentY = Math.max(0, Math.min(max, list.contentY - delta * 60));
                    event.accepted = true;
                }
            }

            delegate: SettingsRow {
                required property var modelData
                required property int index

                width: ListView.view.width
                entry: modelData
                // Gruppentitel nur, wenn mehrere Gruppen zu sehen sind
                // (Suche oder "Alle"), und nur ueber der ersten Zeile.
                // Optional-Zugriff: waehrend des Filterns sind Index und
                // Liste kurz auseinander, dann gibt es den Vorgaenger nicht
                section: (card.searching || card.section === "")
                         && (index === 0 || list.model.values[index - 1]?.section !== modelData.section)
                         ? modelData.section : ""
            }

            // Weiche Kante unten, solange noch Zeilen folgen
            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }
                height: 24
                visible: list.contentHeight - list.contentY - list.height > 2
                gradient: Gradient {
                    GradientStop { position: 0; color: Colors.alpha(Colors.background, 0) }
                    GradientStop { position: 1; color: Colors.background }
                }
            }

            Column {
                anchors.centerIn: parent
                visible: list.count === 0
                spacing: 6

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "search_off"
                    color: Colors.alpha(Colors.fgSurfaceVariant, 0.6)
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 28
                }

                Text {
                    font.family: Config.font
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: I18n.tr("Nichts gefunden")
                    color: Colors.fgSurfaceVariant
                    font.pixelSize: 12
                }
            }
        }

        // Zaehler unten rechts
        Text {
            font.family: Config.font
            anchors {
                right: parent.right
                rightMargin: 24
                bottom: parent.bottom
                bottomMargin: 10
            }
            text: card.browsing ? (card.searching ? I18n.tr("%1 Treffer").arg(walls.item?.images.length ?? 0) : "")
                : card.searching ? I18n.tr("%1 Treffer").arg(list.count) : ""
            color: Colors.alpha(Colors.fgSurfaceVariant, 0.7)
            font.pixelSize: 10
        }
    }
}
