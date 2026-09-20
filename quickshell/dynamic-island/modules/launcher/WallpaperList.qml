pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import qs.modules.services.wallpaper

import "root:/"

// Wallpaper-Auswahl im Launcher: ein Karussell aus Vorschaubildern, das
// aktuelle steht in der Mitte.
//
// Aufbau wie caelestia/modules/launcher/WallpaperList.qml – PathView auf einer
// geraden Linie, mittiger Highlight-Bereich, die Nachbarn kleiner und die
// Aussenseiter ausgeblendet. Die Liste selbst kommt aus dem Wallpapers-Dienst.
//
// Waehrend man sich durchbewegt, zeigt der Hintergrund das markierte Bild
// schon an (Vorschau) – aber erst nach kurzem Verweilen, sonst dekodiert Qt
// bei jedem Tastendruck ein 2560x1440-Bild.
PathView {
    id: view

    property string query: ""
    // Wird gesetzt, wenn ein Bild uebernommen wurde (der Launcher schliesst dann)
    signal applied

    readonly property real imageWidth: 180
    readonly property real imageHeight: Math.round(imageWidth / 16 * 9)
    readonly property real itemPadding: 8
    readonly property real itemWidth: imageWidth + itemPadding * 2

    readonly property var entries: Wallpapers.search(view.query)
    readonly property string currentPath: view.entries[view.currentIndex]?.path ?? ""

    // Immer eine ungerade Zahl: sonst sitzt kein Bild wirklich in der Mitte.
    readonly property int visibleItems: {
        const fits = Math.floor(view.width / view.itemWidth);
        if (fits <= 1)
            return 1;
        return fits % 2 === 0 ? fits - 1 : fits;
    }

    function moveBy(delta: int): void {
        if (view.count === 0)
            return;
        view.currentIndex = (view.currentIndex + delta + view.count) % view.count;
    }

    // Uebernehmen: Bild setzen und Bescheid geben
    function apply(): void {
        if (view.currentPath === "")
            return;
        Wallpapers.set(view.currentPath);
        view.applied();
    }

    implicitHeight: view.itemPadding + view.imageHeight + 4 + 15 + view.itemPadding

    model: view.entries
    pathItemCount: view.visibleItems
    cacheItemCount: 2

    snapMode: PathView.SnapToItem
    preferredHighlightBegin: 0.5
    preferredHighlightEnd: 0.5
    highlightRangeMode: PathView.StrictlyEnforceRange
    highlightMoveDuration: 180

    // Beim Aufbau auf dem aktuell gesetzten Bild stehen, bei einer Suche vorne.
    //
    // Per callLater, weil an derselben Aenderung auch das Modell haengt: setzt
    // man den Index direkt, stellt PathView ihn beim Modellwechsel gleich
    // wieder auf 0 – das Karussell stand dann immer auf dem ersten Bild statt
    // auf dem aktuellen.
    function selectCurrent(): void {
        if (view.count === 0)
            return;
        view.currentIndex = view.query.trim() !== "" ? 0
            : Math.max(0, view.entries.findIndex(w => w.path === Wallpapers.actualCurrent));
        // currentIndex allein reicht nicht: der Versatz des Karussells bleibt
        // nach einem Modellwechsel stehen, das markierte Bild sass dann neben
        // der Mitte statt darin. SnapPosition zieht es auf den Highlight-Platz.
        view.positionViewAtIndex(view.currentIndex, PathView.SnapPosition);
    }

    onEntriesChanged: Qt.callLater(view.selectCurrent)

    Component.onCompleted: {
        Wallpapers.ensureLoaded();
        Qt.callLater(view.selectCurrent);
    }
    // Der Launcher hat die Auswahl verlassen -> Hintergrund zurueck auf echt
    Component.onDestruction: Wallpapers.stopPreview()

    onCurrentIndexChanged: previewTimer.restart()

    Timer {
        id: previewTimer

        interval: 220
        onTriggered: if (view.currentPath !== "")
            Wallpapers.preview(view.currentPath)
    }

    // Mausrad blaettert durchs Karussell. Hi-Res-Raeder liefern Bruchteile
    // einer Rastung, deshalb aufsummieren (gleiches Muster wie im DatePanel).
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

        property real accum: 0

        onWheel: event => {
            const angle = event.angleDelta.y + event.angleDelta.x;
            const pixels = event.pixelDelta.y + event.pixelDelta.x;
            accum += angle !== 0 ? angle / 120 : pixels / 40;

            const steps = accum > 0 ? Math.floor(accum) : Math.ceil(accum);
            if (steps !== 0) {
                accum -= steps;
                view.moveBy(-steps);
            }
            event.accepted = true;
        }
    }

    path: Path {
        startY: view.height / 2

        PathAttribute {
            name: "itemZ"
            value: 0
        }
        PathLine {
            x: view.width / 2
            relativeY: 0
        }
        PathAttribute {
            name: "itemZ"
            value: 1
        }
        PathLine {
            x: view.width
            relativeY: 0
        }
    }

    delegate: Item {
        id: item

        required property int index
        required property var modelData

        readonly property bool isCurrent: PathView.isCurrentItem
        readonly property bool onPath: PathView.onPath

        width: view.itemWidth
        height: view.implicitHeight
        z: PathView.itemZ ?? 0

        scale: item.isCurrent ? 1 : item.onPath ? 0.86 : 0.5
        opacity: item.onPath ? 1 : 0

        Behavior on scale {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }
        Behavior on opacity {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        HoverHandler {
            id: hover

            cursorShape: Qt.PointingHandCursor
            onHoveredChanged: if (hovered)
                view.currentIndex = item.index
        }

        TapHandler {
            onTapped: {
                view.currentIndex = item.index;
                view.apply();
            }
        }

        // Rahmen + Platzhalter, solange das Bild noch laedt
        Rectangle {
            id: frame

            anchors.horizontalCenter: parent.horizontalCenter
            y: view.itemPadding

            width: view.imageWidth
            height: view.imageHeight
            radius: 12
            color: Colors.surfaceContainer
            border.width: item.isCurrent ? 2 : 0
            border.color: Colors.primary

            Behavior on border.width {
                NumberAnimation { duration: 140 }
            }

            Text {
                anchors.centerIn: parent
                visible: thumb.status !== Image.Ready

                text: "image"
                color: Colors.fgSurfaceVariant
                font.family: "Material Symbols Outlined"
                font.pixelSize: 22
            }

            Image {
                id: thumb

                anchors.fill: parent
                anchors.margins: frame.border.width

                source: `file://${item.modelData.path}`
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                // Vorschaugroesse statt Originalaufloesung: sonst haelt Qt je
                // Kachel ein 2560x1440-Bild im Speicher.
                sourceSize.width: view.imageWidth * 2
                sourceSize.height: view.imageHeight * 2
                smooth: !view.moving
                visible: false          // nur Quelle fuer die Maske
            }

            Item {
                id: thumbMask

                anchors.fill: thumb
                layer.enabled: true
                visible: false

                Rectangle {
                    anchors.fill: parent
                    radius: frame.radius - frame.border.width
                    color: "black"
                }
            }

            // Runde Ecken gehen nur ueber eine Maske – `clip` schneidet
            // rechteckig (siehe Cover im MediaPanel).
            MultiEffect {
                anchors.fill: thumb
                visible: thumb.status === Image.Ready

                source: thumb
                maskEnabled: true
                maskSource: thumbMask
            }
        }

        Text {
            anchors {
                top: frame.bottom
                topMargin: 4
                horizontalCenter: parent.horizontalCenter
            }
            width: view.imageWidth

            text: item.modelData.name
            color: item.isCurrent ? Colors.fgSurface : Colors.fgSurfaceVariant
            font.pixelSize: 11
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
    }
}
