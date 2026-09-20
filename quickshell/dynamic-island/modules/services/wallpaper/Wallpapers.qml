pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

// Wallpaper-Dienst: kennt die Bilder im Wallpaper-Ordner, das aktuell
// gesetzte und das gerade nur vorgeschaute.
//
// Vorbild ist caelestia/services/Wallpapers.qml – nur ohne dessen
// Caelestia.Models-Plugin (FileSystemModel gibt es hier nicht). Die Liste
// kommt stattdessen einmalig aus einem `find`; gescannt wird erst, wenn sie
// zum ersten Mal gebraucht wird (`ensureLoaded`), damit der Start der Shell
// nichts davon merkt.
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

    // [{ path, name }] – name ist der Pfad relativ zum Wallpaper-Ordner
    property var list: []
    property bool loaded: false
    property bool loading: false

    // Tatsaechlich gesetzt (aus dem State) bzw. nur vorgeschaut (Auswahl im
    // Launcher). `current` ist das, was der Hintergrund anzeigen soll.
    property string actualCurrent: ""
    property string previewPath: ""
    property bool showPreview: false
    readonly property string current: root.showPreview && root.previewPath !== "" ? root.previewPath
                                                                                  : root.actualCurrent

    // ---- Liste ----
    function ensureLoaded(): void {
        if (!root.loaded && !root.loading)
            root.reload();
    }

    function reload(): void {
        root.loading = true;
        scan.running = true;
    }

    function search(needle: string): var {
        const query = needle.trim().toLowerCase();
        if (query === "")
            return root.list;
        return root.list.filter(w => w.name.toLowerCase().includes(query));
    }

    // ---- Setzen ----
    function set(path: string): void {
        root.stopPreview();
        root.actualCurrent = path;          // sofort, der State zieht gleich nach
        Quickshell.execDetached([root.cli, "wallpaper", "-f", path]);
    }

    function random(): void {
        root.stopPreview();
        Quickshell.execDetached([root.cli, "wallpaper", "-r"]);
    }

    // ---- Vorschau ----
    // Nur das Bild, nicht das Farbschema: die Palette entsteht in der CLI und
    // wuerde pro Vorschau einen ganzen Durchlauf kosten.
    function preview(path: string): void {
        root.previewPath = path;
        root.showPreview = true;
    }

    function stopPreview(): void {
        root.showPreview = false;
        root.previewPath = "";
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

                root.list = entries;
                root.loaded = true;
                root.loading = false;
            }
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
