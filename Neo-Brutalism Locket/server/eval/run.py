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


def keep_awake() -> None:
    """Windows only, for the life of this process: no idle sleep / Modern Standby while the GPU
    works (the driver logged nvlddmkm errors and CUDA faults around standby transitions)."""
    if os.name == "nt":
        import ctypes

        ES_CONTINUOUS, ES_SYSTEM_REQUIRED, ES_DISPLAY_REQUIRED = 0x80000000, 0x1, 0x2
        ctypes.windll.kernel32.SetThreadExecutionState(
            ES_CONTINUOUS | ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED)


METRIC_KEYS = ("total", "edge_ssim", "palette_shift", "clip_style", "style_generic", "face_sim",
               "face_seam", "face_tone")
_TAGS_FILE = SERVER_ROOT / "eval" / "photo_tags.json"
PHOTO_TAGS: dict = json.loads(_TAGS_FILE.read_text(encoding="utf-8")) if _TAGS_FILE.exists() else {}


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
               seed: int = 1234, with_metrics: bool = True, resume: bool = False,
               max_new: int | None = None) -> dict:
    """Run one configuration over every photo (models must already be warm).

    resume: keep the rows of photos already done in results.json and skip them (failed photos
    are retried). max_new: stop after that many new photos, so a driver can run the set in
    short-lived processes (a CUDA fault poisons the whole process)."""
    from eval import metrics
    from locket_server.van_gogh import stylize_van_gogh

    cfg = apply_overrides(base_cfg, overrides)
    out_dir = SERVER_ROOT / "eval" / "out" / name
    out_dir.mkdir(parents=True, exist_ok=True)
    rows = []
    results_file = out_dir / "results.json"
    if resume and results_file.exists():
        rows = [r for r in json.loads(results_file.read_text(encoding="utf-8"))["rows"]
                if "error" not in r]
    done = {r["photo"] for r in rows}
    new = 0
    from locket_server.van_gogh import _load_reference
    for refs in cfg["references"].values():   # as the server warm-up: no encoder moves mid-run
        for ref in refs if isinstance(refs, list) else [refs]:
            registry.ip_embeds(ref, _load_reference(cfg, ref))
    for path in photos:
        if Path(path).stem in done:
            continue
        if max_new is not None and new >= max_new:
            break
        new += 1
        data = Path(path).read_bytes()
        timings: dict = {}
        started = time.time()
        photo = Path(path).stem
        try:
            result = stylize_van_gogh(registry, cfg, data, seed=seed, timings=timings)
        except RuntimeError as error:   # one bad photo (fp16 NaN twice) must not end the run
            rows.append({"photo": photo, "tag": PHOTO_TAGS.get(photo), "error": str(error)})
            print(name, photo, "FAILED", error, flush=True)
            if any(word in str(error).lower() for word in ("cuda", "cudnn", "cublas")):
                break   # a CUDA fault poisons the process: end this chunk, the driver restarts
            continue
        total = round(time.time() - started, 2)
        result.save(out_dir / f"{photo}.png")
        row = {"photo": photo, "total": total, **timings}
        if with_metrics:
            original = preprocess.center_square(preprocess.load_oriented(data), 512)
            row["tag"] = PHOTO_TAGS.get(photo)
            row["edge_ssim"] = round(metrics.edge_ssim(original, result), 3)
            row["palette_shift"] = round(metrics.palette_shift(original, result), 2)
            for key, value in (("clip_style", metrics.clip_style(result)),
                               ("style_generic", metrics.style_generic(result)),
                               ("face_sim", metrics.face_similarity(original, result)),
                               ("face_seam", metrics.face_seam(original, result)),
                               ("face_tone", metrics.face_tone_shift(original, result))):
                row[key] = None if value is None else round(value, 3)
        rows.append(row)
        print(name, json.dumps(row), flush=True)

    def mean(key):
        values = [r[key] for r in rows if r.get(key) is not None]
        return round(statistics.mean(values), 3) if values else None

    summary = {key: mean(key) for key in METRIC_KEYS}
    by_tag = {}
    for tag in sorted({r.get("tag") or "untagged" for r in rows}):
        subset = [r for r in rows if (r.get("tag") or "untagged") == tag]
        by_tag[tag] = {key: (round(statistics.mean(v), 3) if (v := [r[key] for r in subset
                       if r.get(key) is not None]) else None) for key in METRIC_KEYS}
    payload = {"name": name, "overrides": overrides, "config": cfg, "summary": summary,
               "summary_by_tag": by_tag,
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
    parser.add_argument("--resume", action="store_true", help="skip photos already in results.json")
    parser.add_argument("--max-new", type=int, default=None, help="stop after N new photos")
    args = parser.parse_args()
    keep_awake()

    from locket_server.models import load_registry

    base = config.load_yaml(args.config)
    photos = list_photos(args.photos)
    registry = load_registry(base)
    warm_up(registry, base, photos[0], args.seed)
    run_config(registry, base, args.name, args.set, photos, args.seed, not args.no_metrics,
               args.resume, args.max_new)


if __name__ == "__main__":
    main()
