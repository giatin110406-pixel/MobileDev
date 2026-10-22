"""Measure free-text photo search for the phone (archive-ai-search-plan.md, A2-A4).

Data: Flickr30k 1k test split (nlphuji/flickr_1k_test_image_text_retrieval): 1,000 photos with
5 English captions each, the usual text -> image retrieval benchmark.

Reports:
  A2  int8 vs PyTorch: cosine of the query vectors, and whether the top 10 photos are the same
  A3  recall@1/5/10 (the photo a caption was written for is among the first K), PyTorch vs int8
  A4  threshold table: for a cosine cut-off, how often the right photo passes and how many
      photos pass per query (what the phone would show)

Images go through the phone's preprocessing (eval.export_scene_labels.phone_input); their
vectors are cached in --data/image_embeddings.npy.

Usage (from server/, onnxruntime + pyarrow on PYTHONPATH):
    $env:PYTHONPATH = ".eval_tools"
    .venv/Scripts/python.exe -m eval.search_eval --data D:/clip_eval_tmp/flickr1k \
        --model D:/clip_eval_tmp/text_model
"""
from __future__ import annotations

import argparse
import ast
import csv
import time
from pathlib import Path

import numpy as np
import open_clip
import torch

from eval.export_scene_labels import phone_input

MODEL = "MobileCLIP2-S0"
PRETRAINED = "dfndr2b"


def load_flickr(data: Path) -> tuple[list[Path], list[str], np.ndarray]:
    """-> image paths, captions, image index of each caption"""
    images, captions, owner = [], [], []
    folder = next(p for p in (data / "images").rglob("*") if p.is_dir() and "MACOSX" not in str(p)
                  and any(p.glob("*.jpg")))
    with open(data / "test_1k_flickr.csv", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            index = len(images)
            images.append(folder / row["filename"])
            for raw in ast.literal_eval(row["raw"]):
                captions.append(raw)
                owner.append(index)
    return images, captions, np.array(owner)


def image_vectors(model, paths: list[Path], cache: Path) -> np.ndarray:
    if cache.exists():
        return np.load(cache)
    out = []
    with torch.no_grad():
        for i in range(0, len(paths), 32):
            batch = torch.stack([phone_input(p) for p in paths[i:i + 32]])
            feat = model.encode_image(batch)
            out.append((feat / feat.norm(dim=-1, keepdim=True)).numpy())
    vectors = np.concatenate(out).astype(np.float32)
    np.save(cache, vectors)
    return vectors


def torch_text(model, tokenizer, captions: list[str]) -> np.ndarray:
    out = []
    with torch.no_grad():
        for i in range(0, len(captions), 256):
            feat = model.encode_text(tokenizer(captions[i:i + 256]))
            out.append((feat / feat.norm(dim=-1, keepdim=True)).numpy())
    return np.concatenate(out).astype(np.float32)


def onnx_text(path: Path, tokens: np.ndarray) -> tuple[np.ndarray, float]:
    import onnxruntime as ort

    options = ort.SessionOptions()
    options.intra_op_num_threads = 4     # about a phone's big cores
    session = ort.InferenceSession(str(path), options, providers=["CPUExecutionProvider"])
    out, start = [], time.time()
    for row in tokens:                   # one query at a time, as on the phone
        out.append(session.run(["embedding"], {"tokens": row[None]})[0][0])
    return np.stack(out).astype(np.float32), (time.time() - start) / len(tokens) * 1000


def recall(text: np.ndarray, images: np.ndarray, owner: np.ndarray) -> dict[int, float]:
    sims = text @ images.T
    rank = (sims > sims[np.arange(len(owner)), owner][:, None]).sum(axis=1)
    return {k: float((rank < k).mean()) for k in (1, 5, 10)}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", type=Path, required=True)
    ap.add_argument("--model", type=Path, required=True, help="folder from eval.export_text_model")
    ap.add_argument("--variant", default="4bit", choices=["4bit"])
    args = ap.parse_args()

    torch.backends.mha.set_fastpath_enabled(False)
    model, _, _ = open_clip.create_model_and_transforms(MODEL, pretrained=PRETRAINED)
    model.eval()
    tokenizer = open_clip.get_tokenizer(MODEL)

    paths, captions, owner = load_flickr(args.data)
    print(f"{len(paths)} photos, {len(captions)} captions")
    images = image_vectors(model, paths, args.data / "image_embeddings.npy")
    reference = torch_text(model, tokenizer, captions)
    tokens = tokenizer(captions).numpy().astype(np.int64)

    int8, ms = onnx_text(args.model / f"search_text_encoder_{args.variant}.onnx", tokens)
    cos = (int8 * reference).sum(axis=1)
    print(f"\nA2 {args.variant} vs PyTorch: cosine min {cos.min():.4f}, mean {cos.mean():.4f}, "
          f"< 0.99: {(cos < 0.99).sum()} of {len(cos)}")
    top_ref = np.argsort(-(reference[:200] @ images.T), axis=1)[:, :10]
    top_int8 = np.argsort(-(int8[:200] @ images.T), axis=1)[:, :10]
    same = np.mean([len(set(a) & set(b)) / 10 for a, b in zip(top_ref, top_int8)])
    exact = np.mean([(a[:1] == b[:1]).all() for a, b in zip(top_ref, top_int8)])
    print(f"   top-10 overlap {same:.1%}, same first photo {exact:.1%} (200 queries)")
    print(f"   {args.variant} speed on this PC: {ms:.0f} ms per query (4 threads)")

    print("\nA3 recall (right photo among the first K of 1,000)")
    for name, text in (("PyTorch", reference), (args.variant, int8)):
        r = recall(text, images, owner)
        print(f"   {name:8} R@1 {r[1]:.1%}  R@5 {r[5]:.1%}  R@10 {r[10]:.1%}")

    sims = int8 @ images.T
    right = sims[np.arange(len(owner)), owner]
    print("\nA4 cut-off: right photo passes / photos shown per query (median, 90th pct)")
    for cut in np.arange(0.10, 0.31, 0.02):
        shown = (sims >= cut).sum(axis=1)
        print(f"   {cut:.2f}: {np.mean(right >= cut):6.1%}   "
              f"{int(np.median(shown)):4d}  {int(np.percentile(shown, 90)):4d}")


if __name__ == "__main__":
    main()
