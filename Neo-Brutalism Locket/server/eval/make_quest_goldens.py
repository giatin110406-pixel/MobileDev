"""Reference answers for the Dart tests of the on-device quest check.

Picks a few photos from the eval set, saves them as small JPEGs and records what the shipped ONNX
model (the one the app ships) says about them with the server's own rules. The Dart tests then
check their preprocessing and scoring against these numbers.

Usage (from server/), same environment as eval.onnx_check:
    .venv/Scripts/python.exe -m eval.make_quest_goldens --data D:/clip_eval_tmp \
        --model ../assets/quest_model --out ../test/fixtures/quest
"""
from __future__ import annotations

import argparse
import io
import json
from pathlib import Path

import numpy as np
import onnxruntime as ort
from PIL import Image

from eval.onnx_check import preprocess
from eval.quest_catalog import read_quests
from eval.quest_verify_eval import COCO_QUESTS, build_cases, load_coco
from locket_server.verify import decide

# (quest, wants a photo that shows it)
PICKS = [("px_dog", True), ("px_pizza", True), ("vg_sunflower", True),
         ("px_motorbike", True), ("px_dog", False), ("vg_boat", False)]


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", type=Path, required=True)
    ap.add_argument("--model", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)

    meta = json.loads((args.model / "quest_labels.json").read_text(encoding="utf-8"))
    size, dim = meta["inputSize"], meta["dim"]
    text = np.fromfile(args.model / "quest_labels.bin", dtype="<f4").reshape(-1, dim)
    session = ort.InferenceSession(str(args.model / "quest_image_encoder_fp16.onnx"),
                                   providers=["CPUExecutionProvider"])
    quests = read_quests()
    rows = load_coco(next((args.data / "coco/data").glob("val-*.parquet")), 7)
    images, cases = build_cases(rows, next((args.data / "flowers/data").glob("test-*.parquet")), 7)

    used: set[int] = set()
    goldens = []
    for n, (quest, positive) in enumerate(PICKS):
        index = next(i for i, is_pos in cases[quest] if is_pos == positive and i not in used)
        used.add(index)
        # a phone-like square JPEG, like camera_experience's cropToSquareJpeg
        image = Image.open(io.BytesIO(images[index])).convert("RGB")
        side = min(image.size)
        left, top = (image.width - side) // 2, (image.height - side) // 2
        image = image.crop((left, top, left + side, top + side)).resize((384, 384), Image.BILINEAR)
        name = f"photo_{n}_{quest}_{'yes' if positive else 'no'}.jpg"
        buffer = io.BytesIO()
        image.save(buffer, "JPEG", quality=90)
        (args.out / name).write_bytes(buffer.getvalue())

        planes = preprocess(buffer.getvalue(), size, Image.BILINEAR)
        embedding = session.run(None, {"image": planes})[0][0]
        ids = meta["quests"][quest]["labels"]
        names = [meta["labels"][k] for k in ids]
        logits = meta["logitScale"] * (text[ids] @ embedding)
        e = np.exp(logits - logits.max())
        verdict = decide((e / e.sum()).tolist(), names, meta["quests"][quest]["positives"])
        grid = planes[0][:, 16::32, 16::32]  # 8 x 8 samples per channel
        goldens.append({
            "file": name, "quest": quest, "shouldShow": positive,
            "match": verdict.match, "score": verdict.score, "top": verdict.top,
            "embedding": [round(float(v), 6) for v in embedding],
            "channelMeans": [round(float(v), 5) for v in planes[0].mean(axis=(1, 2))],
            "grid": [round(float(v), 4) for v in grid.reshape(-1)],
        })
        print(name, "->", verdict)
    (args.out / "goldens.json").write_text(json.dumps(goldens), encoding="utf-8")


if __name__ == "__main__":
    main()
