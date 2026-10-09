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
                ["an oil painting by Vincent van Gogh", "a photograph"]))
            text = text / text.norm(dim=-1, keepdim=True)
        _state["clip"] = (model, preprocess, text)
    return _state["clip"]


def clip_style(result: Image.Image) -> float | None:
    """Higher = looks more like a Van Gogh painting than a photograph."""
    try:
        import torch

        model, preprocess, text = _clip()
        with torch.no_grad():
            feat = model.encode_image(preprocess(result.convert("RGB")).unsqueeze(0))
            feat = feat / feat.norm(dim=-1, keepdim=True)
            sims = (feat @ text.T)[0]
        return float(sims[0] - sims[1])
    except Exception as error:  # noqa: BLE001
        _state.setdefault("clip_error", str(error))
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
