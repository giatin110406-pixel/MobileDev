"""Export the scene guess for the phone, and measure it on the tagged eval photos.

The phone already runs the quest's image encoder (export_quest_model.py); this only adds the
text side for five scene types, in its own two files so the quest files are untouched:
  scene_labels.json   descriptions in order, which scene each belongs to, logit scale
  scene_labels.bin    float32 text embeddings, one row per description

Rule (ported to Dart in lib/features/image_engine/scene_guess.dart): softmax over all
descriptions, add up the probability per scene, the largest wins.

Usage (from server/):
    .venv/Scripts/python.exe -m eval.export_scene_labels --out ../assets/quest_model
    .venv/Scripts/python.exe -m eval.export_scene_labels --eval eval/photos
--eval also prints the server's rule-based guess (face / brightness / sky) for comparison.
"""
from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path

import numpy as np
import open_clip
import torch
from PIL import Image, ImageOps

from locket_server.verify import TEMPLATES

MODEL = "MobileCLIP2-S0"
PRETRAINED = "dfndr2b"
SIZE = 256

# Order matters only for ties. `day` is the catch-all, so it lists the things phones shoot most.
SCENES: dict[str, tuple[str, ...]] = {
    "portrait": ("a selfie of a person", "a portrait of one person",
                 "a close-up of a person's face"),
    "group": ("a group of people", "friends posing together for a photo", "a couple of people"),
    "night": ("a street at night", "a city at night with lights", "a dark night scene",
              "a concert stage with lights"),
    "sky": ("the sky", "a sunset sky", "clouds in a blue sky",
            "a landscape under a big blue sky", "buildings against a blue sky"),
    "day": ("a landscape in daylight", "a street in the daytime", "a room indoors",
            "food on a table", "an object on a desk", "flowers and plants",
            "a cat", "a dog", "a pet animal", "a hand holding something", "shoes"),
}
# eval/photo_tags.json uses the server's names
TAG_TO_SCENE = {"portrait": "portrait", "group": "group", "night_scene": "night", "sky": "sky",
                "day_scene": "day"}


def text_vectors(model, tokenizer) -> tuple[list[str], list[str], torch.Tensor]:
    labels, scenes = [], []
    for scene, descriptions in SCENES.items():
        for d in descriptions:
            labels.append(d)
            scenes.append(scene)
    with torch.no_grad():
        prompts = [t.format(label) for label in labels for t in TEMPLATES]
        feats = model.encode_text(tokenizer(prompts))
        feats = feats / feats.norm(dim=-1, keepdim=True)
        feats = feats.reshape(len(labels), len(TEMPLATES), -1).mean(dim=1)
        feats = feats / feats.norm(dim=-1, keepdim=True)
    return labels, scenes, feats


def phone_input(path: Path) -> torch.Tensor:
    """Same as questPlanes in Dart: short side to SIZE, centre crop, 0..1, no mean/std."""
    image = ImageOps.exif_transpose(Image.open(path)).convert("RGB")
    scale = SIZE / min(image.size)
    w, h = max(SIZE, round(image.width * scale)), max(SIZE, round(image.height * scale))
    image = image.resize((w, h), Image.BOX)
    left, top = (w - SIZE) // 2, (h - SIZE) // 2
    image = image.crop((left, top, left + SIZE, top + SIZE))
    return torch.from_numpy(np.asarray(image, np.float32) / 255.0).permute(2, 0, 1)


def guess(embedding: torch.Tensor, feats: torch.Tensor, scenes: list[str], scale: float) -> str:
    probs = torch.softmax(embedding @ feats.T * scale, dim=-1)
    totals: dict[str, float] = {}
    for p, s in zip(probs.tolist(), scenes):
        totals[s] = totals.get(s, 0.0) + p
    return max(totals, key=totals.get)


def server_rule(path: Path) -> str:
    """What the server decides today without the phone's hint (pick_reference)."""
    from locket_server import config, preprocess

    cfg = config.load_yaml("van_gogh.yaml")
    source = preprocess.center_square(preprocess.load_oriented(path.read_bytes()), 640)
    if preprocess.detect_faces(source, cfg["face"]["min_confidence"]):
        return "portrait"   # the server has one set for every photo with a face
    if preprocess.mean_luma(source) < cfg["dark_luma_threshold"]:
        return "night"
    if preprocess.sky_fraction(source) >= cfg["sky_threshold"]:
        return "sky"
    return "day"


def evaluate(photos: Path, model, feats, scenes, scale: float, rules: bool) -> None:
    tags = json.loads((photos.parent / "photo_tags.json").read_text(encoding="utf-8"))
    rows = []
    with torch.no_grad():
        for name, tag in sorted(tags.items()):
            path = photos / f"{name}.jpg"
            if not path.exists():
                continue
            emb = model.encode_image(phone_input(path)[None])
            emb = emb / emb.norm(dim=-1, keepdim=True)
            truth = TAG_TO_SCENE[tag]
            rows.append((name, truth, guess(emb[0], feats, scenes, scale),
                         server_rule(path) if rules else None))
    names = list(SCENES)
    print(f"{len(rows)} photos")
    for title, col in (("phone (CLIP)", 2), ("server rules", 3)):
        if col == 3 and not rules:
            continue
        # the server has no group set: a group counts as right when it says portrait
        hits = sum(r[col] == r[1] or (col == 3 and r[1] == "group" and r[col] == "portrait")
                   for r in rows)
        print(f"\n{title}: {hits}/{len(rows)} = {hits / len(rows):.0%}")
        print("truth \\ guess " + " ".join(f"{n:>8}" for n in names))
        for truth in names:
            c = Counter(r[col] for r in rows if r[1] == truth)
            print(f"{truth:>13} " + " ".join(f"{c.get(n, 0):>8}" for n in names))
    wrong = [r for r in rows if r[2] != r[1]]
    if wrong:
        print("\nphone misses: " + ", ".join(f"{n} ({t} -> {g})" for n, t, g, _ in wrong))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", type=Path)
    ap.add_argument("--eval", type=Path, help="folder of photos named as in ../photo_tags.json")
    ap.add_argument("--no-rules", action="store_true", help="skip the server-rule comparison")
    args = ap.parse_args()
    if not args.out and not args.eval:
        ap.error("give --out and/or --eval")

    model, _, _ = open_clip.create_model_and_transforms(MODEL, pretrained=PRETRAINED)
    model.eval()
    tokenizer = open_clip.get_tokenizer(MODEL)
    scale = float(model.logit_scale.exp())
    labels, scenes, feats = text_vectors(model, tokenizer)

    if args.eval:
        evaluate(args.eval, model, feats, scenes, scale, not args.no_rules)
    if args.out:
        args.out.mkdir(parents=True, exist_ok=True)
        (args.out / "scene_labels.bin").write_bytes(feats.numpy().astype("<f4").tobytes())
        (args.out / "scene_labels.json").write_text(json.dumps({
            "model": f"{MODEL}/{PRETRAINED}",
            "inputSize": SIZE,
            "dim": int(feats.shape[1]),
            "logitScale": scale,
            "labels": labels,
            "scenes": scenes,
        }, ensure_ascii=False, indent=1), encoding="utf-8")
        print(f"wrote {len(labels)} descriptions x {feats.shape[1]} dims to {args.out}")


if __name__ == "__main__":
    main()
