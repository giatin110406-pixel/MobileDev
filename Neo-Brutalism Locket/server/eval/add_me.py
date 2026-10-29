"""'Add me in': merge two shots of the same scene so the person who held the camera appears in the
group photo.

shot_1 = the group without the holder, shot_2 = the same scene with the holder standing in.
The holder is cut out of shot_2 along a seam that runs through background pixels both shots
agree on (a closed minimum-cost path found by dynamic programming), then pasted onto shot_1.

When the scene does not allow that (no alignment, background moved, the person stands against
someone else so no clean seam exists) the result says why instead of guessing: `ok` is False and
`reason` is one of the REASON_* codes. Matting for the tight-fit case is a separate step.
"""
from __future__ import annotations

from dataclasses import dataclass, field

import cv2
import numpy as np

REASON_ALIGN = "align_failed"
REASON_BACKGROUND = "background_changed"
REASON_NO_PERSON = "no_new_person"
REASON_TOO_LARGE = "change_too_large"
REASON_NEEDS_MATTING = "needs_matting"

WORK = 640  # the long side everything is measured at; the output stays at full resolution
MIN_MATCHES = 20
MIN_INLIERS = 15
MIN_INLIER_RATIO = 0.35
MAX_CORNER_SHIFT = 0.25  # of the image diagonal; a bigger warp is not "the same scene"
MIN_PERSON_AREA = 0.004  # of the image
MAX_PERSON_AREA = 0.60
MAX_OTHER_CHANGE = 0.12  # change outside the chosen person, of the image
MAX_SEAM_COST = 14.0  # mean colour difference along the cut; above this it cuts through someone
ANGLES = 360


@dataclass
class AddMeResult:
    ok: bool
    reason: str | None = None
    image: np.ndarray | None = None  # BGR, full resolution of shot_1
    mask: np.ndarray | None = None  # float32 0..1, full resolution
    info: dict = field(default_factory=dict)


def _fit(img: np.ndarray, side: int = WORK) -> tuple[np.ndarray, float]:
    scale = min(1.0, side / max(img.shape[:2]))
    if scale == 1.0:
        return img, 1.0
    size = (round(img.shape[1] * scale), round(img.shape[0] * scale))
    return cv2.resize(img, size, interpolation=cv2.INTER_AREA), scale


def align(base: np.ndarray, moving: np.ndarray) -> tuple[np.ndarray | None, np.ndarray | None, dict]:
    """Warp `moving` into `base`'s frame. Returns (warped, valid_mask, info); warped is None if
    the two shots cannot be matched."""
    small_b, scale = _fit(base)
    small_m, _ = _fit(moving)
    sift = cv2.SIFT_create(nfeatures=3000)
    kb, db = sift.detectAndCompute(cv2.cvtColor(small_b, cv2.COLOR_BGR2GRAY), None)
    km, dm = sift.detectAndCompute(cv2.cvtColor(small_m, cv2.COLOR_BGR2GRAY), None)
    info: dict = {"keypoints": (len(kb), len(km))}
    if db is None or dm is None or len(kb) < MIN_MATCHES or len(km) < MIN_MATCHES:
        return None, None, info
    pairs = cv2.BFMatcher().knnMatch(dm, db, k=2)
    good = [p[0] for p in pairs if len(p) == 2 and p[0].distance < 0.75 * p[1].distance]
    info["matches"] = len(good)
    if len(good) < MIN_MATCHES:
        return None, None, info
    src = np.float32([km[m.queryIdx].pt for m in good]).reshape(-1, 1, 2)
    dst = np.float32([kb[m.trainIdx].pt for m in good]).reshape(-1, 1, 2)
    h_small, inl = cv2.findHomography(src, dst, cv2.RANSAC, 3.0)
    if h_small is None:
        return None, None, info
    inliers = int(inl.sum())
    info["inliers"] = inliers
    info["inlier_ratio"] = inliers / len(good)
    if inliers < MIN_INLIERS or info["inlier_ratio"] < MIN_INLIER_RATIO:
        return None, None, info
    # small -> full resolution: H_full = S^-1 H S, with S scaling by `scale`
    s = np.diag([scale, scale, 1.0])
    h_full = np.linalg.inv(s) @ h_small @ s
    h, w = base.shape[:2]
    corners = np.float32([[0, 0], [w, 0], [w, h], [0, h]]).reshape(-1, 1, 2)
    moved = cv2.perspectiveTransform(corners, h_full).reshape(-1, 2)
    shift = float(np.abs(moved - corners.reshape(-1, 2)).max() / np.hypot(w, h))
    info["corner_shift"] = shift
    if shift > MAX_CORNER_SHIFT:
        return None, None, info
    warped = cv2.warpPerspective(moving, h_full, (w, h), flags=cv2.INTER_LINEAR,
                                 borderMode=cv2.BORDER_REPLICATE)
    valid = cv2.warpPerspective(np.full((moving.shape[0], moving.shape[1]), 255, np.uint8),
                                h_full, (w, h), flags=cv2.INTER_NEAREST)
    return warped, valid, info


