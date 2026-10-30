#!/usr/bin/env python3
"""Generates the tileable grey detail textures in assets/textures/ (run from the project root).

Each surface is a pair of 512x512 greyscale maps:
- `<name>.png`, around 0.75-1.0, multiplies a material's flat colour, so the palette in
  docs/style.md stays the palette and the texture only adds paint wear, seams, grain, streaks;
- `<name>_h.png`, a height map around 0.5: the toon shader (world/toon.gdshader) bumps the
  light with it and darkens the hollows, so seams sink, rivets and tread stand up.
Deterministic (fixed seeds): re-running gives the same files.
"""
import numpy as np
from PIL import Image

N = 512
OUT = "assets/textures/%s.png"
YY, XX = np.mgrid[0:N, 0:N]


def noise(seed, scale, octaves=4):
    """Tileable value noise in 0..1."""
    rng = np.random.default_rng(seed)
    out = np.zeros((N, N))
    amp, total = 1.0, 0.0
    for o in range(octaves):
        cells = scale * 2 ** o
        grid = rng.random((cells, cells))
        x = np.arange(N) * cells / N
        i0 = np.floor(x).astype(int) % cells
        i1 = (i0 + 1) % cells
        f = x - np.floor(x)
        f = f * f * (3 - 2 * f)
        a = grid[i0][:, i0] * (1 - f)[None, :] + grid[i0][:, i1] * f[None, :]
        b = grid[i1][:, i0] * (1 - f)[None, :] + grid[i1][:, i1] * f[None, :]
        out += amp * (a * (1 - f)[:, None] + b * f[:, None])
        total += amp
        amp *= 0.5
    return out / total


def blur(v, r=1):
    """A small tileable box blur, to soften hard edges in the height maps."""
    out = np.zeros_like(v)
    k = 0
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            out += np.roll(np.roll(v, dy, 0), dx, 1)
            k += 1
    return out / k


def save(name, albedo, height):
    Image.fromarray((np.clip(albedo, 0, 1) * 255).astype(np.uint8), "L").save(OUT % name)
    Image.fromarray((np.clip(height, 0, 1) * 255).astype(np.uint8), "L").save(OUT % (name + "_h"))


def wrap_dist(cx, cy):
    return np.hypot(((XX - cx + N / 2) % N) - N / 2, ((YY - cy + N / 2) % N) - N / 2)


def dome(h, cx, cy, radius, lift):
    """A round raised head (rivet, bolt) at (cx, cy)."""
    d = wrap_dist(cx, cy)
    h += np.where(d < radius, lift * np.sqrt(np.clip(1 - (d / radius) ** 2, 0, 1)), 0)
    return d


def seam(h, a, pos, axis, width, depth):
    """A recessed seam line, with a slightly darker line in the albedo."""
    idx = np.arange(N)
    d = np.abs(((idx - pos + N / 2) % N) - N / 2)
    prof = np.clip(1 - d / width, 0, 1)
    if axis == 0:  # horizontal line (constant row)
        h -= depth * prof[:, None]
        a -= 0.16 * prof[:, None]
    else:
        h -= depth * prof[None, :]
        a -= 0.14 * prof[None, :]


