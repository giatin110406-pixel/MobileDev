"""Does a local VLM's yes / no on the top candidates cut the wrong photos? (search-v2-plan.md, Phase C)

Pool = 300 random COCO photos (one library of 300). Retrieval = SigLIP2 B/16 cosine. For every
object name the top K photos are asked "Does this photo clearly show a <name>?"; p(Yes) comes from
the Yes / No token probabilities. Results are cached, so it can be stopped and resumed.

Compared at the same pool: retrieval alone (cosine cut-off) vs retrieval + VLM (p(Yes) cut-off),
wrong share against missed share, as in eval.search_fp_eval.

Usage (from server/):
    $env:PYTHONPATH = ".eval_tools"
    .venv/Scripts/python.exe -m eval.vlm_recheck --vlm Qwen/Qwen2-VL-2B-Instruct --k 40
"""
from __future__ import annotations

import argparse
import time

import numpy as np
import torch

from eval import search_fp_eval as ev
from locket_server.search_v2 import check_prompt

POOL = 300


def pool_indices(n: int) -> np.ndarray:
    return np.random.default_rng(1).choice(n, POOL, replace=False)


def load_vlm(name: str):
    from transformers import AutoModelForImageTextToText, AutoProcessor
    proc = AutoProcessor.from_pretrained(name, min_pixels=128 * 28 * 28, max_pixels=320 * 28 * 28)
    proc.tokenizer.padding_side = "left"
    model = AutoModelForImageTextToText.from_pretrained(name, dtype=torch.bfloat16).cuda().eval()
    yes = [proc.tokenizer.encode(w, add_special_tokens=False)[0] for w in ("Yes", "yes")]
    no = [proc.tokenizer.encode(w, add_special_tokens=False)[0] for w in ("No", "no")]
    return proc, model, yes, no


@torch.no_grad()
def p_yes(proc, model, yes, no, images, names: list[str]) -> list[float]:
    texts = []
    for n in names:
        msg = [{"role": "user", "content": [
            {"type": "image"},
            {"type": "text", "text": check_prompt(n)}]}]
        texts.append(proc.apply_chat_template(msg, add_generation_prompt=True))
    inputs = proc(text=texts, images=images, padding=True, return_tensors="pt").to("cuda")
    # Only the next token is used. A full [batch, sequence, vocabulary] tensor wastes VRAM.
    logits = model(**inputs, logits_to_keep=1, use_cache=False).logits[:, -1, :].float()
    lp = torch.log_softmax(logits, dim=-1)
    py = torch.logsumexp(lp[:, yes], dim=-1)
    pn = torch.logsumexp(lp[:, no], dim=-1)
    return torch.sigmoid(py - pn).cpu().tolist()


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--vlm", default="Qwen/Qwen2-VL-2B-Instruct")
    ap.add_argument("--k", type=int, default=40)
    ap.add_argument("--batch", type=int, default=8)
    ap.add_argument("--limit", type=int, default=0, help="only the first N pairs (speed test)")
    args = ap.parse_args()

    raws, truth = ev.load_coco()
    idx = pool_indices(len(raws))
    emb = ev.OpenClip("ViT-B-16-SigLIP2")
    vecs = ev.image_vectors(emb, raws)[idx]
    cats = ev.IDS
    tv = emb.texts([f"a photo of {ev.CATEGORIES[c][0]}" for c in cats])
    sims = vecs @ tv.T                                   # [pool, category]
    del emb
    torch.cuda.empty_cache()

    pairs = [(i, ci) for ci in range(len(cats)) for i in np.argsort(-sims[:, ci])[:args.k]]
    if args.limit:
        pairs = pairs[:args.limit]
    tag = args.vlm.split("/")[-1]
    cache = ev.CACHE / f"vlm_{tag}_bf16_k{args.k}.npz"
    done = dict(zip(map(tuple, np.load(cache)["pairs"]), np.load(cache)["p"])) if cache.exists() else {}
    todo = [p for p in pairs if p not in done]
    print(f"{len(pairs)} pairs, {len(todo)} to ask  ({tag})", flush=True)

    if todo:
        from PIL import Image
        proc, model, yes, no = load_vlm(args.vlm)
        start = time.time()
        for b in range(0, len(todo), args.batch):
            chunk = todo[b:b + args.batch]
            images = [ev.pil(raws[idx[i]]) for i, _ in chunk]
            names = [ev.CATEGORIES[cats[ci]][0] for _, ci in chunk]
            for p, v in zip(chunk, p_yes(proc, model, yes, no, images, names)):
                done[p] = v
            if (b // args.batch) % 25 == 0:
                rate = (b + len(chunk)) / (time.time() - start)
                print(f"  {b + len(chunk)}/{len(todo)}  {rate:.1f} pairs/s", flush=True)
                np.savez(cache, pairs=np.array(list(done)), p=np.array(list(done.values())))
        np.savez(cache, pairs=np.array(list(done)), p=np.array(list(done.values())))
    if args.limit:
        return

    # ---- evaluation on the pool (library of 300, every candidate asked)
    t = truth[idx]
    print(f"\npool {POOL}, top {args.k} per search, {tag}")
    print(f"{'policy':>16} {'wrong':>7} {'missed':>7} {'empty':>7} {'q_wrong':>8}")

    def run(label, shown_fn):
        shown_n = wrong_n = pos_n = miss_n = qpos = qwrong = qneg = qempty = 0
        for ci, c in enumerate(cats):
            has, absent = t[:, c] >= ev.MIN_AREA, t[:, c] == 0
            if not has.any() and not absent.all():
                continue
            shown = shown_fn(ci)
            if not has.any():
                qneg += 1
                qempty += int(not shown.any())
                continue
            qpos += 1
            shown_n += shown.sum()
            w = (shown & absent).sum()
            wrong_n += w
            qwrong += int(w > 0)
            pos_n += has.sum()
            miss_n += (has & ~shown).sum()
        print(f"{label:>16} {wrong_n / max(shown_n, 1):7.1%} {miss_n / max(pos_n, 1):7.1%} "
              f"{qempty / max(qneg, 1):7.1%} {qwrong / max(qpos, 1):8.1%}")

    top = {ci: set(int(i) for i in np.argsort(-sims[:, ci])[:args.k]) for ci in range(len(cats))}
    for tau in np.percentile(sims, [90, 95, 97, 98, 99, 99.5]):
        run(f"cos {tau:.3f}", lambda ci, tau=tau: (sims[:, ci] >= tau) & np.isin(np.arange(POOL), list(top[ci])))
    for tau in (0.2, 0.35, 0.5, 0.65, 0.8, 0.9, 0.95):
        def fn(ci, tau=tau):
            s = np.zeros(POOL, bool)
            for i in top[ci]:
                s[i] = done[(i, ci)] >= tau
            return s
        run(f"vlm p>={tau}", fn)


if __name__ == "__main__":
    main()
