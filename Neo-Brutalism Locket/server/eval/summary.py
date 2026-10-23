"""Compare two finished eval runs: tables per photo tag and contact sheets (original | A | B).

  python -m eval.summary old new            # reads eval/out/old and eval/out/new
  python -m eval.summary cur k3 --sheets 4  # up to 4 sheets per tag group

Only photos finished in both runs are compared. Sheets go to eval/out/compare_<b>_<group>_<n>.png.
"""
from __future__ import annotations

import argparse
import json
import statistics
import sys
from pathlib import Path

SERVER_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(SERVER_ROOT))

from PIL import Image, ImageDraw  # noqa: E402

OUT = SERVER_ROOT / "eval" / "out"
PHOTOS = SERVER_ROOT / "eval" / "photos"
METRICS = ("face_sim", "face_seam", "face_tone", "palette_shift", "clip_style", "style_generic")
HELP = {"face_sim": "higher = same person", "face_seam": "0 = face painted like its surroundings",
        "face_tone": "lower = same skin tone", "palette_shift": "lower = colours follow the photo",
        "clip_style": "higher = more 'painting'", "style_generic": "higher = Van Gogh technique"}


def load(name: str) -> dict:
    path = OUT / name / "results.json"
    rows = json.loads(path.read_text(encoding="utf-8"))["rows"]
    return {r["photo"]: r for r in rows if "error" not in r}


def mean(rows: list, key: str):
    values = [r[key] for r in rows if r.get(key) is not None]
    return round(statistics.mean(values), 3) if values else None


def fmt(value) -> str:
    return "-" if value is None else str(value)


def faces(row: dict) -> int:
    return len(row.get("face_patch_deviation") or [])


def source_square(photo: str, size: int):
    from locket_server import preprocess

    data = (PHOTOS / f"{photo}.jpg").read_bytes()
    return preprocess.center_square(preprocess.load_oriented(data), size)


def broken_count(name: str, photos: list[str]) -> int:
    from locket_server import output_check

    count = 0
    for photo in photos:
        image = Image.open(OUT / name / f"{photo}.png")
        if output_check.is_broken(image, source_square(photo, 640)):
            count += 1
    return count


def tables(a_name: str, b_name: str, a: dict, b: dict, photos: list[str]) -> None:
    tags = sorted({a[p].get("tag") or "untagged" for p in photos})
    print(f"\n{len(photos)} photos finished in both runs\n")
    print(f"{'group':12s} {'n':>3s} {'run':>5s} " + " ".join(f"{m:>13s}" for m in METRICS))
    for tag in ["ALL", *tags]:
        keys = [p for p in photos if tag == "ALL" or (a[p].get("tag") or "untagged") == tag]
        for name, rows in ((a_name, a), (b_name, b)):
            subset = [rows[p] for p in keys]
            print(f"{tag:12s} {len(keys):3d} {name:>5s} " + " ".join(f"{fmt(mean(subset, m)):>13s}" for m in METRICS))
    print("\nmeaning: " + "; ".join(f"{k}: {v}" for k, v in HELP.items()))
    print("\nseconds per photo (median) by number of repainted faces")
    for label, test in (("no face pass", lambda r: faces(r) == 0), ("1 face", lambda r: faces(r) == 1),
                        ("2+ faces", lambda r: faces(r) >= 2)):
        cells = []
        for name, rows in ((a_name, a), (b_name, b)):
            times = [rows[p]["total"] for p in photos if test(rows[p])]
            cells.append(f"{name}: {statistics.median(times):5.1f} s (n={len(times)})" if times else f"{name}: -")
        print(f"  {label:13s} " + "   ".join(cells))
    print("\nphotos where the output check had to redo the frame (main_retry / upscale_retry / upscale_fallback)")
    for name, rows in ((a_name, a), (b_name, b)):
        flagged = [p for p in photos if any(rows[p].get(k) for k in ("main_retry", "upscale_retry", "upscale_fallback"))]
        print(f"  {name}: {len(flagged)} {flagged[:10]}")
    print("\nbroken frames still in the saved images (black block / noise):")
    for name in (a_name, b_name):
        print(f"  {name}: {broken_count(name, photos)}")


def sheets(a_name: str, b_name: str, photos: list[str], a: dict, limit: int, cell: int = 300) -> None:
    from locket_server import preprocess  # noqa: F401  (also sets cache paths)

    groups = {"people": [p for p in photos if a[p].get("tag") in ("portrait", "group")],
              "scenes": [p for p in photos if a[p].get("tag") not in ("portrait", "group")]}
    for group, names in groups.items():
        for index in range(min(limit, (len(names) + 5) // 6)):
            chunk = names[index * 6:(index + 1) * 6]
            if not chunk:
                break
            image = Image.new("RGB", (3 * cell + 8, len(chunk) * (cell + 16)), "white")
            draw = ImageDraw.Draw(image)
            for row, photo in enumerate(chunk):
                y = row * (cell + 16)
                draw.text((2, y + 2), f"{photo} ({a[photo].get('tag')}): original | {a_name} | {b_name}", fill="black")
                tiles = [source_square(photo, cell)] + [
                    Image.open(OUT / n / f"{photo}.png").convert("RGB").resize((cell, cell), Image.LANCZOS)
                    for n in (a_name, b_name)]
                for col, tile in enumerate(tiles):
                    image.paste(tile, (col * (cell + 4), y + 16))
            target = OUT / f"compare_{b_name}_{group}_{index + 1}.png"
            image.save(target)
            print("wrote", target)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("a", help="first run (e.g. the old config)")
    parser.add_argument("b", help="second run (e.g. k3)")
    parser.add_argument("--sheets", type=int, default=3, help="contact sheets per group (6 photos each)")
    args = parser.parse_args()
    a, b = load(args.a), load(args.b)
    photos = sorted(set(a) & set(b))
    if not photos:
        raise SystemExit("no photo is finished in both runs")
    tables(args.a, args.b, a, b, photos)
    print()
    sheets(args.a, args.b, photos, a, args.sheets)


if __name__ == "__main__":
    main()
