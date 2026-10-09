"""Build eval/out/report.html: original | run A | run B ... per photo, with times and metrics.

  python -m eval.report baseline steps16
"""
from __future__ import annotations

import html
import json
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "out"


def main() -> None:
    names = sys.argv[1:]
    if not names:
        raise SystemExit("usage: python -m eval.report RUN [RUN ...]")
    runs = [json.loads((OUT / n / "results.json").read_text(encoding="utf-8")) for n in names]
    # CLIP "style" score calibrated on 2026-10-03: real photos ~ -0.09, Van Gogh paintings ~ +0.10.
    photo_level, painting_level = -0.09, 0.10
    for r in runs:
        for row in r["rows"]:
            clip = row.get("clip_style")
            row["style_pct"] = None if clip is None else round(
                100 * min(1.0, max(0.0, (clip - photo_level) / (painting_level - photo_level))))
        values = [x["style_pct"] for x in r["rows"] if x["style_pct"] is not None]
        r["summary"]["style_pct"] = round(sum(values) / len(values)) if values else None
    thumbs = OUT / "report_assets"
    thumbs.mkdir(exist_ok=True)

    def thumb(src: Path, dst: str) -> str:
        image = ImageOps.exif_transpose(Image.open(src)).convert("RGB")
        image.thumbnail((520, 520))
        image.save(thumbs / dst, quality=88)
        return f"report_assets/{dst}"

    head = "".join(
        f"<th>{html.escape(r['name'])}<br><small>{html.escape(' '.join(r['overrides']) or 'default config')}"
        f"</small></th>" for r in runs)
    summary = "".join(
        f"<tr><td>{html.escape(r['name'])}</td>"
        + "".join(f"<td>{r['summary'].get(k)}</td>" for k in ("total", "edge_ssim", "style_pct", "face_sim"))
        + "</tr>" for r in runs)
    body = []
    for row in runs[0]["rows"]:
        photo = row["photo"]
        cells = [f"<td><img src='{thumb(ROOT / 'photos' / (photo + '.jpg'), photo + '_orig.jpg')}'></td>"]
        for r in runs:
            match = next((x for x in r["rows"] if x["photo"] == photo), None)
            if match is None:
                cells.append("<td>-</td>")
                continue
            small = thumb(OUT / r["name"] / f"{photo}.png", f"{r['name']}_{photo}.jpg")
            stats = ", ".join(f"{k}={match[k]}" for k in ("total", "edge_ssim", "style_pct", "face_sim")
                              if k in match)
            cells.append(f"<td><img src='{small}'><br><small>{stats}</small></td>")
        body.append(f"<tr><th>{photo}</th>{''.join(cells)}</tr>")
    page = f"""<!doctype html><meta charset='utf-8'><title>Eval report</title>
<style>body{{font:14px sans-serif;margin:16px}}img{{max-width:260px;display:block}}
td,th{{vertical-align:top;padding:6px;border:1px solid #ccc}}table{{border-collapse:collapse}}</style>
<h2>Summary (means over photos)</h2>
<table><tr><th>run</th><th>total s</th><th>edge SSIM</th><th>style % (0 photo - 100 painting)</th><th>face sim</th></tr>{summary}</table>
<h2>Per photo</h2><table><tr><th></th><th>original</th>{head}</tr>{''.join(body)}</table>"""
    (OUT / "report.html").write_text(page, encoding="utf-8")
    print(OUT / "report.html")


if __name__ == "__main__":
    main()
