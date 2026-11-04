#!/usr/bin/env python3
"""Plays the soundtrack on real recorded instruments (tools/samples.py) into
assets/audio/music_*.ogg (run from the project root).

All original tunes. Menu: a sea shanty on accordion with oom-pah tuba and stomp-clap (Sea of
Thieves' spirit). Patrol: a calm, sparse pad with a lonely flute, now only on the jukebox as
"Slow watch". The Typhoon has her own slow men's choir. Each instrument has its place left to right in
one reverberant room. Loops are folded so their reverb tails wrap round, and they repeat without
a seam. Needs numpy and ffmpeg.
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import samples as sm  # noqa: E402

SR = sm.SR
OUT = "assets/audio"
rng = np.random.default_rng(7)


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def place(track, sound, at):
    i = max(0, int(at * SR))
    end = min(len(track), i + len(sound))
    track[i:end] += sound[: end - i]


def reverb(x, seconds=1.2, wet=0.25):
    n = int(seconds * SR)
    y = convolve(x, impulse(seconds))
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


def impulse(seconds):
    n = int(seconds * SR)
    ir = rng.normal(0, 1, n) * np.exp(-np.arange(n) / SR * 5.0 / seconds)
    return ir / np.sqrt(np.sum(ir ** 2))


def convolve(x, ir):
    size = 1 << int(np.ceil(np.log2(len(x) + len(ir))))
    return np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[: len(x) + len(ir)]


def mix(stems, length, seconds, room=0.25):
    """The stems {name: (track, loudness, pan -1..1)} together in stereo, in one room, `length`
    samples long with the reverb folded round (length None: all of it, for a one-shot)."""
    left, right = 0.0, 0.0
    for x, level, pan in stems.values():
        x = x / max(1e-6, np.sqrt(np.mean(x[np.abs(x) > 0] ** 2))) * level
        a = (pan + 1) * np.pi / 4
        left = left + x * np.cos(a)
        right = right + x * np.sin(a)
    out = []
    for dry in (left, right):
        wet = convolve(dry, impulse(seconds))
        y = np.zeros(len(wet))
        y[: len(dry)] += dry
        y = y * (1 - room) + wet * room
        out.append(fold(y, length) if length else y)
    return np.stack(out, axis=1)


def save(name, x):
    x = np.tanh(x / max(1e-6, np.max(np.abs(x))) * 1.15) * 0.85  # the loudest hits rounded off
    data = (x * 32767).astype(np.int16)
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "m.wav")
        with wave.open(wav, "wb") as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(data.tobytes())
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", wav, "-c:a", "libvorbis", "-q:a", "5",
                        os.path.join(OUT, f"music_{name}.ogg")], check=True)
    print(name, f"{len(x) / SR:.1f} s")


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
    size = length + SR * 3
    lead, chords, tuba, stomp, clap = (np.zeros(size) for _ in range(5))
    t = 0.0
    for midi, beats in melody:
        if midi:
            at, level = sm.human(t)
            place(lead, sm.note("accordion", midi, beats * beat * 0.95, level, 0.06), at)
        t += beats * beat
    for i, ch in enumerate(bars):
        bar = i * 4 * beat
        root = CHORDS[ch][0]
        at, level = sm.human(bar)
        place(tuba, sm.note("tuba", root - 12, beat * 0.8, level), at)  # oom
        at, level = sm.human(bar + 2 * beat)
        place(tuba, sm.note("tuba", root - 5, beat * 0.8, level), at)  # the fifth below
        for b in (1, 3):  # pah: chord stabs
            for k, midi in enumerate(CHORDS[ch]):
                at, level = sm.human(bar + b * beat)
                place(chords, sm.note("accordion", midi, beat * 0.4, level, 0.05), at + k * 0.004)
        for b in (0, 2):
            at, level = sm.human(bar + b * beat)
            place(stomp, sm.hit("kick", 0.5, level), at)
        for b in (1, 3):
            at, level = sm.human(bar + b * beat)
            place(clap, sm.hit("clap", 0.4, level), at)
    save("menu", mix({"lead": (lead, 0.2, 0.1), "chords": (chords, 0.1, -0.3), "tuba": (tuba, 0.17, 0.0),
                      "stomp": (stomp, 0.13, 0.0), "clap": (clap, 0.08, 0.3)}, length, 1.0, 0.16))


def patrol():
    prog = ["Dm", "Bb", "F", "C", "Dm", "Bb", "Am", "Dm"]
    length = int(len(prog) * 4 * SR)
    size = length + SR * 5
    pad, low, flute = (np.zeros(size) for _ in range(3))
    for i, ch in enumerate(prog):
        for midi in CHORDS[ch]:
            place(pad, sm.note("pad_2_warm", midi, 4.2, 1.0, 1.2, attack=1.0), i * 4)
        place(low, sm.note("string_ensemble_1", CHORDS[ch][0] - 12, 4.2, 1.0, 1.2, attack=1.2), i * 4)
    # A few lonely phrases on the flute, lots of air between them.
    for at, notes in ((2.0, [(69, 1.5), (67, 0.5), (65, 2.0)]), (12.0, [(62, 1.0), (65, 1.0), (64, 3.0)]),
                      (21.0, [(69, 1.0), (72, 1.0), (70, 1.5), (69, 2.5)])):
        t = at
        for midi, beats in notes:
            place(flute, sm.note("flute", midi + 12, beats * 0.98, 1.0, 0.35, attack=0.05), t)
            t += beats
    save("patrol", mix({"pad": (pad, 0.13, -0.2), "low": (low, 0.08, 0.2), "flute": (flute, 0.2, 0.25)}, length, 2.5, 0.4))


def typhoon():
    """An original slow Russian-style men's choir over low strings and a timpani tread: our own
    tune and chords, in the mood of a Cold War submarine, not any film's theme."""
    bpm = 54
    beat = 60 / bpm
    bars = 16
    length = int(bars * 4 * beat * SR)
    size = length + SR * 4
    tenors, basses, low, timp = (np.zeros(size) for _ in range(4))
    # Chords a bar each, D minor: the basses hold the root and fifth, the tenors sing the line.
    roots = [38, 38, 34, 36, 38, 41, 36, 33, 38, 38, 34, 41, 43, 34, 33, 38]
    line = [(62, 2), (65, 1), (64, 1), (62, 3), (60, 1), (58, 2), (62, 2), (60, 4),
            (62, 2), (64, 1), (65, 1), (69, 3), (67, 1), (64, 2), (60, 2), (61, 4),
            (62, 2), (65, 1), (64, 1), (62, 3), (60, 1), (58, 2), (65, 2), (65, 4),
            (67, 2), (65, 1), (62, 1), (58, 3), (60, 1), (61, 2), (64, 2), (62, 4)]
    for i, root in enumerate(roots):
        at = i * 4 * beat
        for midi in (root + 12, root + 19):
            place(basses, sm.note("choir_aahs", midi, 4 * beat * 0.98, 1.0, 0.8, attack=0.5), at)
        place(low, sm.note("contrabass", root, 4 * beat * 0.95, 1.0, 0.6, attack=0.3), at)
        place(timp, sm.hit("timp", 2.5, 1.0 if i % 4 == 0 else 0.55), at)
        place(timp, sm.hit("timp", 2.0, 0.4), at + 2 * beat)
    t = 0.0
    for midi, beats in line:
        place(tenors, sm.note("choir_aahs", midi, beats * beat * 0.96, 1.0, 0.5, attack=0.25), t)
        t += beats * beat
    save("typhoon", mix({"tenors": (tenors, 0.16, 0.1), "basses": (basses, 0.13, -0.1), "low": (low, 0.12, 0.0),
                         "timp": (timp, 0.1, 0.2)}, length, 3.0, 0.45))


if __name__ == "__main__":
    if sys.argv[1:] == ["typhoon"]:
        typhoon()
        sys.exit(0)
    shanty()
    patrol()
    typhoon()
