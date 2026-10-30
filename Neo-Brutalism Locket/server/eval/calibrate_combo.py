"""Combine the embedding cosine and the VLM p(Yes) into one probability (search-v2-plan.md, B2/C2).

Reads the cache written by eval.vlm_recheck (pool of 300, top K per search). Logistic regression on
[logit p(Yes), cosine, cosine minus the search's pool mean, rank], 5-fold cross-validation by
photo (no photo is in both the training and the scored part). Then wrong / missed share at several
probability cut-offs, "missed" counting every photo that has the object, also those never asked.

Usage (from server/):  .venv/Scripts/python.exe -m eval.calibrate_combo --vlm Qwen2-VL-2B-Instruct
"""
from __future__ import annotations

import argparse

import numpy as np
import torch                      # before pyarrow (see search_fp_eval)

from eval import search_fp_eval as ev
from eval.vlm_recheck import POOL, pool_indices


def fit_predict(x_train, y_train, x_test) -> np.ndarray:
    """Logistic regression (standardised features, L2) with LBFGS."""
    mu, sd = x_train.mean(0), x_train.std(0) + 1e-6
    a = torch.tensor((x_train - mu) / sd, dtype=torch.float32)
    b = torch.tensor(y_train, dtype=torch.float32)
    w = torch.zeros(a.shape[1], requires_grad=True)
    bias = torch.zeros(1, requires_grad=True)
    opt = torch.optim.Adam([w, bias], lr=0.05)
    for _ in range(600):
        opt.zero_grad()
        loss = torch.nn.functional.binary_cross_entropy_with_logits(a @ w + bias, b) + 1e-3 * (w ** 2).sum()
        loss.backward()
        opt.step()
    z = torch.tensor((x_test - mu) / sd, dtype=torch.float32) @ w + bias
    return torch.sigmoid(z).detach().numpy()


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--vlm", default="Qwen2-VL-2B-Instruct")
    ap.add_argument("--k", type=int, default=40)
    args = ap.parse_args()

    raws, truth = ev.load_coco()
    idx = pool_indices(len(raws))
    t = truth[idx]
    vecs = np.load(ev.CACHE / "ViT-B-16-SigLIP2_coco.npy")[idx]
    emb = ev.OpenClip("ViT-B-16-SigLIP2")
    tv = emb.texts([f"a photo of {ev.CATEGORIES[c][0]}" for c in ev.IDS])
    sims = vecs @ tv.T
    z = np.load(ev.CACHE / f"vlm_{args.vlm}_k{args.k}.npz")
    pvlm = {(int(a), int(b)): float(p) for (a, b), p in zip(z["pairs"], z["p"])}

    rows, labels, photo, cat = [], [], [], []
    for (i, ci), p in pvlm.items():
        c = ev.IDS[ci]
        area = t[i, c]
        if np.isnan(p):
            continue                                   # fp16 overflow in the VLM (15 of 3,200)
        if 0 < area < ev.MIN_AREA:
            continue                                   # ambiguous: not trained on, not counted
        rank = int((sims[:, ci] > sims[i, ci]).sum())
        p = min(max(p, 1e-4), 1 - 1e-4)
        rows.append([np.log(p / (1 - p)), sims[i, ci], sims[i, ci] - sims[:, ci].mean(), rank / args.k])
        labels.append(int(area >= ev.MIN_AREA))
        photo.append(i)
        cat.append(ci)
    x, y, photo, cat = np.array(rows), np.array(labels), np.array(photo), np.array(cat)

    prob = np.zeros(len(y))
    fold = photo % 5
    for f in range(5):
        prob[fold == f] = fit_predict(x[fold != f], y[fold != f], x[fold == f])

    total_pos = sum(int(((t[:, c] >= ev.MIN_AREA)).sum()) for c in ev.IDS)
    print(f"pairs {len(y)}, positives among them {y.sum()}, positives in the pool {total_pos}")
    print(f"{'p >=':>6} {'wrong':>7} {'missed':>7} {'shown':>6}")
    for tau in (0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 0.95):
        shown = prob >= tau
        wrong = (shown & (y == 0)).sum()
        hit = (shown & (y == 1)).sum()
        print(f"{tau:6.2f} {wrong / max(shown.sum(), 1):7.1%} {1 - hit / total_pos:7.1%} {shown.sum():6d}")
    # same tables for one feature alone, for reference
    for name, col in (("vlm only", 0), ("cos only", 1)):
        s = x[:, col]
        print(f"\n{name}: wrong / missed at the score that keeps N photos")
        for n in (300, 600, 900, 1200):
            tau = np.sort(s)[-n]
            shown = s >= tau
            wrong = (shown & (y == 0)).sum()
            hit = (shown & (y == 1)).sum()
            print(f"  {n:5d}: wrong {wrong / n:6.1%}  missed {1 - hit / total_pos:6.1%}")
    for n in (300, 600, 900, 1200):
        tau = np.sort(prob)[-n]
        shown = prob >= tau
        wrong = (shown & (y == 0)).sum()
        hit = (shown & (y == 1)).sum()
        print(f"combo {n:5d}: wrong {wrong / n:6.1%}  missed {1 - hit / total_pos:6.1%}")


if __name__ == "__main__":
    main()
