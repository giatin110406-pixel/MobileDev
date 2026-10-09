"""Daily-quest photo check: does the photo show what the quest asked for?

Zero-shot CLIP (open_clip ViT-B-32, LAION-2B, the same weights the eval uses). The quest's
`positives` ("a bunch of grapes", "grapes") compete against a fixed list of everyday things plus
the quest's own `negatives`; the photo matches when a positive wins. Runs on the CPU so it never
competes with a diffusion job for the GPU (~0.3 s per photo once loaded).
"""
from __future__ import annotations

import io
import threading
from dataclasses import dataclass
from typing import Callable

from PIL import Image

from . import config  # noqa: F401  (must come first: sets HF cache dirs)

MODEL_NAME = "ViT-B-32"
PRETRAINED = "laion2b_s34b_b79k"
TEMPLATES = ("a photo of {}.", "a close-up photo of {}.", "a blurry photo of {}.")

# A positive wins outright when it is the top label; a spread-out win (several positives sharing
# the probability, e.g. "a dog" and "a puppy") still counts once they add up to this much.
MATCH_SCORE = 0.5

# Everyday things a phone photo is likely to show instead. Broad on purpose: without a "banana"
# here, a banana photo could pass a grape quest just by being the closest positive.
GENERIC_DISTRACTORS = (
    "a person", "a face", "a selfie", "a hand", "people", "a crowd",
    "a wall", "a floor", "a ceiling", "a door", "a window", "a room", "a desk", "a table",
    "a chair", "a sofa", "a bed", "a pillow", "a blanket", "a curtain", "a shelf", "a lamp",
    "a phone", "a laptop", "a computer screen", "a television", "a keyboard", "a mouse",
    "a book", "a notebook", "a pen", "a piece of paper", "a bag", "a backpack", "a box",
    "a cup", "a mug", "a glass of water", "a bottle", "a plate", "a bowl", "a spoon",
    "a bowl of rice", "a bowl of noodles", "bread", "a cake", "meat", "vegetables", "a salad",
    "a banana", "an apple", "an orange", "a mango", "a watermelon", "a strawberry",
    "a tomato", "a lemon", "a pineapple", "a coconut",
    "a dog", "a cat", "a bird", "a fish", "a chicken",
    "a tree", "grass", "a flower", "a houseplant", "leaves",
    "the sky", "clouds", "the sun", "a street", "a road", "a building", "a house", "a city",
    "a car", "a motorbike", "a bicycle", "a bus",
    "the sea", "a river", "a beach", "a mountain",
    "clothes", "a shirt", "a shoe", "a hat", "glasses", "a watch",
    "a toy", "a key", "a coin", "a bottle cap",
    "a black image", "a blurry photo", "darkness",
)


@dataclass(frozen=True)
class VerifyResult:
    match: bool
    score: float  # summed probability of the positives
    top: str      # the single most likely label


Verifier = Callable[[bytes, list[str], list[str]], VerifyResult]


def build_labels(positives: list[str], negatives: list[str]) -> list[str]:
    """Positives first, then distractors that do not repeat a positive."""
    seen = {p.strip().lower() for p in positives}
    labels = [p.strip() for p in positives]
    for label in (*negatives, *GENERIC_DISTRACTORS):
        key = label.strip().lower()
        if key and key not in seen:
            seen.add(key)
            labels.append(label.strip())
    return labels


def decide(probs: list[float], labels: list[str], positive_count: int) -> VerifyResult:
    top_index = max(range(len(probs)), key=probs.__getitem__)
    score = float(sum(probs[:positive_count]))
    return VerifyResult(
        match=top_index < positive_count or score >= MATCH_SCORE,
        score=round(score, 4),
        top=labels[top_index],
    )


def clip_verifier() -> Verifier:
    """Real verifier. The model loads on first use (or `warmup`) and stays on the CPU."""
    state: dict = {}
    lock = threading.Lock()

    def model():
        with lock:
            if "model" not in state:
                import open_clip

                net, _, preprocess = open_clip.create_model_and_transforms(
                    MODEL_NAME, pretrained=PRETRAINED, device="cpu")
                net.eval()
                state.update(model=net, preprocess=preprocess,
                             tokenizer=open_clip.get_tokenizer(MODEL_NAME), text={})
            return state

    def text_features(s: dict, labels: list[str]):
        import torch

        cache: dict = s["text"]
        missing = [label for label in labels if label not in cache]
        if missing:
            prompts = [t.format(label) for label in missing for t in TEMPLATES]
            feats = s["model"].encode_text(s["tokenizer"](prompts))
            feats = feats / feats.norm(dim=-1, keepdim=True)
            feats = feats.reshape(len(missing), len(TEMPLATES), -1).mean(dim=1)
            feats = feats / feats.norm(dim=-1, keepdim=True)
            for label, feat in zip(missing, feats):
                cache[label] = feat
        return torch.stack([cache[label] for label in labels])

    def verify(data: bytes, positives: list[str], negatives: list[str]) -> VerifyResult:
        import torch

        s = model()
        labels = build_labels(positives, negatives)
        image = Image.open(io.BytesIO(data)).convert("RGB")
        with torch.no_grad():
            feat = s["model"].encode_image(s["preprocess"](image).unsqueeze(0))
            feat = feat / feat.norm(dim=-1, keepdim=True)
            logits = s["model"].logit_scale.exp() * feat @ text_features(s, labels).T
            probs = logits.softmax(dim=-1)[0].tolist()
        return decide(probs, labels, len(positives))

    def warmup() -> None:
        import torch

        s = model()
        with torch.no_grad():
            text_features(s, list(GENERIC_DISTRACTORS))

    verify.warmup = warmup  # type: ignore[attr-defined]
    return verify
