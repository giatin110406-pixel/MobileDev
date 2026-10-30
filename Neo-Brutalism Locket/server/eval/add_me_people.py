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
ABSENT = 0.35  # a person of shot 1 is not in shot 2 when the model finds a person on less of their area than this...
CHANGED = 0.4  # ...or when this much of their area changed (the newcomer may stand where they stood)
SHARP = 6.0  # next to people of shot 1 the newcomer's edge is a hard occlusion: opacity is steepened by this
THIN = 0.04  # of WORK: less depth than this inside an outline is a limb, not a body
EDGE_FRONT = 0.03  # of WORK: the newcomer's hand this close to the rim of such a person stays in front


class Segmenter:
    def __init__(self) -> None:
        import mediapipe as mp
        self._seg = mp.solutions.selfie_segmentation.SelfieSegmentation(model_selection=0)

    def __call__(self, bgr: np.ndarray) -> np.ndarray:
        return self._seg.process(cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)).segmentation_mask


class Matter:
    """MODNet (Apache-2.0) portrait matting through ONNX Runtime: the opacity of the person per
    pixel of a BGR picture. The app runs the same model (addme/Matting.kt)."""

    LONG_SIDE = 640

    def __init__(self, path: str = "D:/clip_eval_tmp/modnet/onnx/model.onnx") -> None:
        import onnxruntime as ort
        self._s = ort.InferenceSession(path, providers=["CPUExecutionProvider"])

    def __call__(self, bgr: np.ndarray) -> np.ndarray:
        h, w = bgr.shape[:2]
        f = self.LONG_SIDE / max(h, w)
        nh, nw = max(32, round(h * f / 32) * 32), max(32, round(w * f / 32) * 32)
        x = cv2.resize(bgr, (nw, nh), interpolation=cv2.INTER_AREA if f < 1 else cv2.INTER_CUBIC)
        x = ((x[..., ::-1].astype(np.float32) / 255 - 0.5) / 0.5).transpose(2, 0, 1)[None]
        a = self._s.run(None, {"input": x})[0][0, 0]
        return cv2.resize(a, (w, h), interpolation=cv2.INTER_LINEAR)


def change_threshold(d: np.ndarray) -> float:
    med = float(np.median(d))
    mad = float(np.median(np.abs(d - med))) * 1.4826
    return max(18.0, med + 5.0 * mad)


BAND = 0.0075  # of the long side: how far from the first outline the edge may still move
GUIDE_RADIUS = 0.005
GUIDE_EPS = 1e-3
CROP_MARGIN = 0.15
CROP_SIDE = 768  # the person's crop is segmented at this size, so the model's grid is spent on them


def guided(guide: np.ndarray, src: np.ndarray, r: int, eps: float) -> np.ndarray:
    """He et al.'s guided filter, grey guide, box filters only (the same maths is in AddMeMerger.kt)."""
    box = lambda a: cv2.boxFilter(a, -1, (2 * r + 1, 2 * r + 1), borderType=cv2.BORDER_REPLICATE)
    mean_i, mean_p = box(guide), box(src)
    var_i = box(guide * guide) - mean_i * mean_i
    cov_ip = box(guide * src) - mean_i * mean_p
    a = cov_ip / (var_i + eps)
    b = mean_p - a * mean_i
    return np.clip(box(a) * guide + box(b), 0, 1)


