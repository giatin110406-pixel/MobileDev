"""Wrong-photo / missed-photo measurement of photo search (search-v2-plan.md, Phase A-B).

Data: COCO val (2,476 photos, human object boxes). A photo "has" an object when the object covers
>= MIN_AREA of the image; present but smaller = ignored (a person cannot say if it counts); the
rest do not have it. A search is an object name. Libraries of 20 / 60 / 300 random photos are
drawn many times; every object that has an answer in the library is a search, and so is every
object that is nowhere in it (must show nothing).

Numbers per library size:
  wrong   shown photos that do not have the object / shown photos           (false positives)
  missed  photos that have it and are not shown / photos that have it       (false negatives)
  empty   searches with no answer in the library that show nothing           (should be ~100 %)
  q_wrong searches (with an answer) that show at least one wrong photo

Usage (from server/):
    $env:PYTHONPATH = ".eval_tools"
    .venv/Scripts/python.exe -m eval.search_fp_eval --model mobileclip --lang en
"""
from __future__ import annotations

import argparse
import io
from pathlib import Path

import numpy as np
import torch                       # before pyarrow: the other order crashes on Windows
from PIL import Image, ImageOps

COCO = Path("D:/clip_eval_tmp/coco/data/val-00000-of-00002-c4f2e391ee4aba11.parquet")
CACHE = Path("D:/clip_eval_tmp/search_v2")
MIN_AREA = 0.02

# COCO category id -> (English, Vietnamese)
CATEGORIES = {
    1: ("person", "người"), 2: ("bicycle", "xe đạp"), 3: ("car", "ô tô"),
    4: ("motorcycle", "xe máy"), 5: ("airplane", "máy bay"), 6: ("bus", "xe buýt"),
    7: ("train", "tàu hỏa"), 8: ("truck", "xe tải"), 9: ("boat", "thuyền"),
    10: ("traffic light", "đèn giao thông"), 11: ("fire hydrant", "trụ cứu hỏa"),
    13: ("stop sign", "biển báo dừng"), 14: ("parking meter", "đồng hồ đỗ xe"),
    15: ("bench", "ghế đá"), 16: ("bird", "chim"), 17: ("cat", "mèo"), 18: ("dog", "chó"),
    19: ("horse", "ngựa"), 20: ("sheep", "cừu"), 21: ("cow", "bò"), 22: ("elephant", "voi"),
    23: ("bear", "gấu"), 24: ("zebra", "ngựa vằn"), 25: ("giraffe", "hươu cao cổ"),
    27: ("backpack", "ba lô"), 28: ("umbrella", "cái ô"), 31: ("handbag", "túi xách"),
    32: ("tie", "cà vạt"), 33: ("suitcase", "va li"), 34: ("frisbee", "đĩa ném"),
    35: ("skis", "ván trượt tuyết"), 36: ("snowboard", "ván trượt tuyết"),
    37: ("sports ball", "quả bóng"), 38: ("kite", "diều"), 39: ("baseball bat", "gậy bóng chày"),
    40: ("baseball glove", "găng tay bóng chày"), 41: ("skateboard", "ván trượt"),
    42: ("surfboard", "ván lướt sóng"), 43: ("tennis racket", "vợt tennis"),
    44: ("bottle", "chai"), 46: ("wine glass", "ly rượu"), 47: ("cup", "cốc"),
    48: ("fork", "cái nĩa"), 49: ("knife", "con dao"), 50: ("spoon", "cái thìa"),
    51: ("bowl", "cái bát"), 52: ("banana", "chuối"), 53: ("apple", "táo"),
    54: ("sandwich", "bánh sandwich"), 55: ("orange", "cam"), 56: ("broccoli", "bông cải xanh"),
    57: ("carrot", "cà rốt"), 58: ("hot dog", "xúc xích kẹp bánh"), 59: ("pizza", "pizza"),
    60: ("donut", "bánh donut"), 61: ("cake", "bánh kem"), 62: ("chair", "cái ghế"),
    63: ("couch", "ghế sofa"), 64: ("potted plant", "chậu cây"), 65: ("bed", "cái giường"),
    67: ("dining table", "bàn ăn"), 70: ("toilet", "bồn cầu"), 72: ("tv", "tivi"),
    73: ("laptop", "laptop"), 74: ("mouse", "chuột máy tính"), 75: ("remote", "điều khiển"),
    76: ("keyboard", "bàn phím"), 77: ("cell phone", "điện thoại"), 78: ("microwave", "lò vi sóng"),
    79: ("oven", "lò nướng"), 80: ("toaster", "máy nướng bánh"), 81: ("sink", "bồn rửa"),
    82: ("refrigerator", "tủ lạnh"), 84: ("book", "quyển sách"), 85: ("clock", "đồng hồ"),
    86: ("vase", "bình hoa"), 87: ("scissors", "cái kéo"), 88: ("teddy bear", "gấu bông"),
    89: ("hair drier", "máy sấy tóc"), 90: ("toothbrush", "bàn chải đánh răng"),
}


