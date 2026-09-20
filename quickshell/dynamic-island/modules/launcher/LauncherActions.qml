pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.modules.services.wallpaper

// Aktionen des Launchers – das Gegenstück zu Caelestias `Actions`-Service.
// Erreichbar über das Präfix `>`.
//
// Eine Aktion ist ein schlichtes Objekt:
//   name  – Titel in der Liste
//   desc  – Untertitel
//   icon  – Material-Symbols-Name
// und genau eine der beiden Bauarten:
//   run:  () => { ... }   führt direkt aus und schließt den Launcher;
//                         mit `keepOpen: true` bleibt die Karte offen (für
//                         Aktionen, die nur umschalten)
//   mode: "name"          schaltet die Liste in einen eigenen Modus um; der
//                         Suchtext wird auf ">name " gesetzt und alles Weitere
//                         kommt aus der Quelle, die unter diesem Namen in
//                         LauncherPanel.modes registriert ist.
//                         (Genau so hängt bei Caelestia der Wallpaper-Wechsler
//                         am `autocomplete`-Kommando.)
Singleton {
    id: root

    readonly property var actions: [
        {
            name: "Shell neu laden",
            desc: "Quickshell-Konfiguration neu einlesen",
            icon: "refresh",
            run: () => Quickshell.reload(false)
        },
        {
            name: "Wallpaper",
            desc: "Hintergrund wechseln",
            icon: "wallpaper_slideshow",
            // Eigene Ansicht in derselben Karte (WallpaperPanel.qml), deshalb
            // umschalten statt schliessen
            keepOpen: true,
            run: () => LauncherState.mode = "wallpaper"
        },
        {
            name: "Zufaelliges Wallpaper",
            desc: "Irgendeines aus dem Wallpaper-Ordner",
            icon: "shuffle",
            run: () => Wallpapers.random()
        }
    ]

    function search(needle: string): var {
        const query = needle.trim().toLowerCase();
        if (query === "")
            return root.actions;

        return root.actions.filter(action => `${action.name} ${action.desc}`.toLowerCase().includes(query));
    }
}
