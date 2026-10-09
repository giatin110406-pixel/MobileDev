"""Check the exported phone model (eval.export_quest_model) the way the app will run it.

Runs the ONNX image encoder with onnxruntime on the same photos as eval.quest_verify_eval and
compares: float32 vs smaller variants (float16, int8), and the resize the app might use instead of
PIL's antialiased bilinear. Prints accuracy and how many decisions differ from the float32 + PIL
reference.

Usage (from server/), with pyarrow + onnx + onnxruntime + onnxconverter-common on PYTHONPATH:
    .venv/Scripts/python.exe -m eval.onnx_check --data D:/clip_eval_tmp --model D:/clip_eval_tmp/model
"""
from __future__ import annotations

import argparse
import io
import json
from pathlib import Path

import numpy as np
import onnxruntime as ort
from PIL import Image

from eval.quest_catalog import read_quests
from eval.quest_verify_eval import build_cases, load_coco
from locket_server.verify import decide

RESIZE = {
    "antialias": Image.BILINEAR,   # what torchvision/open_clip does (reference)
    "box": Image.BOX,              # close to Dart's `image` package averaging
    "nearest": Image.NEAREST,      # worst case: no smoothing at all
}


def preprocess(data: bytes, size: int, resample) -> np.ndarray:
    img = Image.open(io.BytesIO(data)).convert("RGB")
    w, h = img.size
    scale = size / min(w, h)
    img = img.resize((max(size, round(w * scale)), max(size, round(h * scale))), resample)
    w, h = img.size
    left, top = (w - size) // 2, (h - size) // 2
    img = img.crop((left, top, left + size, top + size))
    return (np.asarray(img, dtype=np.float32) / 255.0).transpose(2, 0, 1)[None]


def make_variants(model_dir: Path, images, cases, size: int, int8: bool = True) -> dict[str, Path]:
    fp32 = model_dir / "quest_image_encoder.onnx"
    variants = {"fp32": fp32}
    try:
        import onnx
        from onnxconverter_common import float16

        fp16 = model_dir / "quest_image_encoder_fp16.onnx"
        onnx.save(float16.convert_float_to_float16(onnx.load(fp32), keep_io_types=True), fp16)
        variants["fp16"] = fp16
    except Exception as error:  # noqa: BLE001
        print("fp16 skipped:", error)
    if not int8:
        return variants
    try:
        from onnxruntime.quantization import (CalibrationDataReader, QuantFormat, QuantType,
                                              quantize_static)

        calibration = sorted({i for c in cases.values() for i, _ in c})[::25][:100]

        class Reader(CalibrationDataReader):
            def __init__(self):
                self.items = iter(calibration)

            def get_next(self):
                i = next(self.items, None)
                if i is None:
                    return None
                return {"image": preprocess(images[i], size, Image.BILINEAR)}

        int8 = model_dir / "quest_image_encoder_int8.onnx"
        quantize_static(str(fp32), str(int8), Reader(), quant_format=QuantFormat.QDQ,
                        activation_type=QuantType.QUInt8, weight_type=QuantType.QInt8,
                        per_channel=True)
        variants["int8"] = int8
    except Exception as error:  # noqa: BLE001
        print("int8 skipped:", error)
    return variants


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", type=Path, required=True)
    ap.add_argument("--model", type=Path, required=True)
    ap.add_argument("--seed", type=int, default=7)
    ap.add_argument("--only", nargs="*", help="variant:resize pairs to run (default: all)")
    ap.add_argument("--skip-int8", action="store_true", help="int8 is known to break the model")
    args = ap.parse_args()

    meta = json.loads((args.model / "quest_labels.json").read_text(encoding="utf-8"))
    dim, size = meta["dim"], meta["inputSize"]
    text = np.fromfile(args.model / "quest_labels.bin", dtype="<f4").reshape(-1, dim)
    labels = meta["labels"]
    quests = read_quests()

    rows = load_coco(next((args.data / "coco/data").glob("val-*.parquet")), args.seed)
    images, cases = build_cases(rows, next((args.data / "flowers/data").glob("test-*.parquet")),
                                args.seed)
    needed = sorted({i for c in cases.values() for i, _ in c})
    variants = make_variants(args.model, images, cases, size, not args.skip_int8)

    def decisions(session, resample):
        feats = {}
        for i in needed:
            feats[i] = session.run(None, {"image": preprocess(images[i], size, resample)})[0][0]
        out = {}
        for quest, items in cases.items():
            idx = meta["quests"][quest]["label_ids"] if "label_ids" in meta["quests"][quest] \
                else meta["quests"][quest]["labels"]
            names = [labels[k] for k in idx]
            tf = text[idx]
            n_pos = meta["quests"][quest]["positives"]
            for i, _ in items:
                logits = meta["logitScale"] * (tf @ feats[i])
                e = np.exp(logits - logits.max())
                out[(quest, i)] = decide((e / e.sum()).tolist(), names, n_pos).match
        return out

    reference = None
    print(f"{'variant':<7}{'resize':<11}{'size MB':>8}{'acc':>6}{'recall':>8}{'false+':>8}"
          f"{'flips vs ref':>14}{'ms/photo':>10}")
    for name, path in variants.items():
        session = ort.InferenceSession(str(path), providers=["CPUExecutionProvider"])
        for rname, resample in RESIZE.items():
            if args.only and f"{name}:{rname}" not in args.only:
                continue
            import time
            t0 = time.time()
            got = decisions(session, resample)
            ms = (time.time() - t0) / len(needed) * 1000
            if reference is None:
                reference = got
            tp = fn = fp = tn = 0
            for quest, items in cases.items():
                for i, positive in items:
                    match = got[(quest, i)]
                    tp += positive and match
                    fn += positive and not match
                    fp += (not positive) and match
                    tn += (not positive) and not match
            flips = sum(got[k] != reference[k] for k in got)
            print(f"{name:<7}{rname:<11}{path.stat().st_size / 1e6:>8.1f}"
                  f"{(tp + tn) / (tp + fn + fp + tn):>6.1%}{tp / max(1, tp + fn):>8.0%}"
                  f"{fp / max(1, fp + tn):>8.1%}{flips:>14}{ms:>10.0f}")


if __name__ == "__main__":
    main()
