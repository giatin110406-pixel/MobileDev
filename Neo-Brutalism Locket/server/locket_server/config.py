"""Paths and settings. Caches live on D: (C: is nearly full), set before any HF/torch import."""
from __future__ import annotations

import os
from pathlib import Path

SERVER_ROOT = Path(__file__).resolve().parent.parent


def _load_env_file() -> None:
    env_file = SERVER_ROOT / ".env"
    if not env_file.exists():
        return
    for line in env_file.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            key, value = line.split("=", 1)
            os.environ.setdefault(key.strip(), value.strip())


_load_env_file()
os.environ.setdefault("HF_HOME", r"D:\hf-cache")
os.environ.setdefault("TORCH_HOME", r"D:\torch-cache")

CONFIG_DIR = SERVER_ROOT / "configs"
STYLES_DIR = SERVER_ROOT / "styles"
WEIGHTS_DIR = SERVER_ROOT / "weights"


def load_yaml(name: str) -> dict:
    import yaml

    with open(CONFIG_DIR / name, encoding="utf-8") as handle:
        return yaml.safe_load(handle)
