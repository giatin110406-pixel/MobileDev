"""Reference BlazeFace (short-range) decoder + fixtures for the Dart port.

Runs the same .tflite the phone uses through LiteRT, decodes with the MediaPipe rules, checks the
boxes against MediaPipe's own detector, and writes test/fixtures/blazeface_*.json (raw box
regressors + scores + expected boxes) so the Dart decoder can be tested without native TFLite.

  python -m eval.blazeface_fixture
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from ai_edge_litert.interpreter import Interpreter  # noqa: E402
from PIL import Image  # noqa: E402

from locket_server import preprocess  # noqa: E402

SIZE = 128


def make_anchors() -> np.ndarray:
    """896 SSD anchors (cx, cy) in 0..1. Strides 8,16,16,16 -> maps 16x16 (x2) + 8x8 (x6)."""
    anchors = []
    for stride, per_cell in ((8, 2), (16, 6)):
        cells = SIZE // stride
        for y in range(cells):
            for x in range(cells):
                for _ in range(per_cell):
                    anchors.append(((x + 0.5) / cells, (y + 0.5) / cells))
    assert len(anchors) == 896
    return np.array(anchors, np.float32)


def letterbox(image: Image.Image):
    side = max(image.size)
    scale = SIZE / side
    w, h = round(image.width * scale), round(image.height * scale)
    canvas = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
    pad_x, pad_y = (SIZE - w) // 2, (SIZE - h) // 2
    canvas.paste(image.resize((w, h), Image.BILINEAR), (pad_x, pad_y))
    return canvas, scale, pad_x, pad_y


def decode(regressors, scores, anchors, threshold=0.5):
    """regressors (896,16), scores (896,) logits -> boxes (xmin,ymin,xmax,ymax,score) in 0..1."""
    prob = 1 / (1 + np.exp(-np.clip(scores, -100, 100)))
    boxes = []
    for i in np.where(prob >= threshold)[0]:
        cx = regressors[i, 0] / SIZE + anchors[i, 0]
        cy = regressors[i, 1] / SIZE + anchors[i, 1]
        w, h = regressors[i, 2] / SIZE, regressors[i, 3] / SIZE
        boxes.append((cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2, float(prob[i])))
    return nms(boxes, 0.3)


def iou(a, b):
    ix = max(0.0, min(a[2], b[2]) - max(a[0], b[0]))
    iy = max(0.0, min(a[3], b[3]) - max(a[1], b[1]))
    inter = ix * iy
    union = (a[2] - a[0]) * (a[3] - a[1]) + (b[2] - b[0]) * (b[3] - b[1]) - inter
    return inter / union if union > 0 else 0.0


def nms(boxes, threshold):
    kept = []
    for box in sorted(boxes, key=lambda b: -b[4]):
        if all(iou(box, k) <= threshold for k in kept):
            kept.append(box)
    return kept


def main() -> None:
    interpreter = Interpreter(model_path=str(ROOT / "weights" / "blaze_face_short_range.tflite"))
    interpreter.allocate_tensors()
    inp = interpreter.get_input_details()[0]["index"]
    outs = {d["name"]: d["index"] for d in interpreter.get_output_details()}
    anchors = make_anchors()
    out_dir = ROOT.parent / "test" / "fixtures"
    out_dir.mkdir(parents=True, exist_ok=True)

    for photo in sorted((ROOT / "eval" / "photos").glob("*.jpg")):
        image = preprocess.load_oriented(photo.read_bytes())
        canvas, scale, pad_x, pad_y = letterbox(image)
        tensor = (np.asarray(canvas, np.float32) - 127.5) / 127.5
        interpreter.set_tensor(inp, tensor[None])
        interpreter.invoke()
        regressors = interpreter.get_tensor(outs["regressors"])[0]
        scores = interpreter.get_tensor(outs["classificators"])[0, :, 0]
        found = decode(regressors, scores, anchors)

        # map to source pixels, compare with MediaPipe on the same image
        mine = [((b[0] * SIZE - pad_x) / scale, (b[1] * SIZE - pad_y) / scale,
                 (b[2] * SIZE - pad_x) / scale, (b[3] * SIZE - pad_y) / scale, b[4]) for b in found]
        reference = [(f.x, f.y, f.x + f.w, f.y + f.h, f.score)
                     for f in preprocess.detect_faces(image, 0.5)]
        best = [max((iou(m, r) for r in reference), default=0.0) for m in mine]
        print(photo.name, "decoded", len(mine), "mediapipe", len(reference),
              "IoU vs mediapipe", [round(x, 2) for x in best])

        # fixture: first 4 regressors per anchor + score, as flat lists (keeps files small)
        payload = {
            "image": photo.name, "size": list(image.size),
            "regressors": np.round(regressors[:, :4], 4).reshape(-1).tolist(),
            "scores": np.round(scores, 4).tolist(),
            "expected_normalized": [[round(float(v), 4) for v in b] for b in found],
            "expected_pixels": [[round(float(v), 1) for v in b] for b in mine],
            "mediapipe_pixels": [[round(float(v), 1) for v in b] for b in reference],
        }
        (out_dir / f"blazeface_{photo.stem}.json").write_text(json.dumps(payload), encoding="utf-8")


if __name__ == "__main__":
    main()
