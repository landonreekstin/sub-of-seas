#!/usr/bin/env python3
"""Cuts real recordings into the game's sound effects and jukebox records (run from the project
root, after tools/make_sounds.sh, which still makes the few sounds no recording fits). Needs
numpy and ffmpeg.

Downloads each source once into tools/.samples (not committed). Every source and its licence is
in docs/credits.md; run with "credits" to print that table. Each sound keeps the level of the
synthesised one it replaced, so the balance of the game's mix stays as it was tuned.
"""
import os
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from samples import CACHE, SR  # noqa: E402

OUT = "assets/audio"

# Freesound, all CC0 (each page checked): id -> (author, title, author id); we use the 128 kbps preview
FS = "https://cdn.freesound.org/previews/%d/%d_%d-hq.mp3"
FREESOUND = {
    324924: ('Renovatio871', 'Depth Charges Kaboom SFX', 2511427),
    332250: ('cabled_mess', 'Flowing water', 5450487),
    452576: ('kyles', 'chain thick rattle hooked onto metal1.wav', 612689),
    12677: ('Peter_Gross', 'Sonar_pings.ogg', 33429),
    59160: ('f_ilippo', 'grincements_helvetia.aif', 745228),
    151271: ('timgormly', 'Metal Lever 1.aif', 2578041),
    171945: ('RebekahDay', 'LowWhalesong.wav', 3206712),
    187767: ('qubodup', 'Cannon Shot', 71257),
    197800: ('rombart', 'Chalumeau.wav', 2591786),
    241756: ('ElGeorgia', 'diesel engine start.wav', 909598),
    264864: ('AugustSandberg', 'Marine diesel engine', 1934171),
    275578: ('hinzebeat', 'big bubbles on water.wav', 3191786),
    277312: ('elliotlp', 'Pencil Writing on Paper', 2017016),
    353232: ('Sojan', 'Ship Bell Two Chimes', 5477651),
    395042: ('AslakHostaker', 'Turn crank_Old_Metal_Machine_Loop.wav', 7487276),
    398077: ('SukritSen', 'Steam.wav', 6996854),
    406197: ('kyles', 'door metal big heavy close kinda slam thud echo offmic.wav', 612689),
    423957: ('pillwave', 'Toggle Switch', 6164481),
    438737: ('craigsmith', 'G45-35-Distant Explosions Underwater.wav', 2524442),
    457294: ('brunoboselli', 'Air (or steam) pressure release', 300738),
    504641: ('Fission9', 'Underwater Ambience', 9395330),
    521773: ('MrFossy', 'Indoors_Shed_RainOnTinRoof_01.wav', 129727),
    575321: ('taure', 'walk carpet.wav', 2940947),
    650573: ('h2p34', 'Metal Canister Impact Hard', 9534185),
    677722: ('AugustSandberg', 'Water fountain from burst pipe', 1934171),
    678345: ('msx2plus', 'fire alarm bell', 14784311),
    679460: ('Krokulator', 'metal_door_open.wav', 13579627),
    693542: ('dannyraye', 'Splooshes 2', 11532000),
    753138: ('wavecal22', 'Compressed Air-Short-9', 1068206),
    767343: ('DeqstersLab', 'Climbing Metal Ladder hands and feet', 189858),
    813328: ('NickTayloe', 'Crackling Flames (loop)', 11606594),
    835169: ('Mihacappy', 'pipewrenchdrop.wav', 10594370),
    842169: ('AardsReal', '2 Heavy Metal Clangs Free', 13307919),
}

# US Navy recording, public domain, on Wikimedia Commons.
KLAXON = "https://upload.wikimedia.org/wikipedia/commons/8/83/WWII_submarine_dive_klaxon.ogg"

