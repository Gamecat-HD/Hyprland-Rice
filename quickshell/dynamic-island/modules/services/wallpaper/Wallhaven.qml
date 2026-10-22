pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.services.config

// Wallhaven-Suche fuer die Wallpaper-Auswahl: Treffer, Seiten, Downloads.
//
// Die Arbeit macht die CLI (`dynamic-island wallhaven search|download`), sie
// liefert NDJSON auf stdout – erst die Trefferliste, dann je fertigem
// Vorschaubild eine Zeile (die Kacheln stehen also sofort mit Platzhaltern
// da). Hier wird nur gesammelt und in ein ListModel geschrieben: ein
// JS-Array als Modell wuerde bei jedem nachgereichten Thumb alle Kacheln neu
// bauen und das Karussell auf Null stellen.
//
// Die API erlaubt 45 Anfragen pro Minute: eine laufende Suche wird beim
// neuen Start abgebrochen, die naechste Seite kommt erst, wenn die vorige
// samt Thumbs durch ist, und mehr als `maxPages` Seiten gibt es je Suche
// nicht. Entprellt wird im Panel (Tipp-Pause), nicht hier.
//
// Treffer und Einstellungen bleiben nach dem Schliessen der Auswahl stehen,
// beim naechsten Oeffnen geht es ohne neue Anfrage weiter.
//
// Benutzung:  import qs.modules.services.wallpaper
Singleton {
    id: root

    readonly property string cli: Quickshell.env("HOME") + "/.local/bin/dynamic-island"

    // Ob der Wallhaven-Bereich im Panel aufgeklappt ist – nur Laufzeit, die
    // Auswahl faengt nach einem Neustart zusammengeklappt an
    property bool expanded: false

    // Mehr Seiten als das laedt das Karussell nicht nach (24 Treffer je Seite)
    readonly property int maxPages: 6

    // Die laufende Suche: Suchtext und Sortierung (API-Wert), dazu die Meta-
    // Daten der letzten Antwort. `seed` haelt die Zufallsreihenfolge ueber
    // die Seiten hinweg zusammen.
    property string query: ""
    property string sorting: root.sortingApi(Config.wallhaven.sorting)
    property int page: 0
    property int lastPage: 0
    property int total: 0
    property string seed: ""
    property string error: ""

    // Phasen eines Aufrufs: `searching` bis die Trefferliste da ist (dann
    // lohnt eine Statusanzeige), `busy` solange der Prozess noch Thumbs
    // nachreicht (dann keine neue Seite anstossen)
    property bool searching: false
    readonly property bool busy: searchProc.running
    readonly property bool hasMore: root.page > 0 && root.page < Math.min(root.lastPage, root.maxPages)
    // Es gab schon eine Antwort fuer die aktuelle Suche (sonst: nichts
    // gesucht, "keine Treffer" waere falsch)
    property bool answered: false

    // ---- Treffer ----
    // Rollen: wid, url, full, thumb, resolution, size, fileType, favorites,
    // views, local (Pfad oder ""), phase ("" | "downloading" | "error").
    // `wid` statt `id`: das ist in QML reserviert.
    readonly property ListModel items: ListModel {}

    function indexOf(wid: string): int {
        for (let i = 0; i < root.items.count; i++)
            if (root.items.get(i).wid === wid)
                return i;
        return -1;
    }

    function patch(wid: string, values: var): void {
        const at = root.indexOf(wid);
        if (at < 0)
            return;
        for (const key in values)
            root.items.setProperty(at, key, values[key]);
    }

    // ---- Einstellungen -> API ----
    // shell.json haelt deutsche Chip-Werte (wie wallpaper.transition), die
    // API will ihre eigenen Woerter bzw. Bitmasken
    readonly property var sortings: ({
        "relevanz": "relevance",
        "neu": "date_added",
        "zufall": "random",
        "views": "views",
        "favoriten": "favorites",
        "top": "toplist"
    })
    readonly property var topRanges: ({
        "1 Tag": "1d", "3 Tage": "3d", "1 Woche": "1w", "1 Monat": "1M",
        "3 Monate": "3M", "6 Monate": "6M", "1 Jahr": "1y"
    })
    readonly property var purities: ({ "sfw": "100", "sfw+sketchy": "110" })
    readonly property var categoryBits: ({
        "alle": "111", "general": "100", "anime": "010", "people": "001", "general+anime": "110"
    })

    function sortingApi(name: string): string {
        return root.sortings[name] ?? "toplist";
    }

    // Sortierung aus dem Panel: in die Config, Chips dort und im Menue zeigen
    // denselben Wert. Die neue Suche loest der Wechsel von `sorting` aus –
    // so auch, wenn jemand sie im Einstellungsmenue umstellt.
    function setSorting(name: string): void {
        if (name in root.sortings)
            Config.set("wallhaven", "sorting", name);
    }

    onSortingChanged: if (root.answered || root.searching) root.search(root.query, true)

    // ---- Suche ----
    // Erste Seite. `force` sucht auch bei gleichem Text nochmal (Sortierung
    // gewechselt, Fehler wiederholen).
    function search(text: string, force: bool): void {
        const q = text.trim();
        if (!force && q === root.query && (root.answered || root.searching))
            return;
        root.query = q;
        root.seed = "";
        root.page = 0;
        root.lastPage = 0;
        root.total = 0;
        root.answered = false;
        root.fetch(1);
    }

    // Naechste Seite anhaengen – nur wenn gerade nichts laeuft, sonst
    // stapeln sich Anfragen beim schnellen Durchblaettern
    function loadMore(): void {
        if (root.busy || !root.hasMore)
            return;
        root.fetch(root.page + 1);
    }

    function fetch(page: int): void {
        searchProc.running = false;
        root.error = "";
        root.searching = true;

        const c = Config.wallhaven;
        const cmd = [root.cli, "wallhaven", "search", root.query,
            "-s", root.sorting, "-r", root.topRanges[c.topRange] ?? "1M",
            "-c", root.categoryBits[c.categories] ?? "111",
            "-u", root.purities[c.purity] ?? "100",
            "-p", String(page)];
        if (c.atleast !== "aus")
            cmd.push("-a", c.atleast);
        if (c.ratios !== "alle")
            cmd.push("--ratios", c.ratios);
        if (root.sorting === "random" && root.seed !== "")
            cmd.push("--seed", root.seed);

        searchProc.page = page;
        searchProc.command = cmd;
        searchProc.running = true;
    }

    Process {
        id: searchProc

        property int page: 1

        stdout: SplitParser {
            onRead: line => {
                let msg;
                try {
                    msg = JSON.parse(line);
                } catch (e) {
                    return;
                }
                if (msg.type === "result")
                    root.receive(msg);
                else if (msg.type === "thumb")
                    root.patch(msg.id, { thumb: msg.thumb });
                else if (msg.type === "error") {
                    root.error = msg.message ?? "Fehler";
                    root.searching = false;
                }
            }
        }

        // Abgebrochen oder abgestuerzt, ohne dass eine Antwort kam
        onExited: root.searching = false
    }

    function receive(msg: var): void {
        const meta = msg.meta ?? {};
        if (searchProc.page === 1)
            root.items.clear();
        for (const w of msg.items ?? []) {
            root.items.append({
                wid: w.id,
                url: w.url ?? "",
                full: w.full ?? "",
                thumb: w.thumb ?? "",
                resolution: w.resolution ?? "",
                size: Number(w.size ?? 0),
                fileType: w.fileType ?? "",
                favorites: Number(w.favorites ?? 0),
                views: Number(w.views ?? 0),
                local: w.local ?? "",
                phase: ""
            });
        }
        root.page = Number(meta.page ?? searchProc.page);
        root.lastPage = Number(meta.lastPage ?? 1);
        root.total = Number(meta.total ?? root.items.count);
        if (meta.seed)
            root.seed = String(meta.seed);
        root.answered = true;
        root.searching = false;
    }

    // ---- Download ----
    // Einer nach dem anderen: die Bilder sind 2-6 MB, und ein zweiter Klick
    // waehrend des ersten ist eher ein Versehen als ein Wunsch.
    property string downloadingId: ""
    readonly property bool downloading: downloadProc.running
    signal downloaded(string wid, string path, bool applied)

    // `apply`: danach als Wallpaper setzen (ueber Wallpapers.set, damit die
    // Auswahl sofort das neue Bild kennt). Liegt es schon lokal, geht es
    // ohne Netz direkt weiter.
    function download(wid: string, apply: bool): void {
        const at = root.indexOf(wid);
        if (at < 0 || root.downloading)
            return;
        const item = root.items.get(at);
        if (item.local !== "") {
            root.finish(wid, item.local, apply);
            return;
        }
        root.downloadingId = wid;
        root.items.setProperty(at, "phase", "downloading");
        downloadProc.wid = wid;
        downloadProc.apply = apply;
        downloadProc.command = [root.cli, "wallhaven", "download", wid, "--url", item.full];
        downloadProc.running = true;
    }

    function finish(wid: string, path: string, apply: bool): void {
        root.patch(wid, { local: path, phase: "" });
        if (apply)
            Wallpapers.set(path);
        // Ab jetzt steht es auch im lokalen Karussell
        Wallpapers.reload();
        root.downloaded(wid, path, apply);
    }

    Process {
        id: downloadProc

        property string wid: ""
        property bool apply: false
        property string path: ""

        stdout: SplitParser {
            onRead: line => {
                let msg;
                try {
                    msg = JSON.parse(line);
                } catch (e) {
                    return;
                }
                if (msg.type === "done")
                    downloadProc.path = msg.path ?? "";
                else if (msg.type === "error")
                    root.error = msg.message ?? "Download fehlgeschlagen";
            }
        }

        onExited: {
            root.downloadingId = "";
            if (downloadProc.path !== "") {
                root.finish(downloadProc.wid, downloadProc.path, downloadProc.apply);
                downloadProc.path = "";
            } else {
                root.patch(downloadProc.wid, { phase: "error" });
                if (root.error === "")
                    root.error = "Download fehlgeschlagen";
            }
        }
    }
}
