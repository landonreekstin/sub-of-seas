#!/usr/bin/env python3
"""Synthesises the soundtrack into assets/audio/music_*.ogg (run from the project root).

All original tunes. Menu: a sea shanty on accordion with oom-pah bass and stomp-clap (Sea of
Thieves' spirit). Patrol: a calm, sparse pad with a lonely flute. Hunted: a heartbeat pulse
under trembling strings. Stings for the debrief. Loops are folded so their reverb tails wrap
round, and they repeat without a seam. Needs numpy and ffmpeg.
"""
import os
import subprocess
import tempfile
import wave

import numpy as np

SR = 44100
OUT = "assets/audio"
rng = np.random.default_rng(7)


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def env(n, attack, release, sustain=1.0, decay=0.0):
    t = np.arange(n) / SR
    e = np.minimum(1.0, t / max(attack, 1e-4))
    if decay > 0:
        e = e * (sustain + (1 - sustain) * np.exp(-t / decay))
    r = int(release * SR)
    if r > 0 and r < n:
        e[-r:] *= np.linspace(1, 0, r)
    return e


def accordion(f, dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    vib = 1 + 0.003 * np.sin(2 * np.pi * 5.5 * t)
    out = np.zeros(n)
    for det in (0.998, 1.002):  # two reeds a touch apart: the musette shimmer
        ph = 2 * np.pi * f * det * np.cumsum(vib) / SR
        for k in range(1, 9):
            out += np.sin(k * ph) / k * (0.8 if k % 2 == 0 else 1.0)
    return out * env(n, 0.03, 0.08) * 0.12


def bass(f, dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = sum(np.sin(2 * np.pi * f * k * t) / (k * k) for k in (1, 3, 5))
    return out * env(n, 0.005, 0.05, 0.3, 0.25) * 0.5


def flute(f, dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    vib = np.sin(2 * np.pi * f * t + 0.004 * f / 5 * np.sin(2 * np.pi * 5 * t))
    breath = rng.normal(0, 1, n) * 0.04
    return (vib + 0.2 * np.sin(4 * np.pi * f * t) + breath) * env(n, 0.12, 0.4) * 0.16


def pad(fs, dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for f in fs:
        for det in (0.997, 1.0, 1.003):
            out += np.sin(2 * np.pi * f * det * t) + 0.3 * np.sin(4 * np.pi * f * det * t)
    return out / (3 * len(fs)) * env(n, 1.2, 1.5) * 0.35


def strings(fs, dur, trem=11.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for f in fs:
        for k in range(1, 6):
            out += np.sin(2 * np.pi * f * k * t + k) / k
    am = 0.6 + 0.4 * np.sin(2 * np.pi * trem * t)
    return out / len(fs) * am * env(n, 0.6, 0.6) * 0.09


def drum(kind, dur=0.4):
    n = int(dur * SR)
    t = np.arange(n) / SR
    if kind == "stomp":
        return (np.sin(2 * np.pi * (55 + 40 * np.exp(-t * 30)) * t) * np.exp(-t * 18) + rng.normal(0, 0.2, n) * np.exp(-t * 60)) * 0.55
    if kind == "clap":
        noise = rng.normal(0, 1, n)
        noise = np.diff(noise, prepend=0)  # bright
        return noise * np.exp(-t * 35) * 0.18
    if kind == "heart":
        return np.sin(2 * np.pi * (48 + 20 * np.exp(-t * 20)) * t) * np.exp(-t * 9) * 0.7
    if kind == "timp":
        return (np.sin(2 * np.pi * 73 * t) + 0.5 * np.sin(2 * np.pi * 110 * t)) * np.exp(-t * 3.5) * 0.4
    raise ValueError(kind)


def place(track, sound, at):
    i = int(at * SR)
    end = min(len(track), i + len(sound))
    track[i:end] += sound[: end - i]


def reverb(x, seconds=1.2, wet=0.25):
    n = int(seconds * SR)
    ir = rng.normal(0, 1, n) * np.exp(-np.arange(n) / SR * 5.0 / seconds)
    ir /= np.sqrt(np.sum(ir ** 2))
    size = 1 << int(np.ceil(np.log2(len(x) + n)))
    y = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[: len(x) + n]
    out = np.zeros(len(x) + n)
    out[: len(x)] += x
    return out * (1 - wet) + y * wet


def fold(x, length):
    """A loop `length` samples long, with whatever rang on past the end laid back over its start."""
    out = x[:length].copy()
    tail = x[length:]
    while len(tail):
        k = min(len(tail), length)
        out[:k] += tail[:k]
        tail = tail[k:]
    return out


def save(name, x, loop=True):
    x = x / max(1e-6, np.max(np.abs(x))) * 0.85
    data = (x * 32767).astype(np.int16)
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "m.wav")
        with wave.open(wav, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(data.tobytes())
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", wav, "-c:a", "libvorbis", "-q:a", "4",
                        os.path.join(OUT, f"music_{name}.ogg")], check=True)
    print(name, f"{len(x) / SR:.1f} s")


D3, F3, A3 = 50, 53, 57
CHORDS = {"Dm": [50, 53, 57], "C": [48, 52, 55], "Am": [45, 48, 52], "F": [41, 45, 48], "Bb": [46, 50, 53], "G": [43, 47, 50]}


def shanty():
    bpm = 108
    beat = 60 / bpm
    # An original shanty in D minor: (midi or 0 for a rest, beats).
    melody = [
        (62, 1), (65, 1), (69, 1), (69, 1), (67, 1), (65, 1), (64, 1), (60, 1),
        (60, 1), (64, 1), (67, 1), (67, 1), (65, 1), (64, 1), (62, 1), (60, 1),
        (62, 1), (65, 1), (69, 1), (74, 1), (72, 1), (69, 1), (67, 1), (64, 1),
        (65, 0.5), (64, 0.5), (62, 1), (60, 1), (62, 1), (62, 2), (57, 2),
        (69, 1), (69, 1), (72, 1), (69, 1), (67, 1), (64, 1), (60, 1), (64, 1),
        (69, 1), (69, 1), (72, 1), (74, 1), (76, 2), (74, 2),
        (72, 1), (69, 1), (67, 1), (64, 1), (62, 1), (65, 1), (64, 1), (60, 1),
        (62, 0.5), (64, 0.5), (65, 1), (64, 1), (60, 1), (62, 4),
    ]
    bars = ["Dm", "C", "C", "C", "Dm", "Am", "Dm", "Dm", "Am", "C", "Am", "Am", "Am", "Dm", "C", "Dm"]
    length = int(len(bars) * 4 * beat * SR)
    x = np.zeros(length + SR * 3)
    t = 0.0
    for note, beats in melody:
        if note:
            place(x, accordion(hz(note), beats * beat * 0.95), t)
        t += beats * beat
    for i, ch in enumerate(bars):
        bar = i * 4 * beat
        root = CHORDS[ch][0]
        place(x, bass(hz(root - 12), beat * 0.9), bar)  # oom
        place(x, bass(hz(root - 5), beat * 0.9), bar + 2 * beat)  # the fifth below
        for b in (1, 3):  # pah: chord stabs
            for n in CHORDS[ch]:
                place(x, accordion(hz(n), beat * 0.4) * 0.45, bar + b * beat)
        for b in (0, 2):
            place(x, drum("stomp"), bar + b * beat)
        for b in (1, 3):
            place(x, drum("clap"), bar + b * beat)
    save("menu", fold(reverb(x, 1.0, 0.18), length))


def patrol():
    beat = 1.0
    prog = ["Dm", "Bb", "F", "C", "Dm", "Bb", "Am", "Dm"]
    length = int(len(prog) * 4 * beat * SR)
    x = np.zeros(length + SR * 4)
    for i, ch in enumerate(prog):
        place(x, pad([hz(n) for n in CHORDS[ch]] + [hz(CHORDS[ch][0] - 12)], 4.6), i * 4)
    # A few lonely phrases on the flute, lots of air between them.
    for at, notes in ((2.0, [(69, 1.5), (67, 0.5), (65, 2.0)]), (12.0, [(62, 1.0), (65, 1.0), (64, 3.0)]),
                      (21.0, [(69, 1.0), (72, 1.0), (70, 1.5), (69, 2.5)])):
        t = at
        for note, beats in notes:
            place(x, flute(hz(note + 12), beats * 0.98), t)
            t += beats
    save("patrol", fold(reverb(x, 2.5, 0.4), length))


def hunted():
    bpm = 88
    beat = 60 / bpm
    bars = 8
    length = int(bars * 4 * beat * SR)
    x = np.zeros(length + SR * 3)
    for i in range(bars):
        bar = i * 4 * beat
        for b in (0, 0.45, 2, 2.45):  # lub-dub, twice a bar
            place(x, drum("heart") * (1.0 if b in (0, 2) else 0.6), bar + b * beat)
        if i % 2 == 1:
            place(x, drum("timp"), bar + 3.5 * beat)
        for k in range(8):  # a low ostinato, D and E-flat rubbing
            place(x, bass(hz(38 if k % 4 != 3 else 39), beat * 0.4) * 0.5, bar + k * 0.5 * beat)
    cluster = [hz(n) for n in (62, 63, 69)]
    place(x, strings(cluster, bars * 4 * beat * 0.5), 0)
    place(x, strings([hz(n) for n in (65, 66, 72)], bars * 4 * beat * 0.5, 13.0), bars * 2 * beat)
    save("hunted", fold(reverb(x, 1.5, 0.25), length))


def stings():
    beat = 0.32
    x = np.zeros(int(SR * 4))
    for i, n in enumerate((62, 66, 69, 74)):
        place(x, accordion(hz(n), beat * (3 if i == 3 else 1)), i * beat)
    for n in (50, 57, 62):
        place(x, bass(hz(n - 12), 1.5) + accordion(hz(n), 1.5) * 0.4, 3 * beat)
    place(x, drum("stomp"), 3 * beat)
    save("win", reverb(x, 1.5, 0.3), loop=False)
    x = np.zeros(int(SR * 5))
    for i, n in enumerate((57, 56, 55, 50)):
        place(x, strings([hz(n), hz(n - 12)], 1.2 if i < 3 else 2.5, 6.0) * 3, i * 0.9)
    place(x, drum("timp"), 2.7)
    save("lost", reverb(x, 2.0, 0.35), loop=False)


if __name__ == "__main__":
    shanty()
    patrol()
    hunted()
    stings()
