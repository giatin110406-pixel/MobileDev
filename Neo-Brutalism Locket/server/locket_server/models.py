"""Lazy singleton registry for heavy models. One GPU, one job at a time."""
from __future__ import annotations

import gc
import threading
from typing import Any

from . import config  # noqa: F401  (must come first: sets HF cache dirs)

import torch

_lock = threading.RLock()


class ModelRegistry:
    def __init__(self, cfg: dict) -> None:
        self.cfg = cfg
        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        self.dtype = torch.float16 if self.device == "cuda" else torch.float32
        self._pipe = None
        self._lineart = None
        self._depth = None
        self._face_pipe = None
        self._offloaded = False
        self._embeds: dict = {}
        self._stash: dict = {}
        self._slot_kind = "main"

    # -- diffusion pipeline -------------------------------------------------
    def pipe(self):
        with _lock:
            if self._pipe is None:
                from diffusers import (
                    ControlNetModel,
                    DPMSolverMultistepScheduler,
                    StableDiffusionControlNetImg2ImgPipeline,
                )

                c = self.cfg
                nets = [
                    ControlNetModel.from_pretrained(
                        c["controlnet_lineart"], torch_dtype=self.dtype, variant="fp16"
                    ),
                    ControlNetModel.from_pretrained(
                        c["controlnet_depth"], torch_dtype=self.dtype, variant="fp16"
                    ),
                ]
                pipe = StableDiffusionControlNetImg2ImgPipeline.from_pretrained(
                    c["base_model"],
                    controlnet=nets,
                    torch_dtype=self.dtype,
                    variant="fp16",
                    safety_checker=None,
                    requires_safety_checker=False,
                )
                pipe.scheduler = DPMSolverMultistepScheduler.from_config(
                    pipe.scheduler.config,
                    use_karras_sigmas=True,
                    algorithm_type="dpmsolver++",
                    final_sigmas_type="sigma_min",
                )
                pipe.load_ip_adapter(
                    "h94/IP-Adapter",
                    subfolder="models",
                    weight_name="ip-adapter_sd15.safetensors",
                )
                pipe.vae.enable_tiling()
                self._place(pipe)
                self._pipe = pipe
            self._activate("main")
            return self._pipe

    def face_pipe(self):
        """Second pipeline for the face pass: lineart + face-landmark ControlNets. It shares the
        UNet / VAE / text encoder / IP-Adapter with the main pipeline (no second copy in VRAM)."""
        with _lock:
            if self._face_pipe is None:
                from diffusers import ControlNetModel, StableDiffusionControlNetImg2ImgPipeline
                from diffusers.models.controlnets.multicontrolnet import MultiControlNetModel

                main = self.pipe()
                slot = main.controlnet.nets[1]
                face_net = ControlNetModel.from_pretrained(
                    self.cfg["controlnet_face"], subfolder="diffusion_sd15",
                    torch_dtype=self.dtype, variant="fp16")
                # depth and face ControlNets have the same architecture: one net stays on the
                # GPU and `_activate` overwrites its weights in place (no allocation or free)
                self._stash = {
                    "main": {k: v.detach().cpu().clone() for k, v in slot.state_dict().items()},
                    "face": {k: v.detach().cpu() for k, v in face_net.state_dict().items()},
                }
                self._slot_kind = "main"
                del face_net
                components = dict(main.components)
                components["controlnet"] = MultiControlNetModel([main.controlnet.nets[0], slot])
                pipe = StableDiffusionControlNetImg2ImgPipeline(
                    **components, requires_safety_checker=False)
                self._face_pipe = pipe
            self._activate("face")
            return self._face_pipe

    def _activate(self, kind: str) -> None:
        """Three ControlNets (~0.7 GB each) plus the UNet do not fit a 6 GB card (the driver then
        spills to system RAM and every step is 3x slower), and moving nets between CPU and GPU
        faulted the driver after a few photos. The face pass needs the same architecture as the
        depth net, so the one GPU-resident net is re-filled in place from a CPU copy."""
        if self._pipe is None or self._slot_kind == kind or kind not in self._stash:
            return
        self._pipe.controlnet.nets[1].load_state_dict(self._stash[kind])
        self._slot_kind = kind

    def ip_embeds(self, name: str, image) -> list:
        """IP-Adapter embeddings of a style reference, computed once and cached (memory + disk),
        so the 1.2 GB CLIP-ViT-H image encoder can stay off the GPU."""
        with _lock:
            path = config.STYLES_DIR / "van_gogh" / name
            key = f"{path.stem}-{int(path.stat().st_mtime)}"
            if key not in self._embeds:
                cache = config.WEIGHTS_DIR / "ip_embeds" / f"{key}.pt"
                if cache.exists():
                    self._embeds[key] = torch.load(cache)
                else:
                    pipe = self.pipe()
                    on_gpu = self.device == "cuda" and not self._offloaded
                    if on_gpu:
                        pipe.image_encoder.to("cuda")
                    with torch.no_grad():
                        embeds = pipe.prepare_ip_adapter_image_embeds(
                            image, None, self.device, 1, True)
                    if on_gpu:
                        pipe.image_encoder.to("cpu")
                    embeds = [e.to("cpu") for e in embeds]
                    cache.parent.mkdir(parents=True, exist_ok=True)
                    torch.save(embeds, cache)
                    self._embeds[key] = embeds
            return [e.to(self.device, self.dtype) for e in self._embeds[key]]

    def _place(self, pipe) -> None:
        if self.device != "cuda":
            return
        if self.cfg.get("offload") == "always" or self._offloaded:
            pipe.enable_model_cpu_offload()
            self._offloaded = True
        else:
            pipe.to("cuda")
            pipe.image_encoder.to("cpu")   # only needed to build ip_embeds, then cached

    def enable_offload(self) -> None:
        """Called after a CUDA OOM: rebuild the pipeline with CPU offload."""
        with _lock:
            self._offloaded = True
            self._pipe = None
            self._face_pipe = None
            self._stash = {}
            self._slot_kind = "main"
            self.free()

    # -- preprocessors ------------------------------------------------------
    def lineart(self):
        with _lock:
            if self._lineart is None:
                from controlnet_aux import LineartDetector

                self._lineart = LineartDetector.from_pretrained(self.cfg["annotators"])
            return self._lineart

    def depth(self):
        with _lock:
            if self._depth is None:
                from transformers import pipeline

                self._depth = pipeline(
                    "depth-estimation",
                    model=self.cfg["depth_model"],
                    device=0 if self.device == "cuda" else -1,
                )
            return self._depth

    def free(self) -> None:
        gc.collect()
        if self.device == "cuda":
            torch.cuda.empty_cache()

    def vram_free_mb(self) -> int | None:
        if self.device != "cuda":
            return None
        free, _total = torch.cuda.mem_get_info()
        return int(free / 1024 / 1024)


def load_registry(cfg: dict) -> ModelRegistry:
    return ModelRegistry(cfg)
