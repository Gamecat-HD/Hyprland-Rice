pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Zentrale PipeWire-Quelle fuer Lautstaerke und Geraeteauswahl.
Singleton {
    id: root

    property list<PwNode> sinks: []
    property list<PwNode> sources: []

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
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

    function setSink(node: PwNode): void {
        Pipewire.preferredDefaultAudioSink = node;
    }

    function setSource(node: PwNode): void {
        Pipewire.preferredDefaultAudioSource = node;
    }

    function nodeName(node: PwNode): string {
        if (!node)
            return "";
        return node.properties["node.name"] || node.name || "";
    }

    function deviceLabel(node: PwNode): string {
        if (!node)
            return "Unbekanntes Gerät";
        return node.properties["node.description"]
            || node.properties["device.description"]
            || node.properties["node.nick"]
            || node.description
            || node.nickname
            || node.name
            || "Unbekanntes Gerät";
    }

    function isSinkSelected(node: PwNode): bool {
        return node === root.sink || node?.id === root.sink?.id || (root.nodeName(node) !== ""
            && root.nodeName(node) === root.nodeName(root.sink));
    }

    function isSourceSelected(node: PwNode): bool {
        return node === root.source || node?.id === root.source?.id || (root.nodeName(node) !== ""
            && root.nodeName(node) === root.nodeName(root.source));
    }

    function refreshNodes(): void {
        const nextSinks = [];
        const nextSources = [];
        for (const node of Pipewire.nodes.values) {
            if (node.isStream || !node.audio)
                continue;
            if (node.isSink)
                nextSinks.push(node);
            else
                nextSources.push(node);
        }
        const byName = (a, b) => root.deviceLabel(a).localeCompare(root.deviceLabel(b));
        root.sinks = nextSinks.sort(byName);
        root.sources = nextSources.sort(byName);
    }

    Component.onCompleted: root.refreshNodes()

    Connections {
        target: Pipewire.nodes
        function onValuesChanged(): void { root.refreshNodes(); }
    }

    // Macht die PipeWire-Objekt-Properties live beobachtbar
    PwObjectTracker {
        objects: [root.sink, root.source, ...root.sinks, ...root.sources].filter(n => n)
    }
}