def refine_alpha(moved: np.ndarray, person_w: np.ndarray, valid: np.ndarray, segment,
                 olds_w: np.ndarray | None = None, matte=None, occluder=None) -> np.ndarray:
    """Soft opacity of the person at full size. `person_w` is the person's outline at working
    size; the model sees a crop of just them (about 3x the detail), and the edge is snapped to the
    photo's own edges in a band around the outline with a guided filter."""
    h, w = moved.shape[:2]
    side = max(h, w)
    hard = cv2.resize(person_w.astype(np.float32), (w, h), interpolation=cv2.INTER_LINEAR) > 0.5
    ys, xs = np.where(hard)
    if len(xs) == 0:
        return hard.astype(np.float32)
    mx, my = int((xs.max() - xs.min()) * CROP_MARGIN) + 8, int((ys.max() - ys.min()) * CROP_MARGIN) + 8
    x0, x1 = max(0, xs.min() - mx), min(w, xs.max() + mx + 1)
    y0, y1 = max(0, ys.min() - my), min(h, ys.max() + my + 1)
    crop = moved[y0:y1, x0:x1]
    f = CROP_SIDE / max(crop.shape[:2])
    small = cv2.resize(crop, None, fx=f, fy=f, interpolation=cv2.INTER_AREA if f < 1 else cv2.INTER_CUBIC)
    conf = np.zeros((h, w), np.float32)
    conf[y0:y1, x0:x1] = cv2.resize(segment(small), (x1 - x0, y1 - y0), interpolation=cv2.INTER_LINEAR)

    band = max(4, round(BAND * side))
    k = 2 * band + 1
    ker = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (k, k))
    outer = cv2.dilate(hard.astype(np.uint8), ker) > 0
    inner = cv2.erode(hard.astype(np.uint8), ker) > 0
    if matte is not None:
        # The band is the matting model's opacity: the coarse outline's own halo would only put the wall back.
        fine = np.zeros((h, w), np.float32)
        fine[y0:y1, x0:x1] = matte(crop)
        conf = fine
    alpha = np.where(inner, 1.0, np.where(outer, conf, 0.0)).astype(np.float32)
    if matte is not None and olds_w is not None:
        # Over someone of shot 1 the coarse outline is not trusted even inside: what is laid there
        # (a hand, an arm) is the matting model's alone, so no wall comes along with it.
        over_old = cv2.resize(olds_w.astype(np.uint8), (w, h), interpolation=cv2.INTER_NEAREST) > 0
        alpha = np.where(over_old & outer, conf, alpha).astype(np.float32)
    # Where the model hesitates inside the old outline, trust the outline.
    if matte is None:
        alpha = np.where(hard & ~inner, np.maximum(alpha, 0.5 * conf + 0.5 * hard), alpha).astype(np.float32)
    guide = cv2.cvtColor(moved, cv2.COLOR_BGR2GRAY).astype(np.float32) / 255
    r = max(3, round(GUIDE_RADIUS * side))
    if matte is None:
        snapped = guided(guide, alpha, r, GUIDE_EPS)
        alpha = np.where(outer & ~inner, snapped, alpha)
    if olds_w is not None:
        # Where the newcomer's edge meets someone of shot 1 it is a body in front of a body, not a
        # person against a wall: a soft edge there shows as both of them half see-through.
        olds = cv2.resize(olds_w.astype(np.uint8), (w, h), interpolation=cv2.INTER_NEAREST)
        near_old = cv2.dilate(olds, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (4 * band + 1, 4 * band + 1))) > 0
        alpha = np.where(near_old, np.clip((alpha - 0.5) * SHARP + 0.5, 0, 1), alpha).astype(np.float32)
    if occluder is not None:
        shot_1, gone_w = occluder
        old = np.zeros((h, w), np.float32)
        old[y0:y1, x0:x1] = matte(shot_1[y0:y1, x0:x1])
        near_gone = cv2.dilate(gone_w.astype(np.uint8), np.ones((9, 9), np.uint8))
        near_gone = cv2.resize(near_gone, (w, h), interpolation=cv2.INTER_NEAREST) > 0
        alpha = alpha * (1 - old * near_gone)
    alpha *= (valid > 128)  # nothing from where the second shot has no picture
    return np.clip(alpha, 0, 1)


HARMONY_REACH = 0.02  # of the long side: the Poisson boundary lies this far outside the person
HARMONY_FADE = 0.02  # of the long side: how far in from the person's rim the correction is carried


