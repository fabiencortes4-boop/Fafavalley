#!/usr/bin/env python3
"""Compose et fabrique les musiques d'ambiance du jeu dans assets/music/.

Créations originales, synthétisées ici (numpy) puis encodées en OGG
(ffmpeg) : CC0, comme le reste des sons du jeu. Chaque morceau boucle
sans coupure (la réverbération de la fin est ramenée au début).

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
    """'Am', 'F', 'G7', 'Cmaj7', 'Dm7', 'Esus' -> notes MIDI."""
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
    else:
        iv = [0, 4, 7]
    return [base + i for i in iv]


# --------------------------------------------------------------- instruments
def _t(n):
    return np.arange(n) / RATE


def pluck(f, dur, bright=1.0):
    n = int(RATE * dur)
    x = _t(n)
    sig = np.zeros(n)
    for h, a in ((1, 1.0), (2, 0.5 * bright), (3, 0.25 * bright), (4, 0.12 * bright)):
        sig += a * np.sin(2 * np.pi * f * h * x) * np.exp(-x * (4 + 3 * h))
    return sig * np.clip(x / 0.003, 0, 1)


def bell(f, dur):
    """Boîte à musique : partiels inharmoniques, longue résonance."""
    n = int(RATE * dur)
    x = _t(n)
    sig = np.sin(2 * np.pi * f * x) * np.exp(-x * 2.2)
    sig += 0.35 * np.sin(2 * np.pi * f * 2.76 * x) * np.exp(-x * 5)
    sig += 0.15 * np.sin(2 * np.pi * f * 5.4 * x) * np.exp(-x * 9)
    return sig * np.clip(x / 0.002, 0, 1)


def flute(f, dur):
    n = int(RATE * dur)
    x = _t(n)
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.2 * x) * np.clip(x / 0.25, 0, 1)
    phase = 2 * np.pi * f * np.cumsum(vib) / RATE
    sig = np.sin(phase) + 0.18 * np.sin(2 * phase) + 0.06 * np.sin(3 * phase)
    env = np.clip(x / 0.06, 0, 1) * np.clip((dur - x) / 0.08, 0, 1)
    return sig * env


def pad(freqs, dur):
    """Nappe douce : sinus légèrement désaccordés, attaque lente."""
    n = int(RATE * dur)
    x = _t(n)
    sig = np.zeros(n)
    for f in freqs:
        for det in (-0.6, 0.6):
            sig += np.sin(2 * np.pi * (f + det) * x) + 0.2 * np.sin(2 * np.pi * 2 * (f + det) * x)
    env = np.clip(x / 0.6, 0, 1) * np.clip((dur - x) / 0.6, 0, 1)
    return sig * env / max(1, len(freqs))


def bass(f, dur):
    n = int(RATE * dur)
    x = _t(n)
    tri = 2 / np.pi * np.arcsin(np.sin(2 * np.pi * f * x))
    return (tri + 0.5 * np.sin(2 * np.pi * f * x)) * np.exp(-x * 2.5) * np.clip(x / 0.01, 0, 1)


def kick(dur=0.3):
    n = int(RATE * dur)
    x = _t(n)
    f = 110 * np.exp(-x * 18) + 45
    return np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.exp(-x * 10)


rng = np.random.default_rng(3)


def shaker(dur=0.08):
    n = int(RATE * dur)
    s = rng.uniform(-1, 1, n)
    s = np.diff(s, prepend=0)  # bruit aigu
    return s * np.exp(-_t(n) * 45)


def clap(dur=0.18):
    n = int(RATE * dur)
    s = rng.uniform(-1, 1, n)
    s = s - np.convolve(s, np.ones(6) / 6, mode="same")
    x = _t(n)
    return s * (np.exp(-x * 30) + 0.5 * np.exp(-np.maximum(x - 0.012, 0) * 30) * (x > 0.012))


def drip(f):
    n = int(RATE * 0.25)
    x = _t(n)
    ff = f * (1 + 1.5 * np.exp(-x * 40))
    return np.sin(2 * np.pi * np.cumsum(ff) / RATE) * np.exp(-x * 18)


# --------------------------------------------------------------- mixage
class Track:
    def __init__(self, bpm, bars, beats=4):
        self.beat = 60.0 / bpm
        self.length = int(RATE * self.beat * beats * bars)
        self.beats = beats
        self.bus = {}

    def add(self, bus, sig, at_beat, gain):
        start = int(at_beat * self.beat * RATE)
        buf = self.bus.setdefault(bus, np.zeros(self.length + RATE * 6))
        end = min(len(buf), start + len(sig))
        buf[start:end] += sig[:end - start] * gain

    def render(self, reverb=0.25, reverb_buses=None):
        dry = np.zeros(self.length + RATE * 6)
        wet = np.zeros_like(dry)
        for name, buf in self.bus.items():
            dry += buf
            if reverb_buses is None or name in reverb_buses:
                wet += buf
        # Réverbération : convolution avec une queue de bruit décroissante
        n = int(RATE * 2.2)
        ir = rng.uniform(-1, 1, n) * np.exp(-_t(n) * 2.6)
        ir = np.convolve(ir, np.ones(8) / 8, mode="same")  # plus sombre
        size = 1 << int(np.ceil(np.log2(len(wet) + n)))
        rev = np.fft.irfft(np.fft.rfft(wet, size) * np.fft.rfft(ir, size), size)[:len(wet)]
        rev *= reverb / max(1e-9, np.abs(rev).max()) * max(1e-9, np.abs(wet).max())
        mix = dry + rev
        # Boucle parfaite : la queue au-delà de la fin revient au début
        out = mix[:self.length].copy()
        tail = mix[self.length:]
        out[:len(tail)] += tail[:self.length]
        # Normalisation douce
        out = np.tanh(out / (np.abs(out).max() + 1e-9) * 1.3) * 0.82
        return out


def save(name, sig):
    os.makedirs(OUT, exist_ok=True)
    wav = os.path.join(OUT, name + ".wav")
    with wave.open(wav, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((np.clip(sig, -1, 1) * 32767).astype(np.int16).tobytes())
    dst = os.path.join(OUT, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "2", dst], check=True)
    os.remove(wav)
    print("%-10s %5.1f s  %4d Ko" % (name, len(sig) / RATE, os.path.getsize(dst) // 1024))


# --------------------------------------------------------------- composition
def melody_line(track, bus, inst, chords, scale, octave, gain, seed, density=0.7, beats_per_chord=4, rhythm=(1, 1, 0.5, 0.5, 1)):
    """Mélodie qui suit les accords : notes de l'accord sur les temps forts,
    notes de passage ailleurs. Phrases répétées (A A' B A) pour l'oreille."""
    r = np.random.default_rng(seed)
    phrases = {}
    pos = 0.0
    for bar, ch in enumerate(chords):
        key = bar % 4 if bar < len(chords) - 4 else 4 + bar % 4
        if bar % 8 >= 4 and bar % 8 < 6 and (bar // 8) % 2 == 0:
            key = bar % 4  # reprise de la phrase A
        tones = chord_notes(ch, octave)
        if key not in phrases:
            notes = []
            b = 0.0
            prev = tones[0]
            while b < beats_per_chord - 1e-6:
                d = rhythm[r.integers(len(rhythm))]
                d = min(d, beats_per_chord - b)
                if r.random() < density:
                    strong = abs(b - round(b)) < 1e-6 and int(round(b)) % 2 == 0
                    if strong:
                        cand = [t + 12 * k for t in tones for k in (0, 1)]
                    else:
                        cand = [12 * (octave + 1) + s + 12 * k for s in scale for k in (0, 1)]
                    cand = sorted(cand, key=lambda m: abs(m - prev) + r.random() * 3)
                    m = cand[0] if r.random() < 0.7 else cand[min(2, len(cand) - 1)]
                    notes.append((b, d, m))
                    prev = m
                b += d
            phrases[key] = notes
        for b, d, m in phrases[key]:
            track.add(bus, inst(freq(m), d * track.beat * (1.6 if inst is not flute else 0.95)), pos + b, gain)
        pos += beats_per_chord


def arpeggio(track, chords, octave, gain, pattern=(0, 1, 2, 1), step=0.5, inst=pluck, beats_per_chord=4):
    pos = 0.0
    for ch in chords:
        tones = chord_notes(ch, octave)
        k = 0
        b = 0.0
        while b < beats_per_chord - 1e-6:
            m = tones[pattern[k % len(pattern)] % len(tones)]
            track.add("arp", inst(freq(m), step * track.beat * 2.5), pos + b, gain)
            b += step
            k += 1
        pos += beats_per_chord


def bassline(track, chords, gain, pattern=((0, 0), (2, 7)), beats_per_chord=4):
    pos = 0.0
    for ch in chords:
        root = chord_notes(ch, 2)[0]
        for b, iv in pattern:
            track.add("bass", bass(freq(root + iv), track.beat * 1.6), pos + b, gain)
        pos += beats_per_chord


def pads(track, chords, gain, beats_per_chord=4):
    pos = 0.0
    for ch in chords:
        track.add("pad", pad([freq(m) for m in chord_notes(ch, 3)], beats_per_chord * track.beat + 0.5), pos, gain)
        pos += beats_per_chord


MAJOR = [0, 2, 4, 5, 7, 9, 11]
MINOR = [0, 2, 3, 5, 7, 8, 10]
PENTA = [0, 2, 4, 7, 9]


def transpose(scale, root):
    return [(s + NOTE[root]) % 12 for s in scale]


def farm():
    chords = ["C", "G", "Am", "F", "C", "G", "F", "C", "Am", "Em", "F", "G", "C", "G", "F", "C"]
    tr = Track(92, len(chords))
    pads(tr, chords, 0.25)
    arpeggio(tr, chords, 4, 0.22, pattern=(0, 2, 1, 2))
    bassline(tr, chords, 0.5, pattern=((0, 0), (2, 7), (3, 12)))
    melody_line(tr, "lead", flute, chords, transpose(PENTA, "C"), 5, 0.32, seed=11, density=0.75)
    for bar in range(len(chords)):
        for b in (1, 3):
            tr.add("perc", shaker(), bar * 4 + b + 0.5, 0.06)
    return tr.render(0.3)


def village():
    chords = ["F", "C", "Dm", "Bb", "F", "C", "Bb", "C", "Dm", "Am", "Bb", "F", "Gm", "C", "F", "F"]
    tr = Track(108, len(chords))
    pads(tr, chords, 0.16)
    arpeggio(tr, chords, 4, 0.2, pattern=(0, 1, 2, 3), step=0.5)
    bassline(tr, chords, 0.55, pattern=((0, 0), (1, 7), (2, 0), (3, 7)))
    melody_line(tr, "lead", bell, chords, transpose(MAJOR, "F"), 5, 0.38, seed=5, density=0.8, rhythm=(0.5, 0.5, 1, 0.5))
    for bar in range(len(chords)):
        tr.add("perc", kick(), bar * 4, 0.35)
        tr.add("perc", kick(), bar * 4 + 2, 0.25)
        for b in range(4):
            tr.add("perc", shaker(), bar * 4 + b + 0.5, 0.07)
    return tr.render(0.25, reverb_buses=("lead", "pad", "arp"))


def mine():
    chords = ["Am", "Am", "F", "F", "Dm", "Dm", "E", "E", "Am", "Am", "C", "G", "F", "Dm", "E", "E"]
    tr = Track(64, len(chords))
    pads(tr, chords, 0.4)
    bassline(tr, chords, 0.45, pattern=((0, 0),))
    melody_line(tr, "lead", bell, chords, transpose(MINOR, "A"), 4, 0.3, seed=21, density=0.35, rhythm=(1, 2, 1.5))
    r = np.random.default_rng(9)
    for k in range(18):  # gouttes d'eau dans la grotte
        tr.add("fx", drip(r.uniform(1400, 2400)), r.uniform(0, len(chords) * 4 - 1), 0.12)
    return tr.render(0.55)


def home():
    chords = ["Gmaj7", "Em7", "Cmaj7", "D", "Gmaj7", "Em7", "Am7", "D", "Cmaj7", "Bm", "Am7", "D", "Gmaj7", "Em7", "Cmaj7", "D"]
    tr = Track(78, len(chords))
    pads(tr, chords, 0.22)
    arpeggio(tr, chords, 4, 0.16, pattern=(0, 2, 3, 2), step=1.0, inst=bell)
    bassline(tr, chords, 0.35, pattern=((0, 0),))
    melody_line(tr, "lead", bell, chords, transpose(MAJOR, "G"), 5, 0.3, seed=8, density=0.6, rhythm=(1, 1, 2))
    return tr.render(0.35)


def festival():
    chords = ["D", "A", "Bm", "G", "D", "A", "G", "A", "Bm", "F#m", "G", "D", "Em", "A", "D", "D"]
    tr = Track(124, len(chords))
    pads(tr, chords, 0.12)
    arpeggio(tr, chords, 4, 0.22, pattern=(0, 1, 2, 1, 0, 2, 1, 2), step=0.5)
    bassline(tr, chords, 0.55, pattern=((0, 0), (1, 12), (2, 7), (3, 12)))
    melody_line(tr, "lead", flute, chords, transpose(MAJOR, "D"), 5, 0.35, seed=31, density=0.85, rhythm=(0.5, 0.5, 1))
    for bar in range(len(chords)):
        for b in range(4):
            tr.add("perc", kick(), bar * 4 + b, 0.3 if b % 2 == 0 else 0.18)
            tr.add("perc", shaker(), bar * 4 + b + 0.5, 0.08)
        tr.add("perc", clap(), bar * 4 + 1, 0.12)
        tr.add("perc", clap(), bar * 4 + 3, 0.12)
    return tr.render(0.2, reverb_buses=("lead", "pad", "arp"))


def night():
    chords = ["Ebmaj7", "Cm7", "Abmaj7", "Bb", "Ebmaj7", "Gm", "Abmaj7", "Bb", "Cm7", "Gm", "Abmaj7", "Eb", "Fm7", "Bb", "Eb", "Eb"]
    tr = Track(66, len(chords))
    pads(tr, chords, 0.35)
    melody_line(tr, "lead", bell, chords, transpose(PENTA, "Eb"), 5, 0.24, seed=17, density=0.4, rhythm=(1, 2, 1.5))
    bassline(tr, chords, 0.3, pattern=((0, 0),))
    return tr.render(0.5)


if __name__ == "__main__":
    for name, fn in (("farm", farm), ("village", village), ("mine", mine), ("home", home), ("festival", festival), ("night", night)):
        save(name, fn())
