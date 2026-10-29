"""Shot pairs for "add me" built from the AI-made photos in gen_ai_photos_test, with the right
answer known, and the score of `add_me` on them.

People are cut out of their white backgrounds and stood in the empty scenes: two of them are the
group in shot 1; shot 2 is a hand-held retake (a little turned, shifted, zoomed, re-exposed, with
noise and JPEG) where the photographer now stands in too. Cases:

  gap         the photographer stands apart from the group: must merge, and look like the truth
  touching    the photographer stands against or in front of someone: must refuse (or merge well)
  moved       someone in the group moved / the light changed between the shots: must refuse
  other       shot 2 is another scene: must refuse
  nobody      nobody new in shot 2: must refuse

Real hair and clothes edges, real parallax and real light are NOT in here: real pairs remain the
acceptance test (docs/HUONG_DAN_CHUP_CAP_ANH.md). From server/:

    .venv/Scripts/python.exe -m eval.add_me_genai --photos ../gen_ai_photos_test --out D:/clip_eval_tmp/add_me_set
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import cv2
import numpy as np

from eval.add_me import add_me

SIDE = 1024
CANVAS = 1280  # scenes are built bigger, then cropped: a retake's edges show real scene


def cutout(path: Path) -> tuple[np.ndarray, np.ndarray]:
    """The person on a white background -> (BGR crop, alpha 0..1 crop)."""
    img = cv2.imread(str(path))
    img = cv2.resize(img, (SIDE, SIDE), interpolation=cv2.INTER_AREA)
    away = 255 - img.min(axis=2).astype(np.float32)  # how far from white
    alpha = np.clip((away - 14) / 26, 0, 1)
    solid = (alpha > 0.5).astype(np.uint8)
    count, labels, stats, _ = cv2.connectedComponentsWithStats(solid)
    keep = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
    body = (labels == keep).astype(np.uint8)
    body = cv2.morphologyEx(body, cv2.MORPH_CLOSE, np.ones((15, 15), np.uint8))
    # Fill holes (a white shirt is not background) and lose the white fringe.
    flood = body.copy()
    cv2.floodFill(flood, None, (0, 0), 1)
    body |= 1 - flood
    body = cv2.erode(body, np.ones((3, 3), np.uint8))
    alpha = cv2.GaussianBlur(body.astype(np.float32), (0, 0), 1.0)
    ys, xs = np.nonzero(body)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    return img[y0:y1, x0:x1], alpha[y0:y1, x0:x1]


def place(scene: np.ndarray, person: tuple[np.ndarray, np.ndarray], height: float, cx: float,
          feet: float) -> tuple[np.ndarray, np.ndarray]:
    """Stand `person` in `scene`: `height` of the photo tall, centred at x = cx, feet at y = feet
    (fractions). Returns (new scene, the person's alpha in the scene)."""
    img, alpha = person
    h = int(SIDE * height)
    w = max(1, int(img.shape[1] * h / img.shape[0]))
    img = cv2.resize(img, (w, h), interpolation=cv2.INTER_AREA)
    alpha = cv2.resize(alpha, (w, h), interpolation=cv2.INTER_AREA)
    m = (CANVAS - SIDE) / 2  # positions are fractions of the cropped photo
    x0, y0 = int(m + cx * SIDE - w / 2), int(m + feet * SIDE - h)
    full = np.zeros(scene.shape[:2], np.float32)
    sx0, sy0 = max(0, x0), max(0, y0)
    sx1, sy1 = min(CANVAS, x0 + w), min(CANVAS, y0 + h)
    full[sy0:sy1, sx0:sx1] = alpha[sy0 - y0:sy1 - y0, sx0 - x0:sx1 - x0]
    pasted = np.zeros_like(scene)
    pasted[sy0:sy1, sx0:sx1] = img[sy0 - y0:sy1 - y0, sx0 - x0:sx1 - x0]
    out = scene.astype(np.float32) * (1 - full[..., None]) + pasted.astype(np.float32) * full[..., None]
    return out.astype(np.uint8), full


def crop(img: np.ndarray) -> np.ndarray:
    m = (CANVAS - SIDE) // 2
    return img[m:m + SIDE, m:m + SIDE]


def handheld(img: np.ndarray, rng: np.random.Generator) -> np.ndarray:
    """A retake of the canvas: turned, shifted and zoomed a little, re-exposed, noisy, JPEG."""
    angle = rng.uniform(-2, 2)
    scale = rng.uniform(.97, 1.03)
    m = cv2.getRotationMatrix2D((CANVAS / 2, CANVAS / 2), angle, scale)
    m[:, 2] += rng.uniform(-.03, .03, 2) * SIDE
    h = np.vstack([m, [rng.uniform(-2e-5, 2e-5), rng.uniform(-2e-5, 2e-5), 1]])
    out = crop(cv2.warpPerspective(img, h, (CANVAS, CANVAS), borderMode=cv2.BORDER_REFLECT))
    out = out.astype(np.float32) * rng.uniform(.88, 1.12) * rng.uniform(.97, 1.03, 3)
    out += rng.normal(0, 2.0, out.shape)
    out = np.clip(out, 0, 255).astype(np.uint8)
    return cv2.imdecode(cv2.imencode(".jpg", out, [cv2.IMWRITE_JPEG_QUALITY, int(rng.integers(85, 93))])[1], 1)


def make(photos: Path, out: Path, seed: int) -> dict:
    rng = np.random.default_rng(seed)
    scenes = [cv2.resize(cv2.imread(str(p)), (CANVAS, CANVAS), interpolation=cv2.INTER_CUBIC)
              for p in sorted((photos / "background").glob("*.jpg"))]
    people = [cutout(p) for p in sorted((photos / "person").glob("person_*.jpg"))]
    out.mkdir(parents=True, exist_ok=True)
    manifest = {}

    def pick_people(n: int) -> list:
        return [people[i] for i in rng.choice(len(people), n, replace=False)]

    def save(name: str, kind: str, shot_1, shot_2, truth=None, holder=None):
        shot_1 = crop(shot_1)
        truth = None if truth is None else crop(truth)
        holder = None if holder is None else crop(holder)
        cv2.imwrite(str(out / f"{name}_1.jpg"), shot_1, [cv2.IMWRITE_JPEG_QUALITY, 92])
        cv2.imwrite(str(out / f"{name}_2.jpg"), shot_2, [cv2.IMWRITE_JPEG_QUALITY, 92])
        if truth is not None:
            cv2.imwrite(str(out / f"{name}_truth.png"), truth)
            cv2.imwrite(str(out / f"{name}_holder.png"), (holder * 255).astype(np.uint8))
        manifest[name] = kind

    for i in range(30):
        scene = scenes[i % len(scenes)]
        a, b, c = pick_people(3)
        height = rng.uniform(.45, .62)
        feet = rng.uniform(.9, .98)
        kind = ["gap", "gap", "gap", "touching", "moved"][i % 5] if i < 25 else "gap"
        left = rng.random() < .5
        g1, g2 = (.55, .7) if left else (.3, .45)  # group on one side
        shot, _ = place(scene, a, height, g1, feet)
        shot, _ = place(shot, b, height * rng.uniform(.92, 1.05), g2, feet)
        if kind == "touching":
            hx = (g1 - .1) if left else (g2 + .1)  # overlaps the nearest member
        else:
            hx = rng.uniform(.12, .2) if left else rng.uniform(.8, .88)
        truth, holder = place(shot, c, height * rng.uniform(.92, 1.05), hx, feet)
        shot_2 = truth
        if kind == "moved":
            # A group member stepped aside between the shots.
            shot_2, _ = place(scene, a, height, g1 + (.07 if left else -.07), feet)
            shot_2, _ = place(shot_2, b, height, g2, feet)
            shot_2, _ = place(shot_2, c, height, hx, feet)
        save(f"{kind}_{i:02d}", kind, shot, handheld(shot_2, rng), truth, holder)
    for i in range(4):
        a, b = pick_people(2)
        shot, _ = place(scenes[i], a, .5, .4, .95)
        save(f"other_{i:02d}", "other", shot, handheld(scenes[(i + 5) % len(scenes)], rng))
        shot_2, _ = place(scenes[i + 4], b, .5, .6, .95)
        save(f"nobody_{i:02d}", "nobody", shot_2, handheld(shot_2, rng))
    (out / "manifest.json").write_text(json.dumps(manifest, indent=1), encoding="utf-8")
    return manifest


def score(out: Path, manifest: dict) -> dict:
    """Runs `add_me` on every pair. A merge passes when the photographer is in it (>= 95 % of their
    pixels close to the truth) and the join cannot be told apart from the truth around them (mean
    difference in a band around the person under 8 grey levels, about the noise of a retake)."""
    rows = {}
    for name, kind in manifest.items():
        s1 = cv2.imread(str(out / f"{name}_1.jpg"))
        s2 = cv2.imread(str(out / f"{name}_2.jpg"))
        r = add_me(s1, s2)
        row = {"kind": kind, "ok": r.ok, "reason": r.reason}
        if r.ok and (out / f"{name}_truth.png").exists():
            truth = cv2.imread(str(out / f"{name}_truth.png")).astype(np.float32)
            holder = cv2.imread(str(out / f"{name}_holder.png"), 0) > 127
            diff = np.abs(r.image.astype(np.float32) - truth).mean(axis=2)
            ring = cv2.dilate(holder.astype(np.uint8), np.ones((41, 41), np.uint8)) > 0
            ring &= ~cv2.erode(holder.astype(np.uint8), np.ones((9, 9), np.uint8)).astype(bool)
            row["holder_in"] = float((diff[holder] < 30).mean())
            row["band_error"] = float(diff[ring].mean())
            row["pass"] = row["holder_in"] >= .95 and row["band_error"] < 8
            cv2.imwrite(str(out / f"{name}_result.jpg"), r.image)
        rows[name] = row
    return rows


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--photos", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--seed", type=int, default=3)
    args = ap.parse_args()
    manifest = make(args.photos, args.out, args.seed)
    rows = score(args.out, manifest)
    (args.out / "python_scores.json").write_text(json.dumps(rows, indent=1), encoding="utf-8")
    by: dict[str, list] = {}
    for row in rows.values():
        by.setdefault(row["kind"], []).append(row)
    for kind, items in by.items():
        merged = [r for r in items if r["ok"]]
        line = f"{kind:9s} n={len(items):2d} merged={len(merged):2d}"
        if kind in ("gap", "touching") and merged:
            line += f" pass={sum(r['pass'] for r in merged):2d}"
            line += f" band_err(median)={np.median([r['band_error'] for r in merged]):.1f}"
        reasons = sorted({r['reason'] for r in items if not r['ok']})
        print(line, "refused:", reasons)


if __name__ == "__main__":
    main()
