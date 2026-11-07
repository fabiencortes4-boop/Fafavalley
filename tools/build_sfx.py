#!/usr/bin/env python3
"""Fabrique les bruitages du jeu dans assets/audio/ :

- une partie vient des packs Kenney (CC0), copiés depuis assets/kenney/audio/
  (RPG Sounds, Interface Sounds, Short Music Jingles), parfois retravaillés ;
- le reste est synthétisé ici (numpy) : créations originales, CC0.

    python3 tools/build_sfx.py      (nécessite numpy et ffmpeg)
"""
import os
import subprocess
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KENNEY = os.path.join(ROOT, "assets", "kenney", "audio")
OUT = os.path.join(ROOT, "assets", "audio")
RATE = 44100
rng = np.random.default_rng(7)


# --------------------------------------------------------------- outils
def t(duration):
    return np.arange(int(RATE * duration)) / RATE


def env(n, attack=0.005, decay=8.0):
    """Enveloppe : attaque rapide puis décroissance exponentielle."""
    x = np.arange(n) / RATE
    a = np.clip(x / max(attack, 1e-4), 0, 1)
    return a * np.exp(-x * decay)


def noise(duration):
    return rng.uniform(-1, 1, int(RATE * duration))


def lowpass(sig, cutoff):
    """Filtre passe-bas simple (un pôle), appliqué deux fois."""
    alpha = 1 - np.exp(-2 * np.pi * cutoff / RATE)
    out = np.zeros_like(sig)
    for _ in range(2):
        y = 0.0
        for i, v in enumerate(sig):
            y += alpha * (v - y)
            out[i] = y
        sig = out.copy()
    return out


def highpass(sig, cutoff):
    return sig - lowpass(sig, cutoff)


def sweep(f0, f1, duration, shape="sine"):
    x = t(duration)
    f = np.geomspace(f0, f1, len(x))
    phase = 2 * np.pi * np.cumsum(f) / RATE
    if shape == "square":
        return np.sign(np.sin(phase))
    if shape == "tri":
        return 2 / np.pi * np.arcsin(np.sin(phase))
    return np.sin(phase)


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def at(sig, offset):
    return np.concatenate([np.zeros(int(RATE * offset)), sig])


