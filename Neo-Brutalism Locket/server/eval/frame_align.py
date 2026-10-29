"""'Hold the shot' (Chụp hộ): the phone is handed to someone else, who sees where the locked frame
is and which way to move to get back to it. This is the part that decides that, tried here on
ordinary pictures before it goes on a phone.

`estimate(locked, current)` finds how the scene in `current` sits against the scene in `locked`
(ORB features, then a similarity transform: shift, turn and scale, found with RANSAC) and
`guidance` turns that into what to tell the person. When it cannot tell (blank wall, dark, the
scene changed too much) it says "unsure" and why, instead of guessing: the app then says it cannot
recognise the frame.

Conventions (image coordinates, x to the right, y down, as in the pictures):
- `dx`, `dy`: how far the locked scene's centre sits from the frame centre in `current`, as a
  fraction of the frame's width and height. Positive dx means the scene is to the right of where
  it should be, so the person must move the phone's view to the right to bring it back.
- `roll_deg`: how far the scene is turned clockwise; the person rolls the phone clockwise to undo it.
- `scale`: how big the locked scene looks in `current`; above 1 it is too close, so step back.
"""
from __future__ import annotations

import math
from dataclasses import dataclass, field

import cv2
import numpy as np

WORK = 320  # the long side matching is done at (about 10 times a second on a phone)
MIN_MATCHES = 12
MIN_INLIERS = 10
MIN_INLIER_RATIO = 0.4
MAX_ROLL_DEG = 60.0
SCALE_RANGE = (0.5, 2.0)
MIN_SPREAD = 0.10  # inliers must cover this much of the frame, or the estimate rests on one blob

REASON_FEW_FEATURES = "few_features"  # blank wall, dark or blurred: nothing to match on
REASON_NO_MATCH = "no_match"  # features exist but do not agree: another scene
REASON_IMPLAUSIBLE = "implausible"  # an agreed transform too wild to be the same scene
REASON_CONCENTRATED = "concentrated"  # the agreeing points all sit in one small spot

# Within this, the frame counts as found.
ALIGNED_SHIFT = 0.03
ALIGNED_ROLL_DEG = 2.0
ALIGNED_SCALE = 0.04


@dataclass
class Alignment:
    ok: bool
    reason: str | None = None
    dx: float = 0.0
    dy: float = 0.0
    roll_deg: float = 0.0
    scale: float = 1.0
    inliers: int = 0
    info: dict = field(default_factory=dict)


@dataclass
class Guidance:
    """What to tell the person. Each of `horizontal`, `vertical`, `roll`, `distance` is None when
    that part is already within tolerance."""

    state: str  # "aligned" | "adjust" | "unsure"
    horizontal: str | None = None  # "left" | "right"
    vertical: str | None = None  # "up" | "down"
    roll: str | None = None  # "clockwise" | "counterclockwise"
    distance: str | None = None  # "closer" | "back"
    reason: str | None = None


def _prepare(img: np.ndarray) -> tuple[np.ndarray, float]:
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY) if img.ndim == 3 else img
    scale = WORK / max(gray.shape)
    if scale < 1:
        gray = cv2.resize(gray, None, fx=scale, fy=scale, interpolation=cv2.INTER_AREA)
    else:
        scale = 1.0
    # Evens out the exposure difference between a locked frame and the live one.
    return cv2.createCLAHE(clipLimit=2.0, tileGridSize=(4, 4)).apply(gray), scale


def estimate(locked: np.ndarray, current: np.ndarray) -> Alignment:
    a, _ = _prepare(locked)
    b, _ = _prepare(current)
    orb = cv2.ORB_create(nfeatures=800, scaleFactor=1.2, nlevels=6, fastThreshold=10)
    ka, da = orb.detectAndCompute(a, None)
    kb, db = orb.detectAndCompute(b, None)
    if da is None or db is None or len(ka) < MIN_MATCHES or len(kb) < MIN_MATCHES:
        return Alignment(False, REASON_FEW_FEATURES, info={"keypoints": (len(ka or []), len(kb or []))})

    pairs = cv2.BFMatcher(cv2.NORM_HAMMING).knnMatch(da, db, k=2)
    good = [m for m, n in (p for p in pairs if len(p) == 2) if m.distance < 0.75 * n.distance]
    if len(good) < MIN_MATCHES:
        return Alignment(False, REASON_NO_MATCH, info={"good_matches": len(good)})

    src = np.float32([ka[m.queryIdx].pt for m in good])
    dst = np.float32([kb[m.trainIdx].pt for m in good])
    matrix, mask = cv2.estimateAffinePartial2D(
        src, dst, method=cv2.RANSAC, ransacReprojThreshold=3.0, maxIters=2000, confidence=0.99
    )
    if matrix is None:
        return Alignment(False, REASON_NO_MATCH, info={"good_matches": len(good)})
    inliers = int(mask.sum())
    ratio = inliers / len(good)
    info = {"good_matches": len(good), "inliers": inliers, "inlier_ratio": ratio}
    if inliers < MIN_INLIERS or ratio < MIN_INLIER_RATIO:
        return Alignment(False, REASON_NO_MATCH, inliers=inliers, info=info)

    # Do the agreeing points cover the frame, or is it one patch that happens to match?
    pts = src[mask.ravel() == 1]
    h, w = a.shape
    spread = min((pts[:, 0].max() - pts[:, 0].min()) / w, (pts[:, 1].max() - pts[:, 1].min()) / h)
    info["spread"] = spread
    if spread < MIN_SPREAD:
        return Alignment(False, REASON_CONCENTRATED, inliers=inliers, info=info)

    s = math.hypot(matrix[0, 0], matrix[1, 0])
    roll = math.degrees(math.atan2(matrix[1, 0], matrix[0, 0]))
    if not SCALE_RANGE[0] <= s <= SCALE_RANGE[1] or abs(roll) > MAX_ROLL_DEG:
        return Alignment(False, REASON_IMPLAUSIBLE, inliers=inliers, info=info)

    # Where the locked frame's centre lands in the current frame.
    cx, cy = w / 2, h / 2
    mx = matrix[0, 0] * cx + matrix[0, 1] * cy + matrix[0, 2]
    my = matrix[1, 0] * cx + matrix[1, 1] * cy + matrix[1, 2]
    hb, wb = b.shape
    return Alignment(
        True,
        dx=(mx - wb / 2) / wb,
        dy=(my - hb / 2) / hb,
        roll_deg=roll,
        scale=s,
        inliers=inliers,
        info=info,
    )


def guidance(alignment: Alignment) -> Guidance:
    if not alignment.ok:
        return Guidance("unsure", reason=alignment.reason)
    g = Guidance("adjust")
    if abs(alignment.dx) > ALIGNED_SHIFT:
        g.horizontal = "right" if alignment.dx > 0 else "left"
    if abs(alignment.dy) > ALIGNED_SHIFT:
        g.vertical = "down" if alignment.dy > 0 else "up"
    if abs(alignment.roll_deg) > ALIGNED_ROLL_DEG:
        g.roll = "clockwise" if alignment.roll_deg > 0 else "counterclockwise"
    if abs(alignment.scale - 1) > ALIGNED_SCALE:
        g.distance = "back" if alignment.scale > 1 else "closer"
    if not (g.horizontal or g.vertical or g.roll or g.distance):
        g.state = "aligned"
    return g
