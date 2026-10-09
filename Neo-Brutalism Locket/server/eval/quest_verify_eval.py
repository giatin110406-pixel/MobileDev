"""Compare CLIP-family models on the daily-quest photo check.

The quest rules (positives, negatives, distractors, MATCH_SCORE) are the server's own
(`locket_server.verify`), so a model that scores well here behaves the same in the app once the
rules are ported. Test photos are public datasets, not phone photos:

* COCO val 2017 (detection-datasets/coco) for the quests whose subject is a COCO class; a photo
  counts as "showing" the subject when one box covers at least MIN_AREA of the picture.
* Oxford Flowers 102 (nelorth/oxford-flowers) for the sunflower quest.

Usage (from server/):
    .venv/Scripts/python.exe -m eval.quest_verify_eval --data D:/clip_eval_tmp \
        --models ViT-B-32:laion2b_s34b_b79k MobileCLIP2-S0:dfndr2b

pyarrow is not in requirements.txt; put it on PYTHONPATH (e.g. `pip install --target`).
"""
from __future__ import annotations

import argparse
import io
import random
import time
from pathlib import Path

import numpy as np
import pyarrow.parquet as pq
import torch
from PIL import Image

from eval.quest_catalog import read_quests
from locket_server.verify import MATCH_SCORE, TEMPLATES, build_labels, decide

# quest id -> COCO class index (0-based, the 80-class order)
COCO_QUESTS = {
    "vg_bed": 59, "vg_chair": 56, "vg_boat": 8, "px_dog": 16, "px_pizza": 53,
    "px_apple": 47, "px_controller": 65, "px_motorbike": 3, "px_clock": 74,
}
# The dataset ships no class names; 52 was found by looking at the photos (all sunflowers).
SUNFLOWER_LABEL = 52
MIN_AREA = 0.05         # fraction of the picture one box must cover
PER_QUEST_POSITIVES = 40
PER_QUEST_NEGATIVES = 60


def load_coco(path: Path, seed: int, min_area: float = MIN_AREA):
    """-> [(bytes, categories covering >= min_area, all categories)], shuffled"""
    rng = random.Random(seed)
    rows = []
    pf = pq.ParquetFile(path)
    for g in range(pf.num_row_groups):
        t = pf.read_row_group(g, columns=["image", "width", "height", "objects"]).to_pylist()
        for r in t:
            big = {c for c, a in zip(r["objects"]["category"], r["objects"]["area"])
                   if a / (r["width"] * r["height"]) >= min_area}
            present = set(r["objects"]["category"])
            rows.append((r["image"]["bytes"], big, present))
    rng.shuffle(rows)
    return rows


