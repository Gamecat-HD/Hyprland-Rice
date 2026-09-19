pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

// Farb-Singleton – überall per `Colors.<rolle>` nutzbar.
//
// Zwei Quellen:
// 1. DYNAMISCH (Standard): ~/.local/state/caelestia/scheme.json – die Caelestia-CLI
//    extrahiert daraus eine Material-You-Palette direkt aus dem Wallpaper und
//    schreibt die Datei bei jedem Wallpaper-Wechsel neu. Diese Shell watcht sie
//    und färbt sich live um (gleicher Mechanismus wie Caelestias Colours.qml).
// 2. STATISCH (Fallback): themes/<name>.json – aktiver Name in themes/current.
//    Wird genutzt, wenn useDynamic = false ist oder scheme.json (noch) fehlt /
//    einen Key nicht enthält.
//
// Rollen: "fg*" = Text/Icon auf der jeweiligen Fläche (bewusst nicht "on*", QML liest das als Signal-Handler).
Singleton {
    id: root

    readonly property string themeDir: Quickshell.env("HOME") + "/.config/quickshell/myshell/themes/"
    readonly property string schemePath: Quickshell.env("HOME") + "/.local/state/caelestia/scheme.json"

    // Auf false setzen, um statisch bei den themes/*.json zu bleiben
    property bool useDynamic: true

    // geparstes scheme.json ({name, mode, colours:{...}}) – {} wenn nicht geladen
    property var scheme: ({})
    readonly property bool dynamicActive: useDynamic && scheme.name !== undefined

    // ---- Dynamische Quelle: scheme.json (wallpaper-basiert) ----
    FileView {
        id: schemeFile
        path: root.schemePath
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.loadScheme(text())
    }

    function loadScheme(data: string): void {
        try {
            const s = JSON.parse(data);
            if (s && s.colours)
                root.scheme = s;
        } catch (e) {
            console.warn("Colors: scheme.json unparsebar:", e);
        }
    }

    // Rollen-Auflösung: dynamisch, wenn vorhanden, sonst Fallback aus dem Theme
    function pick(key: string, fallback: color): color {
        const c = root.scheme.colours ? root.scheme.colours[key] : null;
        return c ? ("#" + c) : fallback;
    }

    // ---- Statische Quelle: Theme-Dateien ----
    FileView {
        id: currentFile
        path: root.themeDir + "current"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
    }
    readonly property string themeName: currentFile.text().trim() || "ink"

    // Theme-Datei; JsonAdapter-Defaults = Fallback, falls ein Key fehlt
    FileView {
        id: themeFile
        path: root.themeDir + root.themeName + ".json"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()

        adapter: JsonAdapter {
            id: t
            property string name: "Ink"
            property list<string> palette: ["#000A0F", "#FB1418", "#0ED2FC", "#0372DC", "#DE8673"]

            property string background: "#000A0F"
            property string surface: "#04141C"
            property string surfaceContainer: "#0B1F29"
            property string surfaceBright: "#153039"
            property string outline: "#3A5561"

            property string fgBackground: "#E0F4FA"
            property string fgSurfaceVariant: "#A9C2CC"

            property string primary: "#0ED2FC"
            property string fgPrimary: "#000A0F"
            property string primaryDim: "#036B85"

            property string secondary: "#0372DC"
            property string fgSecondary: "#EAF3FF"

            property string tertiary: "#DE8673"
            property string fgTertiary: "#000A0F"

            property string error: "#FB1418"
            property string fgError: "#FFF1F1"
        }
    }

    // ---- Öffentliche Rollen (dynamisch bevorzugt, Theme als Fallback) ----
    readonly property string name: dynamicActive ? (scheme.name ?? t.name) : t.name
    readonly property var palette: dynamicActive ? [
        pick("primaryPaletteKeyColor", t.palette[0]),
        pick("secondaryPaletteKeyColor", t.palette[1]),
        pick("tertiaryPaletteKeyColor", t.palette[2]),
        pick("errorPaletteKeyColor", t.palette[3]),
        pick("neutralPaletteKeyColor", t.palette[4])
    ] : t.palette   // 5 Basisfarben, z.B. für Verläufe

    readonly property color background: pick("background", t.background)
    readonly property color surface: pick("surface", t.surface)
    readonly property color surfaceContainer: pick("surfaceContainer", t.surfaceContainer)
    readonly property color surfaceBright: pick("surfaceBright", t.surfaceBright)
    readonly property color outline: pick("outline", t.outline)
    readonly property color outlineVariant: pick("outlineVariant", t.outline)   // dezente Border-Neutralfarbe (M3)

    readonly property color fgBackground: pick("onBackground", t.fgBackground)
    readonly property color fgSurface: pick("onSurface", t.fgBackground)
    readonly property color fgSurfaceVariant: pick("onSurfaceVariant", t.fgSurfaceVariant)

    readonly property color primary: pick("primary", t.primary)
    readonly property color fgPrimary: pick("onPrimary", t.fgPrimary)
    readonly property color primaryDim: pick("primaryDim", t.primaryDim)

    readonly property color secondary: pick("secondary", t.secondary)
    readonly property color fgSecondary: pick("onSecondary", t.fgSecondary)

    readonly property color tertiary: pick("tertiary", t.tertiary)
    readonly property color fgTertiary: pick("onTertiary", t.fgTertiary)

    readonly property color error: pick("error", t.error)
    readonly property color fgError: pick("onError", t.fgError)

    // Farbe mit Alpha, z.B. Colors.alpha(Colors.surface, 0.8)
    function alpha(c: color, a: real): color {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    // Farbe aufhellen (f > 0) bzw. abdunkeln (f < 0), z.B. Colors.shade(Colors.background, 0.06)
    function shade(c: color, f: real): color {
        return Qt.hsla(c.hslHue, c.hslSaturation,
                       Math.max(0, Math.min(1, c.hslLightness + f)), 1);
    }
}
