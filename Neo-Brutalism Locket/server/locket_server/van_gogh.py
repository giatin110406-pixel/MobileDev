from __future__ import annotations

import time
from typing import Callable

import torch
from PIL import Image, ImageDraw, ImageFilter

from . import config, face_landmarks, preprocess
from .upscale import upscale_x2

StageCallback = Callable[[str, float], None]


def _noop(_stage: str, _fraction: float) -> None:
    return None


def pick_reference(cfg: dict, has_face: bool, luma: float) -> str:
    refs = cfg["references"]
    if has_face:
        return refs["portrait"]
    return refs["dark_scene"] if luma < cfg["dark_luma_threshold"] else refs["bright_scene"]


def _load_reference(cfg: dict, filename: str) -> Image.Image:
    return Image.open(config.STYLES_DIR / "van_gogh" / filename).convert("RGB")


def run_pipe(registry, cfg_main: dict, *, image, lineart, depth, depth_scale, prompt,
              negative, strength, steps, reference, seed, stage_cb, stage_name, stage_span,
              pipe=None):
    """[lineart, depth] on the main pipeline; pass `pipe=registry.face_pipe()` and the landmark
    map as `depth` to run [lineart, face landmarks] instead."""
    pipe = pipe or registry.pipe()
    pipe.set_ip_adapter_scale(cfg_main["ip_adapter_scale"])
    generator = torch.Generator(device="cpu").manual_seed(seed)

    def on_step_end(_pipe, step, _timestep, kwargs):
        stage_cb(stage_name, stage_span[0] + (stage_span[1] - stage_span[0]) * (step + 1) / max(
            1, int(steps * strength)))
        return kwargs

    return pipe(
        prompt=prompt,
        negative_prompt=negative,
        image=image,
        control_image=[lineart, depth],
        ip_adapter_image=reference,
        strength=strength,
        num_inference_steps=steps,
        guidance_scale=cfg_main["guidance"],
        controlnet_conditioning_scale=[cfg_main["lineart_scale"], depth_scale],
        control_guidance_end=cfg_main["control_guidance_end"],
        generator=generator,
        callback_on_step_end=on_step_end,
    ).images[0]


def patch_deviation(patch: Image.Image, reference: Image.Image) -> float:
    """Mean abs difference of 48 px thumbnails (0-255). Painting vs photo is ~20-45; a black or
    garbage patch from a numeric fault is far above that. NaN/blank counts as infinite."""
    import numpy as np

    a = np.asarray(patch.convert("RGB").resize((48, 48), Image.BOX), np.float32)
    b = np.asarray(reference.convert("RGB").resize((48, 48), Image.BOX), np.float32)
    if not np.isfinite(a).all() or a.mean() < 6:
        return float("inf")
    return float(np.abs(a - b).mean())


def restore_eyes(patch: Image.Image, source: Image.Image, mask: Image.Image, strength: float,
                 radius: float) -> Image.Image:
    """Bring the photo's fine brightness detail (lids, iris, highlights) back into the eyes and
    brows only; colours and brush work stay painted, so eyes look real, not cartoon."""
    import numpy as np

    patch = patch.convert("RGB")
    src = source.resize(patch.size, Image.LANCZOS)
    p = np.asarray(patch, np.float32)
    s = np.asarray(src, np.float32)
    bp = np.asarray(patch.filter(ImageFilter.GaussianBlur(radius)), np.float32)
    bs = np.asarray(src.filter(ImageFilter.GaussianBlur(radius)), np.float32)
    detail = ((s - bs) - (p - bp)).mean(axis=2, keepdims=True)
    weight = np.asarray(mask.resize(patch.size, Image.LANCZOS), np.float32)[..., None] / 255.0
    return Image.fromarray(np.clip(p + detail * weight * strength, 0, 255).astype(np.uint8))


def skin_paint(patch: Image.Image, features: Image.Image | None, amount: float,
               size: int = 7, dyn: int = 3) -> Image.Image:
    """Oil-paint filter on the face skin only (not eyes/brows/lips): brush texture without
    moving any feature, so identity cannot drift."""
    import cv2
    import numpy as np

    rgb = np.asarray(patch.convert("RGB"))
    oil = cv2.xphoto.oilPainting(cv2.cvtColor(rgb, cv2.COLOR_RGB2BGR), size, dyn)
    oil = cv2.cvtColor(oil, cv2.COLOR_BGR2RGB).astype(np.float32)
    weight = np.full(rgb.shape[:2], amount, np.float32)
    if features is not None:
        weight *= 1.0 - np.asarray(features.resize(patch.size), np.float32) / 255.0
    weight = weight[..., None]
    return Image.fromarray(np.clip(rgb * (1 - weight) + oil * weight, 0, 255).astype(np.uint8))


def _mask_paste(base: Image.Image, patch: Image.Image, box: tuple[int, int, int, int],
                mask: Image.Image) -> None:
    size = (box[2] - box[0], box[3] - box[1])
    base.paste(patch.resize(size, Image.LANCZOS), (box[0], box[1]), mask.resize(size, Image.LANCZOS))