IDS = sorted(CATEGORIES)
assert len(IDS) == 80


# ---------------------------------------------------------------- data

def load_coco() -> tuple[list[bytes], np.ndarray]:
    """-> jpeg bytes, truth [photo, category id] = largest area share of that object (0 = absent)"""
    import pyarrow.parquet as pq
    table = pq.read_table(COCO, columns=["image", "width", "height", "objects"]).to_pylist()
    images = [r["image"]["bytes"] for r in table]
    truth = np.zeros((len(table), 91), np.float32)
    for i, r in enumerate(table):
        whole = float(r["width"] * r["height"])
        o = r["objects"]
        for cat, area in zip(o["category"], o["area"]):
            cid = IDS[cat]                    # this copy numbers the 80 classes 0..79
            truth[i, cid] = max(truth[i, cid], area / whole)
    return images, truth


def pil(raw: bytes) -> Image.Image:
    return ImageOps.exif_transpose(Image.open(io.BytesIO(raw))).convert("RGB")


# ---------------------------------------------------------------- models

class MobileClip:
    """v1 as on the phone: 256 px short side, centre crop, 0..1 pixels."""
    name = "mobileclip"

    def __init__(self) -> None:
        import open_clip
        torch.backends.mha.set_fastpath_enabled(False)
        self.model, _, _ = open_clip.create_model_and_transforms("MobileCLIP2-S0", pretrained="dfndr2b")
        self.model.eval().cuda()
        self.tok = open_clip.get_tokenizer("MobileCLIP2-S0")

    def _prep(self, image: Image.Image) -> torch.Tensor:
        size = 256
        s = size / min(image.size)
        w, h = max(size, round(image.width * s)), max(size, round(image.height * s))
        image = image.resize((w, h), Image.BOX)
        l, t = (w - size) // 2, (h - size) // 2
        image = image.crop((l, t, l + size, t + size))
        return torch.from_numpy(np.asarray(image, np.float32) / 255.0).permute(2, 0, 1)

    @torch.no_grad()
    def images(self, raws: list[bytes]) -> np.ndarray:
        out = []
        for i in range(0, len(raws), 64):
            batch = torch.stack([self._prep(pil(r)) for r in raws[i:i + 64]]).cuda()
            f = self.model.encode_image(batch)
            out.append((f / f.norm(dim=-1, keepdim=True)).float().cpu().numpy())
        return np.concatenate(out)

    @torch.no_grad()
    def texts(self, texts: list[str]) -> np.ndarray:
        f = self.model.encode_text(self.tok(texts).cuda())
        return (f / f.norm(dim=-1, keepdim=True)).float().cpu().numpy()


class OpenClip:
    """Any open_clip model with its own preprocessing, fp16 on the GPU (SigLIP2 etc.)."""

    def __init__(self, arch: str, pretrained: str = "webli") -> None:
        import open_clip
        self.name = arch
        self.model, _, self.pre = open_clip.create_model_and_transforms(arch, pretrained=pretrained)
        self.model.eval().half().cuda()
        self.tok = open_clip.get_tokenizer(arch)

    @torch.no_grad()
    def images(self, raws: list[bytes]) -> np.ndarray:
        out = []
        for i in range(0, len(raws), 32):
            batch = torch.stack([self.pre(pil(r)) for r in raws[i:i + 32]]).half().cuda()
            f = self.model.encode_image(batch).float()
            out.append((f / f.norm(dim=-1, keepdim=True)).cpu().numpy())
        return np.concatenate(out)

    @torch.no_grad()
    def texts(self, texts: list[str]) -> np.ndarray:
        f = self.model.encode_text(self.tok(texts).cuda()).float()
        return (f / f.norm(dim=-1, keepdim=True)).cpu().numpy()


def make_model(name: str):
    if name == "mobileclip":
        return MobileClip()
    return OpenClip(name)


def image_vectors(model, raws: list[bytes]) -> np.ndarray:
    CACHE.mkdir(parents=True, exist_ok=True)
    path = CACHE / f"{model.name}_coco.npy"
    if path.exists():
        return np.load(path)
    v = model.images(raws).astype(np.float32)
    np.save(path, v)
    return v


# ---------------------------------------------------------------- policies

