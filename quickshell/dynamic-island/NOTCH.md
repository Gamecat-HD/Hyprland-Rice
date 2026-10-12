# Notch – Struktur & Erweiterung

Dokumentation der Notch-Komponente im Quickshell `dynamic-island` Setup.
Stand: Oktober 2026

---

## 1. Wo die Notch im Projekt liegt

```
quickshell/dynamic-island/
├── shell.qml                      # Einstiegspunkt (ShellRoot: Wallpaper, Bar, SettingsWindow)
├── Colors.qml                     # Farb-Singleton (pragma Singleton)
├── Appearance.qml                 # Gestalt-Singleton: Rundung, Rand, Schatten, Bewegung
├── themes/
│   ├── current                    # Textdatei mit aktivem Theme-Namen ("ink")
│   ├── ink.json / synthwave.json  # statische Theme-Fallbacks
└── modules/
    ├── bar/
    │   ├── Bar.qml                # PanelWindow pro Monitor → enthält die Notch
    │   └── components/
    │       ├── notch/             # ← DIE NOTCH
    │       │   ├── Notch.qml      # zentrale Komponente (376 Zeilen)
    │       │   ├── Clock.qml      # Uhr im oberen Band
    │       │   ├── DatePanel.qml  # Datums-Karussell (Hover-Inhalt)
    │       │   ├── DayColumn.qml  # einzelne Tagesspalte im Karussell
    │       │   └── EdgeFade.qml   # Farbverlauf an den Karussell-Rändern
    │       ├── mediaPlayer/       # MediaPlayer (separates Element rechts, NICHT in der Notch)
    │       ├── settings/          # Settings, Audioslider (wird als Akkuring recycelt!), WifiPanel …
    │       ├── statusBar/         # Tray, links neben der Notch
    │       └── workspaceSelector/
    ├── launcher/                  # LauncherPanel, WallpaperPanel, ThemePanel, LauncherState
    ├── services/                  # Singletons: audio, config, media, theme, …
    ├── widgets/                   # Surface (Pillen-Flaeche), Morph/Fade (Behaviors)
    └── settings/                  # SettingsWindow
```

Es gibt **keine qmldir-Dateien** – Singletons (`Colors`, `Config`, `LauncherState`) werden über
`qs.modules.*`-Imports und `pragma Singleton` aufgelöst.

---

## 2. Aufbau der Notch (Notch.qml)

### 2.1 API nach außen (Zeilen 23–29)

Alle Werte kommen von `Bar.qml`:

```qml
required property real verticalMargin
required property real borderWidth
required property color borderColor
required property real cardRadius
readonly property bool containsMouse: hoverSensor.hovered
readonly property alias clock: clock
```

### 2.2 Zustand

```qml
property bool expanded: false                                            // einziger mutabler Zustand
readonly property var hostScreen: notch.QsWindow.window?.screen ?? null
readonly property bool launcherOpen: LauncherState.open && LauncherState.screen === hostScreen
readonly property bool wallpaperOpen: launcherOpen && LauncherState.mode === "wallpaper"
readonly property bool themeOpen: launcherOpen && LauncherState.mode === "theme"
readonly property bool appsOpen: launcherOpen && !wallpaperOpen && !themeOpen
readonly property bool open: expanded || launcherOpen
```

**Zwei Öffnungsquellen teilen sich dieselbe Karte:**
1. **Hover** → Datums-Karussell (`expanded`)
2. **Launcher** (Drag nach unten oder Button) → Launcher/Wallpaper/Theme-Panel

Der Launcher hat Vorrang: `onLauncherOpenChanged: if (launcherOpen) expanded = false` (Z. 89).

### 2.3 Größenrechnung (Zeilen 50–67)

```qml
collapsedHeight: parent.height - verticalMargin
collapsedWidth:  clock.implicitWidth + 50

readonly property real expandedWidth: launcherOpen ? Math.max(collapsedWidth, launcherWidth)
                                                   : Math.max(collapsedWidth, panel.outerWidth)
readonly property real expandedHeight: launcherOpen ? launcherTop + launcherHeight
                                                    : collapsedHeight + clockDropMax + panel.outerHeight
```

