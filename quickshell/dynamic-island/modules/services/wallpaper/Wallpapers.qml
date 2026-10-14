pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.services.config
import qs.modules.services.theme

import qs

// Wallpaper-Dienst: kennt die Bilder im Wallpaper-Ordner, das aktuell
// gesetzte und das gerade nur vorgeschaute.
//
// Vorbild ist caelestia/services/Wallpapers.qml – nur ohne dessen
// Caelestia.Models-Plugin (FileSystemModel gibt es hier nicht). Die Liste
// kommt stattdessen aus einem `find`; gescannt wird erst, wenn sie gebraucht
// wird (`ensureLoaded`, bei jedem Oeffnen der Auswahl - neue Bilder tauchen so
// ohne Neustart auf), damit der Start der Shell nichts davon merkt.
//
// Das Karussell zeigt nie die Originale, sondern kleine Vorschaubilder aus
// ~/.cache/dynamic-island/thumbs (thumbs.sh). Qt dekodiert alle Bilder der
// Shell in einem einzigen Thread; die Originale (bis 40 MB PNG) stauten
// dort alles, auch den Hintergrund – der hing dann auf dem alten Bild.
//
// Gesetzt wird ueber die CLI, nicht selbst: `dynamic-island wallpaper -f`
// schreibt den Pfad in den State, erzeugt die Material-You-Palette und legt
// scheme.json ab – woran wiederum Colors.qml haengt. Ein Wechsel faerbt also
// die ganze Shell mit um.
//
// Benutzung:  import qs.modules.services.wallpaper
Singleton {
    id: root

    // Denselben Ordner wie die CLI nehmen (utils/paths.py)
    readonly property string wallsDir: Quickshell.env("DYNAMIC_ISLAND_WALLPAPERS_DIR")
        || (Quickshell.env("HOME") + "/Pictures/Wallpapers")
    readonly property string statePath: Quickshell.env("HOME") + "/.local/state/dynamic-island/wallpaper/path.txt"
    // Absolut statt nur "dynamic-island": execDetached loest ueber die PATH des
    // Shell-Prozesses auf, und ob ~/.local/bin da drin steht, haengt an der
    // Session – hier nicht.
    readonly property string cli: Quickshell.env("HOME") + "/.local/bin/dynamic-island"
    readonly property string thumbsDir: Quickshell.env("HOME") + "/.cache/dynamic-island/thumbs"

    // [{ path, name }] – name ist der Pfad relativ zum Wallpaper-Ordner
    property var list: []
    property bool loaded: false
    property bool loading: false

    // Namen mit fertigem Vorschaubild ({ name: true }). Wird gesammelt neu
    // zugewiesen (siehe thumbFlush), damit nicht jede Zeile von thumbs.sh
    // alle Kacheln neu auswerten laesst.
    property var thumbs: ({})
    property var pendingThumbs: []

    // Tatsaechlich gesetzt (aus dem State) bzw. nur vorgeschaut (Auswahl im
    // Launcher). `current` ist das, was der Hintergrund anzeigen soll.
    property string actualCurrent: ""
    property string previewPath: ""
    property bool showPreview: false
    readonly property string current: root.showPreview && root.previewPath !== "" ? root.previewPath
                                                                                  : root.actualCurrent

    // ---- Uebergang ----
    // Welche Animation der Hintergrund beim Wechsel spielt (Config
    // wallpaper.transition). "zufall" wuerfelt – aber je Bild fest, damit
    // beide Monitore dieselbe zeigen, ohne sich abzusprechen.
    readonly property var transitions: ["blende", "wischen", "schieben", "kreis", "zoom"]

    // Den Uebergang einmal auf dem aktuellen Bild vorfuehren (WallpaperStage)
    signal replayRequested

    function replay(): void {
        root.replayRequested();
    }

    function transitionFor(path: string): string {
        const chosen = Config.wallpaper.transition;
        if (chosen !== "zufall")
            return chosen;
        let h = 0;
        for (let i = 0; i < path.length; i++)
            h = (h * 31 + path.charCodeAt(i)) | 0;
        return root.transitions[Math.abs(h) % root.transitions.length];
    }

    // ---- Liste ----
    function ensureLoaded(): void {
        if (!root.loading)
            root.reload();
    }

    function reload(): void {
        root.loading = true;
        scan.running = true;
        thumbGen.running = true;
    }

    // Vorschaubild zu einem Eintrag – leer, solange es noch nicht fertig ist.
    // Bewusst kein Rueckfall aufs Original, das wuerde den Stau zurueckholen.
    function thumbFor(name: string): string {
        return root.thumbs[name] ? `file://${root.thumbsDir}/${name}.jpg` : "";
    }

    // Dasselbe als Dateipfad fuer ein beliebiges Wallpaper (Helligkeitsmessung
    // in Appearance). Liegt das Bild ausserhalb des Ordners: das Original.
    function thumbPathFor(path: string): string {
        const prefix = root.wallsDir + "/";
        if (path.startsWith(prefix))
            return `${root.thumbsDir}/${path.slice(prefix.length)}.jpg`;
        return "";
    }

    function search(needle: string): var {
        const query = needle.trim().toLowerCase();
        if (query === "")
            return root.list;
        return root.list.filter(w => w.name.toLowerCase().includes(query));
    }

    // ---- Setzen ----
    function set(path: string): void {
        // Erst das neue Bild eintragen, dann die Vorschau beenden: andersherum
        // sprang `current` kurz aufs alte Bild zurueck, und der Hintergrund
        // blendete erst dorthin und dann wieder zum neuen.
        root.actualCurrent = path;          // sofort, der State zieht gleich nach
        root.stopPreview();
        Quickshell.execDetached([root.cli, "wallpaper", "-f", path]);
    }

    function random(): void {
        root.stopPreview();
        Quickshell.execDetached([root.cli, "wallpaper", "-r"]);
    }

    // ---- Vorschau ----
    // Bild und Farben: `wallpaper -p` rechnet die Palette aus, die das Bild
    // ergeben WUERDE, ohne etwas zu setzen (~90-230ms, danach aus dem Cache).
    // Colors traegt sie nur zur Anzeige, gespeichert wird nichts.
    //
    // Nur wenn das Schema ueberhaupt am Wallpaper haengt: bei einem festen
    // Schema (catppuccin, tokyonight, ...) aendert ein Bildwechsel die Farben
    // nicht, die Vorschau wuerde also etwas zeigen, was nie eintritt.
    function preview(path: string): void {
        root.previewPath = path;
        root.showPreview = true;

        if (Themes.currentName !== "dynamic")
            return;

        colourPreview.running = false;
        colourPreview.wall = path;
        colourPreview.running = true;
    }

    function stopPreview(): void {
        root.showPreview = false;
        root.previewPath = "";
        colourPreview.running = false;
        Colors.clearPreview();
    }

    Process {
        id: colourPreview

        property string wall: ""

        command: [root.cli, "wallpaper", "-p", colourPreview.wall]

        stdout: StdioCollector {
            onStreamFinished: {
                // Wer inzwischen weitergeblaettert oder zugemacht hat, soll
                // nicht die Farben von vorhin bekommen. Leer = der Prozess
                // wurde fuer das naechste Bild abgebrochen.
                if (text.trim() !== "" && root.showPreview && colourPreview.wall === root.previewPath)
                    Colors.loadPreview(text);
            }
        }
    }

    Process {
        id: scan

        // %P = Pfad ohne den Ordner davor. Versteckte Ordner fliegen raus,
        // sonst laendet das .git des Wallpaper-Repos mit in der Liste.
        command: ["find", root.wallsDir, "-type", "f", "-not", "-path", "*/.*",
            "(", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.png",
            "-o", "-iname", "*.webp", "-o", "-iname", "*.jxl", "-o", "-iname", "*.gif", ")",
            "-printf", "%P\n"]

        stdout: StdioCollector {
            onStreamFinished: {
                const entries = text.split("\n")
                    .map(line => line.trim())
                    .filter(line => line !== "")
                    .sort((a, b) => a.localeCompare(b))
                    .map(name => ({
                        path: `${root.wallsDir}/${name}`,
                        name
                    }));

                // Nur bei echter Aenderung neu zuweisen: das Karussell
                // springt bei jedem Modellwechsel zurueck auf das aktuelle Bild
                // – auch wenn man gleich nach dem Oeffnen schon blaettert.
                if (entries.map(e => e.name).join("\n") !== root.list.map(e => e.name).join("\n"))
                    root.list = entries;
                root.loaded = true;
                root.loading = false;
            }
        }
    }

    // Vorschaubilder anlegen bzw. melden (siehe thumbs.sh). Laeuft bei jedem
    // Oeffnen; ohne neue Bilder ist es nach ~20 ms durch.
    Process {
        id: thumbGen

        command: ["bash", Quickshell.shellPath("modules/services/wallpaper/thumbs.sh"),
            root.wallsDir, root.thumbsDir]

        stdout: SplitParser {
            onRead: line => {
                if (line === "" || root.thumbs[line])
                    return;
                root.pendingThumbs.push(line);
                if (!thumbFlush.running)
                    thumbFlush.start();
            }
        }
    }

    Timer {
        id: thumbFlush

        interval: 120
        onTriggered: {
            const next = Object.assign({}, root.thumbs);
            for (const name of root.pendingThumbs)
                next[name] = true;
            root.pendingThumbs = [];
            root.thumbs = next;
        }
    }

    // Aktuelles Wallpaper – dieselbe Datei, die auch die CLI schreibt
    FileView {
        path: root.statePath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.actualCurrent = text().trim()
    }
}
