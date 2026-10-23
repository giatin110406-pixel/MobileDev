"""Packs the engine source into colab/_staging/server.tar, the only file you upload to Google Drive
(folder MyDrive/locket/). Run again after changing the engine, then replace the file in Drive.

    python colab/pack_code.py
"""
from __future__ import annotations

import tarfile
from pathlib import Path

SERVER = Path(__file__).resolve().parent.parent
OUT = SERVER / "colab" / "_staging" / "server.tar"
ITEMS = ["locket_server", "configs", "styles", "requirements.txt", "download_models.py"]
# Only what the Colab eval notebook runs: not eval/out (hundreds of MB), the photos, or the
# quest scripts that live in the same folder.
EVAL_FILES = ["__init__.py", "metrics.py", "run.py", "sweep.py", "sweep_chunked.py", "summary.py",
              "photo_tags.json"]


def skip_cache(info: tarfile.TarInfo) -> tarfile.TarInfo | None:
    return None if "__pycache__" in info.name or info.name.endswith(".pyc") else info


def main() -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with tarfile.open(OUT, "w") as tar:
        for item in ITEMS:
            tar.add(SERVER / item, arcname=f"server/{item}", filter=skip_cache)
        for name in EVAL_FILES:
            tar.add(SERVER / "eval" / name, arcname=f"server/eval/{name}")
    print(f"wrote {OUT} ({OUT.stat().st_size / 1e6:.1f} MB): upload it to Google Drive -> MyDrive/locket/")


if __name__ == "__main__":
    main()
