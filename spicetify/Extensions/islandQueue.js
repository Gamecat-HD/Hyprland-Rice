// NAME: Island Queue
// AUTHOR: gamecat
// DESCRIPTION: Schickt vorherige/aktuelle/naechste Titel der Spotify-Queue per
//              WebSocket an die Dynamic-Island-Shell (ws://127.0.0.1:28199).
//              MPRIS kennt keine Queue, darum dieser Umweg.

/// <reference path="../globals.d.ts" />

(function IslandQueue() {
	if (!Spicetify?.Player?.addEventListener || !Spicetify.Queue) {
		setTimeout(IslandQueue, 500);
		return;
	}

	const URL = "ws://127.0.0.1:28199";
	const DEPTH = 3; // Titel je Richtung
	const IMAGE = "https://i.scdn.co/image/";

	let ws = null;
	let retry = 2000;
	let lastSent = "";

	// spotify:image:<id> → https://i.scdn.co/image/<id>; lokale Dateien haben kein Cover
	const image = (meta) => {
		const raw = meta.image_url || meta.image_large_url || meta.image_xlarge_url || meta.image_small_url || "";
		if (raw.startsWith("spotify:image:")) return IMAGE + raw.slice(14);
		return raw.startsWith("https://") ? raw : "";
	};

	const artists = (meta) => {
		let out = meta.artist_name || "";
		for (let i = 1; meta[`artist_name:${i}`]; i++) out += `, ${meta[`artist_name:${i}`]}`;
		return out || meta.album_title || "";
	};

	// Trenner, Werbung und entfernte Eintraege tauchen in der Queue mit auf
	const usable = (t) =>
		t?.uri && !t.uri.startsWith("spotify:delimiter") && !t.uri.startsWith("spotify:ad:") && !t.removed?.length && t.metadata?.title;

	const pack = (t) => ({
		uri: t.uri,
		title: t.metadata.title,
		artist: artists(t.metadata),
		album: t.metadata.album_title || "",
		art: image(t.metadata),
		queued: t.provider === "queue",
	});

	// Queue-Eintraege kommen je nach Quelle als ProvidedTrack oder mit contextTrack-Huelle
	const unwrap = (t) => t?.contextTrack ?? t;

	// Spicetify.Queue ist nur ein Getter auf PlayerAPI._queue._state; der ist bis zum
	// ersten Queue-Event leer, darum zusaetzlich die internen Rohlisten (wie shuffle+).
	function lists() {
		const pq = Spicetify.Player.origin?._queue ?? Spicetify.Platform?.PlayerAPI?._queue;
		const q = Spicetify.Queue;
		const state = pq?._queueState;
		let next = q?.nextTracks ?? [];
		if (!next.length && state) next = [...(state.queued ?? []), ...(state.nextUp ?? [])];
		let prev = q?.prevTracks ?? [];
		if (!prev.length) prev = pq?._queue?.prevTracks ?? [];
		return { current: q?.track ?? state?.current ?? Spicetify.Player.data?.item, next, prev };
	}

	function snapshot() {
		const { current, next, prev } = lists();
		const cur = unwrap(current);
		return {
			type: "queue",
			current: usable(cur) ? pack(cur) : null,
			// prevTracks ist chronologisch, der direkte Vorgaenger steht am Ende
			prev: prev.map(unwrap).filter(usable).slice(-DEPTH).reverse().map(pack),
			next: next.map(unwrap).filter(usable).slice(0, DEPTH).map(pack),
		};
	}

	function send(force = false) {
		if (ws?.readyState !== WebSocket.OPEN) return;
		const json = JSON.stringify(snapshot());
		if (!force && json === lastSent) return;
		lastSent = json;
		ws.send(json);
	}

	function connect() {
		try {
			ws = new WebSocket(URL);
		} catch {
			return schedule();
		}
		ws.onopen = () => {
			retry = 2000;
			send(true);
		};
		ws.onmessage = (ev) => {
			let msg;
			try {
				msg = JSON.parse(ev.data);
			} catch {
				return;
			}
			if (msg.cmd === "refresh") send(true);
		};
		ws.onclose = schedule;
		ws.onerror = () => ws?.close();
	}

	// Shell aus → leise mit wachsendem Abstand (max. 30 s) neu versuchen
	function schedule() {
		ws = null;
		setTimeout(connect, retry);
		retry = Math.min(retry * 1.5, 30000);
	}

	Spicetify.Player.addEventListener("songchange", () => setTimeout(send, 300));
	// Queue-Aenderungen ohne Titelwechsel (Hinzufuegen, Umsortieren) melden sich ueber "update"
	Spicetify.Player.origin?._events?.addListener?.("update", () => send());
	// Sicherheitsnetz; send() vergleicht und schickt nur bei Aenderung
	setInterval(send, 3000);

	connect();
})();