def _feather_paste(base: Image.Image, patch: Image.Image, box: tuple[int, int, int, int],
                   sigma_fraction: float, paste_scale: float = 0.84) -> None:
    left, top, right, bottom = box
    patch = patch.resize((right - left, bottom - top), Image.LANCZOS)
    mask = Image.new("L", patch.size, 0)
    inset = int(min(patch.size) * (1 - paste_scale) / 2)
    ImageDraw.Draw(mask).ellipse((inset, inset, patch.width - inset, patch.height - inset), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(min(patch.size) * sigma_fraction))
    base.paste(patch, (left, top), mask)


def _is_blank(image: Image.Image) -> bool:
    import numpy as np

    return float(np.asarray(image.convert("L"), np.float32).mean()) < 4.0


def identity_blend(painted: Image.Image, source: Image.Image, faces, strength: float,
                   radius_fraction: float, feather_fraction: float, luma_only: bool = False,
                   mask_w: float = 0.55, mask_h: float = 0.6) -> Image.Image:
    """Put the original face's fine detail (eyelids, brows, iris, lips) back into the painting.

    Frequency separation inside a soft face ellipse: result = painted + strength * (hp(source) -
    hp(painted)), where hp is image minus its Gaussian blur. Colours and brush work stay painted;
    only the small features that diffusion distorts come from the photo."""
    import numpy as np

    out = np.asarray(painted, np.float32).copy()
    src = np.asarray(source.resize(painted.size, Image.LANCZOS), np.float32)
    for face in faces:
        radius = max(1.0, max(face.w, face.h) * radius_fraction)
        blur_p = np.asarray(painted.filter(ImageFilter.GaussianBlur(radius)), np.float32)
        blur_s = np.asarray(source.resize(painted.size, Image.LANCZOS).filter(
            ImageFilter.GaussianBlur(radius)), np.float32)
        detail = (src - blur_s) - (out - blur_p)
        if luma_only:   # move only brightness detail, so colours stay painted
            detail = detail.mean(axis=2, keepdims=True).repeat(3, axis=2)
        mask = Image.new("L", painted.size, 0)
        cx, cy = face.x + face.w / 2, face.y + face.h / 2
        ImageDraw.Draw(mask).ellipse((cx - face.w * mask_w, cy - face.h * mask_h,
                                      cx + face.w * mask_w, cy + face.h * mask_h), fill=255)
        mask = mask.filter(ImageFilter.GaussianBlur(max(face.w, face.h) * feather_fraction))
        weight = np.asarray(mask, np.float32)[..., None] / 255.0 * strength
        out = out + detail * weight
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))


