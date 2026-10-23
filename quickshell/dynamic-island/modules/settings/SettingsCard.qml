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
//
// Breite: das Fenster laesst sich frei ziehen. Unter `compact` schrumpft
// die Leiste zur Symbolspalte (Name beim Zeigen daneben). Die Zeilen stehen
// in Karten (je Gruppe und Config.meta-`group` eine), die Karten in so
// vielen Spalten (360–560 px), wie ins Fenster passen – jede Spalte waechst
// fuer sich, damit eine aufgeklappte Auswahl nur ihre eigene verschiebt.
// Karten mit einem breiten Editor (`wideEditors`) gehen ueber die volle Breite.
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

    // ---- Breite ----
    // Schmale Karte: Leiste nur mit Symbolen
    readonly property bool compact: card.width < 820
    readonly property real sidebarWidth: card.compact ? 64 : 236
    // Platz der Liste rechts der Leiste (Zielwert, nicht der animierte)
    readonly property real listRoom: card.width - card.sidebarWidth - 44

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

    // ---- Die Zeilen, gebaut aus der Datei ----
    readonly property var entries: {
        const needle = card.filter.trim().toLowerCase();
        const out = [];
        // shell.json kommt alphabetisch zurueck (QJsonObject sortiert beim
        // Schreiben) – die Reihenfolge im Menue gibt deshalb die meta-Tabelle
        // vor, Unbekanntes hinten. Plugin-Gruppen: Reihenfolge wie im
        // Manifest (Plugins.meta)
        const order = Object.keys(Config.meta).concat(Object.keys(Plugins.meta));
        const rank = id => {
            const i = order.indexOf(id);
            return i < 0 ? order.length : i;
        };

        for (const section of card.allSections) {
            if (needle === "" && card.section !== "" && section !== card.section)
                continue;

            const values = card.valuesOf(section) ?? {};
            const sorted = Object.keys(values).sort((a, b) =>
                rank(`${section}.${a}`) - rank(`${section}.${b}`) || a.localeCompare(b));
            // Zeilen einer Karte (meta.group) zusammenziehen, Karten in der
            // Reihenfolge ihrer ersten Zeile
            const groupOf = key => Plugins.metaFor(`${section}.${key}`)?.group ?? "";
            const groupOrder = [...new Set(sorted.map(groupOf))];
            const keys = sorted.map((key, i) => ({ key, i }))
                .sort((a, b) => groupOrder.indexOf(groupOf(a.key)) - groupOrder.indexOf(groupOf(b.key)) || a.i - b.i)
                .map(k => k.key);
            for (const key of keys) {
                const id = `${section}.${key}`;
                const meta = Plugins.metaFor(id);
                // Schluessel, die woanders bedient werden (meta.hidden)
                if (meta?.hidden)
                    continue;
                const entry = {
                    id,
                    section,
                    key,
                    group: meta?.group ?? "",
                    value: values[key],
                    title: meta?.title ? I18n.tr(meta.title) : key,
                    // Ohne Eintrag in der Tabelle: ehrlich sagen,
                    // dass der Schluessel neu ist
                    desc: meta?.desc ? I18n.tr(meta.desc) : (meta ? "" : I18n.tr("Schlüssel \"%1\" aus shell.json").arg(key)),
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

    // Die Karten: aufeinanderfolgende Zeilen mit gleicher Gruppe und
    // gleichem meta.group, rows als Indizes in card.entries (durch einen
    // Repeater gereichte Objekte verlieren ihre JS-Arrays – `options` kaeme
    // als Sequenz an, nicht als Array). Ein breiter Editor macht die Karte
    // breit – die anderen (Sperrbildschirm, Desktop) sind nur ein Knopf.
    readonly property var wideEditors: ["quick"]
    readonly property var groupCards: {
        const out = [];
        card.entries.forEach((e, i) => {
            const last = out[out.length - 1];
            if (last && last.section === e.section && last.group === e.group) {
                last.rows.push(i);
                last.wide = last.wide || card.wideEditors.includes(e.editor);
            } else {
                out.push({ section: e.section, group: e.group, rows: [i], wide: card.wideEditors.includes(e.editor) });
            }
        });
        return out;
    }

    // Die Karten auf Baender verteilt: ein Band ist entweder ein Raster aus
    // Spalten (jede Karte in die bisher kuerzeste) oder eine breite Karte.
    // Je Band { width, columns: [[Kartenindex, …], …] }.
    readonly property var layoutBands: {
        const gap = list.gap;
        const room = Math.max(0, card.listRoom);
        // Grobe Hoehe je Karte, um die kuerzeste Spalte zu finden
        const rowWeight = i => {
            const e = card.entries[i];
            return card.wideEditors.includes(e.editor) ? 320 : e.editor !== "" ? 110 : e.desc !== "" ? 54 : 46;
        };
        const weight = c => c.rows.reduce((s, i) => s + rowWeight(i), 0) + 38;

        // Raster und breite Karten in Lesereihenfolge. Ueber mehrere Gruppen
        // ("Alle", Suche) kommen die Editoren ans Ende, sonst reissen sie das
        // Raster in halbleere Baender
        const all = card.groupCards.map((c, i) => i);
        const order = card.searching || card.section === ""
            ? all.filter(i => !card.groupCards[i].wide).concat(all.filter(i => card.groupCards[i].wide))
            : all;
        const runs = [];
        order.forEach(i => {
            const c = card.groupCards[i];
            const last = runs[runs.length - 1];
            if (c.wide)
                runs.push({ wide: true, cards: [i] });
            else if (last && !last.wide)
                last.cards.push(i);
            else
                runs.push({ wide: false, cards: [i] });
        });

        // Spaltenzahl aus der Breite, aber nicht mehr als Karten da sind –
        // eine Seite mit drei Karten bekommt drei breitere Spalten statt vier
        const most = runs.reduce((m, r) => r.wide ? m : Math.max(m, r.cards.length), 1);
        const fit = Math.max(1, Math.floor((room + gap) / (360 + gap)));
        const cols = Math.min(fit, most, 4);
        // Eine Spalte neben einem Editor: so breit wie er, damit die Kanten
        // stimmen; sonst hoechstens 560, damit Titel und Wert nah bleiben
        const hasWide = runs.some(r => r.wide);
        const wideWidth = cols === 1 ? Math.min(room, 820)
                                     : Math.min(room, Math.max(820, Math.min(560, (room - gap * (cols - 1)) / cols) * 2 + gap));
        const colWidth = cols === 1 && hasWide ? wideWidth
                                               : Math.min(560, (room - gap * (cols - 1)) / cols);

        return runs.map(r => {
            if (r.wide)
                return { width: wideWidth, columns: [r.cards] };
            const n = Math.min(cols, r.cards.length);
            const columns = Array.from({ length: n }, () => []);
            const heights = new Array(n).fill(0);
            for (const i of r.cards) {
                const k = heights.indexOf(Math.min(...heights));
                columns[k].push(i);
                heights[k] += weight(card.groupCards[i]);
            }
            return { width: colWidth, columns };
        });
    }

    // Beim Zeigen auf die Symbolspalte: der Knopf, dessen Name daneben steht
    property Item railItem: null

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
        width: card.sidebarWidth
        clip: true

        Behavior on width {
            NumberAnimation { duration: Appearance.fadeDuration; easing.type: Easing.OutCubic }
        }

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
            visible: !card.compact
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
            visible: !card.compact
        }

        // Schmal: statt des Titels das Symbol des Fensters
        Text {
            anchors {
                horizontalCenter: parent.horizontalCenter
                verticalCenter: title.verticalCenter
            }
            text: "settings"
            color: Colors.fgBackground
            font.family: "Material Symbols Outlined"
            font.pixelSize: 20
            visible: card.compact
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

                        // Schmal: mittig; sonst links, Plugin-Gruppen eingerueckt
                        x: card.compact ? (parent.width - width) / 2 : (button.sub ? 22 : 12)
                        anchors.verticalCenter: parent.verticalCenter
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
                        visible: !card.compact
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
                        visible: button.count > 0 && !card.compact
                        text: button.count
                        color: Colors.alpha(Colors.fgSurfaceVariant, 0.7)
                        font.pixelSize: 10
                    }

                    HoverHandler {
                        id: buttonHover

                        cursorShape: Qt.PointingHandCursor
                        onHoveredChanged: {
                            if (hovered)
                                card.railItem = button;
                            else if (card.railItem === button)
                                card.railItem = null;
                        }
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
                Item {
                    width: parent.width
                    height: card.compact ? 14 : 26

                    Text {
                        font.family: Config.font
                        anchors.fill: parent
                        leftPadding: 14
                        verticalAlignment: Text.AlignBottom
                        bottomPadding: 5
                        visible: !card.compact
                        text: I18n.tr("Plugins")
                        color: Colors.fgSurfaceVariant
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 20
                        height: 1
                        visible: card.compact
                        color: Colors.alpha(Colors.outline, 0.4)
                    }
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

                    x: card.compact ? (parent.width - width) / 2 : 12
                    anchors.verticalCenter: parent.verticalCenter
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
                    visible: !card.compact
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
                    onHoveredChanged: {
                        if (hovered)
                            card.railItem = foot;
                        else if (card.railItem === foot)
                            card.railItem = null;
                    }
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

        // Kopf: Gruppentitel + Suche. Der Titel nimmt sich seine Breite,
        // laesst dem Suchfeld aber mindestens 150 px; das Feld waechst mit
        // dem Fenster bis 520 px und bleibt vor dem Schliessen-Knopf stehen.
        Text {
            id: heading
            font.family: Config.font

            anchors {
                left: parent.left
                leftMargin: 24
                verticalCenter: searchBox.verticalCenter
            }
            width: Math.max(0, Math.min(heading.implicitWidth, closeButton.x - 10 - heading.x - 12 - 150))
            // In der Bibliothek steht "Bibliothek › Ordner" in der Seite selbst
            text: card.browsing ? "Wallpaper"
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
                top: parent.top
                leftMargin: 12
                topMargin: 22
            }
            width: Math.max(0, Math.min(closeButton.x - 10 - (heading.x + heading.width + 12), 520))
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
                    elide: Text.ElideRight
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
        // Linksbuendig unter dem Titel; die Seite stellt ihre Karten ab
        // ~850 px selbst in zwei Spalten
        Loader {
            id: manager

            anchors {
                left: parent.left
                top: searchBox.bottom
                bottom: parent.bottom
                leftMargin: 22
                topMargin: 12
                bottomMargin: 16
            }
            width: Math.min(parent.width - 46, 1400)
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
                leftMargin: 24
                rightMargin: 16
                topMargin: 12
                bottomMargin: 16
            }
            active: card.browsing
            visible: active

            sourceComponent: WallpaperManager {
                filter: card.filter
            }
        }

        // ---- Die Liste ----
        // Karten in Baendern (siehe layoutBands), linksbuendig unter dem
        // Titel, damit Kopf und Karten eine Kante haben
        Flickable {
            id: list

            readonly property real gap: 14

            anchors {
                left: parent.left
                right: parent.right
                top: searchBox.bottom
                bottom: parent.bottom
                leftMargin: 24
                rightMargin: 20
                topMargin: 16
                bottomMargin: 16
            }
            visible: !card.managing && !card.browsing
            clip: true
            contentWidth: width
            contentHeight: bands.height + 8
            boundsBehavior: Flickable.StopAtBounds
            // Nicht per Ziehen scrollen: sonst klaut die Liste den
            // Drag-and-Drop-Editoren ihre Geste. Das Mausrad reicht.
            interactive: false

            // Inhalt kuerzer geworden (Filter, andere Spalten): nicht ins Leere zeigen
            onContentHeightChanged: list.contentY = Math.max(0, Math.min(list.contentY, list.contentHeight - list.height))

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

            Column {
                id: bands

                width: list.width
                spacing: list.gap

                Repeater {
                    model: card.layoutBands

                    Row {
                        id: band

                        required property var modelData

                        spacing: list.gap

                        Repeater {
                            model: band.modelData.columns

                            Column {
                                id: column

                                required property var modelData

                                width: band.modelData.width
                                spacing: list.gap

                                Repeater {
                                    model: column.modelData

                                    GroupCard {
                                        required property int modelData

                                        width: column.width
                                        // Waehrend des Filterns sind Indizes
                                        // und Liste kurz auseinander
                                        group: card.groupCards[modelData] ?? null
                                        entries: card.entries
                                        sectionLabel: card.searching || card.section === ""
                                                      ? card.sectionTitle(group?.section ?? "") : ""
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Weiche Kante unten, solange noch Zeilen folgen
        Rectangle {
            anchors {
                left: list.left
                right: list.right
                bottom: list.bottom
            }
            height: 24
            visible: list.visible && list.contentHeight - list.contentY - list.height > 2
            gradient: Gradient {
                GradientStop { position: 0; color: Colors.alpha(Colors.background, 0) }
                GradientStop { position: 1; color: Colors.background }
            }
        }

        Column {
            anchors.centerIn: list
            visible: list.visible && card.entries.length === 0
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

        // Zaehler unten rechts
        Text {
            font.family: Config.font
            anchors {
                right: parent.right
                rightMargin: 24
                bottom: parent.bottom
                bottomMargin: 10
            }
            // In der Bibliothek steht die Trefferzahl in deren Kopfzeile
            text: card.searching && !card.browsing ? I18n.tr("%1 Treffer").arg(card.entries.length) : ""
            color: Colors.alpha(Colors.fgSurfaceVariant, 0.7)
            font.pixelSize: 10
        }
    }

    // Name des Knopfs neben der Symbolspalte
    Rectangle {
        id: railHint

        readonly property Item target: card.compact ? card.railItem : null
        // Beim Ausblenden bleibt der letzte Name stehen, statt leer zu verblassen
        property string label: ""

        readonly property string current: railHint.target?.label ?? ""
        onCurrentChanged: {
            if (railHint.current !== "")
                railHint.label = railHint.current;
        }

        x: sidebar.width + 8
        y: railHint.target ? railHint.target.mapToItem(card, 0, railHint.target.height / 2).y - height / 2 : 0
        width: hintLabel.implicitWidth + 20
        height: 26
        radius: 8
        color: Colors.mix(Colors.background, Colors.fgSurface, 0.1)
        border.width: 1
        border.color: Colors.alpha(Colors.outline, 0.3)
        visible: opacity > 0
        opacity: railHint.current !== "" ? 1 : 0

        Fade on opacity {}

        Text {
            id: hintLabel

            anchors.centerIn: parent
            font.family: Config.font
            text: railHint.label
            color: Colors.fgSurface
            font.pixelSize: 11
        }
    }
}