def build_cases(coco_rows, flowers_path: Path, seed: int):
    """-> (images: list[bytes], cases: {quest_id: [(image_index, is_positive)]})"""
    rng = random.Random(seed)
    images: list[bytes] = [r[0] for r in coco_rows]
    cases: dict[str, list[tuple[int, bool]]] = {}
    for quest, cls in COCO_QUESTS.items():
        pos = [i for i, r in enumerate(coco_rows) if cls in r[1]][:PER_QUEST_POSITIVES]
        neg = [i for i, r in enumerate(coco_rows) if cls not in r[2]][:PER_QUEST_NEGATIVES]
        cases[quest] = [(i, True) for i in pos] + [(i, False) for i in neg]
    # sunflower: Oxford Flowers label by name, negatives = other flowers + COCO photos
    sun = SUNFLOWER_LABEL
    flowers = pq.read_table(flowers_path).to_pylist()
    rng.shuffle(flowers)
    base = len(images)
    pos, neg = [], []
    for r in flowers:
        if r["label"] == sun and len(pos) < PER_QUEST_POSITIVES:
            pos.append(len(images)); images.append(r["image"]["bytes"])
        elif r["label"] != sun and len(neg) < 30:
            neg.append(len(images)); images.append(r["image"]["bytes"])
    cases["vg_sunflower"] = ([(i, True) for i in pos] + [(i, False) for i in neg]
                             + [(i, False) for i in range(PER_QUEST_NEGATIVES // 2)])
    return images, cases


def evaluate(model_spec: str, images, cases, quests, device: str):
    import open_clip

    name, pretrained = model_spec.split(":")
    model, _, preprocess = open_clip.create_model_and_transforms(
        name, pretrained=pretrained, device=device)
    model.eval()
    tokenizer = open_clip.get_tokenizer(name)

    needed = sorted({i for c in cases.values() for i, _ in c})
    feats = {}
    t0 = time.time()
    with torch.no_grad():
        for start in range(0, len(needed), 32):
            chunk = needed[start:start + 32]
            batch = torch.stack([preprocess(Image.open(io.BytesIO(images[i])).convert("RGB"))
                                 for i in chunk]).to(device)
            f = model.encode_image(batch)
            f = f / f.norm(dim=-1, keepdim=True)
            for i, v in zip(chunk, f):
                feats[i] = v
    encode_s = (time.time() - t0) / len(needed)

    text_cache: dict[str, torch.Tensor] = {}

    def text_feats(labels):
        missing = [l for l in labels if l not in text_cache]
        if missing:
            prompts = [t.format(l) for l in missing for t in TEMPLATES]
            f = model.encode_text(tokenizer(prompts).to(device))
            f = f / f.norm(dim=-1, keepdim=True)
            f = f.reshape(len(missing), len(TEMPLATES), -1).mean(dim=1)
            f = f / f.norm(dim=-1, keepdim=True)
            for l, v in zip(missing, f):
                text_cache[l] = v
        return torch.stack([text_cache[l] for l in labels])

    per_quest = {}
    with torch.no_grad():
        for quest, items in cases.items():
            positives, negatives = quests[quest]
            labels = build_labels(positives, negatives)
            tf = text_feats(labels)
            tp = fn = fp = tn = 0
            for i, is_pos in items:
                logits = model.logit_scale.exp() * feats[i] @ tf.T
                probs = logits.softmax(dim=-1).tolist()
                match = decide(probs, labels, len(positives)).match
                if is_pos:
                    tp += match; fn += not match
                else:
                    fp += match; tn += not match
            per_quest[quest] = dict(tp=tp, fn=fn, fp=fp, tn=tn)
    params = sum(p.numel() for p in model.visual.parameters()) / 1e6
    return per_quest, encode_s, params, (model, preprocess)


def cpu_latency(model, preprocess, image_bytes: bytes, threads: int, runs: int = 15) -> float:
    torch.set_num_threads(threads)
    model = model.to("cpu").eval()
    x = preprocess(Image.open(io.BytesIO(image_bytes)).convert("RGB")).unsqueeze(0)
    with torch.no_grad():
        model.encode_image(x)
        t0 = time.time()
        for _ in range(runs):
            model.encode_image(x)
    return (time.time() - t0) / runs * 1000


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", type=Path, required=True)
    ap.add_argument("--models", nargs="+", required=True)
    ap.add_argument("--seed", type=int, default=7)
    ap.add_argument("--device", default="cuda" if torch.cuda.is_available() else "cpu")
    args = ap.parse_args()

    quests = read_quests()
    coco = next((args.data / "coco/data").glob("val-*.parquet"))
    flowers = next((args.data / "flowers/data").glob("test-*.parquet"))
    rows = load_coco(coco, args.seed)
    images, cases = build_cases(rows, flowers, args.seed)
    print(f"{len(images)} photos, {len(cases)} quests, MATCH_SCORE={MATCH_SCORE}")

    for spec in args.models:
        per_quest, enc_s, params, (model, pre) = evaluate(spec, images, cases, quests, args.device)
        print(f"\n== {spec}  (image tower {params:.1f}M params, {enc_s * 1000:.0f} ms/photo on {args.device})")
        print(f"{'quest':<15}{'found':>8}{'missed':>8}{'false+':>8}{'ok-neg':>8}{'acc':>7}")
        T = dict(tp=0, fn=0, fp=0, tn=0)
        for quest, r in per_quest.items():
            n = sum(r.values())
            print(f"{quest:<15}{r['tp']:>8}{r['fn']:>8}{r['fp']:>8}{r['tn']:>8}"
                  f"{(r['tp'] + r['tn']) / n:>7.0%}")
            for k in T:
                T[k] += r[k]
        n = sum(T.values())
        print(f"{'ALL':<15}{T['tp']:>8}{T['fn']:>8}{T['fp']:>8}{T['tn']:>8}"
              f"{(T['tp'] + T['tn']) / n:>7.0%}   "
              f"recall {T['tp'] / max(1, T['tp'] + T['fn']):.0%}, "
              f"false-accept {T['fp'] / max(1, T['fp'] + T['tn']):.0%}")
        sample = images[0]
        for threads in (1, 4):
            print(f"  CPU {threads} thread(s): {cpu_latency(model, pre, sample, threads):.0f} ms/photo")
        del model
        torch.cuda.empty_cache()


if __name__ == "__main__":
    main()
