pragma ComponentBehavior: Bound
import QtQuick

import qs
import qs.modules.services.audio

// Kleiner Audio-Visualiser aus Cava-Pegeln – fuer die Medien-Pille und die
// Live-Activity der Notch.
//
//     Visualizer { count: 5; barWidth: 3; height: 16; active: Media.playing }
//
// Gespiegelt wie eine Wellenform: der Bass sitzt in der Mitte, nach aussen
// folgen die hoeheren Baender, die Balken wachsen aus der Mitte nach oben und
// unten. Fruehere Fassung mittelte linear ueber alle 36 Baender – die oberen
// Gruppen sind bei Musik fast immer leer, es bewegte sich nur ein Balken.
// Hier werden nur die unteren `range` der Baender genutzt und die hoeheren
// Positionen verstaerkt.
//
// Ohne Wiedergabe (`active: false`) stehen die Balken als ruhiger Bogen und
// gedimmt da, statt zu einer Punktreihe zusammenzufallen.
Item {
    id: root

    property int count: 5
    property real barWidth: 3
    property real spacing: 2
    property color color: Colors.primary
    // Laeuft Musik? Steuert Pegel vs. Ruhebogen
    property bool active: true
    // Anteil der Cava-Baender, der ueberhaupt angezeigt wird (von unten)
    property real range: 0.7
    // Verstaerkung je Schritt von der Mitte nach aussen (Hoehen sind leiser)
    property real tilt: 0.45

    // Positionen von der Mitte aus: bei 5 Balken 0 (Mitte), 1, 2
    readonly property int positions: Math.ceil(root.count / 2)

    implicitWidth: root.count * root.barWidth + (root.count - 1) * root.spacing
    implicitHeight: 16

    // Pegel einer Position, 0..1
    function level(pos: int): real {
        const vals = Cava.values;
        const usable = Math.max(root.positions, Math.floor(vals.length * root.range));
        const size = usable / root.positions;
        const from = Math.floor(pos * size);
        const to = Math.max(from + 1, Math.floor((pos + 1) * size));

        let sum = 0;
        for (let k = from; k < to && k < vals.length; k++)
            sum += vals[k];
        const avg = sum / (to - from);
        // Leise Pegel anheben, damit auch ruhige Stellen sichtbar arbeiten
        return Math.min(1, Math.pow(avg * (1 + pos * root.tilt), 0.6));
    }

    Repeater {
        model: root.count

        Rectangle {
            id: bar

            required property int index

            readonly property int pos: Math.round(Math.abs(bar.index - (root.count - 1) / 2))
            // Ruhebogen: Mitte am hoechsten, aussen flacher
            readonly property real idle: root.positions > 1
                ? 0.5 - 0.28 * bar.pos / (root.positions - 1)
                : 0.4
            // Nur sichtbare Balken folgen cava: `visible` ist die effektive
            // Sichtbarkeit (auch versteckte Eltern zaehlen). Versteckte
            // Visualiser (Pille im Notch-Layout, zugeklappte Uebersicht)
            // rechnen und animieren sonst 30x pro Sekunde fuer niemanden.
            readonly property real value: root.active && root.visible ? root.level(bar.pos) : bar.idle

            x: bar.index * (root.barWidth + root.spacing)
            y: (root.height - height) / 2
            width: root.barWidth
            height: Math.max(root.barWidth, bar.value * root.height)
            radius: root.barWidth / 2
            color: root.color
            opacity: root.active ? 1 : 0.4

            // Nur der Wechsel in den Ruhebogen wird animiert. Beim Spielen
            // folgen die Balken cava direkt: eine 90-ms-Animation je Frame
            // lief bei 30 cava-Frames/s ohne Pause und liess das ganze
            // Leistenfenster mit der Monitorrate (180 Hz) neu zeichnen statt
            // mit 30 Hz.
            Behavior on height {
                enabled: root.visible && !root.active
                NumberAnimation { duration: Appearance.morphDuration; easing.type: Easing.OutCubic }
            }
            Behavior on opacity {
                NumberAnimation { duration: Appearance.fadeDuration }
            }
        }
    }
}
