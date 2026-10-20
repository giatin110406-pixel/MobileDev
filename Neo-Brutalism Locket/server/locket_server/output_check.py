"""Detect partly corrupted diffusion / upscale output.

A GPU fault can leave a painting half black or filled with confetti noise while the rest is fine;
the old whole-image `mean < 4` test missed those. Both checks compare 8x8 cells with a trusted
reference, so a dark photo that stays dark is not a fault."""
from __future__ import annotations

import numpy as np
from PIL import Image

GRID = 8
SIDE = 512           # compare at this size: cells of 64 px
MAX_FAULT = 0.03     # more than ~2 of 64 cells bad -> the image is rejected


def _luma(image: Image.Image, side: int = SIDE) -> np.ndarray:
    return np.asarray(image.convert("L").resize((side, side), Image.BOX), np.float32)


def _cells(a: np.ndarray, fn, grid: int = GRID) -> np.ndarray:
    n = a.shape[0] // grid
    return np.array([[fn(a[y * n:(y + 1) * n, x * n:(x + 1) * n]) for x in range(grid)]
                     for y in range(grid)])


def _grain(cell: np.ndarray) -> float:
    return float(np.abs(np.diff(cell, axis=1)).mean())


def fault_fraction(result: Image.Image, source: Image.Image) -> float:
    """Share of cells that are black where the source is bright, or noise where it is smooth."""
    r, s = _luma(result), _luma(source)
    mean_r, mean_s = _cells(r, np.mean), _cells(s, np.mean)
    grain_r, grain_s = _cells(r, _grain), _cells(s, _grain)
    dead = (mean_r < 8) & (mean_s > 50)
    noise = (grain_r > 35) & (grain_r > grain_s * 2.5 + 15)
    return float((dead | noise).mean())


def is_broken(result: Image.Image, source: Image.Image) -> bool:
    return fault_fraction(result, source) > MAX_FAULT


def upscale_broken(big: Image.Image, small: Image.Image) -> bool:
    """A correct x2 upscale, shrunk back, equals its input; one garbage tile (a small block of
    pixels, which the 8x8 `fault_fraction` misses) does not. 16x16 cells, ~1% bad = rejected."""
    diff = _cells(np.abs(_luma(big) - _luma(small)), np.mean, 16)
    return float((diff > 30).mean()) > 0.01