def match_exposure(base: np.ndarray, moving: np.ndarray, valid: np.ndarray) -> np.ndarray:
    """Per-channel gain so the two shots have the same overall brightness, from medians (a
    person covers a small part of the frame, so the median is the background)."""
    sel = valid > 0
    out = moving.astype(np.float32)
    for c in range(3):
        mb = float(np.median(base[..., c][sel]))
        mm = float(np.median(moving[..., c][sel]))
        out[..., c] *= float(np.clip(mb / max(mm, 1.0), 0.7, 1.4))
    return np.clip(out, 0, 255).astype(np.uint8)


def difference(base: np.ndarray, moving: np.ndarray, valid: np.ndarray) -> np.ndarray:
    """Colour distance map (Lab, lightly blurred) at working size; 0 where `moving` has no data."""
    b, _ = _fit(base)
    m, _ = _fit(moving)
    v, _ = _fit(valid)
    lab_b = cv2.GaussianBlur(cv2.cvtColor(b, cv2.COLOR_BGR2LAB).astype(np.float32), (0, 0), 2.0)
    lab_m = cv2.GaussianBlur(cv2.cvtColor(m, cv2.COLOR_BGR2LAB).astype(np.float32), (0, 0), 2.0)
    d = np.linalg.norm(lab_b - lab_m, axis=2)
    d[v < 128] = 0
    return d


def changed_regions(d: np.ndarray) -> tuple[np.ndarray, list[np.ndarray]]:
    """Binary change mask and its connected blobs, biggest first. The threshold follows the
    noise of this pair (median + 5 MAD) so a noisy night shot does not light up everywhere."""
    med = float(np.median(d))
    mad = float(np.median(np.abs(d - med))) * 1.4826
    thr = max(18.0, med + 5.0 * mad)
    mask = (d > thr).astype(np.uint8)
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
    k = max(9, round(WORK * 0.03)) | 1
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (k, k)))
    count, labels, stats, _ = cv2.connectedComponentsWithStats(mask, connectivity=8)
    order = sorted(range(1, count), key=lambda i: -stats[i, cv2.CC_STAT_AREA])
    blobs = [(labels == i).astype(np.uint8) for i in order]
    return mask, blobs


def _rays(mask: np.ndarray, centre: tuple[float, float]) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """For each angle: the unit direction and how far the blob reaches from `centre`."""
    h, w = mask.shape
    theta = np.linspace(0, 2 * np.pi, ANGLES, endpoint=False)
    dx, dy = np.cos(theta), np.sin(theta)
    reach_max = int(np.hypot(h, w))
    r = np.arange(reach_max)
    xs = np.clip((centre[0] + dx[:, None] * r[None, :]).round().astype(int), 0, w - 1)
    ys = np.clip((centre[1] + dy[:, None] * r[None, :]).round().astype(int), 0, h - 1)
    hit = mask[ys, xs] > 0
    last = np.where(hit.any(axis=1), reach_max - 1 - np.argmax(hit[:, ::-1], axis=1), 0)
    return dx, dy, last


