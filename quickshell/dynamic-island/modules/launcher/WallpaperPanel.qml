pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import qs.modules.services.theme
import qs.modules.services.wallpaper

import qs
import qs.modules.bar.components.notch
import qs.modules.services.config
import qs.modules.widgets

// Wallpaper-Auswahl der Notch: eigenes Suchfeld und darunter das Karussell.
//
// Steckt wie LauncherPanel und DatePanel in der Karte der Notch und ist deren
// dritte Ansicht – welche gilt, sagt LauncherState.mode. Bewusst ein eigenes
// Panel statt eines Modus im Launcher: eigenes Suchfeld, eigene Breite.
//
// Unter der Stil-Reihe klappt auf Wunsch die Wallhaven-Suche auf (Knopf in
// der Suchzeile oder Strg+W): eigene Suchzeile mit Sortier-Chips und ein
// zweites Karussell mit den Treffern. Die lokale Reihe bleibt dabei stehen,
// die Notch waechst nur nach unten (Morph).
//
// Tasten (gelten in beiden Suchfeldern, `row` sagt, welche Reihe sie hat):
//   Esc               schliessen
//   Links/Rechts, Tab blaettern in der aktiven Reihe
//   Hoch/Runter       Wallhaven zu: blaettern; offen: Reihe wechseln
//   Enter             lokal: setzen – Wallhaven: herunterladen + setzen
//   Shift+Enter       Wallhaven: nur herunterladen
//   Strg+Links/Rechts Stil des markierten lokalen Bilds wechseln
//   Strg+W            Wallhaven auf-/zuklappen
Item {
    id: panel

    // ---- Schnittstelle zur Notch ----
    property real topOffset: 0
    property real cardRadius: 18
    property real inset: 2
    property bool active: false          // true, solange diese Ansicht offen ist

    readonly property real outerWidth: implicitWidth + inset * 2
    readonly property real outerHeight: implicitHeight + inset
    // Die Hoehe steht fest (siehe listHeight), Reserve und Ist sind dasselbe.
    // Die Notch fragt trotzdem danach, wie beim LauncherPanel.
    readonly property alias maxOuterHeight: panel.outerHeight

    // Feste Hoehe fuer den Bildbereich. Bewusst nicht aus dem Karussell
    // gelesen: das steckt in einem Loader und ist im geschlossenen Zustand gar
    // nicht da – die Notch braucht die Reserve aber schon vorher, sonst
    // schneidet das Fenster die Karte beim Aufgehen einen Frame lang ab.
    readonly property real listHeight: 145

    // Breiter als der Launcher, damit fuenf Bilder nebeneinander passen:
    // 988 nutzbare Breite / 191 je Kachel = 5 (PathView braucht eine ungerade
    // Zahl, sonst sitzt keines in der Mitte).
    implicitWidth: 1000
    // Kachelbreite; die Hoehe darunter haengt daran (16:9 + Beschriftung)
    readonly property real imageWidth: 175
    implicitHeight: searchRow.height + 1 + listWrapper.implicitHeight + 1 + styleRow.height
        + (panel.whOpen ? 1 + whSection.implicitHeight : 0)

    // ---- Wallhaven ----
    // Aufgeklappt merkt sich der Dienst (bleibt ueber das Schliessen hinweg);
    // welche Reihe die Tastatur hat, faengt bei jedem Oeffnen lokal an.
    readonly property bool whOpen: Wallhaven.expanded
    property string row: "local"
    readonly property bool whFocused: panel.whOpen && panel.row === "wallhaven"

    function focusRow(name: string): void {
        if (name === "wallhaven" && !panel.whOpen)
            name = "local";
        panel.row = name;
        if (name === "wallhaven")
            whSearch.forceActiveFocus();
        else
            search.forceActiveFocus();
    }

    // Beim Reihenwechsel die Vorschau der neuen Reihe nachholen – die
    // Karussells zeigen sie nur beim Blaettern
    onRowChanged: {
        if (panel.row === "local") {
            const path = walls.item?.currentPath ?? "";
            if (path !== "")
                Wallpapers.preview(path);
        } else {
            whList.item?.previewNow();
        }
    }

    function toggleWallhaven(): void {
        Wallhaven.expanded = !Wallhaven.expanded;
        if (Wallhaven.expanded) {
            // Ohne Suchtext gleich etwas zeigen (Toplist o.ae. laut Config)
            if (!Wallhaven.answered && !Wallhaven.searching)
                Wallhaven.search(whSearch.text, false);
            panel.focusRow("wallhaven");
        } else {
            panel.focusRow("local");
        }
    }

    // Enter im Wallhaven-Feld: steht eine Suche noch aus (Tipp-Pause), erst
    // die; sonst den markierten Treffer uebernehmen
    function whApply(set: bool): void {
        if (searchDelay.running) {
            searchDelay.stop();
            Wallhaven.search(whSearch.text, false);
        } else {
            whList.item?.apply(set);
        }
    }

    // Fertig heruntergeladen und gesetzt: zu, wie beim lokalen Setzen. Beim
    // reinen Download bleibt die Auswahl offen – die Kachel traegt dann das
    // Haekchen, und das Bild steht in der lokalen Reihe.
    Connections {
        target: Wallhaven

        function onDownloaded(wid: string, path: string, applied: bool): void {
            if (applied && panel.active)
                LauncherState.close();
        }
    }

    // Stil-Reihe unten: "auto" und die Material-Varianten. Sie gilt fuer das
    // markierte Bild, nicht fuer alle – die CLI merkt sich die Wahl je Bild.
    readonly property string targetPath: walls.item?.currentPath ?? ""
    readonly property var styles: [{ name: "auto", icon: "auto_awesome" }].concat(Themes.variants)

    // Feste Wahl des markierten Bilds, sonst "auto"
    readonly property string pinnedStyle: Wallpapers.variantFor(panel.targetPath) || "auto"

    // Was "auto" fuer das markierte Bild ergibt: aus der Vorschau, beim
    // gerade gesetzten Bild ohne Vorschau aus scheme.json
    readonly property string resolvedStyle: Wallpapers.previewPath === panel.targetPath && Wallpapers.previewVariant !== ""
        ? Wallpapers.previewVariant
        : panel.targetPath === Wallpapers.actualCurrent ? Themes.currentVariant : ""

    function pickStyle(name: string): void {
        Wallpapers.setVariant(panel.targetPath, name);
    }

    function cycleStyle(delta: int): void {
        const names = panel.styles.map(v => v.name);
        const at = Math.max(0, names.indexOf(panel.pinnedStyle));
        panel.pickStyle(names[(at + delta + names.length) % names.length]);
    }

    anchors {
        left: parent.left
        right: parent.right
        leftMargin: panel.inset
        rightMargin: panel.inset
    }
    y: panel.topOffset

    // Per LazyPanel entsteht die Ansicht bereits aktiv – dann gibt es kein
    // Wechsel-Signal, die Startarbeit (Fokus, Suchfeld) wird nachgeholt
    Component.onCompleted: if (panel.active) Qt.callLater(panel.activeChanged)

    onActiveChanged: {
        if (active) {
            search.text = "";
            // Der letzte Wallhaven-Suchtext bleibt stehen (ohne neue Anfrage:
            // der Dienst kennt ihn schon)
            whSearch.text = Wallhaven.query;
            panel.row = "local";
            search.forceActiveFocus();
        }
    }

    // ---- Suchzeile ----
    Item {
        id: searchRow

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: 50

        Text {
            id: searchIcon

            anchors {
                left: parent.left
                leftMargin: 16
                verticalCenter: parent.verticalCenter
            }
            text: "wallpaper_slideshow"
            font.family: "Material Symbols Outlined"
            font.pixelSize: 19
            color: Colors.primary
        }

        TextInput {
            id: search
            font.family: Config.font

            anchors {
                left: searchIcon.right
                leftMargin: 12
                right: wallhavenButton.left
                rightMargin: 12
                verticalCenter: parent.verticalCenter
            }
            color: Colors.fgSurface
            font.pixelSize: 14
            selectionColor: Colors.alpha(Colors.primary, 0.35)
            selectedTextColor: Colors.fgSurface
            clip: true

            Keys.onEscapePressed: LauncherState.close()
            Keys.onReturnPressed: walls.item?.apply()
            Keys.onEnterPressed: walls.item?.apply()
            // Die Pfeile blaettern hier im Karussell statt den Textcursor zu
            // bewegen – im Suchfeld steht ohnehin nur ein Filterwort.
            // Mit Strg waehlen sie den Stil des markierten Bilds.
            Keys.onLeftPressed: event => {
                if (event.modifiers & Qt.ControlModifier)
                    panel.cycleStyle(-1);
                else
                    walls.item?.moveBy(-1);
            }
            Keys.onRightPressed: event => {
                if (event.modifiers & Qt.ControlModifier)
                    panel.cycleStyle(1);
                else
                    walls.item?.moveBy(1);
            }
            // Mit offenem Wallhaven wechseln Hoch/Runter die Reihe
            Keys.onUpPressed: panel.whOpen ? panel.focusRow("wallhaven") : walls.item?.moveBy(-1)
            Keys.onDownPressed: panel.whOpen ? panel.focusRow("wallhaven") : walls.item?.moveBy(1)
            Keys.onTabPressed: walls.item?.moveBy(1)
            Keys.onPressed: event => {
                if (event.key === Qt.Key_W && (event.modifiers & Qt.ControlModifier)) {
                    panel.toggleWallhaven();
                    event.accepted = true;
                }
            }

            Text {
                anchors.fill: parent
                visible: search.text === ""
                text: `Wallpaper suchen…   ${Wallpapers.list.length} Bilder`
                color: Colors.alpha(Colors.fgSurfaceVariant, 0.7)
                font: search.font
                verticalAlignment: Text.AlignVCenter
            }
        }

        // Wallhaven auf-/zuklappen; aufgeklappt bleibt der Knopf getoent
        Rectangle {
            id: wallhavenButton

            anchors {
                right: shuffleButton.left
                rightMargin: 4
                verticalCenter: parent.verticalCenter
            }
            width: 32
            height: 32
            radius: height / 2
            color: panel.whOpen ? Colors.alpha(Colors.primary, wallhavenArea.containsMouse ? 0.28 : 0.18)
                : wallhavenArea.containsMouse ? Colors.alpha(Colors.fgSurface, 0.08) : "transparent"

            Behavior on color {
                ColorAnimation { duration: 90 }
            }

            MouseArea {
                id: wallhavenArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: panel.toggleWallhaven()
            }

            Text {
                anchors.centerIn: parent
                text: "travel_explore"
                font.family: "Material Symbols Outlined"
                font.pixelSize: 17
                color: panel.whOpen || wallhavenArea.containsMouse ? Colors.primary : Colors.fgSurfaceVariant
            }
        }

        // Zufallsbild – das Gegenstueck zum Favoriten-Stern im Launcher
        Rectangle {
            id: shuffleButton

            anchors {
                right: parent.right
                rightMargin: 10
                verticalCenter: parent.verticalCenter
            }
            width: 32
            height: 32
            radius: height / 2
            color: shuffleArea.containsMouse ? Colors.alpha(Colors.fgSurface, 0.08) : "transparent"

            Behavior on color {
                ColorAnimation { duration: 90 }
            }

            MouseArea {
                id: shuffleArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Wallpapers.random();
                    LauncherState.close();
                }
            }

            Text {
                anchors.centerIn: parent
                text: "shuffle"
                font.family: "Material Symbols Outlined"
                font.pixelSize: 17
                color: shuffleArea.containsMouse ? Colors.primary : Colors.fgSurfaceVariant
            }
        }
    }

    Rectangle {
        id: separator

        anchors {
            top: searchRow.bottom
            left: parent.left
            right: parent.right
        }
        height: 1
        color: Colors.alpha(Colors.outline, 0.35)
    }

    // ---- Karussell ----
    Item {
        id: listWrapper

        anchors {
            top: separator.bottom
            left: parent.left
            right: parent.right
        }
        implicitHeight: panel.listHeight

        // Als Loader, damit das Karussell nur existiert, solange die Ansicht
        // offen ist: beim Zerstoeren nimmt es seine Hintergrund-Vorschau
        // zurueck und gibt die Vorschaubilder frei.
        Loader {
            id: walls

            anchors.fill: parent
            anchors.margins: 6
            active: panel.active

            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: edgeMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1
            }

            sourceComponent: WallpaperList {
                imageWidth: panel.imageWidth
                query: search.text
                focused: !panel.whFocused
                onApplied: LauncherState.close()
                onWheeled: panel.focusRow("local")
            }
        }

        // Vignette nach aussen: die Reihe blendet zu den Kartenraendern hin aus
        // (Maske auf dem Inhalt, siehe EdgeMask – eine Flaeche in der
        // Theme-Farbe darueber stand auf der schwarzen Notch als grauer Balken)
        EdgeMask {
            id: edgeMask

            anchors.fill: walls
            fade: 200
        }
    }

    Rectangle {
        id: separator2

        anchors {
            top: listWrapper.bottom
            left: parent.left
            right: parent.right
        }
        height: 1
        color: Colors.alpha(Colors.outline, 0.35)
    }

    // ---- Stil ----
    // Wie aus dem markierten Bild die Palette wird. Ein Klick legt den Stil
    // fuer dieses Bild fest (beim aktuellen faerbt es gleich um, sonst zeigt
    // die Vorschau ihn); "auto" rechnet ihn aus der Farbigkeit aus, der
    // ausgerechnete Stil ist dann duenn umrandet. Strg+Pfeile im Suchfeld
    // schalten durch. Wirkt nur beim dynamischen Schema – sonst bleibt die
    // Reihe sichtbar, aber zurueckgenommen (wie in der Theme-Auswahl).
    Item {
        id: styleRow

        anchors {
            top: separator2.bottom
            left: parent.left
            right: parent.right
        }
        height: 46

        opacity: Themes.currentName === "dynamic" ? 1 : 0.45

        Behavior on opacity {
            NumberAnimation { duration: 160 }
        }

        Text {
            id: styleIcon

            anchors {
                left: parent.left
                leftMargin: 16
                verticalCenter: parent.verticalCenter
            }
            text: "palette"
            font.family: "Material Symbols Outlined"
            font.pixelSize: 19
            color: Colors.primary
        }

        // Die Chips behalten ihre natuerliche Breite, der Abstand dazwischen
        // verteilt den Rest (wie in ThemePanel.qml)
        Row {
            id: chips

            anchors {
                left: styleIcon.right
                leftMargin: 14
                right: parent.right
                rightMargin: 14
                verticalCenter: parent.verticalCenter
            }

            property var widths: ({})
            readonly property real naturalWidth: {
                let sum = 0;
                for (const key in chips.widths)
                    sum += chips.widths[key];
                return sum;
            }

            function report(index: int, width: real): void {
                const next = Object.assign({}, chips.widths);
                next[index] = width;
                chips.widths = next;
            }

            spacing: Math.max(4, (chips.width - chips.naturalWidth) / (panel.styles.length - 1))

            Repeater {
                model: panel.styles

                delegate: Rectangle {
                    id: chip

                    required property int index
                    required property var modelData

                    readonly property bool selected: panel.pinnedStyle === chip.modelData.name
                    // Bei "auto": der Stil, den das Bild tatsaechlich bekommt
                    readonly property bool resolved: panel.pinnedStyle === "auto"
                        && panel.resolvedStyle === chip.modelData.name

                    implicitWidth: chipContent.implicitWidth + 20
                    implicitHeight: 28

                    onImplicitWidthChanged: chips.report(chip.index, chip.implicitWidth)
                    Component.onCompleted: chips.report(chip.index, chip.implicitWidth)

                    radius: height / 2
                    color: chip.selected ? Colors.primary
                        : chipArea.containsMouse ? Colors.alpha(Colors.fgSurface, 0.08)
                        : Colors.alpha(Colors.fgSurface, 0.04)
                    border.width: chip.resolved ? 1 : 0
                    border.color: Colors.alpha(Colors.primary, 0.6)

                    Behavior on color {
                        ColorAnimation { duration: 120 }
                    }

                    Row {
                        id: chipContent

                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: chip.modelData.icon
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 14
                            color: chip.selected ? Colors.fgPrimary
                                : chip.resolved ? Colors.primary
                                : Colors.fgSurfaceVariant
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: chip.modelData.name
                            font.family: Config.font
                            font.pixelSize: 11
                            color: chip.selected ? Colors.fgPrimary
                                : chip.resolved ? Colors.primary
                                : Colors.fgSurface
                        }
                    }

                    MouseArea {
                        id: chipArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panel.pickStyle(chip.modelData.name)
                    }
                }
            }
        }
    }

    // ---- Wallhaven ----
    // Der aufklappbare Bereich unter der Stil-Reihe. Die Hoehe des Panels
    // springt sofort, die Notch zieht per Morph nach und schneidet so lange
    // ab – deshalb bleibt der Bereich beim Zuklappen sichtbar, bis er
    // ausgeblendet ist, sonst schrumpft die Karte ueber leerem Grund.
    Rectangle {
        id: separator3

        anchors {
            top: styleRow.bottom
            left: parent.left
            right: parent.right
        }
        height: 1
        color: Colors.alpha(Colors.outline, 0.35)
        opacity: whSection.opacity
        visible: whSection.visible
    }

    Item {
        id: whSection

        anchors {
            top: separator3.bottom
            left: parent.left
            right: parent.right
        }
        implicitHeight: whRow.height + 1 + whWrapper.implicitHeight
        height: implicitHeight

        opacity: panel.whOpen ? 1 : 0
        visible: opacity > 0

        Fade on opacity {}

        // Sortierung als Chips – dieselben Werte wie wallhaven.sorting im Menue
        readonly property var sortings: [
            { name: "relevanz", label: "Relevanz", icon: "manage_search" },
            { name: "neu", label: "Neu", icon: "schedule" },
            { name: "zufall", label: "Zufall", icon: "casino" },
            { name: "views", label: "Views", icon: "visibility" },
            { name: "favoriten", label: "Favs", icon: "favorite" },
            { name: "top", label: "Top", icon: "trending_up" }
        ]

        // Kurzer Stand rechts neben dem Suchfeld; die leeren Zustaende
        // (Suche, keine Treffer, Fehler) stehen gross im Karussellbereich
        readonly property string status: {
            if (Wallhaven.downloading)
                return "lädt herunter…";
            if (Wallhaven.error !== "" && Wallhaven.items.count > 0)
                return Wallhaven.error;
            if (Wallhaven.items.count === 0)
                return "";
            const pages = Math.min(Wallhaven.lastPage, Wallhaven.maxPages);
            return `${Wallhaven.total} Treffer · Seite ${Wallhaven.page}/${pages}`
                + (Wallhaven.searching ? " · lädt…" : "");
        }

        Item {
            id: whRow

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            height: 46

            Text {
                id: whIcon

                anchors {
                    left: parent.left
                    leftMargin: 16
                    verticalCenter: parent.verticalCenter
                }
                text: "travel_explore"
                font.family: "Material Symbols Outlined"
                font.pixelSize: 19
                color: Colors.primary
            }

            TextInput {
                id: whSearch
                font.family: Config.font

                anchors {
                    left: whIcon.right
                    leftMargin: 12
                    right: whStatus.left
                    rightMargin: 12
                    verticalCenter: parent.verticalCenter
                }
                color: Colors.fgSurface
                font.pixelSize: 14
                selectionColor: Colors.alpha(Colors.primary, 0.35)
                selectedTextColor: Colors.fgSurface
                clip: true

                // Tipp-Pause statt jeder Taste: die API erlaubt 45 Anfragen
                // pro Minute
                onTextChanged: searchDelay.restart()

                Keys.onEscapePressed: LauncherState.close()
                Keys.onReturnPressed: event => panel.whApply(!(event.modifiers & Qt.ShiftModifier))
                Keys.onEnterPressed: event => panel.whApply(!(event.modifiers & Qt.ShiftModifier))
                Keys.onLeftPressed: event => {
                    if (event.modifiers & Qt.ControlModifier)
                        panel.cycleStyle(-1);
                    else
                        whList.item?.moveBy(-1);
                }
                Keys.onRightPressed: event => {
                    if (event.modifiers & Qt.ControlModifier)
                        panel.cycleStyle(1);
                    else
                        whList.item?.moveBy(1);
                }
                Keys.onUpPressed: panel.focusRow("local")
                Keys.onDownPressed: panel.focusRow("local")
                Keys.onTabPressed: whList.item?.moveBy(1)
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_W && (event.modifiers & Qt.ControlModifier)) {
                        panel.toggleWallhaven();
                        event.accepted = true;
                    }
                }

                Text {
                    anchors.fill: parent
                    visible: whSearch.text === ""
                    text: "Wallhaven durchsuchen…   tag, -tag, like:ID"
                    color: Colors.alpha(Colors.fgSurfaceVariant, 0.7)
                    font: whSearch.font
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
            }

            Text {
                id: whStatus

                anchors {
                    right: whChips.left
                    rightMargin: 14
                    verticalCenter: parent.verticalCenter
                }
                text: whSection.status
                font.family: Config.font
                font.pixelSize: 11
                color: Wallhaven.error !== "" ? Colors.error : Colors.fgSurfaceVariant
            }

            Row {
                id: whChips

                anchors {
                    right: parent.right
                    rightMargin: 14
                    verticalCenter: parent.verticalCenter
                }
                spacing: 4

                Repeater {
                    model: whSection.sortings

                    delegate: Rectangle {
                        id: sortChip

                        required property var modelData

                        readonly property bool selected: Config.wallhaven.sorting === sortChip.modelData.name

                        implicitWidth: sortContent.implicitWidth + 18
                        implicitHeight: 26
                        radius: height / 2
                        color: sortChip.selected ? Colors.primary
                            : sortArea.containsMouse ? Colors.alpha(Colors.fgSurface, 0.08)
                            : Colors.alpha(Colors.fgSurface, 0.04)

                        Behavior on color {
                            ColorAnimation { duration: 120 }
                        }

                        Row {
                            id: sortContent

                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: sortChip.modelData.icon
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 13
                                color: sortChip.selected ? Colors.fgPrimary : Colors.fgSurfaceVariant
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: sortChip.modelData.label
                                font.family: Config.font
                                font.pixelSize: 11
                                color: sortChip.selected ? Colors.fgPrimary : Colors.fgSurface
                            }
                        }

                        MouseArea {
                            id: sortArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Wallhaven.setSorting(sortChip.modelData.name)
                        }
                    }
                }
            }
        }

        Timer {
            id: searchDelay

            interval: 500
            onTriggered: Wallhaven.search(whSearch.text, false)
        }

        Rectangle {
            id: whSeparator

            anchors {
                top: whRow.bottom
                left: parent.left
                right: parent.right
            }
            height: 1
            color: Colors.alpha(Colors.outline, 0.2)
        }

        Item {
            id: whWrapper

            anchors {
                top: whSeparator.bottom
                left: parent.left
                right: parent.right
            }
            implicitHeight: panel.listHeight

            Loader {
                id: whList

                anchors.fill: parent
                anchors.margins: 6
                active: panel.active && panel.whOpen

                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: whEdgeMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1
                }

                sourceComponent: WallhavenList {
                    imageWidth: panel.imageWidth
                    focused: panel.whFocused
                    onActivated: panel.focusRow("wallhaven")
                    onWheeled: panel.focusRow("wallhaven")
                }
            }

            EdgeMask {
                id: whEdgeMask

                anchors.fill: whList
                fade: 200
            }

            // Leere Zustaende mitten im Karussellbereich
            Column {
                anchors.centerIn: parent
                spacing: 4
                visible: Wallhaven.items.count === 0

                Text {
                    id: emptyIcon

                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Wallhaven.searching ? "progress_activity"
                        : Wallhaven.error !== "" ? "cloud_off"
                        : Wallhaven.answered ? "search_off" : "travel_explore"
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 26
                    color: Wallhaven.error !== "" ? Colors.error : Colors.fgSurfaceVariant

                    RotationAnimation on rotation {
                        running: Wallhaven.searching && Wallhaven.items.count === 0
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 900
                        onStopped: emptyIcon.rotation = 0
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Wallhaven.searching ? "Suche auf wallhaven.cc…"
                        : Wallhaven.error !== "" ? Wallhaven.error
                        : Wallhaven.answered ? "Keine Treffer" : "Tippen, um zu suchen"
                    font.family: Config.font
                    font.pixelSize: 12
                    color: Wallhaven.error !== "" ? Colors.error : Colors.fgSurfaceVariant
                }
            }
        }
    }
}
