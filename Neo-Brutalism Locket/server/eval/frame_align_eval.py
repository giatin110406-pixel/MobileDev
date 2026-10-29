"""Measure `frame_align` on pairs made from ordinary pictures (see frame_align_synth.py).

    python -m eval.frame_align_eval [extra_picture_folder ...]

Uses the pictures in server/eval/photos_* (and any folder you name, e.g. AI-made scenes) as scenes.
For each, many random views are made: shifted up to a quarter of the frame, rolled up to 15
degrees, nearer or farther, with a different exposure, blur, noise and JPEG. Reported:

- direction accuracy: every arrow the person is told (left/right, up/down, roll, closer/back) points
  the right way. The plan's bar is 95% or more. Only axes clearly off (1.5x the "aligned"
  tolerance) are counted: right at the edge of "aligned" either answer is fine.
- the error of the numbers, and how often the answer was wrong while claiming to be sure.
- the hard cases it must answer "unsure" to: a blank wall, and a different scene altogether.
"""
from __future__ import annotations

import hashlib
import sys
from pathlib import Path

import cv2
import numpy as np

from eval import frame_align as fa
from eval.frame_align_synth import (
    Truth,
    flat_picture,
    make_pair,
    random_conditions,
    random_hardness,
    random_truth,
)

HERE = Path(__file__).parent
SIDE = 480
TRIALS_PER_SCENE = 25
HARD = "--easy" not in sys.argv  # --easy: exact shifts and turns only, no tilt and no passers-by


def load_scenes(extra: list[str]) -> list[tuple[str, np.ndarray]]:
    folders = [HERE / "photos_pick10", HERE / "photos_hard8", HERE / "photos_faces"]
    folders += [Path(p) for p in extra]
    seen, scenes = set(), []
    for folder in folders:
        for path in sorted(folder.glob("*")):
            if path.suffix.lower() not in {".jpg", ".jpeg", ".png"}:
                continue
            img = cv2.imread(str(path))
            if img is None:
                continue
            digest = hashlib.md5(img.tobytes()).hexdigest()
            if digest in seen:
                continue
            seen.add(digest)
            # Room for the view to move without running out of picture.
            low = min(img.shape[:2])
            if low < 2 * SIDE:
                k = 2 * SIDE / low
                img = cv2.resize(img, None, fx=k, fy=k, interpolation=cv2.INTER_CUBIC)
            scenes.append((f"{folder.name}/{path.name}", img))
    return scenes


def expected(truth: Truth) -> fa.Guidance:
    """The arrows a perfect estimate would give, for the clearly-off axes only."""
    g = fa.Guidance("adjust")
    if abs(truth.dx) > 1.5 * fa.ALIGNED_SHIFT:
        g.horizontal = "right" if truth.dx > 0 else "left"
    if abs(truth.dy) > 1.5 * fa.ALIGNED_SHIFT:
        g.vertical = "down" if truth.dy > 0 else "up"
    if abs(truth.roll_deg) > 1.5 * fa.ALIGNED_ROLL_DEG:
        g.roll = "clockwise" if truth.roll_deg > 0 else "counterclockwise"
    if abs(truth.scale - 1) > 1.5 * fa.ALIGNED_SCALE:
        g.distance = "back" if truth.scale > 1 else "closer"
    return g


def arrows_right(want: fa.Guidance, got: fa.Guidance) -> bool:
    for axis in ("horizontal", "vertical", "roll", "distance"):
        w = getattr(want, axis)
        if w is not None and getattr(got, axis) != w:
            return False
    return True


def main() -> int:
    scenes = load_scenes([a for a in sys.argv[1:] if not a.startswith("--")])
    if not scenes:
        print("No pictures found.")
        return 1
    rng = np.random.default_rng(7)
    total = ok_count = right = confident_wrong = 0
    shift_err, roll_err, scale_err = [], [], []
    per_scene: list[str] = []

    for name, src in scenes:
        n = r = 0
        for _ in range(TRIALS_PER_SCENE):
            truth = random_truth(rng)
            hard = random_hardness(rng) if HARD else {}
            other = scenes[int(rng.integers(len(scenes)))][1]
            pair = make_pair(
                src,
                truth,
                side=SIDE,
                rng=rng,
                intruder=other,
                **random_conditions(rng),
                **hard,
            )
            truth = pair.truth  # where the centre really landed, tilt included
            est = fa.estimate(pair.locked, pair.current)
            total += 1
            n += 1
            if not est.ok:
                continue
            ok_count += 1
            if arrows_right(expected(truth), fa.guidance(est)):
                right += 1
                r += 1
            d_shift = max(abs(est.dx - truth.dx), abs(est.dy - truth.dy))
            d_roll = abs(est.roll_deg - truth.roll_deg)
            d_scale = abs(est.scale - truth.scale)
            shift_err.append(d_shift)
            roll_err.append(d_roll)
            scale_err.append(d_scale)
            if d_shift > 0.06 or d_roll > 6 or d_scale > 0.1:
                confident_wrong += 1
        per_scene.append(f"  {name:32s} sure {r}/{n}")

    def pct(x: float) -> str:
        return f"{100 * x:5.1f}%"

    print(f"{len(scenes)} scenes, {total} views")
    print(f"answered (sure):          {pct(ok_count / total)}")
    print(f"arrows right when sure:   {pct(right / max(ok_count, 1))}   (bar: 95%)")
    print(f"arrows right overall:     {pct(right / total)}   (unsure counts as not right)")
    print(f"sure but numbers off:     {pct(confident_wrong / max(ok_count, 1))}")
    for label, errs, unit in (
        ("shift error", shift_err, "of frame"),
        ("roll error", roll_err, "deg"),
        ("scale error", scale_err, ""),
    ):
        if errs:
            print(f"{label:24s}  median {np.median(errs):.3f}  95th {np.percentile(errs, 95):.3f} {unit}")

    # The hard cases: it must say "unsure".
    flat_unsure = other_unsure = 0
    flat_n = other_n = 30
    for i in range(flat_n):
        a = flat_picture(SIDE, SIDE, rng)
        b = flat_picture(SIDE, SIDE, rng)
        flat_unsure += not fa.estimate(a, b).ok
    for i in range(other_n):
        first, second = rng.choice(len(scenes), size=2, replace=False)
        one, two = scenes[int(first)][1], scenes[int(second)][1]
        y, x = (one.shape[0] - SIDE) // 2, (one.shape[1] - SIDE) // 2
        a = one[y : y + SIDE, x : x + SIDE]
        y, x = (two.shape[0] - SIDE) // 2, (two.shape[1] - SIDE) // 2
        b = two[y : y + SIDE, x : x + SIDE]
        other_unsure += not fa.estimate(a, b).ok
    print(f"blank wall -> unsure:     {pct(flat_unsure / flat_n)}")
    print(f"another scene -> unsure:  {pct(other_unsure / other_n)}")
    print("per scene:")
    print("\n".join(per_scene))
    return 0


if __name__ == "__main__":
    sys.exit(main())
