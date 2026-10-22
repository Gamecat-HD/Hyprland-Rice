"""Wallhaven-Suche fuer die Wallpaper-Auswahl der Shell.

Die Shell ruft das per Process auf und liest NDJSON von stdout:
  search   -> erst {"type": "result", "meta": …, "items": […]}, dann je fertigem
              Thumbnail {"type": "thumb", "id": …, "thumb": PFAD} (parallel geladen,
              die Kacheln koennen also sofort mit Platzhaltern erscheinen)
  download -> {"type": "done", "id": …, "path": PFAD} bzw. {"type": "error", …}

Kein Key noetig (SFW/Sketchy). Ein Key fuer NSFW/eigene Filter kommt aus
$WALLHAVEN_API_KEY oder ~/.local/state/dynamic-island/wallhaven/apikey - nicht
aus shell.json/cli.json, die liegen im Dotfiles-Repo.
"""

import json
import os
import sys
from argparse import Namespace
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from dynamic_island.utils.paths import c_cache_dir, c_state_dir, wallpapers_dir

API = "https://wallhaven.cc/api/v1"
UA = "dynamic-island-wallhaven/1.0"
SORTINGS = ("relevance", "date_added", "random", "views", "favorites", "toplist")
TOP_RANGES = ("1d", "3d", "1w", "1M", "3M", "6M", "1y")

thumbs_dir: Path = c_cache_dir / "wallhaven/thumbs"
key_path: Path = c_state_dir / "wallhaven/apikey"
# Eigener Unterordner: der Scan der Shell findet die Bilder so von selbst
download_dir: Path = wallpapers_dir / "Wallhaven"


def emit(obj: dict) -> None:
    print(json.dumps(obj), flush=True)


def api_key() -> str | None:
    key = os.getenv("WALLHAVEN_API_KEY")
    if not key:
        try:
            key = key_path.read_text().strip()
        except OSError:
            pass
    return key or None


def fetch(url: str, timeout: float = 15) -> bytes:
    # Erst hier: urllib kostet sonst jeden CLI-Aufruf ~20 ms Startzeit
    from urllib.request import Request, urlopen

    headers = {"User-Agent": UA}
    if url.startswith(API) and (key := api_key()):
        headers["X-API-Key"] = key
    with urlopen(Request(url, headers=headers), timeout=timeout) as r:
        return r.read()


def describe(err: Exception) -> str:
    from urllib.error import HTTPError

    if isinstance(err, HTTPError):
        return {
            401: "API-Key ungueltig",
            404: "Nicht gefunden",
            429: "Zu viele Anfragen (max. 45/min) - kurz warten",
        }.get(err.code, f"HTTP {err.code}")
    return str(getattr(err, "reason", err))


def local_path(item_id: str) -> str | None:
    for ext in ("jpg", "png"):
        p = download_dir / f"wallhaven-{item_id}.{ext}"
        if p.exists():
            return str(p)
    return None


def write_atomic(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + ".part")
    tmp.write_bytes(data)
    os.replace(tmp, path)


class Command:
    args: Namespace

    def __init__(self, args: Namespace) -> None:
        self.args = args

    def run(self) -> None:
        try:
            if self.args.action == "search":
                self.search()
            elif self.args.action == "download":
                self.download()
            elif self.args.action == "key":
                self.set_key()
        except Exception as e:
            emit({"type": "error", "message": describe(e)})
            sys.exit(1)

    def set_key(self) -> None:
        key = (self.args.value or "").strip()
        if key:
            key_path.parent.mkdir(parents=True, exist_ok=True)
            write_atomic(key_path, key.encode())
            key_path.chmod(0o600)
        else:
            key_path.unlink(missing_ok=True)
        emit({"type": "key", "set": bool(key)})

    def search(self) -> None:
        from urllib.parse import urlencode

        a = self.args
        params = {
            "q": a.query or "",
            "categories": a.categories,
            "purity": a.purity,
            "sorting": a.sorting,
            "order": "desc",
            "page": a.page,
        }
        if a.sorting == "toplist":
            params["topRange"] = a.top_range
        if a.sorting == "random" and a.seed:
            params["seed"] = a.seed
        if a.atleast:
            params["atleast"] = a.atleast
        if a.ratios:
            params["ratios"] = a.ratios
        if a.colors:
            params["colors"] = a.colors.lstrip("#")

        res = json.loads(fetch(f"{API}/search?{urlencode(params)}"))
        meta = res.get("meta", {})
        items = []
        todo = []
        for w in res.get("data", []):
            thumb = thumbs_dir / f"{w['id']}.jpg"
            cached = thumb.exists()
            items.append(
                {
                    "id": w["id"],
                    "url": w["url"],
                    "full": w["path"],
                    "thumb": str(thumb) if cached else "",
                    "resolution": w["resolution"],
                    "ratio": w.get("ratio"),
                    "size": w.get("file_size", 0),
                    "fileType": w.get("file_type", ""),
                    "purity": w.get("purity"),
                    "category": w.get("category"),
                    "favorites": w.get("favorites", 0),
                    "views": w.get("views", 0),
                    "colors": w.get("colors", []),
                    "local": local_path(w["id"]),
                }
            )
            if not cached:
                todo.append((w["id"], w["thumbs"]["large"], thumb))

        emit(
            {
                "type": "result",
                "meta": {
                    "page": meta.get("current_page", a.page),
                    "lastPage": meta.get("last_page", 1),
                    "total": meta.get("total", len(items)),
                    "seed": meta.get("seed"),
                },
                "items": items,
            }
        )

        def load(job: tuple[str, str, Path]) -> None:
            item_id, url, path = job
            try:
                write_atomic(path, fetch(url, timeout=10))
                emit({"type": "thumb", "id": item_id, "thumb": str(path)})
            except Exception:
                pass

        with ThreadPoolExecutor(max_workers=8) as pool:
            list(pool.map(load, todo))

    def download(self) -> None:
        item_id = self.args.id
        if not (path := local_path(item_id)):
            url = self.args.url
            if not url:
                url = json.loads(fetch(f"{API}/w/{item_id}"))["data"]["path"]
            ext = "png" if url.lower().endswith(".png") else "jpg"
            target = download_dir / f"wallhaven-{item_id}.{ext}"
            write_atomic(target, fetch(url, timeout=120))
            path = str(target)

        emit({"type": "done", "id": item_id, "path": path})

        if self.args.set:
            from dynamic_island.utils.wallpaper import set_wallpaper

            set_wallpaper(Path(path), False)
