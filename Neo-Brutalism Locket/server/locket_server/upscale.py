from __future__ import annotations

import numpy as np
import torch
from PIL import Image

from .config import WEIGHTS_DIR


def _tile_ok(piece: torch.Tensor, source: torch.Tensor) -> bool:
    """A 2x tile averaged back down must look like its input; GPU numeric faults give garbage."""
    if not torch.isfinite(piece).all():
        return False
    back = torch.nn.functional.avg_pool2d(piece, 2)
    return float((back - source.float().cpu()).abs().mean()) < 0.08


def _checked_tile(model, source: torch.Tensor) -> torch.Tensor:
    for _ in range(2):
        piece = model(source).float().cpu()
        if _tile_ok(piece, source):
            return piece
    # still faulty: plain bicubic for this tile instead of garbage
    return torch.nn.functional.interpolate(source.float().cpu(), scale_factor=2,
                                           mode="bicubic", align_corners=False)


def upscale_x2(image: Image.Image, device: str, tile: int = 256, pad: int = 16) -> Image.Image:
    """Real-ESRGAN x2plus via spandrel, tiled to fit 6 GB VRAM. Loaded per call and freed."""
    from spandrel import ModelLoader

    model = ModelLoader().load_from_file(str(WEIGHTS_DIR / "RealESRGAN_x2plus.pth"))
    model = model.to(device).eval()
    if device == "cuda":
        model = model.half()
    dtype = torch.float16 if device == "cuda" else torch.float32

    array = np.asarray(image.convert("RGB"), dtype=np.float32) / 255.0
    tensor = torch.from_numpy(array).permute(2, 0, 1).unsqueeze(0).to(device=device, dtype=dtype)
    _, _, height, width = tensor.shape
    output = torch.zeros(1, 3, height * 2, width * 2, dtype=torch.float32)
    with torch.no_grad():
        for top in range(0, height, tile):
            for left in range(0, width, tile):
                t0, l0 = max(top - pad, 0), max(left - pad, 0)
                t1, l1 = min(top + tile + pad, height), min(left + tile + pad, width)
                source = tensor[:, :, t0:t1, l0:l1]
                piece = _checked_tile(model, source)
                ct, cl = (top - t0) * 2, (left - l0) * 2
                bh = min(tile, height - top) * 2
                bw = min(tile, width - left) * 2
                output[:, :, top * 2 : top * 2 + bh, left * 2 : left * 2 + bw] = piece[
                    :, :, ct : ct + bh, cl : cl + bw
                ]
    del model, tensor
    if device == "cuda":
        torch.cuda.empty_cache()
    result = (output.squeeze(0).permute(1, 2, 0).clamp(0, 1).numpy() * 255.0).round().astype(np.uint8)
    return Image.fromarray(result)