- `maxDrop` (Z. 64) = **Maximalreserve**, die `Bar.qml` für die Fensterhöhe braucht
  (Maximum aus DatePanel + allen Launcher-Panels).
- Jedes Panel meldet selbst `outerWidth` / `outerHeight` / `maxOuterHeight`.

### 2.4 Öffnen/Schließen (Zeilen 74–106)

Zwei `Timer`:
- `openTimer`: 200 ms Verweilen → `expanded = true`
- `closeTimer`: 250 ms Nachlauf → `expanded = false` (außer `panel.dragging`)

Auslöser ist ein **`HoverSensor`** am Dateiende (Z. 373–375) – bewusst `HoverHandler`
statt `MouseArea`, damit klickbare Kinder den Hover nicht blockieren.

Animationen (Z. 108–113): `Behavior on width/height` mit
`NumberAnimation { duration: 220; easing.type: Easing.OutCubic }`.
Alles Ein-/Ausblenden läuft über `opacity` + `visible: opacity > 0` mit 160 ms Fade.
`clockDrop` (7 px): Die Uhr rutscht beim Aufklappen nach unten.

### 2.5 Die `pill` – sichtbares Herzstück

Ein `Surface` (modules/widgets, siehe Abschnitt 6) mit adaptivem Radius:

```qml
radius: Math.min(height / 2, maxRadius)   // Pille wird zur Karte ab 2 x radius Höhe
```

Verlauf, Rand und Schatten bringt Surface mit; die Kinder liegen in dessen Karte (`clip`).

**Enthaltene Elemente:**

| Element | Zeilen | Funktion |
|---|---|---|
| `DragHandler launcherDrag` | 129–148 | Zug nach unten (Schwelle 55 px) → `LauncherState.show(screen)` |
| `Clock` | 150–166 | Uhr im oberen Band, `y` hängt an `clockDrop`; aufgeklappt in `Colors.primary` |
| `mediaArt` / `mediaBars` | | Live-Activity: Cover links, 3 Cava-Pegel rechts, solange `Media.playing` (Schalter `bar.notchMedia`); nur eingeklappt |
| `Audioslider` als **batteryRing** | 177–200 | Akku-Ring um die Pille (nur eingeklappt), importiert aus `settings/`, Farbe `Colors.mix(Colors.primary, Colors.error, drain)` |
| `powerButton` | 212–258 | Material-Symbol `power_settings_new`, **noch ohne Funktion** (nur `console.log`) |
| `wallpaperButton` | 263–306 | Material-Symbol `wallpaper_slideshow` → `LauncherState.showWallpapers(screen)` |
| `DatePanel` (`id: panel`) | 308–321 | Datums-Karussell |
| `LauncherPanel` (`id: launcher`) | 323–335 | `active: notch.appsOpen` |
| `WallpaperPanel` (`id: wallpapers`) | 337–349 | `active: notch.wallpaperOpen` |
| `ThemePanel` (`id: themes`) | 351–363 | `active: notch.themeOpen` |

> Hinweis: Die Medien-Karte (`MediaPlayer`) hängt **nicht** in der Notch, sondern ist ein
> separates Element rechts in der Bar (Bar.qml Z. 195–202) – teilt nur das Pill/Karten-Muster.

### 2.6 Die Panel-Dateien

**Clock.qml** (23 Zeilen): Reines `Text`-Label, `SystemClock` mit `precision: SystemClock.Minutes`,
Format `"HH:mm"`. Positionierung/Animation macht komplett die Notch.

**DatePanel.qml** (202 Zeilen) – **Referenzmuster für Panels**. Seine Schnittstelle zur Notch (Z. 14–35):