def painted_steel():
    a = 0.9 + 0.07 * (noise(1, 4) - 0.5)
    h = 0.55 + 0.04 * (noise(21, 32, 3) - 0.5)  # orange-peel paint
    # Two panels a tile each way, each panel a touch different.
    panel = ((XX // (N // 2)) + 2 * (YY // (N // 2))) % 4
    a += (panel - 1.5) * 0.012
    for s in (0, N // 2):
        seam(h, a, s, 0, 3.0, 0.3)
        seam(h, a, s, 1, 3.0, 0.3)
    # Rivet rows either side of every seam.
    for s in (0, N // 2):
        for t in range(8, N, 32):
            for off in (-9, 9):
                dome(h, t, s + off, 4.0, 0.3)
                dome(h, s + off, t + 16, 4.0, 0.3)
    # Chipped paint: bare-metal flecks, sunk a little.
    chips = noise(2, 32, 2)
    chip = chips > 0.82
    a += np.where(chip, 0.07, 0)
    h -= np.where(chip, 0.06, 0)
    # Rust streaks running down from the seams.
    streak = noise(3, 64, 2)[:1, :].repeat(N, 0)
    run = np.clip(1 - ((YY - 4) % (N // 2)) / (N * 0.3), 0, 1)
    a -= 0.11 * np.clip((streak - 0.66) * 10, 0, 1) * run * (0.6 + 0.4 * noise(24, 32, 2))
    # Grime in the low places.
    a -= 0.05 * np.clip(noise(4, 8) - 0.55, 0, 1) * 3
    save("painted_steel", a, blur(h))


def deck_plate():
    a = 0.86 + 0.06 * (noise(4, 4) - 0.5)
    h = np.full((N, N), 0.45)
    # Diamond tread: short raised bars alternating 45 degrees.
    cell = 24
    u, w = XX % cell, YY % cell
    alt = ((XX // cell + YY // cell) % 2) == 0
    d = np.where(alt, np.abs(u - w), np.abs(u + w - cell))
    bar = np.clip(1 - d / 2.5, 0, 1) * ((u > 4) & (u < cell - 4))
    h += 0.35 * bar
    a += 0.08 * bar
    for s in (0, N // 2):
        seam(h, a, s, 0, 3.0, 0.35)
        seam(h, a, s, 1, 3.0, 0.35)
    for cx in (12, N // 2 - 12, N // 2 + 12, N - 12):
        for cy in (12, N // 2 - 12, N // 2 + 12, N - 12):
            dome(h, cx, cy, 5.0, 0.3)  # countersunk bolts at the plate corners
    worn = np.clip(noise(5, 8) - 0.55, 0, 1) * 2.5
    a -= 0.12 * worn  # dark, worn walkways
    a += 0.05 * bar * worn  # and the tread polished bright on them
    save("deck_plate", a, blur(h))


def brushed():
    streaks = noise(6, 128, 2)[:1, :].repeat(N, 0)
    a = 0.88 + 0.1 * (streaks - 0.5)
    a += 0.06 * (noise(7, 4) - 0.5)
    a -= np.where(noise(8, 16, 2) > 0.8, 0.12, 0)  # tarnish spots
    h = 0.5 + 0.06 * (streaks - 0.5) + 0.03 * (noise(22, 16) - 0.5)
    save("brushed", a, h)


def wood():
    grain = noise(9, 2, 3)
    rings = np.sin((YY / N * 60 + grain * 14) * np.pi) * 0.5 + 0.5
    plank = XX // (N // 4)
    a = 0.8 + 0.1 * rings + 0.06 * (noise(10, 8) - 0.5) + (plank % 3 - 1) * 0.03
    h = 0.5 + 0.08 * (rings - 0.5)
    for s in range(0, N, N // 4):  # plank seams
        seam(h, a, s, 1, 2.5, 0.35)
    # Butt joints, staggered plank to plank, with a pair of nails at each.
    for p in range(4):
        y = (p * 157 + 60) % N
        x0, x1 = p * N // 4, (p + 1) * N // 4
        band = (XX >= x0) & (XX < x1)
        dy = np.abs(((YY - y + N / 2) % N) - N / 2)
        cut = band & (dy < 2)
        h -= np.where(cut, 0.3, 0)
        a -= np.where(cut, 0.15, 0)
        for nx in (x0 + 20, x1 - 20):
            for ny in (y - 8, y + 8):
                d = wrap_dist(nx, ny)
                a -= np.where(d < 2.5, 0.35, 0)
    save("wood", a, blur(h))


def ship_plating():
    a = 0.9 + 0.06 * (noise(11, 4) - 0.5)
    h = 0.5 + 0.03 * (noise(23, 16) - 0.5)
    strake = N // 4
    # Lapped strakes: each plate stands proud at its lower edge.
    lap = (YY % strake) / strake
    h += 0.18 * lap
    a += 0.03 * (lap - 0.5)
    for s in range(0, N, strake):
        seam(h, a, s, 0, 2.0, 0.15)
        for t in range(6, N, 20):
            dome(h, t, s - 6, 3.0, 0.2)
    for s in range(0, N, N // 2):
        seam(h, a, s, 1, 2.0, 0.2)
    streak = noise(12, 48, 2)[:1, :].repeat(N, 0)
    run = np.clip(1 - (YY % strake) / (strake * 0.9), 0, 1)
    a -= 0.1 * np.clip((streak - 0.64) * 10, 0, 1) * run * (0.6 + 0.4 * noise(25, 32, 2))  # rust running down off each lap
    a -= 0.06 * np.clip(noise(13, 6) - 0.5, 0, 1) * 2  # salt and soot
    save("ship_plating", a, blur(h))


def grain():
    """The fallback on every colour without its own map: a fine painted grain."""
    a = 0.94 + 0.06 * (noise(14, 16, 3) - 0.5) + 0.03 * (noise(15, 3) - 0.5)
    h = 0.5 + 0.12 * (noise(16, 64, 2) - 0.5)
    save("grain", a, h)


def cloth():
    """Woven cotton (shirts, dungarees, bunk blankets)."""
    t = 4
    weft = np.sin(XX / t * np.pi) ** 2
    warp = np.sin(YY / t * np.pi) ** 2
    over = ((XX // t + YY // t) % 2) == 0
    h = 0.5 + 0.25 * np.where(over, weft, warp) - 0.1
    a = 0.92 + 0.06 * (h - 0.5) + 0.05 * (noise(17, 8) - 0.5)
    a -= 0.04 * np.clip(noise(18, 4) - 0.6, 0, 1) * 3  # wear
    save("cloth", a, h)


if __name__ == "__main__":
    painted_steel()
    deck_plate()
    brushed()
    wood()
    ship_plating()
    grain()
    cloth()
