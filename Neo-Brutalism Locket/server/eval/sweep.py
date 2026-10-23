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

# van-gogh-style-face-plan.md, Phase S: Van Gogh technique without the Starry Night palette
S1 = ["main.prompt=post-impressionist oil painting, thick impasto, short broken directional "
      "brushstrokes, bold dark contour lines, visible canvas texture, {subject}, keeping the "
      "original person's face and features",
      "main.negative_portrait_extra=swirls, starry night, cobalt blue sky"]
REFS = ['references.bright_scene=["harvest.jpg", "irises.jpg", "bedroom_arles.jpg", '
        '"sunflowers.jpg", "wheatfield_cypresses.jpg", "almond_blossom.jpg"]',
        'references.dark_scene=["cafe_terrace_night.jpg", "starry_night_rhone.jpg"]',
        'references.sky=["starry_night.jpg", "wheatfield_cypresses.jpg"]',
        "sky_threshold=0.35"]
PORTRAIT_A = ['references.portrait=["la_mousme.jpg", "armand_roulin.jpg", "camille_roulin.jpg"]']
PORTRAIT_B = ['references.portrait=["irises.jpg", "almond_blossom.jpg", "harvest.jpg"]']
SWEEP.update({
    "cur": [],
    "s1": S1,
    "s2a": S1 + REFS + PORTRAIT_A,
    "s2b": S1 + REFS + PORTRAIT_B,
    "s2a_ip04": S1 + REFS + PORTRAIT_A + ["main.ip_adapter_scale_portrait=0.4"],
    "s2b_ip04": S1 + REFS + PORTRAIT_B + ["main.ip_adapter_scale_portrait=0.4"],
    "s2a_ca05": S1 + REFS + PORTRAIT_A + ["main.color_anchor=0.5"],
})


# portrait references with thick brush work and no painted face (Irises, Almond Blossom, The
# Harvest) + colour anchored to the photo, so hair stays hair-coloured (s2a: green hair from the
# Roulin portraits' green background; cur: blue hair from the single wheat-field reference)
SWEEP.update({
    "pa": S1 + REFS + PORTRAIT_B + ["main.color_anchor=0.6"],
    "pb": S1 + REFS + PORTRAIT_B + ["main.color_anchor=1.0"],
})


# Phase F (faces): `pa` + crop from the original photo + strength/reference influence that fall
# with face size (60-90 px faces were re-invented by the model: different person)
FACE_RAMP = ["face.hires=true", "face.px_small=80", "face.px_full=250",
             "face.strength_small=0.3", "face.ip_small=0.15"]
SWEEP.update({
    "g1": SWEEP["pa"] + FACE_RAMP,
    "g2": SWEEP["pa"] + FACE_RAMP + ["face.tone_match=0.8", "face.max_shape_dev=0.25"],
})


# Face pass: the style reference must not paint on faces (blue dabs on chin/cheek); brush
# texture on skin comes from the oil filter, which cannot move a feature; hair is taken from the
# face pass too for small faces.
SWEEP.update({
    "k1": SWEEP["g1"] + ["face.ip_adapter_scale=0.2"],
    "k2": SWEEP["g1"] + ["face.ip_adapter_scale=0.2", "face.skin_paint=0.7"],
    "k3": SWEEP["g1"] + ["face.ip_adapter_scale=0.2", "face.skin_paint=0.7",
                         "face.mask_grow_small=1.5", "face.mask_feather_small=0.08"],
})


# Clearer brush strokes (post-process on the finished painting, faces spared) and fewer steps.
# The main pass already runs only steps * strength (13 of 22) and the face pass 14 of 25.
IMPASTO = ["impasto.strength=1.1", "impasto.face_strength=0.2"]
FAST = ["main.steps=16", "face.steps=18"]
SWEEP.update({
    "imp1": IMPASTO,
    "fast1": FAST,
    "imp1_fast1": IMPASTO + FAST,
})


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