```qml
property real topOffset: 0           // wo in der Karte das Panel beginnt
property real cardRadius: 18
property real inset: 2
property Item gestureArea: panel     // Fläche fürs Mausrad (Notch reicht die ganze Karte rein)
property bool dragEnabled: true

readonly property real outerWidth: implicitWidth + inset * 2
readonly property real outerHeight: implicitHeight + inset
readonly property bool dragging: dragHandler.active   // hält die Notch offen

property int dayOffset: 0            // Notch setzt das beim Zuklappen zurück (Notch.qml Z. 87)
```

Innerhalb: `WheelHandler` mit Hi-Res-Akkumulation, `DragHandler` für horizontales Ziehen,
`Repeater` mit `model: panel.sideColumns * 2 + 1` über `DayColumn`, zwei `EdgeFade`-Vignetten.

**DayColumn.qml**: Wochentag + Datums-Pille. Styling folgt dem Abstand zur Mitte
(`opacity: [1, 0.72, 0.48, 0.3, 0.18][distance]`), heute = `Colors.error` (rot),
Fokus = `Colors.primary`.

**EdgeFade.qml**: `Rectangle` mit horizontalem `Gradient` (Kartenfarbe → transparent,
36 px), `mirrored` + `cornerRadius` (damit der Verlauf die runde Ecke nicht rechteckig füllt).
Wird **ausschließlich** von DatePanel genutzt.

---

## 3. Integration in die Bar

**Importkette:** `shell.qml` → `Bar {}` → `Bar.qml` instanziiert mittig:

```qml
Notch {
    id: notch
    verticalMargin: bar.verticalMargin
    borderWidth: bar.borderWidth
    borderColor: bar.borderColor
    cardRadius: bar.cardRadius
}
```

**Rückrichtung (Notch → Bar):**

| Property | Wirkung in Bar.qml |
|---|---|
| `notch.launcherOpen` | `catching`: Bar-Fenster füllt den Screen, fängt Klicks daneben (`MouseArea` → `LauncherState.close()`); Keyboard-Focus → `WlrKeyboardFocus.Exclusive` |
| `notch.maxDrop` | bestimmt die Fensterhöhe: `implicitHeight: bar.catching ? height : barHeight + Math.max(notch.maxDrop, media.maxDrop, settings.maxDrop, …)` – Layer-Surfaces können nicht überzeichnen, deshalb ist das Fenster höher als die sichtbare Leiste |
| `notch.width` | verdrängt Nachbarn: `StatusBar` anchort mit `rightMargin: notch.width / 2 + 15`, `Settings` mit `leftMargin` |
| — | Input-Maske: `Region { item: notch }` hält die ausgeklappte Karte klickbar, obwohl sie unter der Leistenhöhe liegt |

**Querverbindungen:** Notch ↔ Launcher läuft über den **Singleton `LauncherState`**
(`modules/launcher/LauncherState.qml`) – nötig, weil beide in verschiedenen Fenstern leben.
Bietet `show(screen)`, `showWallpapers()`, `showThemes()`, `close()` und einen
`IpcHandler { target: "launcher" }` für IPC-Zugriff.

---

## 4. Konfiguration

