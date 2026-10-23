"""Thick-paint relief on a finished painting: brush-stroke highlights and shadows, faces spared.

Only the brightness (Lab L) is modulated, so colours, shapes and identity are untouched. Stroke
direction follows the image edges (structure tensor); the strokes are line-integral-convolved noise.
CPU only, about 0.8 s for 1024 px.
"""
from __future__ import annotations

import cv2
import numpy as np
from PIL import Image


def orientation(gray: np.ndarray, sigma_grad: float = 1.5, sigma_tensor: float = 7.0):
    g = cv2.GaussianBlur(gray, (0, 0), sigma_grad)
    gx = cv2.Sobel(g, cv2.CV_32F, 1, 0, ksize=3)
    gy = cv2.Sobel(g, cv2.CV_32F, 0, 1, ksize=3)
    jxx = cv2.GaussianBlur(gx * gx, (0, 0), sigma_tensor)
    jyy = cv2.GaussianBlur(gy * gy, (0, 0), sigma_tensor)
    jxy = cv2.GaussianBlur(gx * gy, (0, 0), sigma_tensor)
    theta = 0.5 * np.arctan2(2 * jxy, jxx - jyy) + np.pi / 2   # along the edges
    return np.cos(theta).astype(np.float32), np.sin(theta).astype(np.float32)


def lic(noise: np.ndarray, vx: np.ndarray, vy: np.ndarray, length: int) -> np.ndarray:
    h, w = noise.shape
    xs, ys = np.meshgrid(np.arange(w, dtype=np.float32), np.arange(h, dtype=np.float32))
    acc = noise.copy()
    n = 1
    for sign in (1, -1):
        x, y = xs.copy(), ys.copy()
        px, py = vx.copy() * sign, vy.copy() * sign
        for _ in range(length):
            dx = cv2.remap(vx, x, y, cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)
            dy = cv2.remap(vy, x, y, cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)
            s = np.sign(dx * px + dy * py)
            s[s == 0] = 1
            dx, dy = dx * s, dy * s
            x += dx
            y += dy
            px, py = dx, dy
            acc += cv2.remap(noise, x, y, cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT)
            n += 1
    return acc / n


def _norm(a: np.ndarray) -> np.ndarray:
    return (a - a.mean()) / (a.std() + 1e-6)


def face_keep_mask(size: int, faces, scale: float, grow: float = 1.5) -> np.ndarray:
    """1 away from faces, 0 on them. `faces` are in the working-size image, `scale` maps to `size`."""
    m = np.zeros((size, size), np.float32)
    for f in faces:
        cx, cy = (f.x + f.w / 2) * scale, (f.y + f.h / 2) * scale
        axes = (int(f.w * scale * grow / 2), int(f.h * scale * grow * 0.62))
        cv2.ellipse(m, (int(cx), int(cy)), axes, 0, 0, 360, 1.0, -1)
    if faces:
        sigma = max(3.0, 0.3 * 0.35 * float(np.sqrt(m.sum() / len(faces))))
        m = cv2.GaussianBlur(m, (0, 0), sigma)
    return 1.0 - np.clip(m, 0, 1)


def apply(image: Image.Image, keep: np.ndarray | None = None, strength: float = 1.1,
          face_strength: float = 0.2, seed: int = 3) -> Image.Image:
    rgb = np.asarray(image.convert("RGB"), np.float32) / 255.0
    lab = cv2.cvtColor(rgb, cv2.COLOR_RGB2LAB)
    luma = lab[..., 0] / 100.0
    vx, vy = orientation(luma)
    base = np.random.default_rng(seed).standard_normal(luma.shape).astype(np.float32)
    fine = _norm(lic(cv2.GaussianBlur(base, (0, 0), 0.7), vx, vy, 10))
    coarse = _norm(lic(cv2.GaussianBlur(base, (0, 0), 2.2), vx, vy, 26))
    height = 0.55 * fine + 0.45 * coarse + 2.0 * cv2.GaussianBlur(_norm(luma), (0, 0), 1.5)
    sx = cv2.Sobel(height, cv2.CV_32F, 1, 0, ksize=3)
    sy = cv2.Sobel(height, cv2.CV_32F, 0, 1, ksize=3)
    shade = _norm(-(sx + sy))                                  # light from the top left
    weight = 1.0 if keep is None else face_strength + (1 - face_strength) * keep
    lab[..., 0] = np.clip(lab[..., 0] * (1 + 0.06 * strength * weight * shade), 0, 100)
    out = cv2.cvtColor(lab, cv2.COLOR_LAB2RGB)
    return Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8))