def harmonize(shot_1: np.ndarray, moved: np.ndarray, soft: np.ndarray) -> np.ndarray:
    """`moved` with its light made to continue shot 1's around the person (Poisson cloning). Two
    phone shots differ in more than one overall gain (auto-exposure follows who is in frame, the
    wall near a newcomer is brighter or darker, the white balance drifts), and without this the
    newcomer's rim shows as a bright or dark outline. The cloning boundary lies in the background
    just outside the person, where shot 1 and shot 2 show the same thing."""
    h, w = moved.shape[:2]
    pad = 16
    reach = max(15, round(HARMONY_REACH * max(h, w)))
    solid = (soft > 0.5).astype(np.uint8)
    mask = cv2.dilate(solid, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * reach + 1, 2 * reach + 1)))
    ys, xs = np.where(mask > 0)
    if len(xs) == 0:
        return moved.astype(np.float32)
    x0, x1 = max(0, xs.min() - pad), min(w, xs.max() + 1 + pad)
    y0, y1 = max(0, ys.min() - pad), min(h, ys.max() + 1 + pad)
    border = lambda a: cv2.copyMakeBorder(a[y0:y1, x0:x1], pad, pad, pad, pad, cv2.BORDER_REPLICATE)
    src, dst = border(moved), border(shot_1)
    m = cv2.copyMakeBorder(mask[y0:y1, x0:x1] * 255, pad, pad, pad, pad, cv2.BORDER_CONSTANT, value=0)
    box = cv2.boundingRect(m)
    try:
        out = cv2.seamlessClone(src, dst, m, (box[0] + box[2] // 2, box[1] + box[3] // 2), cv2.NORMAL_CLONE)
    except cv2.error:
        return moved.astype(np.float32)
    # What Poisson changed is a smooth correction; keep it at the rim, where the outline would
    # show, and fade it out going into the person so they keep the look they were taken with.
    depth = cv2.distanceTransform(solid[y0:y1, x0:x1], cv2.DIST_L2, 3)
    weight = np.exp(-depth / (HARMONY_FADE * max(h, w)))[..., None]
    part = moved[y0:y1, x0:x1].astype(np.float32)
    lit = moved.astype(np.float32).copy()
    lit[y0:y1, x0:x1] = part + (out[pad:pad + (y1 - y0), pad:pad + (x1 - x0)].astype(np.float32) - part) * weight
    return lit


def hidden_behind(person: np.ndarray, gone: np.ndarray) -> np.ndarray:
    """Without the matting model: the part of the newcomer behind the people of shot 1 they
    overlap, at working size (all of the overlap; what reaches past them, like fingers over a
    shoulder, stays)."""
    overlap = person & gone
    own = person & ~gone
    if not overlap.any() or own.sum() < 0.3 * overlap.sum():
        return np.zeros_like(person)
    return overlap


def decide_layer(person: np.ndarray, gone: np.ndarray, p2: np.ndarray, info: dict) -> str:
    """Who is in front where the newcomer overlaps someone of shot 1 who left. An arm goes behind
    the person it is put around (its owner's hand ends on their far shoulder), so the owner is the
    one whose THIN part (an arm, as far as the picture shows: little depth inside its outline) is
    in the overlap: if that is the person of shot 1, the newcomer is in front of their arm;
    otherwise the newcomer's arm goes behind them. Without an overlap, behind."""
    person = person & p2  # the model's own people: a laptop or a cup in the outline is not a body
    overlap = person & gone
    if overlap.sum() < 50:
        return "behind"
    reach = max(5, round(THIN * WORK / 2))
    ring = cv2.dilate(overlap.astype(np.uint8), cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * reach + 1, 2 * reach + 1))) > 0
    ring &= ~overlap
    inside_new = float((ring & person & ~gone).sum())  # what surrounds the overlap is the newcomer alone...
    inside_old = float((ring & gone & ~person).sum())  # ...or the person of shot 1 alone
    info.update(around_new=inside_new, around_old=inside_old)
    # A strip of overlap lying inside someone's body is a limb of the OTHER person put over them.
    return "front" if inside_new > inside_old else "behind"


