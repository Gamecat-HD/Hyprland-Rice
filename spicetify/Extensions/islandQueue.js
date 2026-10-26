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
	const DEPTH_PREV = 5; // Titel zurueck
	const DEPTH_NEXT = 30; // Titel voraus (aufklappbare Warteschlange)
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
		uid: t.uid || "",
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
			prev: prev.map(unwrap).filter(usable).slice(-DEPTH_PREV).reverse().map(pack),
			next: next.map(unwrap).filter(usable).slice(0, DEPTH_NEXT).map(pack),
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
			else if (msg.cmd === "skip") skip(msg);
			else if (msg.cmd === "lyrics") lyrics();
			else if (msg.cmd === "play") play(msg);
		};
		ws.onclose = schedule;
		ws.onerror = () => ws?.close();
	}

	// Zu einem Titel der Warteschlange springen: Spotifys PlayerAPI.skipTo,
	// sonst so oft "weiter", bis er dran ist
	async function skip({ uri, uid, index }) {
		const api = Spicetify.Platform?.PlayerAPI;
		try {
			if (api?.skipTo) {
				await api.skipTo({ uri, uid });
				return;
			}
		} catch (e) {
			console.warn("[islandQueue] skipTo:", e);
		}
		for (let i = 0; i <= index; i++) {
			await Spicetify.Player.next();
			await new Promise((r) => setTimeout(r, 120));
		}
	}

	// Songtext ueber denselben Weg wie Spotifys eigene Lyrics-Ansicht.
	// Antwort immer schicken (auch leer), dann faellt die Shell sofort auf
	// lrclib zurueck statt auf ihren Timeout zu warten.
	async function lyrics() {
		const item = Spicetify.Player.data?.item;
		const uri = item?.uri || "";
		const title = item?.metadata?.title || item?.name || "";
		const answer = { type: "lyrics", uri, title, synced: false, lines: [] };
		const id = uri.startsWith("spotify:track:") ? uri.slice(14) : "";
		if (id) {
			try {
				const res = await Spicetify.CosmosAsync.get(
					`https://spclient.wg.spotify.com/color-lyrics/v2/track/${id}?format=json&vocalRemoval=false&market=from_token`,
				);
				const l = res?.lyrics;
				if (l?.lines?.length) {
					answer.synced = l.syncType === "LINE_SYNCED";
					answer.lines = l.lines.map((x) => ({
						t: answer.synced ? Number(x.startTimeMs) : -1,
						text: x.words === "♪" ? "♪" : x.words || "",
					}));
				}
			} catch (e) {
				// 404 = Spotify hat keinen Text
			}
		}
		if (ws?.readyState === WebSocket.OPEN) ws.send(JSON.stringify(answer));
	}

	// Suchen und abspielen (fuer lokale Clients ueber die Shell, z. B. Sprachsteuerung).
	// Playlists zuerst in der eigenen Bibliothek (auch private, unscharf nach Namen), "liked"/
	// "lieblings…" = Lieblingssongs; sonst erster Treffer der Spotify-Suche. Antwort immer schicken.
	const norm = (t) => (t || "").toLowerCase().normalize("NFKD").replace(/[^\p{L}\p{N} ]/gu, " ").replace(/\b(playlist|my|meine?n?|die|the)\b/g, " ").replace(/\s+/g, " ").trim();

	async function ownPlaylists() {
		const out = [];
		let url = "https://api.spotify.com/v1/me/playlists?limit=50";
		for (let i = 0; url && i < 6; i++) {
			const res = await Spicetify.CosmosAsync.get(url);
			out.push(...(res?.items || []).filter(Boolean));
			url = res?.next;
		}
		return out;
	}

	async function play({ query = "", kind = "track" }) {
		const types = ["track", "artist", "album", "playlist"];
		const type = types.includes(kind) ? kind : "track";
		const answer = { type: "play_result", ok: false, query, kind: type };
		const done = (uri, title, artist = "", source = "") => Object.assign(answer, { ok: true, uri, title, artist, source });
		try {
			const q = norm(query);
			if (/\b(liked|lieblings\w*|favorit\w*|gespeichert\w*)\b/.test(q)) {
				await Spicetify.Player.playUri(`spotify:user:${Spicetify.Platform?.username}:collection`);
				done("collection", "Liked Songs", "", "library");
			} else if (type === "playlist") {
				const mine = await ownPlaylists();
				const hit = mine.find((p) => norm(p.name) === q) || mine.find((p) => norm(p.name).includes(q))
					|| mine.find((p) => q.includes(norm(p.name)) && norm(p.name).length > 2);
				if (hit) {
					await Spicetify.Player.playUri(hit.uri);
					done(hit.uri, hit.name, hit.owner?.display_name || "", "library");
				} else answer.yourPlaylists = mine.map((p) => p.name).slice(0, 40);
			}
			if (!answer.ok) {
				const res = await Spicetify.CosmosAsync.get(
					`https://api.spotify.com/v1/search?q=${encodeURIComponent(query)}&type=${type}&limit=1`,
				);
				const hit = res?.[`${type}s`]?.items?.find(Boolean);
				if (hit?.uri) {
					await Spicetify.Player.playUri(hit.uri);
					done(hit.uri, hit.name || "", (hit.artists || []).map((a) => a.name).join(", ") || hit.owner?.display_name || "", "search");
				} else answer.error = "no result";
			}
		} catch (e) {
			answer.error = String(e?.message || e);
		}
		if (ws?.readyState === WebSocket.OPEN) ws.send(JSON.stringify(answer));
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
