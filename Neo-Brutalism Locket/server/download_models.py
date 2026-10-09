"""Download all model weights to D: caches. Run: python download_models.py"""
from locket_server import config  # noqa: F401  (sets HF_HOME before hf import)
from huggingface_hub import hf_hub_download, snapshot_download

JOBS = [
    ("snapshot", "Lykon/dreamshaper-8", dict(allow_patterns=["*.json", "*.txt", "unet/*fp16*.safetensors", "vae/*fp16*.safetensors", "text_encoder/*fp16*.safetensors"])),
    ("snapshot", "lllyasviel/control_v11p_sd15_lineart", dict(allow_patterns=["*.json", "*fp16*.safetensors"])),
    ("snapshot", "lllyasviel/control_v11f1p_sd15_depth", dict(allow_patterns=["*.json", "*fp16*.safetensors"])),
    ("snapshot", "depth-anything/Depth-Anything-V2-Small-hf", {}),
    ("snapshot", "lllyasviel/Annotators", dict(allow_patterns=["sk_model.pth", "sk_model2.pth"])),
    ("file", ("h94/IP-Adapter", "models/ip-adapter_sd15.safetensors"), {}),
    ("file", ("h94/IP-Adapter", "models/image_encoder/config.json"), {}),
    ("file", ("h94/IP-Adapter", "models/image_encoder/model.safetensors"), {}),
]

for kind, target, kwargs in JOBS:
    print("->", target, flush=True)
    if kind == "snapshot":
        print(snapshot_download(target, **kwargs), flush=True)
    else:
        print(hf_hub_download(target[0], target[1]), flush=True)
print("DONE")