# name -> source (Freesound id, or a url), start s, length s, then what to do to it:
#   rms: level to match, dB; hp/lp: filter, Hz; fade: fade-out, s; loop: seam crossfade, s;
#   snap: start at the first onset in this many s after start; rate: playback speed;
#   thump: another source (id, start, length, dB) under it.
SOUNDS = {
    "depth_charge": {"src": 324924, "start": 0.2, "len": 5.0, "fade": 2.2, "rms": -11.5},
    "torpedo_hit": {"src": 438737, "start": 0.5, "len": 3.0, "fade": 1.0, "rms": -12.8},
    "shell_hit": {"src": 842169, "start": 0.25, "len": 1.0, "fade": 0.3, "rms": -13.9},
    "splash": {"src": 693542, "start": 0.05, "len": 0.8, "fade": 0.3, "rms": -15.4},
    "torpedo_launch": {"src": 753138, "start": 0.05, "len": 0.75, "fade": 0.25, "rms": -11.1, "thump": (406197, 0.25, 0.5, -3)},
    "creak_1": {"src": 59160, "start": 1.9, "len": 2.5, "fade_in": 0.2, "fade": 0.7, "lp": 3000, "rms": -18.6},
    "creak_2": {"src": 59160, "start": 16.5, "len": 2.5, "fade_in": 0.2, "fade": 0.7, "lp": 3000, "rms": -18.4},
    "creak_3": {"src": 59160, "start": 56.5, "len": 2.5, "fade_in": 0.2, "fade": 0.7, "lp": 3000, "rms": -19.0},
    # More of them for the way down (Blaney: "more creaking noises as the sub descends"); the
    # last one slowed to half speed, a long low groan of the whole hull taking the pressure.
    "creak_4": {"src": 59160, "start": 77.0, "len": 2.5, "fade_in": 0.2, "fade": 0.7, "lp": 3000, "rms": -19.0},
    "creak_5": {"src": 59160, "start": 9.5, "len": 2.5, "fade_in": 0.2, "fade": 0.7, "lp": 3000, "rms": -19.0},
    "creak_6": {"src": 59160, "start": 86.0, "len": 4.0, "fade_in": 0.4, "fade": 1.2, "lp": 1600, "rate": 0.5, "rms": -19.0},
    "alarm": {"src": 678345, "start": 0.0, "len": 1.4, "fade": 0.3, "lp": 7000, "rms": -14.0},
    "telegraph_ding": {"src": 353232, "start": 0.25, "len": 1.8, "fade": 0.6, "rms": -13.0},
    "diesel_loop": {"src": 264864, "start": 1.5, "len": 8.0, "loop": 0.5, "lp": 4000, "rms": -13.3},
    "diesel_start": {"src": 241756, "start": 0.15, "len": 2.6, "fade": 0.5, "rms": -12.3},
    "water_loop": {"src": 332250, "start": 8.0, "len": 6.0, "loop": 0.5, "rms": -21.6},
    "fire_loop": {"src": 813328, "start": 22.5, "len": 6.0, "loop": 0.5, "rms": -16.3},
    "torch_loop": {"src": 197800, "start": 23.0, "len": 4.0, "loop": 0.4, "rms": -24.0},
    "wheel_loop": {"src": 395042, "start": 0.1, "len": 6.3, "loop": 0.2, "rms": -19.5},
    "lever": {"src": 151271, "start": 0.1, "len": 0.5, "fade": 0.1, "rms": -13.2},
    "click": {"src": 423957, "start": 0.0, "len": 0.35, "fade": 0.05, "rms": -15.5},
    "vent_rush": {"src": 457294, "start": 0.0, "len": 3.0, "fade": 1.0, "rms": -13.2},
    "blow_loop": {"src": 457294, "start": 8.0, "len": 3.0, "loop": 0.4, "rms": -19.4},
    "hiss_loop": {"src": 398077, "start": 1.0, "len": 1.6, "loop": 0.2, "rms": -24.0},
    "flood": {"src": 275578, "start": 1.4, "len": 2.3, "fade_in": 0.15, "fade": 0.6, "rms": -17.3},
    "clang": {"src": 406197, "start": 0.2, "len": 2.2, "fade": 0.8, "rms": -15.9},
    "door_open": {"src": 679460, "start": 0.1, "len": 1.2, "fade": 0.4, "rms": -16.8},
    "reload": {"src": 452576, "start": 0.0, "len": 2.4, "fade": 0.5, "lp": 9000, "rms": -16.2},
    "canister": {"src": 650573, "start": 0.3, "len": 0.45, "fade": 0.1, "rms": -18.9},
    "pencil": {"src": 277312, "start": 0.1, "len": 0.5, "fade": 0.1, "rms": -25.0},
    "step_1": {"src": 575321, "start": 5.3, "len": 0.14, "snap": 0.5, "fade": 0.06, "hp": 300, "lp": 1800, "rms": -22.4},
    "step_2": {"src": 575321, "start": 6.0, "len": 0.14, "snap": 0.5, "fade": 0.06, "hp": 300, "lp": 1800, "rms": -18.0},
    "step_3": {"src": 575321, "start": 6.7, "len": 0.14, "snap": 0.5, "fade": 0.06, "hp": 300, "lp": 1800, "rms": -22.7},
    "rung": {"src": 767343, "start": 0.9, "len": 0.4, "snap": 0.4, "fade": 0.12, "rms": -23.0},
    "tool": {"src": 835169, "start": 0.55, "len": 0.45, "fade": 0.12, "rms": -22.6},
    "sea_loop": {"src": 504641, "start": 8.0, "len": 8.0, "loop": 1.0, "hp": 60, "lp": 2500, "rms": -25.0},
    "rain_loop": {"src": 521773, "start": 76.0, "len": 6.0, "loop": 0.6, "rms": -25.3},
    "galley_loop": {"src": 521773, "start": 30.0, "len": 5.0, "loop": 0.5, "hp": 1800, "rms": -23.0},  # rain on tin, high only: a pan frying
    "whale_loop": {"src": 171945, "start": 0.0, "len": 15.0, "loop": 1.0, "rms": -17.6},
    "sonar_ping": {"src": 12677, "start": 0.0, "len": 1.9, "fade": 0.4, "rms": -8.4},
    "deck_gun": {"src": 187767, "start": 0.15, "len": 3.0, "fade": 1.2, "rms": -12.5},
    "klaxon": {"src": KLAXON, "start": 0.0, "len": 3.7, "fade": 0.3, "rms": -8.0},
}

