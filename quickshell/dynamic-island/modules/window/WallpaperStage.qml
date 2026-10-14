pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.services.config
import qs.modules.services.wallpaper

// Hintergrundbild eines Monitors samt Uebergang beim Wechsel.
//
// Zwei Ebenen (WallpaperPlane): das neue Bild laedt unsichtbar in der
// hinteren, und erst wenn es fertig dekodiert ist, wird sie zur vorderen und
// spielt den Uebergang ueber dem alten Bild ab. Danach wird das alte frei.
//
// Welches Bild gilt, sagt der Wallpapers-Dienst: das gesetzte oder – waehrend
// man in der Auswahl blaettert – das vorgeschaute. Welche Animation, sagt
// Config.wallpaper.transition (Auswahl im Wallpaper-Panel und im Menue).
//
// Frueher hing der Hintergrund hier manchmal auf einem alten Bild: kam der
// Pfad auf ein Bild zurueck, das die verdeckte Ebene noch fertig geladen
// hatte, aenderte sich ihr `status` nicht mehr – das Signal, auf das der
// Wechsel wartete, kam also nie. Jetzt wird nach dem Laden ausdruecklich
// nachgesehen (`ready`), statt nur auf Signale zu hoffen.
Item {
    id: stage

    // In dieser Groesse dekodieren (Monitoraufloesung)
    property size decodeSize

    readonly property string path: Wallpapers.current

    property Item front: planeA
    readonly property Item back: stage.front === planeA ? planeB : planeA

    property string kind: "blende"
    property real progress: 1
    readonly property bool transitioning: anim.running

    clip: true

    onPathChanged: stage.show(stage.path)
    Component.onCompleted: stage.show(stage.path)

    function show(p: string): void {
        if (p === "")
            return;

        if (anim.running) {
            anim.stop();
            // Zurueck aufs alte Bild (Escape mitten im Vorschau-Uebergang):
            // abbrechen, das alte liegt ja noch fertig darunter
            if (stage.back.path === p) {
                stage.front = stage.back;
                stage.settle();
                return;
            }
            // Sonst den laufenden Uebergang abschliessen – unten wuerde gleich
            // das Bild getauscht, das gerade noch durchscheint
            stage.settle();
        }

        if (stage.front.path === p) {
            // Ein anderes Bild, das hinten noch laedt, wird nicht mehr gebraucht
            stage.back.load("");
            return;
        }

        stage.back.load(p);
        if (stage.back.ready)
            stage.begin();
        // sonst geht es in planeReady weiter, sobald das Bild dekodiert ist
    }

    function planeReady(plane: Item): void {
        if (plane === stage.back && plane.path === stage.path && !anim.running)
            stage.begin();
    }

    function begin(): void {
        const incoming = stage.back;
        // Beim Start der Shell gibt es noch kein altes Bild – einfach einblenden
        const first = stage.front.path === "";
        stage.kind = first ? "blende" : Wallpapers.transitionFor(incoming.path);
        stage.front = incoming;

        const full = Math.max(0, Config.wallpaper.duration);
        // Beim Blaettern in der Auswahl kurz halten, sonst laeuft jeder
        // Pfeiltastendruck hinter der letzten Animation her
        stage.play(Wallpapers.showPreview ? Math.min(full, 350) : full);
    }

    // Vorfuehrung (Klick auf einen Uebergang in der Auswahl): das aktuelle
    // Bild noch einmal ueber dem leeren Hintergrund aufbauen
    function replay(): void {
        if (anim.running) {
            anim.stop();
            stage.settle();
        }
        if (!stage.front.ready)
            return;
        stage.back.load("");
        stage.kind = Wallpapers.transitionFor(stage.front.path);
        stage.play(Math.max(300, Config.wallpaper.duration));
    }

    function play(duration: int): void {
        if (stage.kind === "aus" || duration <= 0) {
            stage.settle();
            return;
        }

        stage.progress = 0;
        anim.duration = duration;
        anim.easing.type = stage.kind === "blende" || stage.kind === "zoom" ? Easing.OutCubic
                                                                           : Easing.InOutCubic;
        anim.restart();
    }

    Connections {
        target: Wallpapers

        function onReplayRequested(): void {
            stage.replay();
        }
    }

    // Uebergang fertig: vorne steht das neue Bild, das alte wird freigegeben
    function settle(): void {
        stage.progress = 1;
        stage.back.load("");
    }

    NumberAnimation {
        id: anim

        target: stage
        property: "progress"
        from: 0
        to: 1
        onFinished: stage.settle()
    }

    WallpaperPlane {
        id: planeA

        decodeSize: stage.decodeSize
        isFront: stage.front === planeA
        transitioning: stage.transitioning
        kind: stage.kind
        progress: stage.progress
        onReadyChanged: if (ready) stage.planeReady(planeA)
    }

    WallpaperPlane {
        id: planeB

        decodeSize: stage.decodeSize
        isFront: stage.front === planeB
        transitioning: stage.transitioning
        kind: stage.kind
        progress: stage.progress
        onReadyChanged: if (ready) stage.planeReady(planeB)
    }
}
