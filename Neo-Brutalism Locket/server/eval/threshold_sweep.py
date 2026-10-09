"""How the quest check's rules trade missed good photos against accepted wrong ones.

Uses the phone model (float16 ONNX from eval.export_quest_model) on the eval photos of
eval.quest_verify_eval and re-scores them under different rules: the MATCH_SCORE threshold and
which of the quest's competing labels are kept. Embeddings are cached, so a sweep takes seconds.

Usage (from server/), pyarrow + onnxruntime on PYTHONPATH:
    .venv/Scripts/python.exe -m eval.threshold_sweep --data D:/clip_eval_tmp --model ../assets/quest_model
"""
from __future__ import annotations

import argparse
import collections
import json
from pathlib import Path

import numpy as np
import onnxruntime as ort

from eval.onnx_check import preprocess
from eval.quest_verify_eval import build_cases, load_coco
from PIL import Image


def embeddings(images, needed, model_dir: Path, cache: Path) -> dict[int, np.ndarray]:
    if cache.exists():
        data = np.load(cache)
        if list(data["ids"]) == needed:
            return dict(zip(needed, data["vectors"]))
    session = ort.InferenceSession(str(model_dir / "quest_image_encoder_fp16.onnx"),
                                   providers=["CPUExecutionProvider"])
    vectors = [session.run(None, {"image": preprocess(images[i], 256, Image.BILINEAR)})[0][0]
               for i in needed]
    np.savez(cache, ids=np.array(needed), vectors=np.array(vectors))
    return dict(zip(needed, vectors))


def verdict(probs: np.ndarray, positives: int, threshold: float) -> bool:
    return int(probs.argmax()) < positives or float(probs[:positives].sum()) >= threshold


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", type=Path, required=True)
    ap.add_argument("--model", type=Path, required=True)
    ap.add_argument("--min-area", type=float, default=0.05,
                    help="a COCO photo 'shows' the subject when one box covers this share")
    ap.add_argument("--cache", type=Path, default=None)
    args = ap.parse_args()

    meta = json.loads((args.model / "quest_labels.json").read_text(encoding="utf-8"))
    text = np.fromfile(args.model / "quest_labels.bin", dtype="<f4").reshape(-1, meta["dim"])
    rows = load_coco(next((args.data / "coco/data").glob("val-*.parquet")), 7, args.min_area)
    images, cases = build_cases(rows, next((args.data / "flowers/data").glob("test-*.parquet")), 7)
    needed = sorted({i for c in cases.values() for i, _ in c})
    cache = args.cache or args.data / "embeddings.npz"
    feats = embeddings(images, needed, args.model, cache)

    probs, misses = {}, collections.defaultdict(collections.Counter)
    for quest, items in cases.items():
        ids = meta["quests"][quest]["labels"]
        for i, positive in items:
            logits = meta["logitScale"] * (text[ids] @ feats[i])
            e = np.exp(logits - logits.max())
            p = e / e.sum()
            probs[(quest, i)] = p
            if positive and not verdict(p, meta["quests"][quest]["positives"], 0.5):
                misses[quest][meta["labels"][ids[int(p.argmax())]]] += 1

    print(f"min area {args.min_area}: what the model answers instead on missed good photos")
    for quest, counter in misses.items():
        print(f"  {quest:<14}", dict(counter.most_common(4)))

    print(f"\n{'threshold':>9}{'recall':>8}{'false+':>8}   per quest recall")
    for threshold in (0.5, 0.4, 0.3, 0.25, 0.2, 0.15, 0.1):
        tp = fn = fp = tn = 0
        per = {}
        for quest, items in cases.items():
            n_pos = meta["quests"][quest]["positives"]
            q_tp = q_fn = 0
            for i, positive in items:
                got = verdict(probs[(quest, i)], n_pos, threshold)
                if positive:
                    tp += got; fn += not got; q_tp += got; q_fn += not got
                else:
                    fp += got; tn += not got
            per[quest] = q_tp / max(1, q_tp + q_fn)
        print(f"{threshold:>9}{tp / (tp + fn):>8.0%}{fp / (fp + tn):>8.1%}   "
              + " ".join(f"{k.split('_')[1][:5]}={v:.0%}" for k, v in per.items()))


if __name__ == "__main__":
    main()
