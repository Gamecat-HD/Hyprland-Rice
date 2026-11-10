pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import qs.modules.services.config
import qs.modules.services.wallpaper
import qs.modules.settings
import qs.modules.widgets

import qs

// Kopf der Seite "Wallpaper" im Einstellungs-Fenster (Config.meta editor
// "wallpaperhero", Zeile wallpaper.hero): das gesetzte Bild gross, daneben
// Name, Ordner, Zaehler und der Zufalls-Timer als Chip, darunter die
// Knoepfe – wie die Kopfzeile bei Caelestia.
//
// Nur das Vorschaubild (Wallpapers.displayThumbFor, 480x270 aus thumbs.sh,
// notfalls das der CLI), nie das Original: Qt dekodiert alle Bilder in einem
// Thread, ein grosses PNG staut sonst die ganze Shell. Beim Wechsel blenden
// zwei Bildplaetze ueber; das neue kommt erst nach vorn, wenn es geladen ist.
//
// Zufall bleibt auf der Seite – man sieht das neue Bild oben auftauchen.
// "Bibliothek" springt zur Seite @wallpapers (WallpaperManager) im selben
// Fenster. Die Zeile oben ist breit (SettingsCard.wideEditors), unter
// ~640 px rueckt der Text unter das Bild.
Item {
    id: hero

    readonly property string path: Wallpapers.actualCurrent
    // "Zufall aus diesem Ordner" nur, wenn das Bild in einem Unterordner
    // liegt und dort noch ein anderes zu finden ist
    readonly property bool folderShuffle: Wallpapers.currentDir !== "" && Wallpapers.currentDirCount > 1

    // In der Bibliothek (WallpaperManager): ohne Bibliothek-Knopf, Klick
    // aufs Bild meldet previewTapped (die Seite oeffnet den Ordner)
    property bool inLibrary: false
    property int maxPreview: 480
    signal previewTapped()

    readonly property bool stacked: hero.width < 640
    readonly property real previewWidth: hero.stacked ? Math.min(hero.width, hero.maxPreview)
                                                      : Math.max(Math.min(300, hero.maxPreview), Math.min(hero.maxPreview, Math.round(hero.width * 0.5)))
    readonly property real previewHeight: Math.round(hero.previewWidth / 16 * 9)

    implicitHeight: (hero.stacked ? hero.previewHeight + 16 + info.implicitHeight
                                  : Math.max(hero.previewHeight, info.implicitHeight)) + 10

    function shuffle(): void {
        Wallpapers.random();
    }

    function shuffleFolder(): void {
        Wallpapers.randomIn(Wallpapers.currentDir);
    }

    // Ordner des Bilds; liegt es ausserhalb des Wallpaper-Ordners, dessen
    // eigener (wie die Ordnerzeile anzeigt). Danach das Fenster zu – es
    // laege sonst ueber dem Dateimanager (wie in WallpaperManager).
    function openFolder(): void {
        const outside = hero.path !== "" && Wallpapers.nameFor(hero.path) === "";
        Wallpapers.openFolder(outside ? hero.path.slice(0, hero.path.lastIndexOf("/")) : Wallpapers.currentDir);
        SettingsState.close();
    }

    // Seite wechseln, das Fenster bleibt offen (SettingsCard reagiert auf
    // die Aenderung von SettingsState.request)
    function openLibrary(): void {
        SettingsState.openPage("@wallpapers", {});
    }

    // Zufalls-Timer an/aus. "start" (einmal je Login) zaehlt als aus – der
    // Chip meint nur den Timer; die feine Wahl steht in den Zeilen darunter.
    function toggleRandomTimer(): void {
        Config.set("wallpaper", "random", Config.wallpaper.random === "timer" ? "aus" : "timer");
    }

    // ---- Das Bild ----
    Item {
        id: frame

        anchors {
            left: parent.left
            top: parent.top
            topMargin: 4
        }
        width: hero.previewWidth
        height: hero.previewHeight

        readonly property string wanted: Wallpapers.displayThumbFor(hero.path)
        // Welcher Platz vorn liegt (0 = slotA)
        property int front: 0
        readonly property var frontSlot: frame.front === 0 ? slotA : slotB
        readonly property var backSlot: frame.front === 0 ? slotB : slotA
        readonly property bool shown: frame.frontSlot.key !== "" && frame.frontSlot.status === Image.Ready

        // Neues Bild in den hinteren Platz laden; nach vorn kommt es erst,
        // wenn es fertig ist (ready) – so bleibt das alte bis dahin stehen
        function load(): void {
            if (frame.frontSlot.key === frame.wanted)
                return;
            frame.backSlot.key = frame.wanted;
            frame.backSlot.source = frame.wanted;
            if (frame.wanted === "")
                frame.front = 1 - frame.front;
        }

        function ready(slot: var): void {
            if (slot === frame.backSlot && slot.status === Image.Ready && slot.key === frame.wanted)
                frame.front = 1 - frame.front;
        }

        onWantedChanged: frame.load()
        Component.onCompleted: frame.load()

        // Platzhalter, solange (noch) kein Vorschaubild da ist
        Rectangle {
            anchors.fill: parent
            radius: 14
            color: Colors.surfaceContainer

            Text {
                anchors.centerIn: parent
                text: "image"
                font.family: "Material Symbols Outlined"
                font.pixelSize: 34
                color: Colors.fgSurfaceVariant
                opacity: frame.shown ? 0 : 1

                Fade on opacity {}
            }
        }

        Item {
            id: images

            anchors.fill: parent
            visible: false          // nur Quelle fuer die Maske
            layer.enabled: true

            Image {
                id: slotA

                property string key: ""

                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                opacity: frame.front === 0 ? 1 : 0
                onStatusChanged: frame.ready(slotA)

                Fade on opacity {}
            }

            Image {
                id: slotB

                property string key: ""

                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                opacity: frame.front === 1 ? 1 : 0
                onStatusChanged: frame.ready(slotB)

                Fade on opacity {}
            }
        }

        Item {
            id: mask

            anchors.fill: parent
            layer.enabled: true
            visible: false

            Rectangle {
                anchors.fill: parent
                radius: 14
                color: "black"
            }
        }

        MultiEffect {
            anchors.fill: images
            source: images
            maskEnabled: true
            maskSource: mask
            shadowEnabled: Appearance.shadow
            shadowColor: Appearance.shadowColor
            shadowOpacity: 0.45
            shadowBlur: 0.8
            shadowVerticalOffset: 3
        }

        // Feiner Rand obendrauf; beim Zeigen etwas heller (Klick = Bibliothek)
        Rectangle {
            anchors.fill: parent
            radius: 14
            color: "transparent"
            border.width: 1
            border.color: frameHover.hovered ? Colors.alpha(Colors.primary, 0.6) : Appearance.borderColor

            Behavior on border.color {
                ColorAnimation { duration: Appearance.fadeDuration }
            }
        }

        HoverHandler {
            id: frameHover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: hero.inLibrary ? hero.previewTapped() : hero.openLibrary()
        }
    }

    // ---- Name, Ordner, Zaehler, Chip und Knoepfe ----
    Column {
        id: info

        anchors {
            left: hero.stacked ? parent.left : frame.right
            leftMargin: hero.stacked ? 0 : 22
            right: parent.right
            top: hero.stacked ? frame.bottom : frame.top
            topMargin: hero.stacked ? 16 : 2
        }
        spacing: 4

        Text {
            width: parent.width
            text: hero.path !== "" ? Wallpapers.titleFor(hero.path) : I18n.tr("Kein Wallpaper gesetzt")
            font.family: Config.font
            font.pixelSize: 19
            font.weight: Font.DemiBold
            color: Colors.fgBackground
            elide: Text.ElideRight
        }

        Row {
            width: parent.width
            spacing: 5

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "folder"
                font.family: "Material Symbols Outlined"
                font.pixelSize: 14
                color: Colors.fgSurfaceVariant
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 19
                text: Wallpapers.folderFor(hero.path) || I18n.tr("Wallpaper-Ordner")
                font.family: Config.font
                font.pixelSize: 12
                color: Colors.fgSurfaceVariant
                elide: Text.ElideRight
            }
        }

        Item {
            width: 1
            height: 6
        }

        Row {
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Wallpapers.loading && Wallpapers.list.length === 0 ? I18n.tr("Lade…")
                    : Wallpapers.list.length === 1 ? I18n.tr("1 Bild") : I18n.tr("%1 Bilder").arg(Wallpapers.list.length)
                font.family: Config.font
                font.pixelSize: 12
                color: Colors.fgSurfaceVariant
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "·"
                font.family: Config.font
                font.pixelSize: 12
                color: Colors.fgSurfaceVariant
            }

            // Zufalls-Timer: Klick schaltet ihn an/aus (toggleRandomTimer)
            HeroButton {
                anchors.verticalCenter: parent.verticalCenter
                implicitHeight: 24
                icon: Config.wallpaper.random === "timer" ? "timer" : "shuffle"
                label: Config.wallpaper.random === "timer" ? I18n.tr("Zufall alle %1 min").arg(Config.wallpaper.randomMinutes)
                     : Config.wallpaper.random === "start" ? I18n.tr("Zufall beim Start")
                     : I18n.tr("Zufall aus")
                on: Config.wallpaper.random === "timer"
                onClicked: hero.toggleRandomTimer()
            }
        }

        Item {
            width: 1
            height: 14
        }

        // Zufall (aus allen | aus dem Ordner des aktuellen)
        Row {
            spacing: 4

            HeroButton {
                big: true
                filled: true
                icon: "shuffle"
                label: I18n.tr("Zufall")
                onClicked: hero.shuffle()
            }

            HeroButton {
                visible: hero.folderShuffle
                big: true
                tonal: true
                icon: "folder"
                label: I18n.tr("aus Ordner")
                onClicked: hero.shuffleFolder()
            }
        }

        Item {
            width: 1
            height: 4
        }

        // Ordner, Neu laden, Bibliothek – bricht um, wenn es eng wird
        Flow {
            width: parent.width
            spacing: 6

            HeroButton {
                icon: "folder_open"
                label: I18n.tr("Ordner öffnen")
                onClicked: hero.openFolder()
            }

            HeroButton {
                icon: Wallpapers.loading ? "progress_activity" : "refresh"
                label: I18n.tr("Neu laden")
                spinning: Wallpapers.loading
                onClicked: Wallpapers.reload()
            }

            HeroButton {
                visible: !hero.inLibrary
                icon: "photo_library"
                label: I18n.tr("Bibliothek")
                onClicked: hero.openLibrary()
            }
        }
    }
}
