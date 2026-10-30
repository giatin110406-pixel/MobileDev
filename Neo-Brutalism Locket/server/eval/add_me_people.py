"""Add me, version 2: find the new person with a person segmenter instead of trusting that
nothing else changed between the shots.

Version 1 (eval/add_me.py) took "what changed" as the person, so a leaf, a group member shifting
or a retake from a step to the side made it refuse. Here a pixel belongs to the photographer only
when shot 2 sees a person there, shot 1 does not, and the colour really changed. Everything else
that changed is left as it was in shot 1. The segmenter is MediaPipe's selfie model, the same
family as ML Kit's selfie segmentation the app runs.

From server/:

    .venv/Scripts/python.exe -m eval.add_me_people --set D:/clip_eval_tmp/add_me_heldout
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import cv2
import numpy as np

from eval.add_me import (
    REASON_ALIGN, REASON_NO_PERSON, REASON_TOO_LARGE, WORK, MIN_PERSON_AREA, MAX_PERSON_AREA,
    AddMeResult, _fit, align, difference, match_exposure,
)

PERSON = 0.5  # segmenter confidence that counts as "a person is here"
SEEN_BEFORE = 0.35  # a body in shot 2 this much on shot 1's people is someone who was there


class Segmenter:
    def __init__(self) -> None:
        import mediapipe as mp
        self._seg = mp.solutions.selfie_segmentation.SelfieSegmentation(model_selection=0)

    def __call__(self, bgr: np.ndarray) -> np.ndarray:
        return self._seg.process(cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)).segmentation_mask


def change_threshold(d: np.ndarray) -> float:
    med = float(np.median(d))
    mad = float(np.median(np.abs(d - med))) * 1.4826
    return max(18.0, med + 5.0 * mad)


def add_me_people(shot_1: np.ndarray, shot_2: np.ndarray, segment) -> AddMeResult:
    moved, valid, info = align(shot_1, shot_2)
    if moved is None:
        return AddMeResult(False, REASON_ALIGN, info=info)
    moved = match_exposure(shot_1, moved, valid)
    d = difference(shot_1, moved, valid)
    small_1, _ = _fit(shot_1)
    small_2, _ = _fit(moved)
    p1 = segment(small_1) > PERSON
    p2 = segment(small_2) > PERSON
    changed = d > change_threshold(d)
    total = d.size

    new = (p2 & ~p1 & changed).astype(np.uint8)
    new = cv2.morphologyEx(new, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
    n, labels, stats, _ = cv2.connectedComponentsWithStats(new, connectivity=8)
    k = max(9, round(WORK * 0.03)) | 1
    body = cv2.morphologyEx(p2.astype(np.uint8), cv2.MORPH_CLOSE,
                            cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (k, k)))
    _, body_labels = cv2.connectedComponents(body, connectivity=8)
    # Candidates: a new patch and the body in shot 2 it is part of. A group member who shifted
    # makes a new patch too, but their body mostly covers where shot 1 had them, so a body that
    # shot 1 did not have comes first, then the bigger one.
    candidates = []
    for c in range(1, n):
        area = float(stats[c, cv2.CC_STAT_AREA]) / total
        if area < MIN_PERSON_AREA:
            continue
        ids = np.unique(body_labels[labels == c])
        whole = np.isin(body_labels, ids[ids > 0])
        seen = float((whole & p1).sum()) / max(1, int(whole.sum()))
        candidates.append((seen > SEEN_BEFORE, -area, c, whole, seen))
    if not candidates:
        return AddMeResult(False, REASON_NO_PERSON, info=info)
    _, neg_area, _, whole, seen = min(candidates, key=lambda t: t[:2])
    info.update(new_area=-neg_area, seen_before=seen, candidates=len(candidates))

    # The whole person shot 2 sees there, less what shot 1 already had and did not change
    # (a group member they stand against stays shot 1's).
    person = whole & ~(p1 & ~changed)
    # Edges the segmenter missed (loose hair, a bag strap) when they changed right next to it.
    near = cv2.dilate(person.astype(np.uint8), np.ones((7, 7), np.uint8)) > 0
    person = (person | (near & changed)).astype(np.uint8)
    person = cv2.morphologyEx(person, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
    # (AddMeMerger.kt keeps the same steps; the segmenter there is ML Kit's selfie model.)
    area = float(person.sum()) / total
    info["person_area"] = area
    if area > MAX_PERSON_AREA:
        return AddMeResult(False, REASON_TOO_LARGE, info=info)

    h, w = shot_1.shape[:2]
    soft = cv2.dilate(person, np.ones((3, 3), np.uint8)).astype(np.float32)
    soft = cv2.resize(soft, (w, h), interpolation=cv2.INTER_LINEAR)
    soft = np.clip(cv2.GaussianBlur(soft, (0, 0), max(1.5, 0.003 * max(h, w))), 0, 1)
    out = shot_1.astype(np.float32) * (1 - soft[..., None]) + moved.astype(np.float32) * soft[..., None]
    return AddMeResult(True, None, np.clip(out, 0, 255).astype(np.uint8), soft, info)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--set", type=Path, required=True)
    ap.add_argument("--save", action="store_true", help="write <name>_people.jpg next to each pair")
    args = ap.parse_args()
    manifest = json.loads((args.set / "manifest.json").read_text(encoding="utf-8"))
    segment = Segmenter()
    by: dict[str, list] = {}
    for name, kind in manifest.items():
        s1 = cv2.imread(str(args.set / f"{name}_1.jpg"))
        s2 = cv2.imread(str(args.set / f"{name}_2.jpg"))
        r = add_me_people(s1, s2, segment)
        row = {"name": name, "ok": r.ok, "reason": r.reason}
        truth_path = args.set / f"{name}_truth.png"
        if r.ok and truth_path.exists():
            truth = cv2.imread(str(truth_path)).astype(np.float32)
            holder = cv2.imread(str(args.set / f"{name}_holder.png"), 0) > 127
            diff = np.abs(r.image.astype(np.float32) - truth).mean(axis=2)
            ring = cv2.dilate(holder.astype(np.uint8), np.ones((41, 41), np.uint8)) > 0
            ring &= ~cv2.erode(holder.astype(np.uint8), np.ones((9, 9), np.uint8)).astype(bool)
            row["holder_in"] = float((diff[holder] < 30).mean())
            row["band_error"] = float(diff[ring].mean())
            row["pass"] = row["holder_in"] >= .95 and row["band_error"] < 8
        if r.ok and args.save:
            cv2.imwrite(str(args.set / f"{name}_people.jpg"), r.image)
        by.setdefault(kind, []).append(row)
    for kind, rows in by.items():
        merged = [r for r in rows if r["ok"]]
        line = f"{kind:9s} n={len(rows):2d} merged={len(merged):2d}"
        if merged and "pass" in merged[0]:
            line += f" pass={sum(r['pass'] for r in merged):2d}"
            line += f" holder_in(min)={min(r['holder_in'] for r in merged):.2f}"
            line += f" band_err(median)={np.median([r['band_error'] for r in merged]):.1f}"
        fails = [f"{r['name']}:{r['reason'] or ('%.2f/%.1f' % (r['holder_in'], r['band_error']))}"
                 for r in rows if not r.get("pass", False)]
        print(line, fails)


if __name__ == "__main__":
    main()