def find_seam(d: np.ndarray, person: np.ndarray) -> tuple[np.ndarray, float]:
    """Closed minimum-cost cut around `person`: for every angle pick a radius in a band just
    outside the blob so the path steps by at most one radius per angle and the summed colour
    difference is smallest. Returns (filled mask at working size, mean cost along the cut)."""
    h, w = person.shape
    ys, xs = np.nonzero(person)
    centre = (float(xs.mean()), float(ys.mean()))
    dx, dy, reach = _rays(person, centre)
    band = max(12, round(WORK * 0.04))
    k = np.arange(band)
    radius = reach[:, None] + 1 + k[None, :]
    px = np.clip((centre[0] + dx[:, None] * radius).round().astype(int), 0, w - 1)
    py = np.clip((centre[1] + dy[:, None] * radius).round().astype(int), 0, h - 1)
    cost = d[py, px] + 0.01 * k[None, :]  # a hair of preference for the tighter cut

    inf = np.float32(1e9)
    # dp[s, j]: cheapest path that started at offset s and now sits at offset j
    dp = np.full((band, band), inf, np.float32)
    dp[np.arange(band), np.arange(band)] = cost[0]
    back = np.zeros((ANGLES, band, band), np.int8)
    for a in range(1, ANGLES):
        down = np.full_like(dp, inf)
        down[:, 1:] = dp[:, :-1]
        up = np.full_like(dp, inf)
        up[:, :-1] = dp[:, 1:]
        stacked = np.stack([down, dp, up])  # came from offset j-1, j, j+1
        pick = stacked.argmin(axis=0)
        back[a] = (pick - 1).astype(np.int8)
        dp = stacked.min(axis=0) + cost[a][None, :]
    starts = np.arange(band)
    closing = np.abs(np.arange(band)[None, :] - starts[:, None]) <= 1
    dp_closed = np.where(closing, dp, inf)
    s, j = np.unravel_index(int(dp_closed.argmin()), dp_closed.shape)
    total = float(dp_closed[s, j])
    path = np.zeros(ANGLES, int)
    path[-1] = j
    for a in range(ANGLES - 1, 0, -1):
        path[a - 1] = path[a] + int(back[a, s, path[a]])  # back holds -1/0/+1 = previous offset - this one
    path = np.clip(path, 0, band - 1)

    r_cut = reach + 1 + path
    pts = np.stack([centre[0] + dx * r_cut, centre[1] + dy * r_cut], axis=1).round().astype(np.int32)
    filled = np.zeros((h, w), np.uint8)
    cv2.fillPoly(filled, [pts], 1)
    filled |= person
    return filled, total / ANGLES


def add_me(shot_1: np.ndarray, shot_2: np.ndarray, seed: tuple[float, float] | None = None) -> AddMeResult:
    """Put the person who is only in `shot_2` into `shot_1`. `seed` (x, y as 0..1 of the image)
    picks which person when several things changed."""
    moved, valid, info = align(shot_1, shot_2)
    if moved is None:
        return AddMeResult(False, REASON_ALIGN, info=info)
    moved = match_exposure(shot_1, moved, valid)
    d = difference(shot_1, moved, valid)
    _, blobs = changed_regions(d)
    total = d.shape[0] * d.shape[1]
    if not blobs or blobs[0].sum() / total < MIN_PERSON_AREA:
        return AddMeResult(False, REASON_NO_PERSON, info=info)

    chosen = blobs[0]
    if seed is not None:
        sx, sy = round(seed[0] * (d.shape[1] - 1)), round(seed[1] * (d.shape[0] - 1))
        inside = [b for b in blobs if b[sy, sx]]
        chosen = inside[0] if inside else min(
            blobs, key=lambda b: np.hypot(*(np.argwhere(b).mean(axis=0) - (sy, sx))))
    person = cv2.dilate(chosen, np.ones((5, 5), np.uint8))
    area = float(person.sum()) / total
    others = sum(float(b.sum()) for b in blobs if b is not chosen) / total
    info.update(person_area=area, other_change=others)
    if area > MAX_PERSON_AREA:
        return AddMeResult(False, REASON_TOO_LARGE, info=info)
    if others > MAX_OTHER_CHANGE:
        return AddMeResult(False, REASON_BACKGROUND, info=info)

    cut, seam_cost = find_seam(d, person)
    info["seam_cost"] = seam_cost
    if seam_cost > MAX_SEAM_COST:
        return AddMeResult(False, REASON_NEEDS_MATTING, info=info)

    h, w = shot_1.shape[:2]
    soft = cv2.resize(cut.astype(np.float32), (w, h), interpolation=cv2.INTER_LINEAR)
    soft = cv2.GaussianBlur(soft, (0, 0), max(1.5, 0.004 * max(h, w)))
    soft = np.clip(soft, 0, 1)
    out = shot_1.astype(np.float32) * (1 - soft[..., None]) + moved.astype(np.float32) * soft[..., None]
    return AddMeResult(True, None, np.clip(out, 0, 255).astype(np.uint8), soft, info)