def stylize_van_gogh(registry, cfg: dict, data: bytes, *, seed: int | None = None,
                     stage_cb: StageCallback = _noop, timings: dict | None = None) -> Image.Image:
    timings = timings if timings is not None else {}

    def lap(name: str, start: float) -> None:
        timings[name] = round(time.time() - start, 2)

    t = time.time()
    seed = preprocess.seed_from_bytes(data) if seed is None else seed
    size = cfg["working_size"]
    source = preprocess.center_square(preprocess.load_oriented(data), size)
    stage_cb("preparing", 0.02)
    faces = preprocess.detect_faces(source, cfg["face"]["min_confidence"]) if cfg["face"]["enabled"] else []
    reference = _load_reference(cfg, pick_reference(cfg, bool(faces), preprocess.mean_luma(source)))
    lineart = preprocess.make_lineart(registry, source)
    depth = preprocess.make_depth(registry, source)
    lap("preprocess", t)

    main = cfg["main"]
    subject = "portrait of a person" if faces else "scene"
    prompt = main["prompt"].format(subject=subject)

    def generate(fn):
        try:
            return fn()
        except torch.cuda.OutOfMemoryError:
            registry.enable_offload()
            return fn()

    t = time.time()
    stage_cb("painting", 0.08)
    painted = generate(lambda: run_pipe(
        registry, main, image=source, lineart=lineart, depth=depth,
        depth_scale=main["depth_scale"], prompt=prompt, negative=main["negative_prompt"],
        strength=main["strength"], steps=main["steps"], reference=reference, seed=seed,
        stage_cb=stage_cb, stage_name="painting", stage_span=(0.08, 0.70)))
    if _is_blank(painted):   # rare fp16 NaN -> black frame: redo once with another seed
        painted = generate(lambda: run_pipe(
            registry, main, image=source, lineart=lineart, depth=depth,
            depth_scale=main["depth_scale"], prompt=prompt, negative=main["negative_prompt"],
            strength=main["strength"], steps=main["steps"], reference=reference, seed=seed + 101,
            stage_cb=stage_cb, stage_name="painting", stage_span=(0.08, 0.70)))
        if _is_blank(painted):
            raise RuntimeError("diffusion produced a blank image twice")
    lap("main_pass", t)

    t = time.time()
    face_cfg = cfg["face"]
    for index, face in enumerate(faces[:face_cfg.get("max_faces", 4)]):
        stage_cb("refining face", 0.70 + 0.12 * index / max(1, len(faces)))
        cx, cy = face.x + face.w / 2, face.y + face.h / 2
        half = max(face.w, face.h) * face_cfg["expand"] / 2
        box = (int(max(cx - half, 0)), int(max(cy - half, 0)),
               int(min(cx + half, size)), int(min(cy + half, size)))
        if box[2] - box[0] < 32 or box[3] - box[1] < 32:
            continue
        crop_size = face_cfg["size"]
        source_crop = source.crop(box).resize((crop_size, crop_size), Image.LANCZOS)
        painted_crop = (source_crop if face_cfg.get("init") == "source" else
                        painted.crop(box).resize((crop_size, crop_size), Image.LANCZOS))
        face_lineart = preprocess.make_lineart(registry, source_crop)
        face_main = dict(
            main,
            lineart_scale=face_cfg["lineart_scale"],
            ip_adapter_scale=face_cfg.get("ip_adapter_scale", main["ip_adapter_scale"]),
        )
        landmarks = face_landmarks.landmark_map(source_crop) if face_cfg.get("landmarks") else None
        if face_cfg.get("landmarks") and landmarks is None:
            continue   # detector false positive (no real face mesh): leave the painting untouched
        if landmarks is not None:
            # eyes, brows, lips, pupils are pinned by the landmark ControlNet, so the face can be
            # painted at a high strength (real brush work) without distorting them
            patch = None
            for attempt in range(2):   # a numeric fault gives a black/garbage patch: redo once
                candidate = generate(lambda: run_pipe(
                    registry, face_main, image=painted_crop, lineart=face_lineart, depth=landmarks,
                    depth_scale=face_cfg["landmark_scale"],
                    prompt=prompt + ", " + face_cfg["prompt_extra"],
                    negative=main["negative_prompt"], strength=face_cfg["strength"],
                    steps=face_cfg["steps"], reference=reference,
                    seed=seed + index + 1 + 1000 * attempt,
                    stage_cb=stage_cb, stage_name="refining face", stage_span=(0.72, 0.82),
                    pipe=registry.face_pipe()))
                deviation = patch_deviation(candidate, source_crop)
                timings.setdefault("face_patch_deviation", []).append(round(deviation, 1))
                if deviation <= face_cfg.get("max_deviation", 70):
                    patch = candidate
                    break
            if patch is None:
                continue   # twice faulty: keep the main-pass painting for this face
            if face_cfg.get("skin_paint", 0) > 0:
                features = face_landmarks.feature_mask(source_crop, face_cfg.get("eye_grow", 1.7))
                patch = skin_paint(patch, features, face_cfg["skin_paint"],
                                   face_cfg.get("oil_size", 7), face_cfg.get("oil_dyn", 3))
            if face_cfg.get("eye_detail", 0) > 0:
                eyes = face_landmarks.eye_mask(source_crop, face_cfg.get("eye_grow", 1.35))
                if eyes is not None:
                    patch = restore_eyes(patch, source_crop, eyes, face_cfg["eye_detail"],
                                         face_cfg.get("eye_radius", 0.012) * crop_size)
            mask = face_landmarks.face_mask(source_crop, face_cfg.get("mask_grow", 1.08),
                                            face_cfg.get("mask_feather", 0.04))
            if mask is not None:
                _mask_paste(painted, patch, box, mask)
                continue
            _feather_paste(painted, patch, box, face_cfg["feather_sigma_fraction"],
                           face_cfg.get("paste_scale", 0.84))
            continue
        patch = generate(lambda: run_pipe(
            registry, face_main, image=painted_crop, lineart=face_lineart, depth=face_lineart,
            depth_scale=0.0, prompt=prompt + ", " + face_cfg["prompt_extra"],
            negative=main["negative_prompt"], strength=face_cfg["strength"],
            steps=face_cfg["steps"], reference=reference, seed=seed + index + 1,
            stage_cb=stage_cb, stage_name="refining face", stage_span=(0.72, 0.82)))
        _feather_paste(painted, patch, box, face_cfg["feather_sigma_fraction"],
                       face_cfg.get("paste_scale", 0.84))
    ident = cfg.get("identity", {})
    if faces and ident.get("enabled", False):
        painted = identity_blend(painted, source, faces, ident["strength"],
                                 ident["radius_fraction"], ident["feather_fraction"],
                                 ident.get("luma_only", False), ident.get("mask_w", 0.55),
                                 ident.get("mask_h", 0.6))
    lap("face_pass", t)

    t = time.time()
    stage_cb("upscaling", 0.85)
    registry.free()
    big = upscale_x2(painted, registry.device)
    result = big.resize((cfg["output_size"], cfg["output_size"]), Image.LANCZOS)
    lap("upscale", t)
    stage_cb("done", 1.0)
    return result
