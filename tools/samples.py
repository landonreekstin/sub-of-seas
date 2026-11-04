"""Real recorded notes and drum hits for tools/make_music.py and tools/make_shanty.py.

Downloads each one the first time into tools/.samples (not committed; the sources and their
licences are in docs/credits.md). Pitched instruments are FluidR3_GM (CC BY 3.0), rendered per
note; drums are VCSL (CC0). Needs ffmpeg.
"""
import os
import subprocess
import urllib.parse
import urllib.request

import numpy as np

SR = 44100
CACHE = os.path.join(os.path.dirname(__file__), ".samples")
FLUID = "https://raw.githubusercontent.com/gleitz/midi-js-soundfonts/gh-pages/FluidR3_GM/%s-mp3/%s.mp3"
VCSL = "https://raw.githubusercontent.com/sgossner/VCSL/master/"
NAMES = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]

# name -> a path in VCSL, several takes of each so repeated hits differ
_S = "Membranophones/Struck Membranophones/"
_I = "Idiophones/Struck Idiophones/"
DRUMS = {
    "bodhran": [_S + "Frame Drum/HDrumL_Hit_v3_rr1_Sum.wav", _S + "Frame Drum/HDrumL_Hit_v3_rr2_Sum.wav"],
    "bodhran_soft": [_S + "Frame Drum/HDrumL_HitMuted_v2_rr1_Sum.wav", _S + "Frame Drum/HDrumL_HitMuted_v2_rr2_Sum.wav"],
    "snare": [_S + "Snare Drum, Modern 1/Snare2_HitSN_v5_rr1_Mid.wav", _S + "Snare Drum, Modern 1/Snare2_HitSN_v5_rr2_Mid.wav"],
    "kick": [_S + "Bass Drum 1/BDrumNew_hit_v3_rr1_Sum.wav", _S + "Bass Drum 1/BDrumNew_hit_v3_rr2_Sum.wav"],
    "heart": [_S + "Bass Drum 1/BDrumNew_hit_v2_rr1_Sum.wav", _S + "Bass Drum 1/BDrumNew_hit_v2_rr2_Sum.wav"],
    "hat": [_I + "Hi-Hat Cymbal/HiHat_HitC_v3_rr1_Mid.wav", _I + "Hi-Hat Cymbal/HiHat_HitC_v3_rr2_Mid.wav"],
    "crash": [_I + "Suspended Cymbal 1/susCymb1_hit_f1.wav"],
    "clap": [_I + f"Claps/Clap_rr{i}.wav" for i in (1, 2, 3, 4)],
    "timp": [_S + "Timpani 1/Hit/Timpani1_Hit_v2_rr1_Sum.wav", _S + "Timpani 1/Hit/Timpani1_Hit_v2_rr2_Sum.wav"],
}

_memo = {}
_rng = np.random.default_rng(23)


def _fetch(url, name):
    path = os.path.join(CACHE, name)
    if not os.path.exists(path):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        req = urllib.request.Request(url, headers={"User-Agent": "sub-of-seas"})
        with urllib.request.urlopen(req, timeout=60) as r, open(path + ".part", "wb") as f:
            f.write(r.read())
        os.replace(path + ".part", path)
    return path


def decode(path):
    """A sound file as mono floats at SR."""
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", path, "-f", "f32le", "-ac", "1", "-ar", str(SR), "-"],
                         check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


def _trim(x):
    """Off with the silence before the sound starts (the encoder's, and the recording's)."""
    start = int(np.argmax(np.abs(x) > 0.02 * np.max(np.abs(x))))
    return x[max(0, start - 16):]


def _note_name(midi):
    return f"{NAMES[midi % 12]}{midi // 12 - 1}"


def sample(inst, midi):
    key = (inst, midi)
    if key not in _memo:
        path = _fetch(FLUID % (inst, _note_name(midi)), f"fluid/{inst}/{_note_name(midi)}.mp3")
        x = _trim(decode(path))
        _memo[key] = x / max(1e-6, np.sqrt(np.mean(x[:SR] ** 2)))  # every note of it equally loud
    return _memo[key]


def _hold(x, n):
    """`x` lasting `n` samples: a held note past the end of its recording goes round its middle."""
    if len(x) >= n:
        return x[:n]
    fade = SR // 8
    loop = x[len(x) // 3 : len(x) - SR // 10]
    out = x[: len(x) - SR // 10].copy()
    ramp = np.linspace(0, 1, fade)
    while len(out) < n:
        out[-fade:] = out[-fade:] * ramp[::-1] + loop[:fade] * ramp
        out = np.concatenate((out, loop[fade:]))
    return out[:n]


def note(inst, midi, dur, level=1.0, release=0.1, attack=0.0):
    """One note: the recording, cut to `dur` seconds with a natural `release` after it."""
    n = int((dur + release) * SR)
    x = _hold(sample(inst, midi), n).copy()
    if attack > 0:
        a = min(n, int(attack * SR))
        x[:a] *= np.linspace(0, 1, a)
    r = min(n, int(release * SR))
    x[-r:] *= np.linspace(1, 0, r) ** 2
    return x * level


def hit(kind, dur=None, level=1.0):
    """One drum hit, a different take each time."""
    paths = DRUMS[kind]
    path = paths[_rng.integers(len(paths))]
    if path not in _memo:
        file = _fetch(VCSL + urllib.parse.quote(path), "vcsl/" + os.path.basename(path))
        x = _trim(decode(file))
        _memo[path] = x / max(1e-6, np.max(np.abs(x)))
    x = _memo[path]
    if dur is not None and len(x) > int(dur * SR):
        x = x[: int(dur * SR)].copy()
        r = min(len(x), SR // 50)
        x[-r:] *= np.linspace(1, 0, r)
    return x * level


def human(at, level=1.0, late=0.006, spread=0.1):
    """A player, not a machine: a touch off the beat, a touch louder or softer."""
    return at + float(_rng.normal(0, late)), level * (1 + float(_rng.normal(0, spread)))
