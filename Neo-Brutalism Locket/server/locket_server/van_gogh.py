from __future__ import annotations

import time
from typing import Callable

import torch
from PIL import Image, ImageDraw, ImageFilter

from . import config, face_landmarks, output_check, preprocess
from .upscale import upscale_x2

StageCallback = Callable[[str, float], None]


def _noop(_stage: str, _fraction: float) -> None:
    return None


# The phone's scene guess (lib/features/image_engine/scene_guess.dart) -> reference set. It
# replaces the brightness / sky rules, which were measured worse (eval.export_scene_labels).
PHONE_SCENES = {"night": "dark_scene", "sky": "sky", "day": "bright_scene"}


def pick_reference(cfg: dict, has_face: bool, luma: float, seed: int = 0,
                   sky: float = 0.0, scene: str | None = None) -> str:
    """Scene type -> reference set; a set is a list, picked by seed (same photo, same painting).
    A found face always means the portrait set. Otherwise the phone's `scene` decides when it
    sent one; without it, the sky set (Starry Night) only when `sky_threshold` is set and the
    top is mostly sky."""
    refs = cfg["references"]
    if has_face:
        key = "portrait"
    elif scene in PHONE_SCENES and PHONE_SCENES[scene] in refs:
        key = PHONE_SCENES[scene]
    elif luma < cfg["dark_luma_threshold"]:
        key = "dark_scene"
    elif cfg.get("sky_threshold") is not None and sky >= cfg["sky_threshold"]:
        key = "sky"
    else:
        key = "bright_scene"
    choice = refs[key]
    return choice[seed % len(choice)] if isinstance(choice, list) else choice


def color_anchor(painted: Image.Image, source: Image.Image, amount: float,
                 radius_fraction: float) -> Image.Image:
    """Pull the painting's local colour (Lab a/b, blurred) back toward the photo's, keeping
    brightness and brush strokes: black hair stays dark instead of turning cobalt."""
    import numpy as np
    from skimage.color import lab2rgb, rgb2lab

    radius = max(2.0, painted.width * radius_fraction)
    src = source.resize(painted.size, Image.LANCZOS)
    lab_p = rgb2lab(np.asarray(painted.convert("RGB"), np.float32) / 255.0)
    blur_p = rgb2lab(np.asarray(painted.filter(ImageFilter.GaussianBlur(radius)), np.float32) / 255.0)
    blur_s = rgb2lab(np.asarray(src.filter(ImageFilter.GaussianBlur(radius)), np.float32) / 255.0)
    lab_p[..., 1:] += amount * (blur_s[..., 1:] - blur_p[..., 1:])
    return Image.fromarray((np.clip(lab2rgb(lab_p), 0, 1) * 255).round().astype(np.uint8))


