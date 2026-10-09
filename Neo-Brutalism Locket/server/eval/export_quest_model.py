"""Export the daily-quest photo check for the phone.

Writes, into --out:
  quest_image_encoder.onnx        float32 image -> L2-normalised embedding (MobileCLIP2-S0)
  quest_image_encoder_fp16.onnx   the same with float16 weights (this is what the app ships)
  quest_labels.json          every label the app can score, in order, plus per-quest label lists
  quest_labels.bin           float32 text embeddings, one row per label in quest_labels.json

The app only runs the image encoder; the rules (positives vs distractors, MATCH_SCORE) are the
same as locket_server.verify, ported to Dart. Re-run this after changing quest_catalog.dart.

Usage (from server/):
    .venv/Scripts/python.exe -m eval.export_quest_model --out ../assets/quest_model
(onnx and onnxconverter-common are not in requirements.txt: pip install onnx==1.17.0
onnxconverter-common==1.14.0 --target <dir> and put it on PYTHONPATH.)
"""
from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path

import numpy as np
import open_clip
import torch

from eval.quest_catalog import read_quests
from locket_server.verify import MATCH_SCORE, TEMPLATES, build_labels

MODEL = "MobileCLIP2-S0"
PRETRAINED = "dfndr2b"
SIZE = 256


class ImageEncoder(torch.nn.Module):
    def __init__(self, visual):
        super().__init__()
        self.visual = visual

    def forward(self, image):
        feat = self.visual(image)
        return feat / feat.norm(dim=-1, keepdim=True)


def reparameterised(visual):
    from timm.utils import reparameterize_model

    return reparameterize_model(copy.deepcopy(visual))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--keep-float32", action="store_true",
                    help="also keep the 45 MB float32 model in --out (for eval.onnx_check); "
                         "never leave it in the app's assets")
    args = ap.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)

    model, _, _ = open_clip.create_model_and_transforms(MODEL, pretrained=PRETRAINED)
    model.eval()
    tokenizer = open_clip.get_tokenizer(MODEL)

    fast = ImageEncoder(reparameterised(model.visual)).eval()
    probe = torch.rand(4, 3, SIZE, SIZE)
    with torch.no_grad():
        ref = model.encode_image(probe)
        ref = ref / ref.norm(dim=-1, keepdim=True)
        got = fast(probe)
    cosine = torch.nn.functional.cosine_similarity(ref, got).min().item()
    print(f"reparameterised vs original embedding: min cosine {cosine:.6f}")
    assert cosine > 0.999, "reparameterisation changed the embedding"

    onnx_path = args.out / "quest_image_encoder.onnx"
    torch.onnx.export(
        fast, torch.rand(1, 3, SIZE, SIZE), str(onnx_path), opset_version=17,
        input_names=["image"], output_names=["embedding"], dynamo=False)
    import onnx
    from onnxconverter_common import float16

    # float16 weights: half the size, identical decisions (eval.onnx_check); int8 breaks the model.
    half = onnx_path.with_name("quest_image_encoder_fp16.onnx")
    onnx.save(float16.convert_float_to_float16(onnx.load(onnx_path), keep_io_types=True), half)
    print(f"wrote {half} ({half.stat().st_size / 1e6:.1f} MB)")
    if not args.keep_float32:
        onnx_path.unlink()

    quests = read_quests()
    order: list[str] = []
    index: dict[str, int] = {}
    per_quest = {}
    for quest_id, (positives, negatives) in quests.items():
        labels = build_labels(positives, negatives)
        for label in labels:
            if label not in index:
                index[label] = len(order)
                order.append(label)
        per_quest[quest_id] = {"positives": len(positives), "labels": [index[l] for l in labels]}

    with torch.no_grad():
        prompts = [t.format(label) for label in order for t in TEMPLATES]
        feats = model.encode_text(tokenizer(prompts))
        feats = feats / feats.norm(dim=-1, keepdim=True)
        feats = feats.reshape(len(order), len(TEMPLATES), -1).mean(dim=1)
        feats = feats / feats.norm(dim=-1, keepdim=True)
    (args.out / "quest_labels.bin").write_bytes(feats.numpy().astype("<f4").tobytes())
    (args.out / "quest_labels.json").write_text(json.dumps({
        "model": f"{MODEL}/{PRETRAINED}",
        "inputSize": SIZE,
        "dim": int(feats.shape[1]),
        "logitScale": float(model.logit_scale.exp()),
        "matchScore": MATCH_SCORE,
        "labels": order,
        "quests": per_quest,
    }, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"{len(quests)} quests, {len(order)} labels x {feats.shape[1]} dims")


if __name__ == "__main__":
    main()
