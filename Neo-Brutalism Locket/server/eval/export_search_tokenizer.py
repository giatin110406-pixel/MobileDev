"""Export the CLIP tokenizer for the phone (archive-ai-search-plan.md, A5).

Writes:
  <assets>/clip_merges.txt.gz                 the BPE merges open_clip uses (lines 1..48894 of
                                              bpe_simple_vocab_16e6.txt.gz), shipped in the app
  <goldens>/tokenizer_goldens.json            sentences and the token ids open_clip gives them
                                              (without the zero padding), checked by
                                              test/clip_tokenizer_test.dart

The Dart port (lib/features/search/clip_tokenizer.dart) skips open_clip's ftfy.fix_text and
html.unescape: typed or translated text has no broken encodings or HTML entities. The goldens
contain only text where those two steps change nothing, plus a check that it is so.

Usage (from server/):
    .venv/Scripts/python.exe -m eval.export_search_tokenizer --assets ../assets/search_model \
        --goldens ../test/fixtures/search --flickr D:/clip_eval_tmp/flickr1k
"""
from __future__ import annotations

import argparse
import gzip
import html
import json
from pathlib import Path

import ftfy
import open_clip
from open_clip.tokenizer import default_bpe

MERGES = 49152 - 256 - 2   # the slice open_clip.tokenizer.SimpleTokenizer keeps

TRICKY = [
    "A dog", "  two   spaces  and\ttabs\n", "It's a dog's life, isn't it?", "they'll we'd I'm you've",
    "Hello!!! ... ??? (brackets) [square] {curly}", "price $12.50 & 100% #1 @home",
    "3 cats, 12 dogs and 2025 birds", "café naïve résumé", "Áo đỏ đứng cạnh xe máy",
    "ảnh đi biển với Lan năm ngoái", "emoji 😀 and ❤️", "日本の犬", "UPPER lower MiXeD",
    "a-b c_d e/f g.h", "o'clock", "rock'n'roll", "",
    " ".join(["word"] * 120),   # longer than 77 tokens: truncated, last id is end-of-text
]


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--assets", type=Path, required=True)
    ap.add_argument("--goldens", type=Path, required=True)
    ap.add_argument("--flickr", type=Path, help="Flickr30k 1k folder (eval.search_eval) for 500 captions")
    args = ap.parse_args()

    lines = gzip.open(default_bpe()).read().decode("utf-8").split("\n")
    merges = lines[1:MERGES + 1]
    args.assets.mkdir(parents=True, exist_ok=True)
    out = args.assets / "clip_merges.txt.gz"
    out.write_bytes(gzip.compress("\n".join(merges).encode("utf-8"), mtime=0))
    print(f"wrote {out} ({out.stat().st_size / 1e3:.0f} KB, {len(merges)} merges)")

    sentences = list(TRICKY)
    if args.flickr:
        from eval.search_eval import load_flickr

        sentences += load_flickr(args.flickr)[1][:500]
    for s in sentences:
        assert html.unescape(html.unescape(ftfy.fix_text(s))) == s, f"not a clean golden: {s!r}"

    tokenizer = open_clip.get_tokenizer("MobileCLIP2-S0")
    rows = []
    for s in sentences:
        ids = tokenizer([s])[0].tolist()
        while ids and ids[-1] == 0:
            ids.pop()
        rows.append({"text": s, "ids": ids})
    args.goldens.mkdir(parents=True, exist_ok=True)
    path = args.goldens / "tokenizer_goldens.json"
    path.write_text(json.dumps({"contextLength": 77, "cases": rows}, ensure_ascii=False, indent=0),
                    encoding="utf-8")
    print(f"wrote {path} ({len(rows)} sentences)")


if __name__ == "__main__":
    main()