def match_color(patch: Image.Image, target: Image.Image, mask: Image.Image | None,
                amount: float) -> Image.Image:
    """Match the face patch's Lab mean/std to the main-pass painting of the same area, so the
    repainted face has the painting's tone instead of the photo's (no 'pasted' look)."""
    import numpy as np
    from skimage.color import lab2rgb, rgb2lab

    p = rgb2lab(np.asarray(patch.convert("RGB"), np.float32) / 255.0)
    t = rgb2lab(np.asarray(target.convert("RGB").resize(patch.size, Image.LANCZOS), np.float32) / 255.0)
    weight = (np.ones(p.shape[:2], bool) if mask is None else
              np.asarray(mask.resize(patch.size), np.float32) > 127)
    if weight.sum() < 64:
        return patch
    matched = p.copy()
    for channel in range(3):
        pm, ps = p[..., channel][weight].mean(), p[..., channel][weight].std() + 1e-3
        tm, ts = t[..., channel][weight].mean(), t[..., channel][weight].std() + 1e-3
        matched[..., channel] = (p[..., channel] - pm) * ts / ps + tm
    out = p + amount * (matched - p)
    return Image.fromarray((np.clip(lab2rgb(out), 0, 1) * 255).round().astype(np.uint8))


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
        ip_adapter_image_embeds=reference,
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
                     scene: str | None = None, stage_cb: StageCallback = _noop,
                     timings: dict | None = None) -> Image.Image:
    timings = timings if timings is not None else {}

    def lap(name: str, start: float) -> None:
        timings[name] = round(time.time() - start, 2)

    t = time.time()
    seed = preprocess.seed_from_bytes(data) if seed is None else seed
    size = cfg["working_size"]
    raw = preprocess.load_oriented(data)
    source = preprocess.center_square(raw, size)
    side = min(raw.size)
    raw_square = raw.crop(((raw.width - side) // 2, (raw.height - side) // 2,
                           (raw.width - side) // 2 + side, (raw.height - side) // 2 + side))
    stage_cb("preparing", 0.02)
    faces = preprocess.detect_faces(source, cfg["face"]["min_confidence"]) if cfg["face"]["enabled"] else []
    sky = preprocess.sky_fraction(source) if cfg.get("sky_threshold") is not None else 0.0
    # picked by the photo's hash, not `seed`: the eval runs every photo with one fixed seed
    reference_name = pick_reference(cfg, bool(faces), preprocess.mean_luma(source),
                                    preprocess.seed_from_bytes(data), sky, scene)
    timings["reference"] = reference_name
    reference = registry.ip_embeds(reference_name, _load_reference(cfg, reference_name))
    lineart = preprocess.make_lineart(registry, source)
    depth = preprocess.make_depth(registry, source)
    lap("preprocess", t)

    main = cfg["main"]
    if faces and main.get("ip_adapter_scale_portrait") is not None:
        main = dict(main, ip_adapter_scale=main["ip_adapter_scale_portrait"])
    subject = "portrait of a person" if faces else "scene"
    prompt = main["prompt"].format(subject=subject)
    negative = main["negative_prompt"]
    if faces and main.get("negative_portrait_extra"):
        negative = negative + ", " + main["negative_portrait_extra"]

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
        depth_scale=main["depth_scale"], prompt=prompt, negative=negative,
        strength=main["strength"], steps=main["steps"], reference=reference, seed=seed,
        stage_cb=stage_cb, stage_name="painting", stage_span=(0.08, 0.70)))
    # a GPU fault can blank or fill only part of the frame: redo once with another seed
    if _is_blank(painted) or output_check.is_broken(painted, source):
        timings["main_retry"] = True
        painted = generate(lambda: run_pipe(
            registry, main, image=source, lineart=lineart, depth=depth,
            depth_scale=main["depth_scale"], prompt=prompt, negative=negative,
            strength=main["strength"], steps=main["steps"], reference=reference, seed=seed + 101,
            stage_cb=stage_cb, stage_name="painting", stage_span=(0.08, 0.70)))
        if _is_blank(painted) or output_check.is_broken(painted, source):
            raise RuntimeError("diffusion produced a blank image twice")
    if main.get("color_anchor", 0) > 0:
        painted = color_anchor(painted, source, main["color_anchor"],
                               main.get("color_anchor_radius", 0.03))
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
        if face_cfg.get("hires") and side > size:   # real pixels of the original, not the 640 copy
            k = side / size
            hi_box = tuple(int(round(v * k)) for v in box)
            source_crop = raw_square.crop(hi_box).resize((crop_size, crop_size), Image.LANCZOS)
        else:
            source_crop = source.crop(box).resize((crop_size, crop_size), Image.LANCZOS)
        painted_crop = (source_crop if face_cfg.get("init") == "source" else
                        painted.crop(box).resize((crop_size, crop_size), Image.LANCZOS))
        face_lineart = preprocess.make_lineart(registry, source_crop)
        # The smaller the face, the less the model may invent: at 60-90 px it has to make up eyes
        # and mouth, which changes the person. Strength and style-reference influence ramp from
        # `*_small` (face <= px_small px wide in the original photo) to the normal values
        # (face >= px_full px).
        face_px = face.w * side / size
        if face_cfg.get("px_full"):
            ramp = min(1.0, max(0.0, (face_px - face_cfg["px_small"])
                                / (face_cfg["px_full"] - face_cfg["px_small"])))
        else:
            ramp = 1.0
        face_strength = face_cfg.get("strength_small", face_cfg["strength"]) + ramp * (
            face_cfg["strength"] - face_cfg.get("strength_small", face_cfg["strength"]))
        face_ip = face_cfg.get("ip_small", face_cfg.get("ip_adapter_scale", main["ip_adapter_scale"])) + ramp * (
            face_cfg.get("ip_adapter_scale", main["ip_adapter_scale"])
            - face_cfg.get("ip_small", face_cfg.get("ip_adapter_scale", main["ip_adapter_scale"])))
        timings.setdefault("face_px", []).append(round(face_px))
        face_main = dict(main, lineart_scale=face_cfg["lineart_scale"], ip_adapter_scale=face_ip)
        landmarks = face_landmarks.landmark_map(source_crop) if face_cfg.get("landmarks") else None
        if face_cfg.get("landmarks") and landmarks is None:
            continue   # detector false positive (no real face mesh): leave the painting untouched
        if landmarks is not None:
            # eyes, brows, lips, pupils are pinned by the landmark ControlNet, so the face can be
            # painted at a high strength (real brush work) without distorting them
            # a numeric fault gives a black/garbage patch: redo once. With the shape guard on, a
            # patch whose eyes/mouth moved is also redone: new seed, then a lower strength.
            max_shape = face_cfg.get("max_shape_dev")
            source_points = face_landmarks.face_points(source_crop)
            attempts = [(0, face_strength), (1, face_strength)]
            if max_shape is not None:
                attempts.append((2, face_strength - 0.1))
            patch, best = None, None
            for attempt, strength in attempts:
                candidate = generate(lambda: run_pipe(
                    registry, face_main, image=painted_crop, lineart=face_lineart, depth=landmarks,
                    depth_scale=face_cfg["landmark_scale"],
                    prompt=prompt + ", " + face_cfg["prompt_extra"],
                    negative=negative, strength=strength,
                    steps=face_cfg["steps"], reference=reference,
                    seed=seed + index + 1 + 1000 * attempt,
                    stage_cb=stage_cb, stage_name="refining face", stage_span=(0.72, 0.82),
                    pipe=registry.face_pipe()))
                deviation = patch_deviation(candidate, source_crop)
                timings.setdefault("face_patch_deviation", []).append(round(deviation, 1))
                if deviation > face_cfg.get("max_deviation", 70):
                    continue
                points = face_landmarks.face_points(candidate) if source_points is not None else None
                shape = (face_landmarks.shape_deviation(source_points, points)
                         if points is not None else None)
                timings.setdefault("face_shape_dev", []).append(
                    None if shape is None else round(shape, 3))
                if max_shape is None or shape is None or shape <= max_shape:
                    patch = candidate
                    break
                if best is None or shape < best[0]:
                    best = (shape, candidate)
            if patch is None and best is not None:
                patch = best[1]   # every try moved a feature: keep the least moved
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
            grow = face_cfg.get("mask_grow", 1.08)
            feather = face_cfg.get("mask_feather", 0.04)
            if "mask_grow_small" in face_cfg:   # small faces: take hair and neck from the face pass too
                grow = face_cfg["mask_grow_small"] + ramp * (grow - face_cfg["mask_grow_small"])
                feather = face_cfg.get("mask_feather_small", feather) + ramp * (
                    feather - face_cfg.get("mask_feather_small", feather))
            mask = face_landmarks.face_mask(source_crop, grow, feather)
            if face_cfg.get("tone_match", 0) > 0:   # skin tone comes from the photo, not the reference
                patch = match_color(patch, source_crop, mask, face_cfg["tone_match"])
            if face_cfg.get("color_match", 0) > 0:
                patch = match_color(patch, painted.crop(box), mask, face_cfg["color_match"])
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
    if output_check.upscale_broken(big, painted):   # a garbage tile: once more, then plain bicubic
        timings["upscale_retry"] = True
        big = upscale_x2(painted, registry.device)
        if output_check.upscale_broken(big, painted):
            timings["upscale_fallback"] = True
            big = painted.resize((painted.width * 2, painted.height * 2), Image.BICUBIC)
    result = big.resize((cfg["output_size"], cfg["output_size"]), Image.LANCZOS)
    lap("upscale", t)
    stage_cb("done", 1.0)
    return result
