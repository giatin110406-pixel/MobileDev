"""Automatic quality signals for the eval harness. They support, never replace, looking at the
side-by-side report. Heavy models load lazily; a missing optional package yields None."""
from __future__ import annotations

import numpy as np
from PIL import Image

_state: dict = {}


def edge_ssim(original: Image.Image, result: Image.Image, size: int = 512) -> float:
    """Structure kept: SSIM of blurred Canny edge maps (1.0 = same edges)."""
    import cv2
    from skimage.metrics import structural_similarity

    def edges(im: Image.Image) -> np.ndarray:
        gray = np.asarray(im.convert("L").resize((size, size), Image.LANCZOS))
        edge = cv2.Canny(gray, 80, 160)
        return cv2.GaussianBlur(edge, (0, 0), 2.0)

    return float(structural_similarity(edges(original), edges(result), data_range=255))


def _clip():
    if "clip" not in _state:
        import open_clip
        import torch

        model, _, preprocess = open_clip.create_model_and_transforms(
            "ViT-B-32", pretrained="laion2b_s34b_b79k")
        tokenizer = open_clip.get_tokenizer("ViT-B-32")
        model.eval()
        with torch.no_grad():
            text = model.encode_text(tokenizer(
                ["an oil painting by Vincent van Gogh", "a photograph",
                 "a post-impressionist oil painting with thick short brushstrokes",
                 "The Starry Night by Vincent van Gogh, swirling blue and yellow sky"]))
            text = text / text.norm(dim=-1, keepdim=True)
        _state["clip"] = (model, preprocess, text)
    return _state["clip"]


def _clip_sims(result: Image.Image):
    import torch

    model, preprocess, text = _clip()
    with torch.no_grad():
        feat = model.encode_image(preprocess(result.convert("RGB")).unsqueeze(0))
        feat = feat / feat.norm(dim=-1, keepdim=True)
        return (feat @ text.T)[0]


def clip_style(result: Image.Image) -> float | None:
    """Higher = looks more like a Van Gogh painting than a photograph."""
    try:
        sims = _clip_sims(result)
        return float(sims[0] - sims[1])
    except Exception as error:  # noqa: BLE001
        _state.setdefault("clip_error", str(error))
        return None


def style_generic(result: Image.Image) -> float | None:
    """Higher = Van Gogh technique without copying one painting; low = 'Starry Night filter'."""
    try:
        sims = _clip_sims(result)
        return float(sims[2] - sims[3])
    except Exception as error:  # noqa: BLE001
        _state.setdefault("clip_error", str(error))
        return None


def palette_shift(original: Image.Image, result: Image.Image, size: int = 32) -> float:
    """Mean CIE76 delta-E between heavily downsized photo and result. Brush strokes vanish at
    32 px, so this measures colours replaced (black hair painted cobalt), not texture."""
    from skimage.color import rgb2lab

    def lab(im: Image.Image) -> np.ndarray:
        small = im.convert("RGB").resize((size, size), Image.BOX)
        return rgb2lab(np.asarray(small, np.float32) / 255.0)

    return float(np.linalg.norm(lab(original) - lab(result), axis=2).mean())


def _hf_energy(gray: np.ndarray) -> np.ndarray:
    import cv2

    return np.abs(gray - cv2.GaussianBlur(gray, (0, 0), 1.5))


def face_seam(original: Image.Image, result: Image.Image, size: int = 512) -> float | None:
    """How much smoother the face is than the painting around it, relative to the photo.
    log(texture outside / inside) in the result minus the same in the photo: 0 = the face is
    painted like its surroundings, > 0 = a smooth 'pasted photo' face. None without a face."""
    try:
        import cv2

        from locket_server import face_landmarks, preprocess

        original = original.convert("RGB").resize((size, size), Image.LANCZOS)
        result = result.convert("RGB").resize((size, size), Image.LANCZOS)
        faces = preprocess.detect_faces(original, 0.5)
        if not faces:
            return None
        face = faces[0]
        cx, cy = face.x + face.w / 2, face.y + face.h / 2
        half = max(face.w, face.h) * 0.9
        box = (int(max(cx - half, 0)), int(max(cy - half, 0)),
               int(min(cx + half, size)), int(min(cy + half, size)))
        crop_mask = face_landmarks.face_mask(original.crop(box), 1.0, 0.0)
        if crop_mask is None:
            return None
        mask = np.zeros((size, size), np.uint8)
        mask[box[1]:box[3], box[0]:box[2]] = (np.asarray(crop_mask) > 127).astype(np.uint8)
        ring_px = max(3, int(max(face.w, face.h) * 0.2))
        kernel = np.ones((ring_px, ring_px), np.uint8)
        inside = cv2.erode(mask, np.ones((5, 5), np.uint8)).astype(bool)
        ring = (cv2.dilate(mask, kernel) - mask).astype(bool)
        if inside.sum() < 50 or ring.sum() < 50:
            return None

        def gap(im: Image.Image) -> float:
            energy = _hf_energy(np.asarray(im.convert("L"), np.float32))
            return float(np.log((energy[ring].mean() + 1e-3) / (energy[inside].mean() + 1e-3)))

        return gap(result) - gap(original)
    except Exception as error:  # noqa: BLE001
        _state.setdefault("seam_error", str(error))
        return None


