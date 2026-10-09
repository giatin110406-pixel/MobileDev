from __future__ import annotations

import argparse
import json
import time
from pathlib import Path

from . import config


def main() -> None:
    parser = argparse.ArgumentParser(prog="locket_server.cli")
    sub = parser.add_subparsers(dest="command", required=True)
    stylize = sub.add_parser("stylize")
    stylize.add_argument("--style", default="van_gogh", choices=["van_gogh"])
    stylize.add_argument("input")
    stylize.add_argument("-o", "--output", required=True)
    stylize.add_argument("--seed", type=int)
    stylize.add_argument("--config", default="van_gogh.yaml")
    args = parser.parse_args()

    from .models import load_registry
    from .van_gogh import stylize_van_gogh

    cfg = config.load_yaml(args.config)
    registry = load_registry(cfg)
    timings: dict = {}
    started = time.time()
    result = stylize_van_gogh(
        registry, cfg, Path(args.input).read_bytes(), seed=args.seed,
        stage_cb=lambda stage, fraction: print(f"[{fraction:5.0%}] {stage}", flush=True),
        timings=timings)
    result.save(args.output)
    print(json.dumps({"timings": timings, "total": round(time.time() - started, 1)}))


if __name__ == "__main__":
    main()