def policy_v1(sims: np.ndarray) -> np.ndarray:
    """What the phone shows today (photo_search.dart): sure 0.23, floor 0.18, margin 0.03,
    lift gate 0.06 in a library of >= 8, at most 60."""
    best = sims.max()
    if len(sims) >= 8 and best - sims.mean() < 0.06:
        return np.zeros(len(sims), bool)
    shown = (sims >= 0.23) | ((sims >= 0.18) & (sims >= best - 0.03))
    if shown.sum() > 60:
        shown &= sims >= np.sort(sims)[-60]
    return shown


def thr(tau: float):
    """Fixed cosine cut-off."""
    return lambda sims: sims >= tau


def zscore(k: float):
    """Standing out of this library: (cosine - mean) / std >= k. Adapts to each search."""
    def policy(sims: np.ndarray) -> np.ndarray:
        sd = sims.std()
        return (sims - sims.mean()) / (sd if sd > 1e-6 else 1.0) >= k
    return policy


POLICIES = {"v1": policy_v1}


# ---------------------------------------------------------------- evaluation

def evaluate(image_vecs, truth, text_vecs: dict[int, np.ndarray], policy, size: int,
             draws: int, seed: int = 7) -> dict[str, float]:
    rng = np.random.default_rng(seed)
    shown_n = wrong_n = pos_n = miss_n = 0
    q_pos = q_wrong = q_neg = q_empty = 0
    for _ in range(draws):
        idx = rng.choice(len(image_vecs), size, replace=False)
        lib, t = image_vecs[idx], truth[idx]
        for cat, vec in text_vecs.items():
            has, absent = t[:, cat] >= MIN_AREA, t[:, cat] == 0
            if not has.any() and not absent.all():
                continue                     # only tiny instances: nothing certain to say
            shown = policy(lib @ vec)
            if not has.any():
                q_neg += 1
                q_empty += int(not shown.any())
                continue
            q_pos += 1
            shown_n += shown.sum()
            wrong = (shown & absent).sum()
            wrong_n += wrong
            q_wrong += int(wrong > 0)
            pos_n += has.sum()
            miss_n += (has & ~shown).sum()
    return {
        "wrong": wrong_n / max(shown_n, 1), "missed": miss_n / max(pos_n, 1),
        "empty": q_empty / max(q_neg, 1), "q_wrong": q_wrong / max(q_pos, 1),
        "queries": q_pos, "no_answer": q_neg,
    }


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", default="mobileclip")
    ap.add_argument("--lang", default="en", choices=["en", "vi"])
    ap.add_argument("--policy", default="v1")
    ap.add_argument("--draws", type=int, default=30)
    ap.add_argument("--sweep", action="store_true", help="operating points instead of one policy")
    args = ap.parse_args()

    raws, truth = load_coco()
    model = make_model(args.model)
    vecs = image_vectors(model, raws)
    col = 0 if args.lang == "en" else 1
    cats = list(CATEGORIES)
    prompts = [f"a photo of {CATEGORIES[c][col]}" for c in cats]
    tv = model.texts(prompts)
    text_vecs = {c: tv[i] for i, c in enumerate(cats)}

    if args.sweep:
        size = 60
        print(f"{args.model} {args.lang}, library {size}: operating points")
        print(f"{'policy':>10} {'wrong':>7} {'missed':>7} {'empty':>7} {'q_wrong':>8}")
        lo, hi = np.percentile(vecs @ tv.T, [50, 99.5])
        for tau in np.linspace(lo, hi, 12):
            r = evaluate(vecs, truth, text_vecs, thr(tau), size, args.draws)
            print(f"{'t%.3f' % tau:>10} {r['wrong']:7.1%} {r['missed']:7.1%} {r['empty']:7.1%} {r['q_wrong']:8.1%}")
        for k in (1.5, 2, 2.5, 3, 3.5, 4, 5):
            r = evaluate(vecs, truth, text_vecs, zscore(k), size, args.draws)
            print(f"{'z%.1f' % k:>10} {r['wrong']:7.1%} {r['missed']:7.1%} {r['empty']:7.1%} {r['q_wrong']:8.1%}")
        return

    print(f"model {args.model}  lang {args.lang}  policy {args.policy}  ({args.draws} libraries per size)")
    print(f"{'library':>8} {'wrong':>7} {'missed':>7} {'empty':>7} {'q_wrong':>8}  searches")
    for size in (20, 60, 300):
        r = evaluate(vecs, truth, text_vecs, POLICIES[args.policy], size, args.draws)
        print(f"{size:>8} {r['wrong']:7.1%} {r['missed']:7.1%} {r['empty']:7.1%} {r['q_wrong']:8.1%}"
              f"  {r['queries']} with answer, {r['no_answer']} without")


if __name__ == "__main__":
    main()