### `modules/services/config/Config.qml`
Persistiert als `~/.config/dynamic-island/shell.json` (`FileView` + `JsonAdapter`, `watchChanges`).
Schalter: `bar.workspaces`, `bar.tray`, `bar.settings`, `bar.media`, `bar.notifications`,
`bar.stats`, `bar.battery`.
Die Notch selbst ist **nicht abschaltbar** („ohne sie gäbe es weder Uhr noch Launcher").
Die Notch liest `Config.bar.battery` für den Akkuring.
Das `meta`-Objekt liefert Klartext-Beschriftungen – **neue Keys erscheinen automatisch im Settings-Menü**.

### `Colors.qml`
Alle Farben. Dynamische Quelle `~/.local/state/dynamic-island/scheme.json`
(wallpaper-basiert, Material-You), statischer Fallback `themes/<name>.json`.
Rollen: `Colors.background`, `Colors.primary`, `Colors.error`, `Colors.outlineVariant`
+ Helfer `alpha()`, `mix()`, `shade()`.

### Hartkodierte Größen (dezentral)
- `cardRadius` = `Appearance.radius` (20), `verticalMargin: 10`, `barHeight: 40` → Bar.qml
- Spaltenbreite 26, inset 2 → DatePanel.qml
- `clockDropMax: 7`, `launcherTop: 10` → Notch.qml

---

## 5. Wie du die Notch erweiterst

### A) Neues Panel im ausgeklappten Inhalt (Muster: DatePanel)

Beispiel „KalenderPanel":

1. **Neue Datei** `modules/bar/components/notch/CalendarPanel.qml` mit der Standard-Schnittstelle
   (aus DatePanel.qml Z. 14–35): `topOffset`, `cardRadius`, `inset`, `gestureArea`, `dragEnabled`
   + `readonly outerWidth/outerHeight`, bei großem Inhalt zusätzlich `maxOuterHeight`
   (Muster: LauncherPanel.qml Z. 31).

2. **In Notch.qml einfügen** (Kind von `pill`, neben DatePanel ~Z. 321):

   ```qml
   CalendarPanel {
       id: calendar
       topOffset: notch.collapsedHeight + notch.clockDrop
       cardRadius: notch.cardRadius
       gestureArea: pill
       dragEnabled: !launcherDrag.active
       opacity: notch.expanded && !notch.launcherOpen ? 1 : 0   // eigene Sichtbedingung!
       visible: opacity > 0
       Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
   }
   ```

3. **In die Größenrechnung einrechnen**, falls das Panel mit `expanded` erscheint:
   `expandedWidth` (Z. 59–60, `Math.max(collapsedWidth, panel.outerWidth)` erweitern)
   und ggf. `maxDrop` (Z. 64–67).

4. **Geste vorhanden?** → `dragEnabled: !launcherDrag.active` setzen und `dragging`
   des Panels im `closeTimer` respektieren (Z. 101).

5. **Offset-State?** → Reset in `onExpandedChanged` ergänzen
   (Präzedenz: `panel.dayOffset = 0`, Z. 87).

### B) Neuer Launcher-Modus (Muster: WallpaperPanel/ThemePanel)

1. Neues Panel in `modules/launcher/` mit Schnittstelle
   `topOffset/cardRadius/inset/active` + `outerWidth/outerHeight/maxOuterHeight`.
2. Neuen `mode`-String in **`LauncherState.qml`** (Z. 17–22) dokumentieren und
   `showXxx(target)` ergänzen (Muster: `showThemes`, Z. 59–61); optional IPC-Endpoint (Z. 74–96).
3. In **Notch.qml**: `readonly property bool xxxOpen` (Muster Z. 37–39), Panel-Instanz mit
   `active: notch.xxxOpen` + `opacity`-Binding (Muster Z. 351–363), Maße in
   `launcherWidth`/`launcherHeight` (Z. 52–57) und `maxDrop` (Z. 64–67) ergänzen.

### C) Kleinste Variante: Launcher-Listenmodus ohne eigenes Panel

`LauncherPanel` unterstützt eigene Listenquellen per `property var modes: ({})`
(LauncherPanel.qml Z. 33–36). Eine Quelle braucht nur:

- `results(query)` → `[{name, desc, icon}]`
- `activate(item)`

Erreichbar über `>name …` im Suchfeld. **Das kleinste Erweiterungs-Interface des gesamten Systems.**

### D) Neuer Button in der Notch

Muster: `powerButton` (Z. 212–258) / `wallpaperButton` (Z. 263–306):

- 28×28-`Item` mit Material-Symbols-Ligatur
- `HoverHandler` (Cursor) + `TapHandler` (kein MouseArea – wegen des DragHandlers!)
- Fade-Bindung an `notch.expanded && !notch.launcherOpen`
- Anker links/rechts an der Uhr-Zeile

### ⚠ Wichtig: Sichtbarkeits-Matrix

Alle Panels sind **permanent instanziiert** und nur per `opacity`/`visible` verborgen.
Die Karte misst sich am `Math.max` der aktiven Inhalte. Derzeit zeigt sich **genau eine**
Ansicht gleichzeitig:

| Zustand | sichtbares Panel |
|---|---|
| `expanded && !launcherOpen` | DatePanel |
| `appsOpen` | LauncherPanel |
| `wallpaperOpen` | WallpaperPanel |
| `themeOpen` | ThemePanel |

Ein neues Panel braucht also eine klare eigene Bedingung in dieser Matrix – sonst
überlagert es ein bestehendes oder vergrößert die Karte permanent.

---

## 6. Optik-System (seit Oktober 2026)

Alle Pillen und Karten der Leiste teilen sich drei Bausteine:

| Baustein | Datei | Aufgabe |
|---|---|---|
| `Appearance` | `Appearance.qml` (Singleton, `import qs`) | Rundung (20), Rand, Verlauf (`lift`), Schatten, Dauer und **Overshoot** der Bewegung |
| `Surface` | `modules/widgets/Surface.qml` | Die Flaeche: Schatten (MultiEffect auf schwarzer Form, ausserhalb der Karte) + Karte mit Verlauf, Rand, `clip`. Kinder landen in der Karte (`default property`). `clipContent: false`, wenn etwas herausragen soll (Settings-Dropdown). `baseColor` fuer andere Grundtoene (Medien-Karte). `radius` liefert die aktuelle Rundung fuer Masken. |
| `Morph` / `Fade` | `modules/widgets/Morph.qml`, `Fade.qml` | Behaviors: `Morph on width {}` federt (OutBack mit `Appearance.overshoot`), `Fade on opacity {}` blendet weich. Morph nie auf Werte legen, die bis 0 gehen – der Overshoot wuerde negativ. |

Vorbild ist saneAspects "Dynamite" (eine Insel, die mit echtem Nachschwingen morpht).
Das Nachschwingen stellt man im Einstellungs-Menue ein: `appearance.bounce` = aus / leicht / mittel / stark.

Wer eine neue Pille baut: `Surface { anchors.fill: parent; maxRadius: cardRadius }` statt eines
Rectangles, Groessen mit `Morph on …`, Inhalte mit `Fade on opacity`. Die `borderWidth`/`borderColor`-
Properties von Bar.qml koennen durchgereicht werden, muessen aber nicht (Surface hat die Appearance-Defaults).

Der Visualiser (Cava) wird in Bar.qml eingeschaltet, sobald etwas spielt und entweder die Medien-Karte
oder die Live-Activity der Notch an ist – ein einziges Binding, damit sich nicht zwei widersprechen.

### Layouts (Config `appearance.layout`)

| Wert | Was die Leiste zeigt |
|---|---|
| `insel` | Alle Pillen (Standard). Cover/Pegel in der Notch nur mit `bar.notchMedia`. |
| `notch` | Nur die Notch, angedockt an der Oberkante, im Stil von saneAspect: **schwarz** (`Appearance.notchColor`), ohne Rand und Verlauf, mit gewoelbten **Schultern** (`NotchShoulder.qml`, links/rechts *ausserhalb* der Notch-Breite, Radius 10 zu / 16 auf). Schatten erst aufgeklappt (`Surface.shadowStrength`). Eingeklappt 32 px hoch, eine breite Leiste: links Workspace-Staebchen (`NotchWorkspaces.qml`, `notch.workspaces`), mittig die Uhr, rechts Aufnahme-Punkt, Nachrichten-Zaehler (`notch.messages`) und Datum (`notch.date`). Laeuft Musik (`notch.media`), ersetzt das Cover die Workspaces und die Cava-Pegel das Datum. Beide Seiten sind gleich breit (`compactSide`), die Uhr bleibt mittig. Hover: waechst um `Appearance.notchHoverLift` nach unten und doppelt zur Seite (`growth`) statt zu skalieren. Aufgeklappt wird die Uhr 1.3x zur Ueberschrift; die Pillen im Hub sind flache Chips ohne Schatten (`Surface.nested`). Aufgeklappt: Kopfzeile mit runden Knoepfen (`NotchButton`, inline in Notch.qml: Wallpaper + Musik-Schalter links, Nachrichten-Schalter + Power rechts; aktiv = Akzent-Fuellung, Power-Hover rot), Trennlinie zwischen Datum und Hub (`panelBottom`, `hubGap`). An Fables erweiterte Einstellungen angebunden: Animationsdauern ueber `Appearance.morphDuration`/`fadeDuration` (appearance.speed), Schulter-Radius aufgeklappt = 0.8 x appearance.radius, Workspace-Staebchen = bar.workspaceCount, Uhr 12h/24h, Schatten-Schalter; notch.workspaces/notch.date nur aktiv im Notch-Layout (`requires`). |

**Der Hub.** Im Notch-Layout verschwinden die anderen Pillen nicht, sie ziehen um: Bar.qml haelt sie in einem
Wrapper-Item `pills`, dessen `parent` im Notch-Layout `notch.hub` ist (ein 40 px hohes Item unter dem
Datumsstreifen, Breite `hubWidth` >= 600). Dieselben Instanzen, deshalb gelten Maske, Tastaturfokus und
`settings.typingPassword` in Bar.qml weiter. Klappt eine Pille im Hub auf (Settings 520 px, Medien,
Benachrichtigungen), ragt sie aus dem Hub heraus und die Notch waechst mit (`hubBottom` aus `childrenRect`,
`hubContentWidth` setzt Bar.qml aus der Settings-Karte). Der Wrapper ist wichtig: einzeln umgeparkte Pillen
hatten kurzzeitig Anker auf Geschwister in anderen Eltern ("Cannot anchor to an item that isn't a parent or
sibling") und die Settings-Pille blieb verschwunden.

Die Anker der Pillen schalten per `bar.notchMode` um: in der Leiste haengen Tray und Settings an der
Bildschirmmitte +/- `notch.width / 2`, im Hub bilden sie links eine Kette (Workspaces -> System -> Tray ->
Settings), Medien und Glocke haengen rechts.


### Uebersicht + Untermenues (Notch-Layout, Stand 2026-10-12 abends)

Der Hub ist weg. Im Notch-Layout sind die Pillen der Leiste ganz aus (`pills.visible: !notchMode` in Bar.qml);
ihre Inhalte stehen als **Untermenues** in der Notch. Das sind Launcher-Modi wie Apps/Power (`LauncherState.views`):

| Ansicht | Datei | Kuerzel | Launcher |
|---|---|---|---|
| Uebersicht (Hover) | Notch.qml: Uhr + Glocke (Indikator), DatePanel, `NowPlayingRow`, `SystemGlance` | – | – |
| Medien | `launcher/MediaViewPanel.qml` (MediaPanel: Player-Auswahl, Ring-Visualiser, Fortschritt) | – (SUPER+M = Music-Workspace) | `>medien` |
| Steuerung | `launcher/ControlPanel.qml` (Tray + `Settings { embedded: true }`) | SUPER+A | `>steuerung` |
| Benachrichtigungen | `launcher/NotificationsPanel.qml` (Liste, Nicht stoeren, Alle loeschen) | SUPER+N | `>benachrichtigungen` |
| System | `launcher/SystemPanel.qml` (`stats/StatsCard.qml`, auch von der StatsPill genutzt) | SUPER+I | `>system` |
| Power | `launcher/PowerPanel.qml` | SUPER+X | `>power` |

- Gemeinsame Basis `launcher/ViewPanel.qml` (Titelzeile + Inhalt, Schnittstelle wie PowerPanel).
- **Blaettern:** `flipWheel` auf der Karte (Mausrad bzw. Kippen/Wischen, Hi-Res-Akkumulation, 280 ms Sperre).
  Datums-Karussell und Listen nehmen ihr Rad selbst (`DatePanel.gestureArea` angedockt = Panel).
  `LauncherState.step()` blaettert; zurueck auf die Uebersicht schliesst den Launcher und setzt `expanded`.
- Seiten-Indikator `pager` (Punkte) unten in Uebersicht und Untermenues.
- Kuerzel rufen `LauncherState.toggleMode()` (nochmal = zu). Untermenues nehmen keinen Exclusive-Fokus,
  ausser beim WLAN-Passwort/BT-PIN in der Steuerung (`notch.controlTyping`).
- Geteilte Dienste mit genau einem Binding in Bar.qml: `Cava.enabled`, `SystemStats.watching`, `Media.trackPosition`.
- Eingeklappt: `notch.media` = Cover, neu `notch.visualizer` = Pegel (statt Datum).

**(ersetzt, siehe unten)** ~~`WorkspaceStrip.qml` direkt unter der Uhr in der Uebersicht: Nummern der Workspaces
dieses Monitors (Klick = wechseln, schliesst einen offenen Special vorher) und die existierenden Special-Workspaces als
Symbole (Klick = toggeln, aktiver = tertiaere Pille). Symbole aus `SpecialIcons.js` (geteilt mit `NotchWorkspaces.qml`,
das eingeklappt ein offenes Special als Symbol hinter den Staebchen zeigt).

**Blaettern ueberarbeitet:** eine Geste = eine Seite (`flipWheel.spent`, frei erst nach 220 ms Ruhe, `gestureEnd`),
Touchpad-Schwelle 70 px, Richtungswechsel verwirft den Rest. Der Inhalt gleitet in Scrollrichtung herein
(`notch.slide` + `slideIn`, `Translate` auf Uebersicht-Elementen und Untermenues).

**Nachbesserung:** Specials stehen nur in der Workspace-Leiste, wenn auf dem Monitor einer offen ist (als Pille hinten
in der Reihe). Blaettern nur noch ueber der Kopfzeile (`flipZone`, Hoehe bis zur Workspace-Leiste): die Karte haengt oben
fest, die Seiten sind unterschiedlich hoch – unten springt alles, oben nie. Seiten-Punkte oben links auf Uhr-Hoehe
(`headerCenter`), Untermenue-Titel mittig. Benachrichtigungsliste scrollt animiert (`scrollAnim`). Kein Kuerzel fuer
Medien mehr (SUPER+M gehoert dem Music-Workspace).

**Stand 2026-10-12 spaet:** Alle Blaetter-Seiten haben dieselbe Breite (`pageWidth` 548 = Steuerung), nichts verschiebt sich
seitlich. Kopfzeile auf allen Seiten gleich: links die Workspace-Staebchen (`NotchWorkspaces`, bleiben beim Aufklappen
stehen und sind klickbar), Mitte Uhr bzw. Titel, rechts Seiten-Punkte + Glocke. `WorkspaceStrip.qml` ist wieder weg.
Specials wie bei Caelestia: ist einer offen, legt sich ueber die Staebchen eine kleine Pille mit allen Specials (aktiver
tertiaer, Klick toggelt). Blaettern: Schwelle halbe Rastung (60) bzw. 50 px, feste Sperre 350 ms (`flipCooldown`), Zaehler
verfaellt nach 500 ms Pause (`accumDecay`). Medien-Untermenue: `MediaPanel` in fester 320-px-Spalte.

**Feinschliff:** Kein Leerraum auf den Seiten – Datums-Karussell angedockt mit 15 sichtbaren Tagen (`visibleColumns`,
`columnWidth` jetzt von aussen setzbar), Medien-Zeilen ueber die volle Breite mit gedeckeltem Cover
(`MediaPanel.maxCoverSize`), leere Benachrichtigungsliste ohne Listenflaeche. Blaettern laeuft ueber den Rand
(`LauncherState.step` mit Modulo), Schwelle Viertel-Rastung (30) bzw. 30 px, Sperre 300 ms. Special-Overlay exakt so breit
wie die Staebchen-Reihe, die Specials teilen sich die Breite.

**Specials als Staebchen:** Statt Symbol-Overlay stehen offene Specials im Stil der Workspace-Anzeige da: die
Workspace-Staebchen blenden fast aus (0.12), an ihrer Stelle die Specials als Staebchen, jeder in eigener Farbe
(`specialColor`: Musik gruen, Kommunikation blau, Sysmon orange, Stern violett, Helligkeit am Theme), der offene hoch.
`SpecialIcons.js` entfernt.

**Kontrast:** `Appearance.notchColor` ist schwarz, ausser das Farbschema hat dunkle Schrift (`darkText`, Luminanz von
`Colors.fgBackground` < 0.45) – dann der helle Theme-Hintergrund. `wallTopLuma` misst per `magick` bei jedem
Wallpaper-Wechsel (auch Vorschau) die Helligkeit des oberen Mittelstreifens; liegt sie naeher als 0.14 an der Notch-Farbe,
bekommt die Notch eine 1-px-Kontur (`notchBorder`), die Schultern ziehen sie entlang der Kurve weiter
(`NotchShoulder.strokeWidth`), die obere Kante liegt ausserhalb (`y: -borderWidth`).
**Klick auf den aktiven Workspace** toggelt den allgemeinen Special (`special:special`). **Blaettern ohne Sperre.**

**Hi-Res-Rad richtig:** eine Seite je voller Rastung (120 Einheiten; die G502 liefert ~8 x 15), Touchpad 60 px, keine
Sperre, Zaehler verfaellt nach 500 ms. **Steuerung:** `Settings.dropdownReserve` rechnet nur noch den Teil, der wirklich
unter der Karte herausragt (`mapToItem`) – vorher wuchs die Ansicht beim Oeffnen jedes Dropdowns um dessen volle Hoehe.
**Benachrichtigungen:** Liste waechst mit `list.contentHeight` (alle Zeilen per `cacheBuffer` erzeugt) bis 440 px.

**Steuerung fest hoch:** eingebettet ist `Settings.height` = `embeddedHeight` (groesste von Kacheln/WLAN/BT/Audio + Rand);
Unterseiten und Dropdowns aendern die Notch-Hoehe nicht mehr (gemessen: 438 px in allen Zustaenden).
**Rad ueber den Workspace-Staebchen:** springt je Rastung zum naechsten/vorigen Workspace mit Fenstern (leere werden
uebersprungen, am Ende von vorn). `flipZone` liegt dafuer mit `z: -1` unter den Staebchen.

**Steuerung erweitert (2026-10-12 abends):** Audio-Dienst kennt Eingangspegel (`sourceVolume`, `setSourceVolume`,
`toggleSourceMute`), Pegel je Knoten (`setNodeVolume`, `toggleNodeMute`) und die Wiedergabe-Streams der Apps
(`streams`, `streamLabel`). Audio-Menue: Pegel-Zeile (`LevelRow`) fuer gewaehltes Aus- und Eingabegeraet, Abschnitt
APPS mit Lautstaerke je App (Symbol = stumm). Neue Kacheln `mic` (Mikrofon-Regler, Symbol-Klick = stumm) und `power`
(Energieprofil zyklisch) in QuickLayout/SettingsTiles. **WLAN schneller:** `Network.refresh()` liest sofort den Cache
(`--rescan no`, ~60 ms statt 6 s) und stoesst die Suche separat an (`nmcli device wifi rescan`, kehrt sofort zurueck),
danach zweimal nachlesen; `scanning` dreht den Aktualisieren-Knopf. Die Steuerung laedt die Liste schon beim Oeffnen vor.

**Glocke anklickbar:** Klick auf die Glocke oben rechts oeffnet das Untermenue Benachrichtigungen, aus diesem heraus geht
es per Klick zurueck zur Uebersicht.
