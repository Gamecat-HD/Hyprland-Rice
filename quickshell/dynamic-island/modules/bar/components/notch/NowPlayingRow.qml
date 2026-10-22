pragma ComponentBehavior: Bound
import QtQuick

import qs
import qs.modules.services.media

// "Jetzt laeuft" in der aufgeklappten Notch (Uebersicht): Cover, Titel und
// Interpret, Visualiser, Play/Pause. Nur da, solange es einen Player gibt –
// alles Weitere (Player-Auswahl, Fortschritt, Vor/Zurueck) steht im
// Medien-Untermenue (SUPER+M bzw. blaettern).
//
// Wisch-Geste der Notch (swipe in Notch.qml): die ganze Karte folgt dem
// Zeiger (`shift`), daneben haengt eine zweite Karte (ghost) im selben Look,
// die mit hereingezogen wird. Kennt MediaQueue die Warteschlange (Spotify),
// zeigt sie den naechsten bzw. vorigen Titel samt Cover und Blend; sonst
// bleibt sie leer und traegt nur den aktuellen Blend. `pull` ist der
// Fortschritt bis zur Schwelle, -1..1 (negativ = nach links = naechster
// Titel).
//
// Beim Wechsel (skipSong → commit) faehrt die zweite Karte ganz herein,
// dann springt alles ohne Animation auf 0 zurueck. Damit der Sprung nicht
// auffaellt, zeigt die echte Karte an dieser Stelle schon den neuen Titel
// aus dem Schnappschuss (`flipTo`) – MPRIS hinkt dem Wechsel ein paar
// hundert Millisekunden hinterher. Erst wenn Media nachgezogen hat (oder
// nach einer Frist), uebernimmt wieder der Live-Stand.
Item {
    id: root

    property real shift: 0
    property real pull: 0
    // Kartenfarbe, in die der Cover-Hintergrund nach rechts ausblendet
    property color fadeColor: Appearance.notchColor
    // Abstand zur zweiten Karte; so weit muss `shift` beim Wechsel laufen
    readonly property real gap: 16
    readonly property real flipDistance: root.width + root.gap
    // Zweite Karte rechts (naechster) oder links (voriger)
    readonly property real ghostSide: root.pull < 0 ? 1 : -1

    // ---- Was die Karten zeigen ----
    // Titel-Objekte wie aus MediaQueue: { title, artist, art }. `live` ist
    // der MPRIS-Stand, alles andere sind Schnappschuesse.
    readonly property var live: ({ title: Media.title, artist: Media.artist, art: Media.art })

    // Nachbar fuer die zweite Karte, beim ersten Zug eingefroren: die Queue
    // rechnet nach dem Wechsel um (bzw. ist kurz ungueltig), die Karte darf
    // mitten in der Fahrt nicht umspringen. null = Queue unbekannt (leer).
    property var ghostTrack: null
    property int ghostTrackSide: 0

    // Uebergabe beim Wechsel (siehe Kopfkommentar)
    property var flipFrom: null    // alter Titel, solange die echte Karte hinausfaehrt
    property var flipTo: null      // neuer Titel, bis Media nachgezogen hat
    readonly property var shown: root.flipFrom ?? root.flipTo ?? root.live

    // Media hat den neuen Titel samt Cover: Schnappschuss nicht mehr noetig.
    // Ohne das Cover-Kriterium blitzte kurz der Platzhalter auf, weil
    // Media.art beim Titelwechsel erst leer ist und dann aus dem Cache kommt.
    readonly property bool caughtUp: !!root.flipTo && Media.title === root.flipTo.title && Media.art !== ""
    // Entkoppelt per callLater: flipTo direkt im Handler zu leeren wertet
    // caughtUp mitten in seiner eigenen Auswertung neu aus (Binding-Loop)
    onCaughtUpChanged: {
        if (root.caughtUp) {
            catchUp.stop();
            Qt.callLater(() => root.flipTo = null);
        }
    }

    // Frist, falls Media nie passt (anderer Player, Titel weicht ab)
    Timer {
        id: catchUp

        interval: 1500
        onTriggered: root.flipTo = null
    }

    implicitHeight: 52

    onPullChanged: {
        if (root.pull === 0) {
            // Zug vorbei (zurueckgeschnappt oder Wechsel durch): zweite Karte
            // weg, die echte zeigt ab jetzt flipTo bzw. den Live-Stand
            root.ghostTrack = null;
            root.ghostTrackSide = 0;
            root.flipFrom = null;
            return;
        }
        const sideChanged = root.ghostTrackSide !== root.ghostSide;
        // Waehrend des Wechsels steht der Schnappschuss fest – es sei denn,
        // der Zug wurde unterbrochen und laeuft in die andere Richtung
        if (root.flipFrom && !sideChanged)
            return;
        // Nachladen, solange das Cover der Queue noch fehlt (laedt gerade)
        if (sideChanged || !root.ghostTrack || !root.ghostTrack.art) {
            const next = MediaQueue.valid
                ? (root.ghostSide > 0 ? MediaQueue.upcoming : MediaQueue.previous)
                : null;
            root.ghostTrackSide = root.ghostSide;
            if (next !== root.ghostTrack)
                root.ghostTrack = next;
        }
    }

    // Vom Wechsel (Notch.skipSong) aufgerufen, bevor die zweite Karte ganz
    // hereinfaehrt: alter Titel bleibt auf der hinausfahrenden Karte, der
    // neue kommt vom Schnappschuss – auch wenn Media schon unterwegs umspringt.
    function commit(): void {
        root.flipFrom = root.shown;
        root.flipTo = root.ghostTrack;
        if (root.flipTo && !root.caughtUp)
            catchUp.restart();
        else {
            root.flipTo = null;
            catchUp.stop();
        }
    }

    // ---- Zweite Karte: naechster / voriger Titel ----
    // Haengt neben der echten Karte und faehrt mit `shift` herein. Solange
    // nichts gezogen wird, liegt sie ausserhalb der Notch-Karte (die clippt).
    NowPlayingCard {
        id: ghost

        x: root.ghostSide * root.flipDistance
        width: root.width
        height: root.height
        transform: Translate { x: root.shift }
        visible: root.pull !== 0
        opacity: 0.45 + 0.55 * Math.abs(root.pull)
        fadeColor: root.fadeColor
        track: root.ghostTrack
    }

    // ---- Echte Karte: gleitet als Ganzes mit dem Zeiger ----
    NowPlayingCard {
        id: card

        anchors.fill: parent
        transform: Translate { x: root.shift }
        live: true
        fadeColor: root.fadeColor
        track: root.shown
    }
}
