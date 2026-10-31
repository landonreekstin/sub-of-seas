#!/usr/bin/env python3
"""Synthesises the crew's band parts into assets/audio/shanty_<instrument>.ogg (run from the
project root). Needs numpy and ffmpeg.

Blaney: instruments of all types that each play their part of a song, so when all of them are
in it is the whole song, like Sea of Thieves; first "The Foggy Dew" (the traditional Irish air
the Chieftains recorded). This is our own arrangement of the traditional tune, in E minor, a
mix of traditional and modern instruments. Every part is the same length and loops on the same
clock, so whoever plays joins in time. The parts are scaled together (not one by one), so the
balance between them is the arrangement's.
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import make_music as mm  # noqa: E402  (the shared synth helpers)

SR = mm.SR
OUT = "assets/audio"
BPM = 84
BEAT = 60.0 / BPM
rng = np.random.default_rng(11)

# The air: (MIDI note, beats). A pickup, then A A B B A, four bars each (81 beats).
A_BARS = [(64, 1), (64, .5), (66, .5), (67, 1), (69, 1), (71, 1.5), (69, .5), (67, 1), (64, 1), (62, 1), (64, 1), (66, 1), (62, 1)]
MELODY = (
    [(59, 1)]
    + A_BARS + [(64, 3), (59, 1)]
    + A_BARS + [(64, 3), (71, 1)]
    + [(74, 1.5), (71, .5), (74, 1), (76, 1), (74, 1), (71, 1), (69, 1), (71, 1), (74, 1.5), (71, .5), (69, 1), (67, 1), (69, 3), (71, 1)]
    + [(74, 1.5), (71, .5), (74, 1), (76, 1), (74, 1), (71, 1), (69, 1), (67, 1), (64, 1), (62, 1), (64, 1), (67, 1), (69, 3), (59, 1)]
    + A_BARS + [(64, 4)]
)
PICKUP = 1.0
CHORDS = {"Em": [52, 55, 59], "D": [50, 54, 57], "G": [55, 59, 62]}
BARS = ["Em", "Em", "D", "Em"] * 2 + ["G", "G", "D", "D", "G", "G", "Em", "D"] + ["Em", "Em", "D", "Em"]
TOTAL = PICKUP + len(BARS) * 4
LENGTH = int(TOTAL * BEAT * SR)


def hz(m):
    return mm.hz(m)


def track():
    return np.zeros(LENGTH + SR * 4)


def bar_start(i):
    return (PICKUP + i * 4) * BEAT


def melody_notes():
    at = 0.0
    for note, beats in MELODY:
        yield note, at * BEAT, beats * BEAT
        at += beats


def whistle(f, dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    vib = 0.003 * np.sin(2 * np.pi * 5.8 * t) * np.minimum(1, t / 0.3)
    ph = 2 * np.pi * f * np.cumsum(1 + vib) / SR
    breath = rng.normal(0, 1, n) * 0.05 * mm.env(n, 0.01, 0.05)
    return (np.sin(ph) + 0.12 * np.sin(2 * ph) + breath) * mm.env(n, 0.025, 0.08)


def fiddle(f, dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    vib = 0.006 * np.sin(2 * np.pi * 5.5 * t) * np.clip((t - 0.15) / 0.3, 0, 1)
    ph = 2 * np.pi * f * np.cumsum(1 + vib) / SR
    out = sum(np.sin(k * ph) / k ** 1.1 for k in range(1, 12))
    bow = rng.normal(0, 1, n) * 0.03
    return (out + bow) * mm.env(n, 0.07, 0.12)


def guitar_chord(root, dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for m in (root, root + 7, root + 12):  # a power chord
        ph = 2 * np.pi * hz(m) * t
        out += sum(np.sin(k * ph) / k for k in range(1, 8))
    out = np.tanh(out * 2.5)  # overdrive
    out = np.convolve(out, np.ones(6) / 6, mode="same")  # take the fizz off
    return out * mm.env(n, 0.004, 0.06, 0.35, 0.18)


def synth(fs, dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for f in fs:
        for det in (0.995, 1.0, 1.005):
            ph = 2 * np.pi * f * det * t
            out += sum(np.sin(k * ph) / k for k in range(1, 7))
    out = np.convolve(out, np.ones(10) / 10, mode="same")
    return out / (3 * len(fs)) * mm.env(n, 0.5, 0.6)


def kit(kind, dur=0.35):
    n = int(dur * SR)
    t = np.arange(n) / SR
    if kind == "kick":
        return np.sin(2 * np.pi * (48 + 70 * np.exp(-t * 35)) * t) * np.exp(-t * 14)
    if kind == "snare":
        noise = rng.normal(0, 1, n)
        return (noise * np.exp(-t * 22) * 0.7 + np.sin(2 * np.pi * 190 * t) * np.exp(-t * 30) * 0.5)
    if kind == "hat":
        noise = np.diff(rng.normal(0, 1, n), prepend=0)
        return noise * np.exp(-t * 70) * 0.35
    if kind == "crash":
        noise = np.diff(rng.normal(0, 1, int(1.5 * SR)), prepend=0)
        return noise * np.exp(-np.arange(len(noise)) / SR * 3.0) * 0.35
    raise ValueError(kind)


def bodhran(strong, dur=0.3):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = 62 if strong else 90
    skin = rng.normal(0, 1, n) * np.exp(-t * 50) * 0.25
    return (np.sin(2 * np.pi * (f + 30 * np.exp(-t * 25)) * t) * np.exp(-t * (9 if strong else 16)) + skin) * (1.0 if strong else 0.55)


def part_whistle():
    x = track()
    for note, at, dur in melody_notes():
        mm.place(x, whistle(hz(note + 12), dur * 0.95), at)
    return x


def part_fiddle():
    x = track()
    for note, at, dur in melody_notes():
        mm.place(x, fiddle(hz(note), dur * 0.98), at)
    return x


def part_concertina():
    x = track()
    for i, c in enumerate(BARS):
        for half in (0, 2):
            for m in CHORDS[c]:
                mm.place(x, mm.accordion(hz(m + 12), BEAT * 1.9), bar_start(i) + half * BEAT)
    return x


def part_bodhran():
    x = track()
    for i in range(len(BARS)):
        for k in range(8):  # eighth notes, the stick going down and up, the beat leaned on
            mm.place(x, bodhran(k in (0, 4), 0.3), bar_start(i) + k * 0.5 * BEAT)
    mm.place(x, bodhran(False), 0)  # the pickup
    return x


def part_guitar():
    x = track()
    for i, c in enumerate(BARS):
        root = CHORDS[c][0] - 12
        for at, dur in ((0, 1.4), (1.5, 0.9), (2.5, 0.5), (3, 1.0)):
            mm.place(x, guitar_chord(root, dur * BEAT), bar_start(i) + at * BEAT)
    return x


def part_bass():
    x = track()
    for i, c in enumerate(BARS):
        root = CHORDS[c][0] - 12
        nxt = CHORDS[BARS[(i + 1) % len(BARS)]][0] - 12
        for at, m in ((0, root), (2, root + 7), (3, root if nxt == root else nxt + (1 if nxt < root else -1))):
            mm.place(x, mm.bass(hz(m), BEAT * 0.95) * 1.4, bar_start(i) + at * BEAT)
    mm.place(x, mm.bass(hz(47), BEAT * 0.9) * 1.4, 0)  # B up to the E
    return x


def part_drums():
    x = track()
    for i in range(len(BARS)):
        b = bar_start(i)
        if i % 4 == 0:
            mm.place(x, kit("crash"), b)
        for at in (0, 2, 2.5):
            mm.place(x, kit("kick"), b + at * BEAT)
        for at in (1, 3):
            mm.place(x, kit("snare"), b + at * BEAT)
        for k in range(8):
            mm.place(x, kit("hat") * (1.0 if k % 2 == 0 else 0.6), b + k * 0.5 * BEAT)
    return x


def part_synth():
    x = track()
    for i, c in enumerate(BARS):
        tones = [hz(m + 12) for m in CHORDS[c]]
        mm.place(x, synth(tones, BEAT * 4.2) * 1.2, bar_start(i))
        for k in range(8):  # a soft arpeggio over the pad
            m = CHORDS[c][[0, 1, 2, 1][k % 4]] + 24
            n = int(BEAT * 0.45 * SR)
            t = np.arange(n) / SR
            mm.place(x, np.sign(np.sin(2 * np.pi * hz(m) * t)) * 0.12 * np.exp(-t * 8), bar_start(i) + k * 0.5 * BEAT)
    return x


# name -> (part, level in the mix, reverb wet)
PARTS = {
    "whistle": (part_whistle, 1.0, 0.3),
    "fiddle": (part_fiddle, 0.95, 0.3),
    "concertina": (part_concertina, 0.55, 0.25),
    "bodhran": (part_bodhran, 0.6, 0.2),
    "guitar": (part_guitar, 0.55, 0.15),
    "bass": (part_bass, 0.65, 0.1),
    "drums": (part_drums, 0.5, 0.12),
    "synth": (part_synth, 0.45, 0.35),
}


def write(name, x, path=None):
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "m.wav")
        with wave.open(wav, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(data.tobytes())
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", wav, "-c:a", "libvorbis", "-q:a", "4",
                        path or os.path.join(OUT, f"shanty_{name}.ogg")], check=True)


if __name__ == "__main__":
    stems = {}
    for name, (fn, level, wet) in PARTS.items():
        x = fn()
        x = x / max(1e-6, np.sqrt(np.mean(x ** 2))) * 0.1 * level  # each part to its level by loudness
        stems[name] = mm.fold(mm.reverb(x, 1.3, wet), LENGTH)
    full = sum(stems.values())
    scale = 0.16 / np.sqrt(np.mean(full ** 2))  # the band by loudness, the drum hits soft-limited
    for name, x in stems.items():
        write(name, np.tanh(x * scale * 1.5) * 0.95)  # alone a part plays a little louder
        print(name, f"{LENGTH / SR:.1f} s")
    if len(sys.argv) > 1:  # the whole band together, to listen to: make_shanty.py preview.ogg
        write("full", np.tanh(full * scale) * 0.95, sys.argv[1])
