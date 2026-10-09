"""MediaPipe face-mesh helpers: the landmark control image for the face ControlNet
(CrucibleAI/ControlNetMediaPipeFace, SD1.5) and a face-shaped paste mask."""
from __future__ import annotations

import importlib.util
from functools import lru_cache

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from . import config  # noqa: F401  (sets HF cache dirs)

FACE_REPO = "CrucibleAI/ControlNetMediaPipeFace"


@lru_cache(maxsize=1)
def _laion_face_common():
    """The drawing code that produced the ControlNet's training annotations; it must match."""
    from huggingface_hub import hf_hub_download

    path = hf_hub_download(FACE_REPO, "laion_face_common.py")
    spec = importlib.util.spec_from_file_location("laion_face_common", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def landmark_map(image: Image.Image) -> Image.Image | None:
    """Control image (black background, coloured eyes/brows/lips/oval/pupils) or None if no face."""
    import mediapipe as mp

    rgb = image.convert("RGB")
    with mp.solutions.face_mesh.FaceMesh(static_image_mode=True, max_num_faces=1,
                                         refine_landmarks=True,
                                         min_detection_confidence=0.5) as mesh:
        if not mesh.process(np.asarray(rgb)).multi_face_landmarks:
            return None
    drawn = _laion_face_common().generate_annotation(rgb, 1)
    return Image.fromarray(np.asarray(drawn).astype(np.uint8)).convert("RGB")


def face_mask(image: Image.Image, grow: float = 1.08, feather_fraction: float = 0.04):
    """Soft mask following the real face outline (hull of all mesh points, slightly grown), or None."""
    import mediapipe as mp

    rgb = image.convert("RGB")
    with mp.solutions.face_mesh.FaceMesh(static_image_mode=True, max_num_faces=1,
                                         refine_landmarks=True,
                                         min_detection_confidence=0.5) as mesh:
        found = mesh.process(np.asarray(rgb)).multi_face_landmarks
    if not found:
        return None
    width, height = rgb.size
    points = np.array([(p.x * width, p.y * height) for p in found[0].landmark], np.float32)
    import cv2

    hull = cv2.convexHull(points).reshape(-1, 2)
    centre = hull.mean(axis=0)
    hull = centre + (hull - centre) * grow
    mask = Image.new("L", rgb.size, 0)
    ImageDraw.Draw(mask).polygon([tuple(p) for p in hull], fill=255)
    return mask.filter(ImageFilter.GaussianBlur(max(2.0, min(rgb.size) * feather_fraction)))


def eye_mask(image: Image.Image, grow: float = 1.35, feather_fraction: float = 0.012):
    """Soft mask over both eyes and brows (hull of each side's mesh points), or None."""
    import cv2
    import mediapipe as mp

    rgb = image.convert("RGB")
    with mp.solutions.face_mesh.FaceMesh(static_image_mode=True, max_num_faces=1,
                                         refine_landmarks=True,
                                         min_detection_confidence=0.5) as mesh:
        found = mesh.process(np.asarray(rgb)).multi_face_landmarks
    if not found:
        return None
    fm = mp.solutions.face_mesh
    width, height = rgb.size
    landmarks = found[0].landmark
    mask = Image.new("L", rgb.size, 0)
    draw = ImageDraw.Draw(mask)
    for eye, brow, iris in ((fm.FACEMESH_LEFT_EYE, fm.FACEMESH_LEFT_EYEBROW, fm.FACEMESH_LEFT_IRIS),
                            (fm.FACEMESH_RIGHT_EYE, fm.FACEMESH_RIGHT_EYEBROW, fm.FACEMESH_RIGHT_IRIS)):
        indices = {i for pair in (*eye, *brow, *iris) for i in pair}
        points = np.array([(landmarks[i].x * width, landmarks[i].y * height) for i in indices],
                          np.float32)
        hull = cv2.convexHull(points).reshape(-1, 2)
        centre = hull.mean(axis=0)
        draw.polygon([tuple(p) for p in centre + (hull - centre) * grow], fill=255)
    return mask.filter(ImageFilter.GaussianBlur(max(1.5, min(rgb.size) * feather_fraction)))


def feature_mask(image: Image.Image, eye_grow: float = 1.7, feather_fraction: float = 0.012):
    """Eyes, brows and lips (hulls, grown): the parts that must NOT get a paint filter."""
    import cv2
    import mediapipe as mp

    rgb = image.convert("RGB")
    with mp.solutions.face_mesh.FaceMesh(static_image_mode=True, max_num_faces=1,
                                         refine_landmarks=True,
                                         min_detection_confidence=0.5) as mesh:
        found = mesh.process(np.asarray(rgb)).multi_face_landmarks
    if not found:
        return None
    fm = mp.solutions.face_mesh
    width, height = rgb.size
    landmarks = found[0].landmark
    mask = Image.new("L", rgb.size, 0)
    draw = ImageDraw.Draw(mask)
    groups = ((fm.FACEMESH_LEFT_EYE, fm.FACEMESH_LEFT_EYEBROW, fm.FACEMESH_LEFT_IRIS),
              (fm.FACEMESH_RIGHT_EYE, fm.FACEMESH_RIGHT_EYEBROW, fm.FACEMESH_RIGHT_IRIS),
              (fm.FACEMESH_LIPS,))
    for group in groups:
        indices = {i for part in group for pair in part for i in pair}
        points = np.array([(landmarks[i].x * width, landmarks[i].y * height) for i in indices],
                          np.float32)
        hull = cv2.convexHull(points).reshape(-1, 2)
        centre = hull.mean(axis=0)
        draw.polygon([tuple(p) for p in centre + (hull - centre) * eye_grow], fill=255)
    return mask.filter(ImageFilter.GaussianBlur(max(1.5, min(rgb.size) * feather_fraction)))
