#!/usr/bin/env python3
"""Erzeugt die Systemklaenge der Shell (modules/services/sounds/sounds/*.wav).

Eigene Synthese statt Klangthema: kurze, glasige Synth-Toene passend zum
Rice (Synthwave/HUD) – FM-Glocken, Dreieck-Arpeggios, Glides, ein Echo.
Nur Standardbibliothek, 48 kHz mono 16 bit. Neu erzeugen:

    python3 -I modules/services/sounds/gen.py
"""

import math
import random
import struct
import wave
from pathlib import Path

RATE = 48000
OUT = Path(__file__).resolve().parent / "sounds"


def silence(sec: float) -> list[float]:
    return [0.0] * int(sec * RATE)


def env(i: int, n: int, attack: float, decay: float) -> float:
    """Kurzer Anstieg, exponentielles Abklingen (decay = Zeitkonstante in s)."""
    t = i / RATE
    a = min(1.0, t / attack) if attack > 0 else 1.0
    tail = min(1.0, (n - i) / (0.004 * RATE))      # Knackschutz am Ende
    return a * math.exp(-t / decay) * tail


def bell(freq: float, dur: float, ratio: float = 3.5, index: float = 2.2,
         decay: float = 0.18, attack: float = 0.005) -> list[float]:
    """FM-Glocke: Traeger + Modulator, dessen Index mit abklingt (DX-Glas)."""
    n = int(dur * RATE)
    out = []
    for i in range(n):
        t = i / RATE
        e = env(i, n, attack, decay)
        mod = index * math.exp(-t / (decay * 0.5)) * math.sin(2 * math.pi * freq * ratio * t)
        out.append(e * math.sin(2 * math.pi * freq * t + mod))
    return out


def tri(freq: float, dur: float, decay: float = 0.09, attack: float = 0.004) -> list[float]:
    """Weiches Dreieck (wenige Obertoene) – Arpeggio-Noten."""
    n = int(dur * RATE)
    out = []
    for i in range(n):
        t = i / RATE
        ph = (freq * t) % 1.0
        v = 4 * abs(ph - 0.5) - 1
        v = 0.75 * v + 0.25 * math.sin(2 * math.pi * freq * t)
        out.append(env(i, n, attack, decay) * v)
    return out


def glide(f0: float, f1: float, dur: float, decay: float = 0.16) -> list[float]:
    """Sinus-Glide mit leichter Oktave darueber, exponentiell im Ton."""
    n = int(dur * RATE)
    out, ph, ph2 = [], 0.0, 0.0
    for i in range(n):
        k = i / max(1, n - 1)
        f = f0 * (f1 / f0) ** (k ** 0.6)
        ph += 2 * math.pi * f / RATE
        ph2 += 2 * math.pi * 2 * f / RATE
        e = env(i, n, 0.006, decay)
        out.append(e * (math.sin(ph) + 0.18 * math.sin(ph2)))
    return out


def noise_click(dur: float, cutoff: float, decay: float, seed: int) -> list[float]:
    """Gefiltertes Rauschen (zweimal Tiefpass minus Tiefpass = Bandpass)."""
    rng = random.Random(seed)
    n = int(dur * RATE)
    a = math.exp(-2 * math.pi * cutoff / RATE)
    b = math.exp(-2 * math.pi * cutoff * 0.25 / RATE)
    lp1 = lp2 = 0.0
    out = []
    for i in range(n):
        x = rng.uniform(-1, 1)
        lp1 = (1 - a) * x + a * lp1
        lp2 = (1 - b) * x + b * lp2
        out.append(env(i, n, 0.0008, decay) * (lp1 - lp2) * 3)
    return out


def mix(*parts: tuple[float, float, list[float]]) -> list[float]:
    """(start in s, Pegel, Signal) uebereinanderlegen."""
    end = max(int(s * RATE) + len(sig) for s, _g, sig in parts)
    out = [0.0] * end
    for s, g, sig in parts:
        o = int(s * RATE)
        for i, v in enumerate(sig):
            out[o + i] += g * v
    return out


def echo(sig: list[float], delay: float, feedback: float, repeats: int = 3) -> list[float]:
    d = int(delay * RATE)
    out = sig + [0.0] * d * repeats
    for r in range(1, repeats + 1):
        g = feedback ** r
        for i, v in enumerate(sig):
            out[i + d * r] += g * v
    return out


def lowpass(sig: list[float], cutoff: float) -> list[float]:
    a = math.exp(-2 * math.pi * cutoff / RATE)
    y, out = 0.0, []
    for v in sig:
        y = (1 - a) * v + a * y
        out.append(y)
    return out


def write(name: str, sig: list[float], peak: float = 0.6) -> None:
    m = max(1e-9, max(abs(v) for v in sig))
    data = b"".join(struct.pack("<h", int(max(-1, min(1, v * peak / m)) * 32767)) for v in sig)
    OUT.mkdir(exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)


# Noten (Hz)
A5, B5, CS6, E6, FS6, A6, B6 = 880.0, 987.77, 1108.73, 1318.51, 1479.98, 1760.0, 1975.53
E5, B4, E4 = 659.26, 493.88, 329.63


def main() -> None:
    # Neue Nachricht: zwei Glasglocken aufwaerts (Quinte), leises Echo
    write("message", echo(mix(
        (0.00, 1.0, bell(B5, 0.5, decay=0.16)),
        (0.075, 0.9, bell(FS6, 0.6, decay=0.2)),
    ), 0.13, 0.28), peak=0.55)

    # Screenshot: weicher Verschluss (zwei Rauschklicks) + heller Blip
    write("shutter", mix(
        (0.000, 1.0, noise_click(0.06, 5200, 0.012, 1)),
        (0.055, 0.7, noise_click(0.06, 4200, 0.014, 2)),
        (0.010, 0.35, bell(A6, 0.25, ratio=2.0, index=1.0, decay=0.06)),
    ), peak=0.5)

    # Ladekabel an: Arpeggio aufwaerts, letzte Note klingt aus
    write("plug", echo(mix(
        (0.00, 0.8, tri(E5, 0.12, decay=0.05)),
        (0.06, 0.8, tri(B5, 0.12, decay=0.05)),
        (0.12, 1.0, bell(E6, 0.5, ratio=2.0, index=1.2, decay=0.16)),
    ), 0.11, 0.22, 2), peak=0.5)

    # Ladekabel ab: dasselbe abwaerts und gedaempft
    write("unplug", lowpass(mix(
        (0.00, 0.9, tri(E6, 0.12, decay=0.05)),
        (0.06, 0.8, tri(B5, 0.12, decay=0.05)),
        (0.12, 1.0, tri(E5, 0.4, decay=0.14)),
    ), 3000), peak=0.45)

    # Sperren: Glide abwaerts in die Tiefe, ein Klick am Ende
    write("lock", mix(
        (0.00, 1.0, lowpass(glide(A5, E4, 0.32, decay=0.14), 2400)),
        (0.17, 0.5, noise_click(0.04, 2600, 0.008, 3)),
    ), peak=0.5)

    # Entsperren: Glide aufwaerts, oben ein Glanzpunkt
    write("unlock", echo(mix(
        (0.00, 0.9, lowpass(glide(E5, B5, 0.22, decay=0.12), 4000)),
        (0.12, 0.7, bell(E6, 0.45, ratio=3.0, index=1.6, decay=0.13)),
        (0.17, 0.35, bell(B6, 0.4, ratio=3.0, index=1.2, decay=0.1)),
    ), 0.12, 0.22, 2), peak=0.5)


if __name__ == "__main__":
    main()