# Public domain, on Wikimedia Commons: name -> (url, credit)
RECORDS = {
    "record_anchors_1920": ("https://upload.wikimedia.org/wikipedia/commons/5/5a/Anchors_Aweigh_played_by_the_USNA_Band_in_1920.mp3",
                            "Anchors Aweigh, USNA Band, 1920"),
    "record_anchors_1929": ("https://upload.wikimedia.org/wikipedia/commons/d/da/Anchors_Aweigh%2C_1929_recording.oga",
                            "Anchors Aweigh, US Navy Band, 1929"),
    "record_over_there": ("https://upload.wikimedia.org/wikipedia/commons/d/d9/Over_There_%281917%29.mp3",
                          "Over There, Billy Murray, 1917"),
}


def fetch(src):
    if isinstance(src, int):
        url = FS % (src // 1000, src, FREESOUND[src][2])
        path = os.path.join(CACHE, "fs", f"{src}.mp3")
    else:
        url = src
        path = os.path.join(CACHE, "other", os.path.basename(src))
    if not os.path.exists(path):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        req = urllib.request.Request(url, headers={"User-Agent": "SubOfSeasCredits/1.0 (github.com/landonreekstin/sub-of-seas)"})
        for attempt in range(5):  # Wikimedia asks scripts to slow down
            try:
                with urllib.request.urlopen(req, timeout=120) as r, open(path + ".part", "wb") as f:
                    f.write(r.read())
                break
            except urllib.error.HTTPError as e:
                if e.code != 429 or attempt == 4:
                    raise
                time.sleep(30)
        os.replace(path + ".part", path)
    return path


def decode(src, start=0.0, length=None, hp=None, lp=None, rate=None):
    cmd = ["ffmpeg", "-loglevel", "error", "-ss", str(start)]
    if length is not None:
        cmd += ["-t", str(length * (rate or 1.0))]
    cmd += ["-i", fetch(src)]
    af = []
    if rate:
        af += [f"asetrate={int(SR * rate)}", f"aresample={SR}"]
    if hp:
        af += [f"highpass=f={hp}"] * 2  # steep: no low thud gets through
    if lp:
        af.append(f"lowpass=f={lp}")
    if af:
        cmd += ["-af", ",".join(af)]
    cmd += ["-f", "f32le", "-ac", "1", "-ar", str(SR), "-"]
    raw = subprocess.run(cmd, check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


def active_rms(x):
    """Loudness (dB) of the part of a sound that is actually sounding."""
    a = x[np.abs(x) > np.max(np.abs(x)) * 0.03]
    return 20 * np.log10(np.sqrt(np.mean(a ** 2)))


def write_wav(name, x):
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def make(name, s):
    src, start, length = s["src"], s["start"], s["len"]
    loop = s.get("loop", 0.0)
    filt = {k: s.get(k) for k in ("hp", "lp", "rate")}
    x = decode(src, start, length + loop + s.get("snap", 0.0), **filt)
    if "snap" in s:
        peak = np.max(np.abs(x))
        first = int(np.argmax(np.abs(x) > peak * 0.25))
        x = x[max(0, first - int(0.004 * SR)) :]
    if loop > 0:
        n = int(length * SR)
        k = min(int(loop * SR), len(x) - n)
        ramp = np.sqrt(np.linspace(0, 1, k))
        out = x[:n].copy()
        out[:k] = x[:k] * ramp + x[n : n + k] * ramp[::-1]  # the seam: the end fades into the start
        x = out
    else:
        x = x[: int(length * SR)].copy()
        a = int(s.get("fade_in", 0.003) * SR)
        x[:a] *= np.linspace(0, 1, a)
        r = min(len(x), int(s.get("fade", 0.02) * SR))
        x[-r:] *= np.linspace(1, 0, r) ** 2
    if "thump" in s:
        tsrc, tstart, tlen, tdb = s["thump"]
        t = decode(tsrc, tstart, tlen, lp=500)
        t = t / np.max(np.abs(t)) * np.max(np.abs(x)) * 10 ** (tdb / 20)
        t[-len(t) // 3 :] *= np.linspace(1, 0, len(t[-len(t) // 3 :]))
        x[: len(t)] += t[: len(x)]
    x = x * 10 ** ((s["rms"] - active_rms(x)) / 20)
    peak = np.max(np.abs(x))
    if peak > 0.97:  # a hard hit that would clip is rounded off rather than turned down
        x = np.tanh(x / 0.97) * 0.97 / np.tanh(peak / 0.97) * min(1.0, peak)
    write_wav(name, x)
    print(f"{name:18} {len(x) / SR:5.2f} s  peak {np.max(np.abs(x)):.2f}")


def make_record(name, url, rms=-20.0):
    """A whole old recording, crackle and all, for the jukebox."""
    x = decode(url)
    x = x * 10 ** ((rms - active_rms(x)) / 20)
    x = np.tanh(x)
    data = (x * 32767).astype(np.int16)
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "m.wav")
        with wave.open(wav, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(data.tobytes())
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", wav, "-c:a", "libvorbis", "-q:a", "3",
                        os.path.join(OUT, f"music_{name}.ogg")], check=True)
    print(f"{name:18} {len(x) / SR:5.1f} s")


def credits():
    """The table in docs/credits.md."""
    used = {}
    for name, spec in SOUNDS.items():
        for src in (spec["src"], spec.get("thump", (None,))[0]):
            if isinstance(src, int):
                used.setdefault(src, []).append(name)
    for src, names in sorted(used.items()):
        author, title, _ = FREESOUND[src]
        print(f"| {', '.join(names)} | [{title}](https://freesound.org/s/{src}/) | {author} | CC0 |")


if __name__ == "__main__":
    wanted = sys.argv[1:]
    if wanted == ["credits"]:
        credits()
        sys.exit()
    for name, spec in SOUNDS.items():
        if not wanted or name in wanted:
            make(name, spec)
    for name, (url, _credit) in RECORDS.items():
        if not wanted or name in wanted:
            make_record(name, url)
