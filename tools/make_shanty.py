#!/usr/bin/env python3
"""Plays the crew's band parts on real recorded instruments (tools/samples.py) into
assets/audio/shanty_<instrument>.ogg (run from the project root). Needs numpy and ffmpeg.

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
import make_music as mm  # noqa: E402  (the shared mixing helpers)
import samples as sm  # noqa: E402

SR = mm.SR
OUT = "assets/audio"
BPM = 84
BEAT = 60.0 / BPM

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


def track():
    return np.zeros(LENGTH + SR * 4)


def bar_start(i):
    return (PICKUP + i * 4) * BEAT


def melody_notes():
    at = 0.0
    for note, beats in MELODY:
        yield note, at * BEAT, beats * BEAT
        at += beats


def part_whistle():  # recorder is the nearest thing to a tin whistle in the library
    x = track()
    for note, at, dur in melody_notes():
        at, level = sm.human(at, late=0.005, spread=0.06)
        mm.place(x, sm.note("recorder", note + 12, dur * 0.95, level, 0.05), at)
    return x


def part_fiddle():
    x = track()
    for note, at, dur in melody_notes():
        at, level = sm.human(at, late=0.008, spread=0.08)
        mm.place(x, sm.note("fiddle", note, dur * 0.98, level, 0.12), at)
    return x


def part_concertina():
    x = track()
    for i, c in enumerate(BARS):
        for half in (0, 2):
            for k, m in enumerate(CHORDS[c]):
                at, level = sm.human(bar_start(i) + half * BEAT, late=0.004, spread=0.05)
                mm.place(x, sm.note("tango_accordion", m + 12, BEAT * 1.8, level, 0.1), at + k * 0.005)
    return x


def part_bodhran():
    x = track()
    for i in range(len(BARS)):
        for k in range(8):  # eighth notes, the stick going down and up, the beat leaned on
            at, level = sm.human(bar_start(i) + k * 0.5 * BEAT, late=0.005)
            kind = "bodhran" if k in (0, 4) else "bodhran_soft"
            mm.place(x, sm.hit(kind, 0.6, level * (1.0 if k in (0, 4) else 0.6)), at)
    mm.place(x, sm.hit("bodhran_soft", 0.6, 0.6), 0)  # the pickup
    return x


def part_guitar():
    x = track()
    for i, c in enumerate(BARS):
        root = CHORDS[c][0] - 12
        for beat, dur in ((0, 1.4), (1.5, 0.9), (2.5, 0.5), (3, 1.0)):
            for k, m in enumerate((root, root + 7, root + 12)):  # a power chord, strummed down
                at, level = sm.human(bar_start(i) + beat * BEAT, late=0.003, spread=0.05)
                mm.place(x, sm.note("overdriven_guitar", m, dur * BEAT, level, 0.06), at + k * 0.006)
    return x


def part_bass():
    x = track()
    for i, c in enumerate(BARS):
        root = CHORDS[c][0] - 12
        nxt = CHORDS[BARS[(i + 1) % len(BARS)]][0] - 12
        for beat, m in ((0, root), (2, root + 7), (3, root if nxt == root else nxt + (1 if nxt < root else -1))):
            at, level = sm.human(bar_start(i) + beat * BEAT, late=0.004)
            mm.place(x, sm.note("electric_bass_finger", m, BEAT * 0.95, level, 0.06), at)
    mm.place(x, sm.note("electric_bass_finger", 47, BEAT * 0.9, 1.0, 0.06), 0)  # B up to the E
    return x


def part_drums():
    x = track()
    for i in range(len(BARS)):
        b = bar_start(i)
        if i % 4 == 0:
            mm.place(x, sm.hit("crash", 2.5, 0.5), b)
        for at in (0, 2, 2.5):
            t, level = sm.human(b + at * BEAT, late=0.004)
            mm.place(x, sm.hit("kick", 0.6, level), t)
        for at in (1, 3):
            t, level = sm.human(b + at * BEAT, late=0.004)
            mm.place(x, sm.hit("snare", 0.5, level * 0.8), t)
        for k in range(8):
            t, level = sm.human(b + k * 0.5 * BEAT, late=0.004)
            mm.place(x, sm.hit("hat", 0.15, level * (0.35 if k % 2 == 0 else 0.2)), t)
    return x


def part_synth():
    x = track()
    for i, c in enumerate(BARS):
        for m in CHORDS[c]:
            mm.place(x, sm.note("pad_2_warm", m + 12, BEAT * 4, 0.6, 0.5, attack=0.4), bar_start(i))
        for k in range(8):  # a soft arpeggio over the pad
            m = CHORDS[c][[0, 1, 2, 1][k % 4]] + 24
            mm.place(x, sm.note("lead_1_square", m, BEAT * 0.4, 0.12, 0.08), bar_start(i) + k * 0.5 * BEAT)
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
        x = x / max(1e-6, np.sqrt(np.mean(x[np.abs(x) > 0] ** 2))) * 0.1 * level  # each part to its level by loudness
        stems[name] = mm.fold(mm.reverb(x, 1.3, wet), LENGTH)
    full = sum(stems.values())
    scale = 0.16 / np.sqrt(np.mean(full ** 2))  # the band by loudness, the drum hits soft-limited
    for name, x in stems.items():
        write(name, np.tanh(x * scale * 1.5) * 0.95)  # alone a part plays a little louder
        print(name, f"{LENGTH / SR:.1f} s")
    write("full", np.tanh(full * scale) * 0.95, os.path.join(OUT, "music_foggy_dew.ogg"))  # the jukebox's copy