def save(name, sig, peak=0.8):
    sig = np.asarray(sig, dtype=np.float64)
    if np.max(np.abs(sig)) > 0:
        sig = sig / np.max(np.abs(sig)) * peak
    fade = min(len(sig), int(RATE * 0.01))
    sig[-fade:] *= np.linspace(1, 0, fade)
    wav = os.path.join(OUT, name + ".wav")
    with wave.open(wav, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((sig * 32767).astype(np.int16).tobytes())
    ogg(wav, os.path.join(OUT, name + ".ogg"))
    os.remove(wav)


def ogg(src, dst, filters=None):
    cmd = ["ffmpeg", "-y", "-loglevel", "error", "-i", src]
    if filters:
        cmd += ["-af", filters]
    cmd += ["-ac", "1", "-c:a", "libvorbis", "-q:a", "4", dst]
    subprocess.run(cmd, check=True)


# --------------------------------------------------------------- sons synthétisés
def synth_all():
    # Houe : motte de terre (bruit sourd) + petit choc grave
    for k, pitch in enumerate((1.0, 0.85)):
        d = 0.22
        dirt = lowpass(noise(d), 900 * pitch) * env(int(RATE * d), 0.002, 22)
        thud = sweep(140 * pitch, 60 * pitch, d) * env(int(RATE * d), 0.001, 30)
        crumbs = mix(*[at(lowpass(noise(0.03), 2500) * env(int(RATE * 0.03), 0.001, 90), 0.05 + 0.03 * i) for i in range(3)])
        save("dig_%d" % k, mix(dirt * 1.2, thud, crumbs * 0.4))

    # Arrosoir : ruissellement + gouttes
    d = 0.6
    stream = lowpass(highpass(noise(d), 700), 3500)
    stream *= (0.6 + 0.4 * np.sin(2 * np.pi * 13 * t(d))) * np.minimum(1, t(d) * 12) * np.exp(-t(d) * 2.2)
    drops = mix(*[at(sweep(900 + 300 * i, 1700 + 200 * i, 0.04) * env(int(RATE * 0.04), 0.001, 70), 0.08 + 0.11 * i) for i in range(5)])
    save("water", mix(stream, drops * 0.35))

    # Éclaboussure (bouchon, poisson)
    d = 0.35
    splash = lowpass(noise(d), 4000) * env(int(RATE * d), 0.002, 14)
    bloop = sweep(500, 160, 0.12) * env(int(RATE * 0.12), 0.002, 25)
    save("splash", mix(splash, bloop * 0.8))

    # Lancer de ligne : souffle + plouf
    whoosh = lowpass(highpass(noise(0.25), 500), 2500) * np.sin(np.pi * t(0.25) / 0.25) ** 2
    save("cast", mix(whoosh * 0.7, at(mix(splash * 0.6, bloop * 0.5), 0.28)))

    # Pioche sur la pierre : tintement métallique
    for k, pitch in enumerate((1.0, 1.12)):
        d = 0.3
        ring = sum(np.sin(2 * np.pi * f * pitch * t(d)) * a for f, a in ((1650, 1), (2480, 0.6), (3720, 0.35), (5100, 0.2)))
        ring *= env(int(RATE * d), 0.001, 18)
        click = highpass(noise(0.02), 2000) * env(int(RATE * 0.02), 0.0005, 120)
        save("clink_%d" % k, mix(ring * 0.7, click))

    # Pierre qui éclate
    d = 0.45
    crunch = lowpass(highpass(noise(d), 500), 3000) * env(int(RATE * d), 0.001, 11)
    bits = mix(*[at(highpass(noise(0.03), 1500) * env(int(RATE * 0.03), 0.0005, 80), 0.04 * i + 0.02) for i in range(6)])
    thud = sweep(110, 50, 0.2) * env(int(RATE * 0.2), 0.001, 20)
    save("rock_break", mix(crunch, bits * 0.5, thud * 0.8))

    # Arbre qui tombe : craquement + choc sourd
    d = 0.7
    creak = sweep(220, 90, 0.35, "square") * env(int(RATE * 0.35), 0.01, 6) * 0.25
    fall = lowpass(noise(0.4), 600) * env(int(RATE * 0.4), 0.002, 9)
    boom = sweep(90, 40, 0.3) * env(int(RATE * 0.3), 0.001, 12)
    save("tree_fall", mix(creak, at(mix(fall, boom), 0.3)))

    # Herbe fauchée / coup dans le vide : souffle bref
    for k, (lo, hi) in enumerate(((1800, 6000), (900, 3500))):
        d = 0.18
        sw = highpass(lowpass(noise(d), hi), lo) * np.sin(np.pi * t(d) / d) ** 3
        save(("swish", "whoosh")[k], sw)

    # Graine semée : petit pop doux
    save("plant", mix(sweep(380, 720, 0.07) * env(int(RATE * 0.07), 0.002, 40), lowpass(noise(0.05), 1500) * env(int(RATE * 0.05), 0.001, 60) * 0.4))

    # Ramassage : bulle montante
    save("pickup", mix(sweep(620, 1250, 0.08, "tri") * env(int(RATE * 0.08), 0.002, 25),
                       at(sweep(940, 1860, 0.07, "tri") * env(int(RATE * 0.07), 0.002, 30), 0.05) * 0.7))

    # Coup sur un monstre / monstre vaincu / blessure / bouchée
    save("hit", mix(sweep(260, 90, 0.1, "square") * env(int(RATE * 0.1), 0.001, 30) * 0.5,
                    lowpass(noise(0.08), 2500) * env(int(RATE * 0.08), 0.001, 45)))
    save("monster_die", mix(sweep(700, 120, 0.3, "square") * env(int(RATE * 0.3), 0.002, 9) * 0.4,
                            at(lowpass(noise(0.25), 1200) * env(int(RATE * 0.25), 0.01, 12), 0.1)))
    save("hurt", sweep(330, 140, 0.18, "square") * env(int(RATE * 0.18), 0.002, 14))
    save("eat", mix(*[at(lowpass(highpass(noise(0.05), 600), 3000) * env(int(RATE * 0.05), 0.001, 70), 0.12 * i) for i in range(3)]))
    # Touche : « bloup » + vaguelettes
    save("bite", mix(sweep(300, 900, 0.09) * env(int(RATE * 0.09), 0.001, 30), at(splash * 0.5, 0.06)))
    # Poisson perdu : glissando descendant
    save("escape", sweep(600, 200, 0.4, "tri") * env(int(RATE * 0.4), 0.01, 5))
    synth_rewards()


def synth_rewards():
    """Sons de récompense : découverte (album) et succès débloqué."""
    def bell(f, d, decay=6.0):
        x = t(d)
        tone = np.sin(2 * np.pi * f * x) + 0.4 * np.sin(2 * np.pi * f * 2.01 * x) + 0.15 * np.sin(2 * np.pi * f * 3.02 * x)
        return tone * env(len(x), 0.002, decay)
    # Découverte : trois clochettes montantes + scintillement
    notes = (1047, 1319, 1568)
    sparkle = mix(*[at(bell(2093 + 180 * i, 0.12, 30) * 0.25, 0.2 + 0.035 * i) for i in range(5)])
    save("discover", mix(*[at(bell(f, 0.5, 7), 0.07 * i) for i, f in enumerate(notes)], sparkle), 0.7)
    # Succès : petite fanfare (do-mi-sol-do, accord final tenu)
    fan = [at(bell(f, 0.25, 10) * 0.8, 0.11 * i) for i, f in enumerate((523, 659, 784))]
    chord = mix(bell(1047, 1.1, 3), bell(1319, 1.1, 3) * 0.7, bell(1568, 1.1, 3) * 0.6, bell(523, 1.1, 3) * 0.5)
    save("achievement", mix(*fan, at(chord, 0.33), at(sparkle, 0.3)), 0.75)
    # Pièce : tintement bref (compteur d'or)
    save("coin", mix(bell(1976, 0.12, 28), at(bell(2637, 0.1, 32) * 0.6, 0.03)), 0.5)


# --------------------------------------------------------------- sons Kenney
KENNEY_SOUNDS = {
    # nom dans le jeu : (fichier source, filtre ffmpeg facultatif)
    "chop_0": ("rpg/chop.ogg", None),
    "chop_1": ("rpg/chop.ogg", "asetrate=44100*1.12,aresample=44100"),
    "coins": ("rpg/handleCoins.ogg", None),
    "coins_2": ("rpg/handleCoins2.ogg", None),
    "door": ("rpg/doorOpen_1.ogg", None),
    "chest": ("rpg/creak1.ogg", None),
    "letter": ("rpg/bookOpen.ogg", None),
    "page": ("rpg/bookFlip2.ogg", None),
    "sword": ("rpg/knifeSlice.ogg", None),
    "cloth": ("rpg/cloth2.ogg", None),
    "harvest": ("ui/pluck_001.ogg", None),
    "harvest_2": ("ui/pluck_002.ogg", None),
    "click": ("ui/click_002.ogg", None),
    "select": ("ui/select_002.ogg", None),
    "open": ("ui/open_001.ogg", None),
    "close": ("ui/close_001.ogg", None),
    "error": ("ui/error_004.ogg", None),
    "craft": ("ui/confirmation_002.ogg", None),
    "drop": ("ui/drop_002.ogg", None),
    "levelup": ("jingles/jingles_PIZZA03.ogg", None),
    "catch": ("jingles/jingles_STEEL06.ogg", None),
    "sleep": ("jingles/jingles_PIZZA00.ogg", None),
}


def kenney_all():
    for name, (src, filters) in KENNEY_SOUNDS.items():
        ogg(os.path.join(KENNEY, src), os.path.join(OUT, name + ".ogg"), filters)
    # Pas : version douce (herbe, terre) et version franche (mine)
    for i in range(4):
        src = os.path.join(KENNEY, "rpg", "footstep0%d.ogg" % (i * 2))
        ogg(src, os.path.join(OUT, "step_%d.ogg" % i), "lowpass=f=1400,volume=0.55")
        ogg(src, os.path.join(OUT, "step_stone_%d.ogg" % i), "volume=0.6")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    kenney_all()
    synth_all()
    print(len(os.listdir(OUT)), "sons dans", OUT)
