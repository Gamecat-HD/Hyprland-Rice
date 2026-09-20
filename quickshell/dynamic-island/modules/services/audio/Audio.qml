pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Zentrale Audio-Quelle: der Default-Sink von PipeWire, live getrackt.
// Verbraucher (Audioslider, Icons, ...) lesen nur noch Audio.volume /
// Audio.muted – das Pipewire-Handling lebt komplett hier.
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false

    function setVolume(value: real): void {
        if (sink?.audio)
            sink.audio.volume = Math.max(0, Math.min(1, value));
    }

    function toggleMute(): void {
        if (sink?.audio)
            sink.audio.muted = !sink.audio.muted;
    }

    // Macht die PipeWire-Objekt-Properties live beobachtbar
    PwObjectTracker {
        objects: [root.sink].filter(n => n)
    }
}
