"""Index-time tags: can a caption + object list written once per photo answer searches?
(search-v2-plan.md, "Decision on speed")

The VLM writes, for each of the 300 pool photos of eval.vlm_recheck, one line of objects and a
caption. A search for an object name matches when the name (or a synonym) is in that text.
Compared with the cosine and the search-time VLM check on the same pool, and combined with them.

Usage (from server/):
    $env:PYTHONPATH = ".eval_tools"
    .venv/Scripts/python.exe -m eval.index_tags --vlm Qwen/Qwen2-VL-2B-Instruct
"""
from __future__ import annotations

import torch

from locket_server.search_v2 import TAG_PROMPT

PROMPT = TAG_PROMPT


def load_vlm(name: str):
    from transformers import AutoModelForImageTextToText, AutoProcessor
    proc = AutoProcessor.from_pretrained(name, min_pixels=128 * 28 * 28, max_pixels=448 * 28 * 28)
    proc.tokenizer.padding_side = "left"
    model = AutoModelForImageTextToText.from_pretrained(name, dtype=torch.bfloat16).cuda().eval()
    return proc, model


@torch.no_grad()
def describe(proc, model, images, prompt: str = TAG_PROMPT) -> list[str]:
    msg = [{"role": "user", "content": [{"type": "image"}, {"type": "text", "text": prompt}]}]
    text = proc.apply_chat_template(msg, add_generation_prompt=True)
    inputs = proc(text=[text] * len(images), images=images, padding=True, return_tensors="pt").to("cuda")
    out = model.generate(**inputs, max_new_tokens=220, do_sample=False)
    return proc.batch_decode(out[:, inputs["input_ids"].shape[1]:], skip_special_tokens=True)


def main() -> None:
    # One full-coverage evaluator; old top-40 measurements are historical only.
    from eval.compare_tags import main as compare
    compare()


if __name__ == "__main__":
    main()
