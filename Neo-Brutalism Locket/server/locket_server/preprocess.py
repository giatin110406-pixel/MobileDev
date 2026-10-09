from __future__ import annotations

import hashlib
import io
from dataclasses import dataclass

import numpy as np
from PIL import Image, ImageOps

from .config import WEIGHTS_DIR


def load_oriented(data: bytes) -> Image.Image:
    """Decode bytes, bake EXIF orientation, return RGB."""
    image = Image.open(io.BytesIO(data))
    return ImageOps.exif_transpose(image).convert("RGB")


def center_square(image: Image.Image, size: int) -> Image.Image:
    side = min(image.size)
    left = (image.width - side) // 2
    top = (image.height - side) // 2
    return image.crop((left, top, left + side, top + side)).resize((size, size), Image.LANCZOS)


def seed_from_bytes(data: bytes) -> int:
    return int.from_bytes(hashlib.sha256(data).digest()[:4], "little")


def mean_luma(image: Image.Image) -> float:
    gray = np.asarray(image.convert("L"), dtype=np.float32) / 255.0
    return float(gray.mean())


@dataclass
class Face:
    x: int
    y: int
    w: int
    h: int
    score: float


_detector = None


def _iou(a: Face, b: Face) -> float:
    ix = max(0.0, min(a.x + a.w, b.x + b.w) - max(a.x, b.x))
    iy = max(0.0, min(a.y + a.h, b.y + b.h) - max(a.y, b.y))
    inter = ix * iy
    return inter / (a.w * a.h + b.w * b.h - inter) if inter > 0 else 0.0


def detect_faces(image: Image.Image, min_confidence: float = 0.6) -> list[Face]:
    """Short-range BlazeFace plus the full-range model, merged. The short-range model sees
    only large faces: on a 4-person photo it found 1 face, full-range found 3."""
    import mediapipe as mp

    width, height = image.size
    found = list(_detect_short_range(image, min_confidence))
    with mp.solutions.face_detection.FaceDetection(
            model_selection=1, min_detection_confidence=max(min_confidence, 0.5)) as detector:
        for d in detector.process(np.asarray(image.convert("RGB"))).detections or []:
            box = d.location_data.relative_bounding_box
            face = Face(box.xmin * width, box.ymin * height, box.width * width,
                        box.height * height, float(d.score[0]))
            if face.w > 0 and face.h > 0 and all(_iou(face, other) < 0.3 for other in found):
                found.append(face)
    return sorted(found, key=lambda f: f.w * f.h, reverse=True)


def _detect_short_range(image: Image.Image, min_confidence: float = 0.6) -> list[Face]:
    """MediaPipe BlazeFace (tasks API; the legacy `solutions` API no longer exists)."""
    global _detector
    import mediapipe as mp
    from mediapipe.tasks import python as mp_python
    from mediapipe.tasks.python import vision

    if _detector is None:
        options = vision.FaceDetectorOptions(
            base_options=mp_python.BaseOptions(
                model_asset_path=str(WEIGHTS_DIR / "blaze_face_short_range.tflite")
            ),
            min_detection_confidence=min_confidence,
        )
        _detector = vision.FaceDetector.create_from_options(options)
    mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=np.asarray(image))
    result = _detector.detect(mp_image)
    faces = []
    for detection in result.detections:
        box = detection.bounding_box
        score = detection.categories[0].score if detection.categories else 0.0
        if score >= min_confidence:
            faces.append(Face(box.origin_x, box.origin_y, box.width, box.height, float(score)))
    return sorted(faces, key=lambda f: f.w * f.h, reverse=True)


def make_lineart(registry, image: Image.Image) -> Image.Image:
    detector = registry.lineart()
    detector.to(registry.device)
    out = detector(image, coarse=False, detect_resolution=image.width, image_resolution=image.width)
    detector.to("cpu")
    return out.convert("RGB").resize(image.size, Image.LANCZOS)


def make_depth(registry, image: Image.Image) -> Image.Image:
    depth = registry.depth()(image)["depth"]
    return depth.convert("RGB").resize(image.size, Image.LANCZOS)
