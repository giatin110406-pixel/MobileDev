"""Run several named variants in one process (models load once).

  python -m eval.sweep            # the built-in one-factor-at-a-time sweep below
Variants are lists of dotted overrides applied to configs/van_gogh.yaml.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from eval.run import list_photos, run_config, warm_up  # noqa: E402
from locket_server import config  # noqa: E402
from locket_server.models import load_registry  # noqa: E402

SWEEP = {
    "s55": ["main.strength=0.55"],
    "s65": ["main.strength=0.65"],
    "s75": ["main.strength=0.75"],
    "ip08": ["main.ip_adapter_scale=0.8"],
    "ip10": ["main.ip_adapter_scale=1.0"],
    "g6": ["main.guidance=6.0"],
    "g75": ["main.guidance=7.5"],
    "d2off": ["identity.enabled=false"],
    "d2on": [],
    "f1": ["identity.strength=0.5", "identity.luma_only=true", "identity.mask_w=0.42", "identity.mask_h=0.5"],
    "f2": ["identity.strength=0.8", "identity.luma_only=true", "identity.mask_w=0.42", "identity.mask_h=0.5"],
    "f3": ["face.init=\"source\"", "face.strength=0.5", "identity.strength=0.5", "identity.luma_only=true", "identity.mask_w=0.42", "identity.mask_h=0.5"],
    "f4": ["face.init=\"source\"", "face.strength=0.5", "identity.enabled=false"],
    "g1": ["face.init=\"source\"", "face.strength=0.35", "face.paste_scale=0.6", "face.feather_sigma_fraction=0.08", "identity.enabled=false"],
    "g2": ["face.init=\"source\"", "face.strength=0.45", "face.paste_scale=0.6", "face.feather_sigma_fraction=0.08", "identity.strength=0.5", "identity.luma_only=true", "identity.mask_w=0.42", "identity.mask_h=0.5"],
    "h1": ["face.landmarks=true", "face.init=\"source\"", "identity.enabled=false", "face.strength=0.55", "face.landmark_scale=1.0", "face.lineart_scale=0.5", "face.ip_adapter_scale=0.5"],
    "h2": ["face.landmarks=true", "face.init=\"source\"", "identity.enabled=false", "face.strength=0.65", "face.landmark_scale=1.0", "face.lineart_scale=0.4", "face.ip_adapter_scale=0.6"],
    "k1": ["face.eye_detail=0.7"],
    "k2": ["face.eye_detail=1.0", "face.strength=0.6"],
    "m1": ["face.strength=0.45", "face.eye_detail=1.0", "face.eye_grow=1.7", "face.eye_radius=0.008"],
    "m2": ["face.strength=0.35", "face.eye_detail=1.0", "face.eye_grow=1.7", "face.eye_radius=0.008"],
    "m3": ["face.strength=0.6", "face.ip_adapter_scale=0.8", "face.eye_detail=1.0", "face.eye_grow=1.5"],
    "n1": ["face.strength=0.5", "face.eye_detail=1.0", "face.eye_grow=1.5", "face.eye_radius=0.008"],
    "n2": ["face.strength=0.5", "face.eye_detail=1.0", "face.eye_grow=1.5", "face.eye_radius=0.008", "face.skin_paint=0.7"],
    "n3": ["face.strength=0.45", "face.eye_detail=1.0", "face.eye_grow=1.5", "face.eye_radius=0.008", "face.skin_paint=1.0", "face.oil_size=9"],
    "id07": ["identity.enabled=true"],
    "id10": ["identity.enabled=true", "identity.strength=1.0"],
}


def main() -> None:
    base = config.load_yaml("van_gogh.yaml")
    import os

    folder = os.environ.get("SWEEP_PHOTOS", str(Path(__file__).resolve().parent / "photos"))
    photos = list_photos(folder)
    registry = load_registry(base)
    warm_up(registry, base, photos[0], 1234)
    names = sys.argv[1:] or list(SWEEP)
    for name in names:
        run_config(registry, base, name, SWEEP[name], photos,
                   with_metrics=os.environ.get("SWEEP_METRICS", "1") == "1")


if __name__ == "__main__":
    main()
