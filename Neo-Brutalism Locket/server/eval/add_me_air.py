"""Pairs for "add me" where the new person's arm or body reaches over where someone stood in
shot 1, while that someone is NOT in shot 2 (they left the frame, or hold the phone): the case of
Pixel's demo (a father's arm goes behind the mother and the hand rests on the daughter).

Shot 1: two people. Shot 2: only the newcomer, overlapping where one of them stood. The truth with
the newcomer behind that person (`*_behind.png`) and in front of them (`*_front.png`) are both
kept, since a photo of the two shots alone cannot say which one is right.

From server/:
    .venv/Scripts/python.exe -m eval.add_me_air --photos ../gen_ai_photos_test --out D:/clip_eval_tmp/add_me_air
"""
from __future__ import annotations

import argparse
from pathlib import Path

import cv2
import numpy as np

from eval.add_me_genai import CANVAS, SIDE, crop, cutout, handheld, place


def make(photos: Path, out: Path, seed: int, count: int) -> None:
    rng = np.random.default_rng(seed)
    scenes = [cv2.resize(cv2.imread(str(p)), (CANVAS, CANVAS), interpolation=cv2.INTER_CUBIC)
              for p in sorted((photos / "background").glob("*.jpg"))]
    people = [cutout(p) for p in sorted((photos / "person").glob("person_*.jpg"))]
    out.mkdir(parents=True, exist_ok=True)
    for i in range(count):
        scene = scenes[i % len(scenes)]
        a, b, c = (people[j] for j in rng.choice(len(people), 3, replace=False))
        height = rng.uniform(.45, .6)
        feet = rng.uniform(.92, .98)
        left = rng.random() < .5
        xa, xb = (.55, .72) if left else (.28, .45)
        xc = xb - .12 if left else xb + .12  # the newcomer stands beside b, overlapping b's edge
        old, _ = place(scene, a, height, xa, feet)
        shot_1, b_alpha = place(old, b, height * rng.uniform(.95, 1.03), xb, feet)
        alone, c_alpha = place(scene, c, height * rng.uniform(.95, 1.03), xc, feet)
        behind, _ = place(alone, a, height, xa, feet)
        behind, _ = place(behind, b, height, xb, feet)  # b (and a) over the newcomer
        front, _ = place(shot_1, c, height, xc, feet)
        name = f"air_{i:02d}"
        cv2.imwrite(str(out / f"{name}_1.jpg"), crop(shot_1), [cv2.IMWRITE_JPEG_QUALITY, 92])
        cv2.imwrite(str(out / f"{name}_2.jpg"), handheld(alone, rng), [cv2.IMWRITE_JPEG_QUALITY, 92])
        cv2.imwrite(str(out / f"{name}_behind.png"), crop(behind))
        cv2.imwrite(str(out / f"{name}_front.png"), crop(front))
        cv2.imwrite(str(out / f"{name}_holder.png"), (crop(c_alpha) * 255).astype(np.uint8))
        cv2.imwrite(str(out / f"{name}_b.png"), (crop(b_alpha) * 255).astype(np.uint8))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--photos", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--seed", type=int, default=21)
    ap.add_argument("--count", type=int, default=12)
    args = ap.parse_args()
    make(args.photos, args.out, args.seed, args.count)


if __name__ == "__main__":
    main()