def _face_net():
    if "face" not in _state:
        from facenet_pytorch import InceptionResnetV1

        _state["face"] = InceptionResnetV1(pretrained="vggface2").eval()
    return _state["face"]


def _face_embedding(image: Image.Image, face) -> "np.ndarray":
    import torch

    cx, cy = face.x + face.w / 2, face.y + face.h / 2
    half = max(face.w, face.h) * 0.75
    crop = image.crop((int(cx - half), int(cy - half), int(cx + half), int(cy + half)))
    crop = crop.convert("RGB").resize((160, 160), Image.LANCZOS)
    tensor = torch.from_numpy(np.asarray(crop, np.float32)).permute(2, 0, 1)
    tensor = ((tensor - 127.5) / 128.0).unsqueeze(0)
    with torch.no_grad():
        return _face_net()(tensor)[0].numpy()


def face_similarity(original: Image.Image, result: Image.Image) -> float | None:
    """Cosine similarity of face embeddings (largest face). None when no face is found in
    either image (a heavily painted face may not be detected, which is itself a signal)."""
    try:
        from locket_server import preprocess

        size = 512
        original = original.convert("RGB").resize((size, size), Image.LANCZOS)
        result = result.convert("RGB").resize((size, size), Image.LANCZOS)
        faces_a = preprocess.detect_faces(original, 0.5)
        faces_b = preprocess.detect_faces(result, 0.4)
        if not faces_a or not faces_b:
            return None
        a = _face_embedding(original, faces_a[0])
        b = _face_embedding(result, faces_b[0])
        return float(np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b)))
    except Exception as error:  # noqa: BLE001
        _state.setdefault("face_error", str(error))
        return None


def last_errors() -> dict:
    return {k: v for k, v in _state.items() if k.endswith("_error")}


def face_tone_shift(original: Image.Image, result: Image.Image, size: int = 512) -> float | None:
    """How far the skin tone moved: CIE76 distance of the mean Lab colour inside each face
    (inner 60 % of the detection box) between photo and result. ~5 = same person under a brush,
    > 15 = different skin tone. Mean over detected faces; None without a face."""
    try:
        from skimage.color import rgb2lab

        from locket_server import preprocess

        original = original.convert("RGB").resize((size, size), Image.LANCZOS)
        result = result.convert("RGB").resize((size, size), Image.LANCZOS)
        faces = preprocess.detect_faces(original, 0.5)
        if not faces:
            return None
        lab_a = rgb2lab(np.asarray(original, np.float32) / 255.0)
        lab_b = rgb2lab(np.asarray(result, np.float32) / 255.0)
        values = []
        for f in faces[:4]:
            cx, cy, half = f.x + f.w / 2, f.y + f.h / 2, max(f.w, f.h) * 0.3
            x0, x1 = int(max(cx - half, 0)), int(min(cx + half, size))
            y0, y1 = int(max(cy - half, 0)), int(min(cy + half, size))
            if x1 - x0 < 4 or y1 - y0 < 4:
                continue
            values.append(float(np.linalg.norm(
                lab_a[y0:y1, x0:x1].reshape(-1, 3).mean(0) - lab_b[y0:y1, x0:x1].reshape(-1, 3).mean(0))))
        return float(np.mean(values)) if values else None
    except Exception as error:  # noqa: BLE001
        _state.setdefault("tone_error", str(error))
        return None
