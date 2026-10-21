// Island — liefert Cover-Bilder als CSS-Variablen fuer den Ambient-Glow:
//   --island-art       (auf <html>)      : Cover des laufenden Titels
//   --island-page-art  (auf #main-view)  : Cover der gerade geoeffneten Seite
//                                          (Playlist/Album/Artist-Header), sonst entfernt
// user.css zeichnet daraus unscharfe Glows hinter Hauptansicht, NPV und Player-Leiste.
(function island() {
  if (!window.Spicetify || !Spicetify.Player || !Spicetify.Player.data || !Spicetify.Platform) {
    setTimeout(island, 300);
    return;
  }

  const root = document.documentElement;

  // --- Schrift ----------------------------------------------------------------
  // Spotify setzt --encore-*-font-stack in einem @layer mit !important; das
  // schlaegt jede Regel aus user.css. Nur ein Inline-Style mit !important gewinnt.
  const body = '"Inter Variable", "Inter", "Noto Sans", sans-serif';
  const title = '"Inter Display", "Inter Variable", "Inter", sans-serif';
  root.style.setProperty("--encore-body-font-stack", body, "important");
  root.style.setProperty("--encore-title-font-stack", title, "important");
  root.style.setProperty("--encore-variable-font-stack", title, "important");

  function toHttp(raw) {
    if (!raw) return "";
    if (raw.startsWith("spotify:image:")) return "https://i.scdn.co/image/" + raw.slice("spotify:image:".length);
    return raw;
  }

  function coverUrl() {
    const item = Spicetify.Player.data && Spicetify.Player.data.item;
    const meta = (item && item.metadata) || {};
    return toHttp(meta.image_xlarge_url || meta.image_large_url || meta.image_url || "");
  }

  // Erst laden, dann setzen -> kein Flackern beim Wechsel
  function setVar(el, name, url) {
    if (!url) { el.style.removeProperty(name); return; }
    const img = new Image();
    img.onload = () => el.style.setProperty(name, `url("${url}")`);
    img.onerror = () => el.style.removeProperty(name);
    img.src = url;
  }

  // --- Laufender Titel --------------------------------------------------------
  let currentTrackArt = null;
  function updateTrackArt() {
    const url = coverUrl();
    if (url === currentTrackArt) return;
    currentTrackArt = url;
    setVar(root, "--island-art", url);
  }
  Spicetify.Player.addEventListener("songchange", updateTrackArt);
  updateTrackArt();

  // --- Seiten-Cover (Entity-Header) ------------------------------------------
  let currentPageArt = null;
  let tries = 0;
  function findPageArt() {
    const img = document.querySelector(
      "#main-view .main-entityHeader-imageContainer img, #main-view .main-entityHeader-image img, #main-view img.main-entityHeader-image"
    );
    return img && img.src ? img.src : "";
  }
  function updatePageArt() {
    const mainView = document.getElementById("main-view");
    if (!mainView) return;
    const url = findPageArt();
    if (!url && tries < 20) { tries++; setTimeout(updatePageArt, 150); return; }
    tries = 0;
    if (url === currentPageArt) return;
    currentPageArt = url;
    setVar(mainView, "--island-page-art", url);
  }
  function onNavigate() {
    tries = 0;
    currentPageArt = null;
    const mainView = document.getElementById("main-view");
    if (mainView) mainView.style.removeProperty("--island-page-art");
    setTimeout(updatePageArt, 50);
  }
  if (Spicetify.Platform.History && Spicetify.Platform.History.listen) {
    Spicetify.Platform.History.listen(onNavigate);
  }
  onNavigate();

  // Header-Bilder, die nach dem Routing nachgeladen werden, nachziehen
  const mo = new MutationObserver(() => {
    const url = findPageArt();
    if (url !== currentPageArt && (url || currentPageArt)) {
      currentPageArt = url;
      const mainView = document.getElementById("main-view");
      if (mainView) setVar(mainView, "--island-page-art", url);
    }
  });
  const target = document.getElementById("main-view") || document.body;
  mo.observe(target, { childList: true, subtree: true, attributes: true, attributeFilter: ["src"] });
})();
