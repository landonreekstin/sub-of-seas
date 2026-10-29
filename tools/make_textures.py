#!/usr/bin/env python3
"""Generates the tileable grey detail textures in assets/textures/ (run from the project root).

Each is a 256x256 greyscale map around 0.75-1.0 that multiplies a material's flat colour, so
the palette in docs/style.md stays the palette and the texture only adds paint wear, seams,
rivets, grain and streaks. Deterministic (fixed seeds): re-running gives the same files.
"""
import numpy as np
from PIL import Image

N = 256
OUT = "assets/textures/%s.png"


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


def save(name, v):
    Image.fromarray((np.clip(v, 0, 1) * 255).astype(np.uint8), "L").save(OUT % name)


def rivets(v, spacing, offset, radius, light=0.12):
    yy, xx = np.mgrid[0:N, 0:N]
    for cy in range(offset, N, spacing):
        for cx in range(offset // 2, N, spacing // 4):
            d = np.hypot(((xx - cx + N / 2) % N) - N / 2, ((yy - cy + N / 2) % N) - N / 2)
            v += np.where(d < radius, light * (1 - d / radius), 0)
            v -= np.where((d >= radius) & (d < radius + 1.5), 0.08, 0)
    return v


def painted_steel():
    v = 0.9 + 0.08 * (noise(1, 4) - 0.5)
    # Panel seams: a dark line with a light lip, two panels per tile each way.
    for s in (0, N // 2):
        v[s, :] -= 0.22
        v[(s + 1) % N, :] += 0.06
        v[:, s] -= 0.18
    v = rivets(v, N // 2, 6, 3.0)
    # Chipped paint: bright flecks where the bare metal shows.
    chips = noise(2, 32, 2)
    v += np.where(chips > 0.84, 0.06, 0)
    # Rust streaks running down from the seams.
    streak = noise(3, 32, 2)[:, :1].repeat(N, 1).T  # vertical bands
    run = np.clip(1 - (np.arange(N) % (N // 2)) / (N * 0.35), 0, 1)[:, None]
    v -= np.where(streak > 0.7, 0.12 * run, 0)
    save("painted_steel", v)


def deck_plate():
    yy, xx = np.mgrid[0:N, 0:N]
    v = 0.86 + 0.06 * (noise(4, 4) - 0.5)
    # Diamond tread: short raised bars alternating 45 degrees.
    cell = 16
    u, w = xx % cell, yy % cell
    alt = ((xx // cell + yy // cell) % 2) == 0
    d = np.where(alt, np.abs(u - w), np.abs(u + w - cell))
    v += np.where((d < 2) & (u > 3) & (u < cell - 3), 0.1, 0)
    for s in (0, N // 2):
        v[s, :] -= 0.25
        v[:, s] -= 0.25
    v -= 0.1 * np.clip(noise(5, 8) - 0.6, 0, 1) * 2.5  # worn, darker walkways
    save("deck_plate", v)


def brushed():
    v = 0.88 + 0.1 * (noise(6, 64, 2)[:1, :].repeat(N, 0) - 0.5)
    v += 0.06 * (noise(7, 4) - 0.5)
    v -= np.where(noise(8, 16, 2) > 0.8, 0.12, 0)  # tarnish spots
    save("brushed", v)


def wood():
    yy, xx = np.mgrid[0:N, 0:N]
    grain = noise(9, 2, 3)
    rings = np.sin((yy / N * 40 + grain * 12) * np.pi) * 0.5 + 0.5
    v = 0.82 + 0.1 * rings + 0.06 * (noise(10, 8) - 0.5)
    for s in range(0, N, N // 4):  # plank seams
        v[:, s] -= 0.3
    save("wood", v)


def ship_plating():
    v = 0.9 + 0.06 * (noise(11, 4) - 0.5)
    for s in range(0, N, N // 4):
        v[s, :] -= 0.1  # strakes
    for s in range(0, N, N // 2):
        v[:, s] -= 0.06
    streak = noise(12, 24, 2)[:, :1].repeat(N, 1).T
    v -= np.where(streak > 0.68, 0.1 * np.linspace(1, 0, N)[:, None], 0)
    save("ship_plating", v)


if __name__ == "__main__":
    painted_steel()
    deck_plate()
    brushed()
    wood()
    ship_plating()
