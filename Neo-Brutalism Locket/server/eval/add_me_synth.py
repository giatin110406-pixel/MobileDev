"""Synthetic shot pairs with a known right answer, for checking that `add_me` runs and does the
right thing. They say nothing about how it copes with real hair and clothes: that needs real pairs
(see docs/HUONG_DAN_CHUP_CAP_ANH.md).

A pair is a textured background, a few 'group' figures, and the same scene again with one more
figure, the second shot slightly shifted and re-exposed like a hand-held retake.
"""
from __future__ import annotations

from dataclasses import dataclass

import cv2
import numpy as np


@dataclass
class SynthPair:
    shot_1: np.ndarray
    shot_2: np.ndarray
    truth: np.ndarray  # what a perfect merge looks like, in shot_1's frame
    holder: np.ndarray  # uint8 mask of the holder in shot_1's frame


def background(rng: np.random.Generator, h: int, w: int) -> np.ndarray:
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    base = np.stack([
        120 + 60 * np.sin(xx / 97 + rng.uniform(0, 6)),
        130 + 50 * np.cos(yy / 71 + rng.uniform(0, 6)),
        110 + 70 * np.sin((xx + yy) / 133 + rng.uniform(0, 6)),
    ], axis=2)
    img = np.clip(base + rng.normal(0, 6, (h, w, 3)), 0, 255).astype(np.uint8)
    for _ in range(90):  # corners and edges for the matcher to hold on to
        x, y = int(rng.integers(0, w)), int(rng.integers(0, h))
        size = int(rng.integers(8, 40))
        colour = tuple(int(c) for c in rng.integers(20, 235, 3))
        if rng.random() < 0.5:
            cv2.rectangle(img, (x, y), (x + size, y + size), colour, -1)
        else:
            cv2.circle(img, (x, y), size // 2, colour, -1)
    return img


def figure(img: np.ndarray, centre_x: int, height: int, colour: tuple[int, int, int]) -> np.ndarray:
    """Draw a head-and-body figure; returns its mask. Skin and clothes differ from the background."""
    h, w = img.shape[:2]
    mask = np.zeros((h, w), np.uint8)
    foot = h - int(h * 0.05)
    body_h, body_w = int(height * 0.62), int(height * 0.34)
    cv2.ellipse(mask, (centre_x, foot - body_h // 2), (body_w // 2, body_h // 2), 0, 0, 360, 1, -1)
    head_r = int(height * 0.13)
    cv2.circle(mask, (centre_x, foot - body_h - head_r + 4), head_r, 1, -1)
    img[mask > 0] = colour
    cv2.circle(img, (centre_x, foot - body_h - head_r + 4), head_r, (150, 180, 225), -1)
    return mask


def make_pair(seed: int, h: int = 960, w: int = 1280, group: int = 3, jitter: float = 1.0,
              holder_gap: int | None = None) -> SynthPair:
    """`holder_gap` = distance in px between the holder's centre and the nearest group figure's
    centre; leave None to leave room (a clean case). Small values put them shoulder to shoulder."""
    rng = np.random.default_rng(seed)
    bg = background(rng, h, w)
    scene_1 = bg.copy()
    xs = np.linspace(w * 0.15, w * 0.62, group).astype(int)
    for x in xs:
        figure(scene_1, int(x), int(h * 0.55), tuple(int(c) for c in rng.integers(30, 220, 3)))
    holder_x = int(w * 0.85) if holder_gap is None else int(xs[-1] + holder_gap)
    scene_2 = scene_1.copy()
    holder = figure(scene_2, holder_x, int(h * 0.58), (40, 40, 200))
    truth = scene_2.copy()

    # the retake is a hand-held shot: small shift/rotation, exposure drift, sensor noise
    angle = rng.uniform(-1.2, 1.2) * jitter
    shift = rng.uniform(-8, 8, 2) * jitter
    m = cv2.getRotationMatrix2D((w / 2, h / 2), angle, 1.0 + rng.uniform(-0.01, 0.01) * jitter)
    m[:, 2] += shift
    shot_2 = cv2.warpAffine(scene_2, m, (w, h), borderMode=cv2.BORDER_REFLECT)
    shot_2 = np.clip(shot_2.astype(np.float32) * rng.uniform(0.94, 1.06, 3)
                     + rng.normal(0, 2.5, shot_2.shape), 0, 255).astype(np.uint8)
    shot_1 = np.clip(scene_1.astype(np.float32) + rng.normal(0, 2.5, scene_1.shape), 0, 255).astype(np.uint8)
    return SynthPair(shot_1, shot_2, truth, holder)
