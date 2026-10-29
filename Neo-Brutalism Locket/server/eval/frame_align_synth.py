"""Pairs of views of one scene with a known right answer, for `frame_align`: the locked frame, and
the same scene as a phone handed to someone else would see it (shifted, turned, nearer or farther,
a different exposure, a little shaky). Cut from an ordinary picture, so the scene is real; what is
not real is the phone, the hands and the hurry. A claim about the app needs real pairs.
"""
from __future__ import annotations

import math
from dataclasses import dataclass

import cv2
import numpy as np


@dataclass
class Truth:
    dx: float  # where the locked scene's centre sits in the current frame, fraction of the width
    dy: float
    roll_deg: float  # how far the scene is turned clockwise in the current frame
    scale: float  # how big the locked scene looks in the current frame


@dataclass
class ViewPair:
    locked: np.ndarray
    current: np.ndarray
    truth: Truth


def make_pair(
    src: np.ndarray,
    truth: Truth,
    *,
    side: int = 480,
    brightness: float = 1.0,
    gamma: float = 1.0,
    blur: float = 0.0,
    noise: float = 0.0,
    jpeg_quality: int | None = None,
    keystone: tuple[float, float] = (0.0, 0.0),
    occlusion: float = 0.0,
    intruder: np.ndarray | None = None,
    mover: float = 0.0,
    rng: np.random.Generator | None = None,
) -> ViewPair:
    """`src` should be at least a couple of times `side` wide and tall so the shifted view still lies
    inside the picture (it is reflected at the border if not)."""
    h, w = src.shape[:2]
    rng = rng or np.random.default_rng(0)
    # The locked frame: a `side` square from the middle of the picture.
    x0, y0 = (w - side) // 2, (h - side) // 2
    locked = src[y0 : y0 + side, x0 : x0 + side].copy()

    # Locked-frame coordinates l = p - c0 map to current coordinates q = A l + t.
    a = truth.scale * np.array(
        [
            [math.cos(math.radians(truth.roll_deg)), -math.sin(math.radians(truth.roll_deg))],
            [math.sin(math.radians(truth.roll_deg)), math.cos(math.radians(truth.roll_deg))],
        ]
    )
    centre = np.array([side / 2, side / 2])
    t = centre + np.array([truth.dx * side, truth.dy * side]) - a @ centre
    c0 = np.array([x0, y0], dtype=np.float64)
    m = np.vstack([np.hstack([a, (t - a @ c0).reshape(2, 1)]), [0, 0, 1]])
    # Keystone: the phone is tilted a little, so the frame is not a flat shift and turn of the
    # first one (a similarity cannot describe it exactly). Fixes the frame's centre.
    mid = np.array([side / 2, side / 2])
    to_mid = np.array([[1, 0, -mid[0]], [0, 1, -mid[1]], [0, 0, 1]], dtype=np.float64)
    persp = np.array([[1, 0, 0], [0, 1, 0], [keystone[0], keystone[1], 1]], dtype=np.float64)
    m = np.linalg.inv(to_mid) @ persp @ to_mid @ m
    current = cv2.warpPerspective(
        src, m, (side, side), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT
    )
    # Where the locked frame's centre really lands now.
    landed = m @ np.array([x0 + side / 2, y0 + side / 2, 1.0])
    landed = landed[:2] / landed[2]
    truth = Truth(
        dx=float((landed[0] - side / 2) / side),
        dy=float((landed[1] - side / 2) / side),
        roll_deg=truth.roll_deg,
        scale=truth.scale,
    )
    if occlusion > 0 and intruder is not None:
        # Someone walks through the frame: a patch of another scene lands on it.
        area = occlusion * side * side
        bw = int(min(side * 0.7, math.sqrt(area * rng.uniform(0.5, 1.0))))
        bh = int(min(side * 0.9, area / max(bw, 1)))
        px, py = int(rng.integers(0, side - bw)), int(rng.integers(0, side - bh))
        patch = cv2.resize(intruder, (bw, bh), interpolation=cv2.INTER_AREA)
        current[py : py + bh, px : px + bw] = patch

    if mover > 0:
        # Someone in the frame moved: a patch of the scene sits somewhere else than it should, so
        # its features agree with each other on a different shift than the rest of the frame.
        area = mover * side * side
        bw = int(min(side * 0.5, math.sqrt(area * rng.uniform(0.6, 1.0))))
        bh = int(min(side * 0.8, area / max(bw, 1)))
        sx, sy = int(rng.integers(0, side - bw)), int(rng.integers(0, side - bh))
        dxm = int(rng.integers(-side // 5, side // 5))
        dym = int(rng.integers(-side // 5, side // 5))
        tx = int(np.clip(sx + dxm, 0, side - bw))
        ty = int(np.clip(sy + dym, 0, side - bh))
        current[ty : ty + bh, tx : tx + bw] = current[sy : sy + bh, sx : sx + bw].copy()

    current = _perturb(current, brightness, gamma, blur, noise, jpeg_quality, rng)
    return ViewPair(locked, current, truth)


def _perturb(img, brightness, gamma, blur, noise, jpeg_quality, rng):
    out = img.astype(np.float32) / 255.0
    out = np.clip(out * brightness, 0, 1) ** gamma
    out = (out * 255).astype(np.uint8)
    if blur > 0:
        out = cv2.GaussianBlur(out, (0, 0), blur)
    if noise > 0:
        out = np.clip(out.astype(np.float32) + rng.normal(0, noise, out.shape), 0, 255).astype(np.uint8)
    if jpeg_quality is not None:
        ok, buf = cv2.imencode(".jpg", out, [cv2.IMWRITE_JPEG_QUALITY, jpeg_quality])
        if ok:
            out = cv2.imdecode(buf, cv2.IMREAD_COLOR)
    return out


def random_truth(rng: np.random.Generator) -> Truth:
    """Something a person might hold the phone at: up to a quarter of the frame off, a little
    rolled, a bit nearer or farther."""
    return Truth(
        dx=float(rng.uniform(-0.25, 0.25)),
        dy=float(rng.uniform(-0.25, 0.25)),
        roll_deg=float(rng.uniform(-15, 15)),
        scale=float(rng.uniform(0.85, 1.18)),
    )


def random_hardness(rng: np.random.Generator) -> dict:
    """What an exact warp lacks: a tilted phone, and people moving through the frame."""
    return dict(
        keystone=(float(rng.uniform(-0.0003, 0.0003)), float(rng.uniform(-0.0003, 0.0003))),
        occlusion=float(rng.uniform(0, 0.25)),
        mover=float(rng.uniform(0, 0.2)),
    )


def random_conditions(rng: np.random.Generator) -> dict:
    """A different exposure, a bit of shake blur and sensor noise, JPEG like the stream."""
    return dict(
        brightness=float(rng.uniform(0.75, 1.3)),
        gamma=float(rng.uniform(0.85, 1.2)),
        blur=float(rng.uniform(0, 1.5)),
        noise=float(rng.uniform(0, 5)),
        jpeg_quality=int(rng.integers(55, 92)),
    )


def flat_picture(h: int, w: int, rng: np.random.Generator) -> np.ndarray:
    """A blank wall: one colour and a whisper of noise. Nothing to match on."""
    base = np.full((h, w, 3), rng.integers(120, 200), np.uint8)
    return np.clip(base + rng.normal(0, 1.2, base.shape), 0, 255).astype(np.uint8)
