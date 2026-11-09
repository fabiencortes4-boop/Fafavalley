#!/usr/bin/env python3
"""Compose et fabrique les musiques d'ambiance du jeu dans assets/music/.

Créations originales, synthétisées ici (numpy) puis encodées en OGG stéréo
(ffmpeg) : CC0, comme le reste des sons du jeu. Chaque morceau boucle sans
coupure (la réverbération de la fin est ramenée au début).

Le parti pris : une musique douce qu'on peut écouter des heures. Tempos
lents, instruments ronds (piano électrique, harpe, flûte soufflée, nappes
chaudes, basse ronde), tout filtré pour ôter les aigus agressifs, pas de
batterie (sauf un tambourin feutré à la fête), mélodies construites en
phrases qui se répondent (A A' B A'') plutôt qu'au hasard, des passages
sans mélodie pour respirer, réverbération et léger écho en stéréo, et un
mixage sans saturation.

    python3 tools/build_music.py      (nécessite numpy et ffmpeg)
"""
import os
import subprocess
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "music")
RATE = 32000
NOTE = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6,
        "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


def freq(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def chord_notes(name, octave=4):
    """'Am', 'F', 'G7', 'Cmaj7', 'Dm7', 'Esus', 'Cadd9' -> notes MIDI."""
    root = name[0] + (name[1] if len(name) > 1 and name[1] in "#b" else "")
    rest = name[len(root):]
    base = 12 * (octave + 1) + NOTE[root]
    if rest.startswith("maj7"):
        iv = [0, 4, 7, 11]
    elif rest.startswith("m7"):
        iv = [0, 3, 7, 10]
    elif rest.startswith("m"):
        iv = [0, 3, 7]
    elif rest.startswith("7"):
        iv = [0, 4, 7, 10]
    elif rest.startswith("sus"):
        iv = [0, 5, 7]
    elif rest.startswith("add9"):
        iv = [0, 4, 7, 14]
    else:
        iv = [0, 4, 7]
    return [base + i for i in iv]


# --------------------------------------------------------------- filtres
def lowpass(sig, cutoff, order=2):
    """Filtre passe-bas doux (gabarit de Butterworth, appliqué en fréquence)."""
    if cutoff is None:
        return sig
    n = len(sig)
    size = 1 << int(np.ceil(np.log2(n)))
    spec = np.fft.rfft(sig, size)
    f = np.fft.rfftfreq(size, 1 / RATE)
    spec *= 1 / np.sqrt(1 + (f / cutoff) ** (2 * order))
    return np.fft.irfft(spec, size)[:n]


def _t(n):
    return np.arange(n) / RATE


def _env(n, attack, release, dur):
    x = _t(n)
    return np.clip(x / max(attack, 1e-4), 0, 1) * np.clip((dur - x) / max(release, 1e-4), 0, 1)


# --------------------------------------------------------------- instruments
def epiano(f, dur, tone=1.0):
    """Piano électrique : sinus modulé en fréquence (attaque un peu claire qui
    s'arrondit vite), petite « lame » à l'octave, longue tenue douce."""
    ring = max(dur, 1.2)
    n = int(RATE * ring)
    x = _t(n)
    index = 1.1 * tone * np.exp(-x * 6)
    mod = np.sin(2 * np.pi * f * x) * index
    sig = np.sin(2 * np.pi * f * x + mod) * np.exp(-x * 1.4)
    sig += 0.12 * tone * np.sin(2 * np.pi * f * 4 * x) * np.exp(-x * 14)
    return sig * _env(n, 0.006, 0.25, ring)


def harp(f, dur):
    """Harpe / guitare nylon : harmoniques qui s'éteignent vite, fondamentale
    qui chante."""
    ring = max(dur, 1.5)
    n = int(RATE * ring)
    x = _t(n)
    sig = np.zeros(n)
    for h, a in ((1, 1.0), (2, 0.35), (3, 0.12), (4, 0.05)):
        sig += a * np.sin(2 * np.pi * f * h * x + h) * np.exp(-x * (1.6 + 2.2 * h))
    return sig * _env(n, 0.004, 0.3, ring)


def musicbox(f, dur):
    """Boîte à musique feutrée (peu de partiels aigus)."""
    ring = max(dur, 1.6)
    n = int(RATE * ring)
    x = _t(n)
    sig = np.sin(2 * np.pi * f * x) * np.exp(-x * 1.8)
    sig += 0.18 * np.sin(2 * np.pi * f * 3.0 * x) * np.exp(-x * 6)
    return sig * _env(n, 0.004, 0.3, ring)


rng = np.random.default_rng(3)


def flute(f, dur):
    """Flûte soufflée : attaque lente, vibrato qui arrive après, un peu de souffle."""
    n = int(RATE * dur)
    x = _t(n)
    vib = 1 + 0.0035 * np.sin(2 * np.pi * 4.8 * x) * np.clip((x - 0.25) / 0.4, 0, 1)
    phase = 2 * np.pi * f * np.cumsum(vib) / RATE
    sig = np.sin(phase) + 0.08 * np.sin(2 * phase) + 0.02 * np.sin(3 * phase)
    breath = lowpass(rng.uniform(-1, 1, n), 2200) * 0.05
    return (sig + breath) * _env(n, 0.12, 0.18, dur)


def pad(freqs, dur):
    """Nappe chaude : ondes douces désaccordées qui respirent lentement."""
    n = int(RATE * dur)
    x = _t(n)
    sig = np.zeros(n)
    for f in freqs:
        for det in (-0.8, 0.0, 0.8):
            p = 2 * np.pi * (f + det) * x
            sig += np.sin(p) + 0.1 * np.sin(3 * p)
    sig *= 1 + 0.12 * np.sin(2 * np.pi * 0.25 * x)
    return sig * _env(n, 1.2, 1.2, dur) / max(1, 3 * len(freqs))


def bass(f, dur):
    """Basse ronde (contrebasse feutrée)."""
    n = int(RATE * max(dur, 0.6))
    x = _t(n)
    sig = np.sin(2 * np.pi * f * x) + 0.25 * np.sin(4 * np.pi * f * x) * np.exp(-x * 4)
    return sig * np.exp(-x * 1.2) * _env(n, 0.02, 0.15, len(x) / RATE)


def tambourine(dur=0.12):
    """Tambourin feutré (seulement pour la fête)."""
    n = int(RATE * dur)
    s = lowpass(rng.uniform(-1, 1, n), 5000) - lowpass(rng.uniform(-1, 1, n), 1500)
    return s * np.exp(-_t(n) * 35)


def soft_kick(dur=0.35):
    n = int(RATE * dur)
    x = _t(n)
    f = 70 * np.exp(-x * 12) + 42
    return np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.exp(-x * 9)


def drip(f):
    n = int(RATE * 0.3)
    x = _t(n)
    ff = f * (1 + 0.8 * np.exp(-x * 40))
    return np.sin(2 * np.pi * np.cumsum(ff) / RATE) * np.exp(-x * 14) * _env(n, 0.003, 0.05, 0.3)


# --------------------------------------------------------------- mixage
class Track:
    """Pistes (bus) en stéréo : chacune a son panoramique, son filtre et sa
    part de réverbération."""

    def __init__(self, bpm, bars, beats=4):
        self.beat = 60.0 / bpm
        self.length = int(RATE * self.beat * beats * bars)
        self.beats = beats
        self.bus = {}
        self.conf = {}

    def setup(self, bus, pan=0.0, cutoff=6000, send=0.3, delay=0.0):
        self.conf[bus] = (pan, cutoff, send, delay)

    def add(self, bus, sig, at_beat, gain):
        start = int(at_beat * self.beat * RATE)
        buf = self.bus.setdefault(bus, np.zeros(self.length + RATE * 8))
        end = min(len(buf), start + len(sig))
        if end > start:
            buf[start:end] += sig[:end - start] * gain

    def render(self, room=2.4):
        total = self.length + RATE * 8
        dry = np.zeros((2, total))
        wet = np.zeros(total)
        for name, buf in self.bus.items():
            pan, cutoff, send, delay = self.conf.get(name, (0.0, 6000, 0.3, 0.0))
            sig = lowpass(buf, cutoff)
            if delay > 0:
                # Écho doux en croisé (deux répétitions de plus en plus faibles)
                d = int(delay * self.beat * RATE)
                echo = np.zeros_like(sig)
                echo[d:] += sig[:-d] * 0.28
                echo[2 * d:] += sig[:-2 * d] * 0.1
                echo = lowpass(echo, 2500)
                dry[0] += echo * 0.9
                dry[1] += np.roll(echo, d // 2) * 0.9
            a = (pan + 1) * np.pi / 4
            dry[0] += sig * np.cos(a)
            dry[1] += sig * np.sin(a)
            wet += sig * send
        # Réverbération stéréo : deux queues de bruit décorrélées, assombries
        n = int(RATE * room)
        size = 1 << int(np.ceil(np.log2(total + n)))
        out = dry.copy()
        for ch in range(2):
            ir = rng.uniform(-1, 1, n) * np.exp(-_t(n) * (6.0 / room))
            ir = lowpass(ir, 3000)
            ir[: int(RATE * 0.02)] = 0  # prédélai : la note reste nette
            rev = np.fft.irfft(np.fft.rfft(wet, size) * np.fft.rfft(ir, size), size)[:total]
            rev *= 0.9 * np.abs(wet).max() / max(1e-9, np.abs(rev).max())
            out[ch] += rev
        # Boucle parfaite : la queue au-delà de la fin revient au début
        mix = out[:, :self.length].copy()
        tail = out[:, self.length:]
        mix[:, :tail.shape[1]] += tail[:, :self.length]
        # Mastering doux : léger passe-bas général, compression lente, pas de saturation
        mix = np.array([lowpass(mix[0], 7000, 1), lowpass(mix[1], 7000, 1)])
        level = np.convolve(np.abs(mix).max(axis=0), np.ones(RATE // 4) / (RATE // 4), mode="same")
        gain = 1 / (1 + 0.6 * level / (level.max() + 1e-9))
        mix *= gain
        return mix / (np.abs(mix).max() + 1e-9) * 0.7


def save(name, sig):
    os.makedirs(OUT, exist_ok=True)
    wav = os.path.join(OUT, name + ".wav")
    inter = np.clip(sig.T.reshape(-1), -1, 1)
    with wave.open(wav, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((inter * 32767).astype(np.int16).tobytes())
    dst = os.path.join(OUT, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "0", dst], check=True)
    os.remove(wav)
    print("%-10s %5.1f s  %4d Ko" % (name, sig.shape[1] / RATE, os.path.getsize(dst) // 1024))


# --------------------------------------------------------------- composition
MAJOR = [0, 2, 4, 5, 7, 9, 11]
MINOR = [0, 2, 3, 5, 7, 8, 10]
PENTA = [0, 2, 4, 7, 9]
PENTA_MINOR = [0, 3, 5, 7, 10]


def transpose(scale, root):
    return sorted((s + NOTE[root]) % 12 for s in scale)


def melody(track, bus, inst, chords, scale, low, high, gain, seed, rhythms, rests=(),
           density=0.8, length_factor=1.0, beats_per_chord=4):
    """Mélodie en phrases de 4 mesures : A, A' (même dessin, autre fin), B,
    A''. Chaque mesure reprend un rythme et un contour mémorisés, posés sur
    l'accord du moment (notes de l'accord sur les temps forts, gamme
    pentatonique ailleurs : jamais de fausse note). Les fins de phrase se
    posent sur une note longue de l'accord. `rests` : mesures sans mélodie."""
    r = np.random.default_rng(seed)
    pool = [m for m in range(low, high + 1) if m % 12 in scale]
    shapes = {}

    def shape(key):
        if key not in shapes:
            rh = rhythms[r.integers(len(rhythms))]
            steps = [int(r.choice([-2, -1, -1, 0, 1, 1, 2])) for _ in rh]
            keep = [r.random() < density for _ in rh]
            keep[0] = True
            shapes[key] = (rh, steps, keep)
        return shapes[key]

    cur = pool[len(pool) // 2]
    pos = 0.0
    for bar, ch in enumerate(chords):
        if bar in rests:
            pos += beats_per_chord
            continue
        phrase = (bar // 4) % 4  # 0 A, 1 A', 2 B, 3 A''
        in_phrase = bar % 4
        kind = "B" if phrase == 2 else "A"
        tones = [m for m in pool if m % 12 in {n % 12 for n in chord_notes(ch)}]
        if in_phrase == 3:
            # Fin de phrase : une ou deux notes, puis une note longue de l'accord
            target = min(tones, key=lambda m: abs(m - cur) + (0 if m % 12 == chord_notes(ch)[0] % 12 else 2))
            if phrase in (0, 2):
                track.add(bus, inst(freq(cur), track.beat * length_factor), pos, gain * 0.9)
                track.add(bus, inst(freq(target), track.beat * 3 * length_factor), pos + 1, gain)
            else:
                track.add(bus, inst(freq(target), track.beat * 4 * length_factor), pos, gain)
            cur = target
            pos += beats_per_chord
            continue
        rh, steps, keep = shape((kind, in_phrase))
        b = 0.0
        for d, st, k in zip(rh, steps, keep):
            strong = abs(b - round(b)) < 1e-6 and int(round(b)) % 2 == 0
            cands = tones if strong else pool
            idx = min(range(len(pool)), key=lambda i: abs(pool[i] - cur))
            want = pool[max(0, min(len(pool) - 1, idx + st))]
            m = min(cands, key=lambda c: abs(c - want))
            if k:
                track.add(bus, inst(freq(m), d * track.beat * length_factor), pos + b, gain * (1.0 if strong else 0.85))
                cur = m
            b += d
        pos += beats_per_chord


def arpeggio(track, bus, chords, octave, gain, pattern=(0, 1, 2, 1), step=0.5, inst=harp, beats_per_chord=4, accent=1.0):
    pos = 0.0
    for ch in chords:
        tones = chord_notes(ch, octave)
        k = 0
        b = 0.0
        while b < beats_per_chord - 1e-6:
            m = tones[pattern[k % len(pattern)] % len(tones)] + (12 if pattern[k % len(pattern)] >= len(tones) else 0)
            g = gain * (accent if k == 0 else 1.0)
            track.add(bus, inst(freq(m), step * track.beat * 2.0), pos + b, g)
            b += step
            k += 1
        pos += beats_per_chord


def comping(track, bus, chords, octave, gain, hits=(0, 2), inst=epiano, beats_per_chord=4):
    """Accords plaqués doucement, sur quelques temps."""
    pos = 0.0
    for ch in chords:
        for h in hits:
            for i, m in enumerate(chord_notes(ch, octave)):
                track.add(bus, inst(freq(m), track.beat * 1.5, 0.6), pos + h + i * 0.012, gain / 3)
        pos += beats_per_chord


def bassline(track, chords, gain, pattern=((0, 0, 2), (2, 7, 2)), beats_per_chord=4):
    pos = 0.0
    for ch in chords:
        root = chord_notes(ch, 2)[0]
        for b, iv, d in pattern:
            track.add("bass", bass(freq(root + iv), track.beat * d), pos + b, gain)
        pos += beats_per_chord


def pads(track, chords, gain, octave=3, beats_per_chord=4):
    pos = 0.0
    for ch in chords:
        track.add("pad", pad([freq(m) for m in chord_notes(ch, octave)], beats_per_chord * track.beat + 1.2), pos, gain)
        pos += beats_per_chord


def standard_buses(tr, lead_pan=0.1, lead_delay=0.75):
    tr.setup("pad", pan=0.0, cutoff=2200, send=0.5)
    tr.setup("arp", pan=-0.35, cutoff=3500, send=0.35)
    tr.setup("keys", pan=0.3, cutoff=3200, send=0.35)
    tr.setup("bass", pan=0.0, cutoff=700, send=0.05)
    tr.setup("lead", pan=lead_pan, cutoff=4500, send=0.4, delay=lead_delay)
    tr.setup("perc", pan=0.2, cutoff=6000, send=0.15)
    tr.setup("fx", pan=0.0, cutoff=4000, send=0.6)


# Ferme (jour) : do majeur, balade tranquille, harpe et flûte
def farm():
    a = ["C", "G", "Am", "F", "C", "G", "F", "C"]
    b = ["F", "G", "Em", "Am", "F", "G", "C", "C"]
    chords = a + a + b + a
    tr = Track(76, len(chords))
    standard_buses(tr)
    pads(tr, chords, 0.32)
    arpeggio(tr, "arp", chords, 3, 0.2, pattern=(0, 1, 2, 3, 2, 1, 2, 1), step=0.5, accent=1.15)
    bassline(tr, chords, 0.42, pattern=((0, 0, 2.5), (2.5, 7, 1.5)))
    melody(tr, "lead", flute, chords, transpose(PENTA, "C"), 67, 86, 0.3, seed=11,
           rhythms=[(1, 1, 2), (1.5, 0.5, 2), (2, 1, 1), (1, 0.5, 0.5, 2)], rests=range(0, 4), density=0.85, length_factor=0.95)
    return tr.render(2.6)


# Village et port : fa majeur, un peu plus enlevé, piano électrique et harpe
def village():
    a = ["F", "C", "Dm", "Bb", "F", "C", "Bb", "C"]
    b = ["Dm", "Am", "Bb", "F", "Gm", "C", "F", "F"]
    chords = a + a + b + a
    tr = Track(88, len(chords))
    standard_buses(tr)
    pads(tr, chords, 0.2)
    comping(tr, "keys", chords, 4, 0.32, hits=(0, 1.5, 3))
    arpeggio(tr, "arp", chords, 4, 0.12, pattern=(0, 1, 2, 1), step=1.0)
    bassline(tr, chords, 0.45, pattern=((0, 0, 1.5), (1.5, 7, 1), (3, 12, 1)))
    melody(tr, "lead", lambda f, d: epiano(f, d, 0.8), chords, transpose(PENTA, "F"), 65, 84, 0.34, seed=5,
           rhythms=[(1, 0.5, 0.5, 2), (0.5, 0.5, 1, 2), (1.5, 0.5, 1, 1), (2, 2)], rests=range(24, 28), density=0.9)
    for bar in range(len(chords)):
        for bt in (1, 3):
            tr.add("perc", tambourine(0.08), bar * 4 + bt, 0.025)
    return tr.render(2.4)


# Mine : la mineur, lente, nappes graves, gouttes d'eau
def mine():
    a = ["Am", "Am", "F", "F", "Dm", "Dm", "E", "E"]
    b = ["Am", "Am", "C", "G", "F", "Dm", "E", "E"]
    chords = a + b + a + b
    tr = Track(58, len(chords))
    standard_buses(tr, lead_delay=1.0)
    tr.setup("pad", pan=0.0, cutoff=1500, send=0.6)
    pads(tr, chords, 0.45, octave=2)
    bassline(tr, chords, 0.35, pattern=((0, 0, 4),))
    melody(tr, "lead", musicbox, chords, transpose(PENTA_MINOR, "A"), 64, 81, 0.2, seed=21,
           rhythms=[(2, 2), (3, 1), (1, 3)], rests=list(range(0, 4)) + list(range(16, 20)), density=0.6)
    r = np.random.default_rng(9)
    for k in range(16):  # gouttes d'eau dans la grotte
        tr.add("fx", drip(r.uniform(1100, 1800)), r.uniform(0, len(chords) * 4 - 1), 0.06)
    return tr.render(3.4)


# Maison et intérieurs : sol majeur, piano électrique en arpèges lents
def home():
    a = ["Gmaj7", "Em7", "Cmaj7", "D", "Gmaj7", "Em7", "Am7", "D"]
    b = ["Cmaj7", "Bm", "Am7", "D", "Gmaj7", "Em7", "Cmaj7", "D"]
    chords = a + b + a + b
    tr = Track(68, len(chords))
    standard_buses(tr)
    pads(tr, chords, 0.24)
    arpeggio(tr, "keys", chords, 4, 0.2, pattern=(0, 2, 1, 3, 2, 1), step=1.0 * 2 / 3,
             inst=lambda f, d: epiano(f, d, 0.5))
    bassline(tr, chords, 0.32, pattern=((0, 0, 4),))
    melody(tr, "lead", musicbox, chords, transpose(PENTA, "G"), 71, 88, 0.2, seed=8,
           rhythms=[(1, 1, 2), (2, 2), (1.5, 0.5, 2)], rests=list(range(0, 4)) + list(range(16, 20)), density=0.75)
    return tr.render(2.8)


# Fête : ré majeur, joyeuse mais ronde (pas de claquements)
def festival():
    a = ["D", "A", "Bm", "G", "D", "A", "G", "A"]
    b = ["Bm", "F#m", "G", "D", "Em", "A", "D", "D"]
    chords = a + a + b + a
    tr = Track(108, len(chords))
    standard_buses(tr, lead_delay=0.5)
    pads(tr, chords, 0.14)
    arpeggio(tr, "arp", chords, 4, 0.16, pattern=(0, 1, 2, 1, 0, 2, 1, 2), step=0.5, accent=1.2)
    comping(tr, "keys", chords, 4, 0.22, hits=(1, 3))
    bassline(tr, chords, 0.45, pattern=((0, 0, 1), (1, 12, 0.5), (2, 7, 1), (3, 12, 0.5)))
    melody(tr, "lead", flute, chords, transpose(PENTA, "D"), 69, 88, 0.3, seed=31,
           rhythms=[(0.5, 0.5, 1, 2), (1, 0.5, 0.5, 1, 1), (0.5, 0.5, 0.5, 0.5, 2)], rests=range(0, 4), density=0.9)
    for bar in range(len(chords)):
        tr.add("perc", soft_kick(), bar * 4, 0.22)
        tr.add("perc", soft_kick(), bar * 4 + 2, 0.15)
        for bt in range(4):
            tr.add("perc", tambourine(), bar * 4 + bt + 0.5, 0.05)
    return tr.render(2.2)


# Nuit : mi bémol, très lente, nappes et quelques notes de piano
def night():
    a = ["Ebmaj7", "Cm7", "Abmaj7", "Bb", "Ebmaj7", "Gm", "Abmaj7", "Bb"]
    b = ["Cm7", "Gm", "Abmaj7", "Eb", "Fm7", "Bb", "Eb", "Eb"]
    chords = a + b + a + b
    tr = Track(56, len(chords))
    standard_buses(tr, lead_delay=1.0)
    pads(tr, chords, 0.38)
    melody(tr, "lead", lambda f, d: epiano(f, d, 0.4), chords, transpose(PENTA, "Eb"), 67, 84, 0.24, seed=17,
           rhythms=[(2, 2), (3, 1), (1, 1, 2)], rests=list(range(0, 4)) + list(range(20, 24)), density=0.65, length_factor=1.3)
    bassline(tr, chords, 0.28, pattern=((0, 0, 4),))
    return tr.render(3.4)


if __name__ == "__main__":
    for name, fn in (("farm", farm), ("village", village), ("mine", mine), ("home", home), ("festival", festival), ("night", night)):
        save(name, fn())
