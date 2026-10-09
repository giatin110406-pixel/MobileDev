"""Run one Van Gogh configuration over the eval photo set.

  python -m eval.run --name baseline
  python -m eval.run --name steps16 --set main.steps=16 --set working_size=576
  python -m eval.run --name nofaces --set face.enabled=false --no-metrics

Outputs go to eval/out/<name>/ (PNGs + results.json). Build the side-by-side page with
`python -m eval.report baseline steps16`.
"""
from __future__ import annotations

import argparse
import copy
import glob
import json
import os
import statistics
import sys
import time
from pathlib import Path

SERVER_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(SERVER_ROOT))
os.environ.setdefault("HF_HUB_DISABLE_SYMLINKS_WARNING", "1")
os.environ.setdefault("PYTHONWARNINGS", "ignore")

from PIL import Image  # noqa: E402

from locket_server import config, preprocess  # noqa: E402


def apply_overrides(cfg: dict, overrides: list[str]) -> dict:
    cfg = copy.deepcopy(cfg)
    for item in overrides:
        key, _, raw = item.partition("=")
        value = json.loads(raw) if raw[:1] in "0123456789-[{\"" or raw in ("true", "false", "null") else raw
        node = cfg
        parts = key.split(".")
        for part in parts[:-1]:
            node = node[part]
        node[parts[-1]] = value
    return cfg


def list_photos(folder: str) -> list[str]:
    photos = sorted(glob.glob(os.path.join(folder, "*.jpg")) + glob.glob(os.path.join(folder, "*.png")))
    if not photos:
        raise SystemExit(f"no photos in {folder}")
    return photos


def run_config(registry, base_cfg: dict, name: str, overrides: list[str], photos: list[str],
               seed: int = 1234, with_metrics: bool = True) -> dict:
    """Run one configuration over every photo (models must already be warm)."""
    from eval import metrics
    from locket_server.van_gogh import stylize_van_gogh

    cfg = apply_overrides(base_cfg, overrides)
    out_dir = SERVER_ROOT / "eval" / "out" / name
    out_dir.mkdir(parents=True, exist_ok=True)
    rows = []
    for path in photos:
        data = Path(path).read_bytes()
        timings: dict = {}
        started = time.time()
        result = stylize_van_gogh(registry, cfg, data, seed=seed, timings=timings)
        total = round(time.time() - started, 2)
        photo = Path(path).stem
        result.save(out_dir / f"{photo}.png")
        row = {"photo": photo, "total": total, **timings}
        if with_metrics:
            original = preprocess.center_square(preprocess.load_oriented(data), 512)
            row["edge_ssim"] = round(metrics.edge_ssim(original, result), 3)
            clip = metrics.clip_style(result)
            face = metrics.face_similarity(original, result)
            row["clip_style"] = None if clip is None else round(clip, 3)
            row["face_sim"] = None if face is None else round(face, 3)
        rows.append(row)
        print(name, json.dumps(row), flush=True)

    def mean(key):
        values = [r[key] for r in rows if r.get(key) is not None]
        return round(statistics.mean(values), 3) if values else None

    summary = {key: mean(key) for key in ("total", "edge_ssim", "clip_style", "face_sim")}
    payload = {"name": name, "overrides": overrides, "config": cfg, "summary": summary,
               "errors": metrics.last_errors(), "rows": rows}
    (out_dir / "results.json").write_text(json.dumps(payload, indent=2), encoding="utf-8")
    print("SUMMARY", name, json.dumps(summary), flush=True)
    return payload


def warm_up(registry, cfg: dict, photo: str, seed: int) -> None:
    """Untimed run that loads every model, so per-photo times are the warm times."""
    from locket_server.van_gogh import stylize_van_gogh

    stylize_van_gogh(registry, cfg, Path(photo).read_bytes(), seed=seed)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--name", required=True)
    parser.add_argument("--config", default="van_gogh.yaml")
    parser.add_argument("--set", action="append", default=[], metavar="dotted.key=value")
    parser.add_argument("--photos", default=str(SERVER_ROOT / "eval" / "photos"))
    parser.add_argument("--seed", type=int, default=1234)
    parser.add_argument("--no-metrics", action="store_true")
    args = parser.parse_args()

    from locket_server.models import load_registry

    base = config.load_yaml(args.config)
    photos = list_photos(args.photos)
    registry = load_registry(base)
    warm_up(registry, base, photos[0], args.seed)
    run_config(registry, base, args.name, args.set, photos, args.seed, not args.no_metrics)


if __name__ == "__main__":
    main()
