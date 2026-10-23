"""Run sweep variants in short-lived processes (resumable).

  python -m eval.sweep_chunked cur s2a s2b
  python -m eval.sweep_chunked old:van_gogh_before_k3.yaml new:van_gogh.yaml

`name` alone = overrides of that name in eval/sweep.py on van_gogh.yaml; `name:file.yaml` = that
whole config file (a name that is not in sweep.py then has no overrides).

Each process loads the models, runs at most CHUNK new photos and exits, so a CUDA fault (which
poisons the whole process) costs one chunk, not the sweep. A variant is finished when every
photo has a row without an error; a chunk that makes no progress twice in a row stops it.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from eval.run import keep_awake, list_photos  # noqa: E402
from eval.sweep import SWEEP  # noqa: E402

CHUNK = 15


def done_count(name: str) -> int:
    path = ROOT / "eval" / "out" / name / "results.json"
    if not path.exists():
        return 0
    return sum(1 for r in json.loads(path.read_text(encoding="utf-8"))["rows"] if "error" not in r)


def main() -> None:
    keep_awake()
    folder = os.environ.get("SWEEP_PHOTOS", str(ROOT / "eval" / "photos"))
    total = len(list_photos(folder))
    for arg in sys.argv[1:] or list(SWEEP):
        name, _, config_file = arg.partition(":")
        stalled = 0
        while done_count(name) < total and stalled < 2:
            before = done_count(name)
            cmd = [sys.executable, "-m", "eval.run", "--name", name, "--resume",
                   "--max-new", str(CHUNK), "--photos", folder]
            if config_file:
                cmd += ["--config", config_file]
            for item in SWEEP.get(name, []):
                cmd += ["--set", item]
            print(f"[{name}] {before}/{total} done, starting a chunk", flush=True)
            subprocess.run(cmd, cwd=ROOT)
            stalled = stalled + 1 if done_count(name) == before else 0
        print(f"[{name}] finished: {done_count(name)}/{total}", flush=True)


if __name__ == "__main__":
    main()