def add_me_people(shot_1: np.ndarray, shot_2: np.ndarray, segment, refine: bool = True,
                  layer: str = "auto", relight: bool = True, matte=None) -> AddMeResult:
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
    # People of shot 1 who are not in shot 2 (they left the frame or hold the phone) have nothing
    # in shot 2 to compare with, so "unchanged" says nothing about them: where the newcomer
    # overlaps them it is a question of who is in front. "behind" (the default) keeps them on top
    # except within a hand's reach of their rim, where a hand resting on a shoulder stays in
    # front; "front" lays the newcomer over them. People who are in shot 2 too keep shot 1's
    # pixels wherever nothing changed.
    kk = max(9, round(WORK * 0.03)) | 1
    olds = cv2.morphologyEx(p1.astype(np.uint8), cv2.MORPH_CLOSE,
                            cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (kk, kk)))
    n_old, old_labels = cv2.connectedComponents(olds, connectivity=8)
    gone = np.zeros(p1.shape, bool)
    for lab in range(1, n_old):
        blob = old_labels == lab
        if blob.sum() >= MIN_PERSON_AREA * total and (p2[blob].mean() < ABSENT or changed[blob].mean() > CHANGED):
            gone |= blob
    info["gone_people"] = int(gone.any())
    person = whole & ~((p1 & ~gone) & ~changed)
    if layer == "auto":
        layer = decide_layer(person, gone, p2, info)
    # Behind someone who left: with the matting model the newcomer keeps their whole outline and
    # is covered by that person's own matte from shot 1, so the line between them (a shirt and the
    # fingers over it) follows the real edge; without it, the overlap is cut at working size.
    occlude = layer == "behind" and gone.any() and matte is not None and refine
    if layer == "behind" and gone.any() and not occlude:
        person = person & ~hidden_behind(person, gone)
    # Edges the segmenter missed (loose hair, a bag strap) when they changed right next to it.
    # Not where someone of shot 1 left: there everything "changed", the wall round a hand too.
    near = cv2.dilate(person.astype(np.uint8), np.ones((7, 7), np.uint8)) > 0
    person = (person | (near & changed & ~gone)).astype(np.uint8)
    person = cv2.morphologyEx(person, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
    # (AddMeMerger.kt keeps the same steps; the segmenter there is ML Kit's selfie model.)
    area = float(person.sum()) / total
    info["person_area"] = area
    if area > MAX_PERSON_AREA:
        return AddMeResult(False, REASON_TOO_LARGE, info=info)

    h, w = shot_1.shape[:2]
    if refine:
        soft = refine_alpha(moved, person, valid, segment, p1, matte,
                            occluder=(shot_1, gone) if occlude else None)
        soft = cv2.GaussianBlur(soft, (0, 0), 0.8)
    else:
        soft = cv2.dilate(person, np.ones((3, 3), np.uint8)).astype(np.float32)
        soft = cv2.resize(soft, (w, h), interpolation=cv2.INTER_LINEAR)
        soft = np.clip(cv2.GaussianBlur(soft, (0, 0), max(1.5, 0.003 * max(h, w))), 0, 1)
    lit = harmonize(shot_1, moved, soft) if relight else moved.astype(np.float32)
    out = shot_1.astype(np.float32) * (1 - soft[..., None]) + lit * soft[..., None]
    return AddMeResult(True, None, np.clip(out, 0, 255).astype(np.uint8), soft, info)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--set", type=Path, required=True)
    ap.add_argument("--save", action="store_true", help="write <name>_people.jpg next to each pair")
    ap.add_argument("--layer", choices=["auto", "behind", "front"], default="auto")
    ap.add_argument("--no-matting", action="store_true", help="the coarse edge only")
    ap.add_argument("--plain", action="store_true", help="the first outline, no edge refinement")
    args = ap.parse_args()
    manifest = json.loads((args.set / "manifest.json").read_text(encoding="utf-8"))
    segment = Segmenter()
    matte = None if args.no_matting else Matter()
    by: dict[str, list] = {}
    for name, kind in manifest.items():
        s1 = cv2.imread(str(args.set / f"{name}_1.jpg"))
        s2 = cv2.imread(str(args.set / f"{name}_2.jpg"))
        r = add_me_people(s1, s2, segment, refine=not args.plain, layer=args.layer, matte=matte)
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
