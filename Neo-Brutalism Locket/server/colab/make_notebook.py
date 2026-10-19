"""Regenerates colab/locket_server.ipynb from the cell sources below (edit them here, then run
`python colab/make_notebook.py`). The notebook starts the stylize server on a Colab GPU and opens a
public https address for the phone app."""
from __future__ import annotations

import json
from pathlib import Path

INTRO = """# Locket stylize server on Colab

Runtime -> **Change runtime type -> T4 GPU**, then **Runtime -> Run all**. The last cell prints the
**address** and **token** for the app and then keeps running: leave it running while people use the app,
**Disconnect and delete runtime** when you are done.

One-time: put `server.tar` (made by `python colab/pack_code.py` on your PC) into Google Drive at `MyDrive/locket/`.
Optional: the key icon in the left bar -> add a secret `LOCKET_TOKEN` (fixed token, notebook access on)."""

CHECK = '''import subprocess
import urllib.request

gpu = subprocess.run(["nvidia-smi", "-L"], capture_output=True, text=True).stdout.strip()
print(gpu or "NO GPU -> Runtime -> Change runtime type -> T4 GPU, then run again")'''

DRIVE = '''import os
import pathlib
import sys
import tarfile

from google.colab import drive

drive.mount("/content/drive")
DRIVE = pathlib.Path("/content/drive/MyDrive/locket")
DRIVE.mkdir(exist_ok=True)
WORK = pathlib.Path("/content")

assert (DRIVE / "server.tar").exists(), "Upload server.tar to Google Drive -> MyDrive/locket/ (see the first cell)"
tarfile.open(DRIVE / "server.tar").extractall(WORK, filter="data")      # always the latest code from Drive
print("code ready")'''

INSTALL = '''# Colab runs Python 3.13, but the pinned libraries (numpy 1.26, mediapipe 0.10.21) stop at 3.12, so the
# server gets its own Python 3.12 environment with the same pins as server/requirements.txt.
subprocess.run([sys.executable, "-m", "pip", "install", "-q", "uv"], check=True)
VENV = WORK / "venv"
PY = str(VENV / "bin" / "python")
if not VENV.exists():
    subprocess.run([sys.executable, "-m", "uv", "venv", "--python", "3.12", str(VENV)], check=True)
skip = ("torch", "torchvision", "pytest", "httpx", "open_clip_torch")
pins = ["torch==2.6.0", "torchvision==0.21.0"]
for line in (WORK / "server" / "requirements.txt").read_text(encoding="utf-8").splitlines():
    line = line.split("#")[0].strip()
    if line and not line.lower().startswith(skip):
        pins.append(line)
subprocess.run([sys.executable, "-m", "uv", "pip", "install", "--python", PY, *pins], check=True)
print("libraries ready")'''

MODELS = '''MODELS = WORK / "models"
WEIGHTS = {
    "RealESRGAN_x2plus.pth":
        "https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.1/RealESRGAN_x2plus.pth",
    "blaze_face_short_range.tflite":
        "https://storage.googleapis.com/mediapipe-models/face_detector/"
        "blaze_face_short_range/float16/1/blaze_face_short_range.tflite",
}

if not MODELS.exists():
    if (DRIVE / "models.tar").exists():
        print("restoring models from Drive (~2 min)...")
        MODELS.mkdir()
        tarfile.open(DRIVE / "models.tar").extractall(MODELS, filter="data")
    else:
        print("first run: downloading ~6 GB of models (~5-10 min), saved to Drive for next time")
        (MODELS / "weights").mkdir(parents=True)
        for name, url in WEIGHTS.items():
            urllib.request.urlretrieve(url, MODELS / "weights" / name)
        env = dict(os.environ, HF_HOME=str(MODELS / "hf"), TORCH_HOME=str(MODELS / "torch"))
        subprocess.run([PY, "download_models.py"], cwd=WORK / "server", env=env, check=True)
        with tarfile.open(DRIVE / "models.tar", "w") as tar:
            tar.add(MODELS / "hf", arcname="hf")
            tar.add(MODELS / "weights", arcname="weights")
if not (WORK / "server" / "weights").exists():
    os.symlink(MODELS / "weights", WORK / "server" / "weights")
print("models ready")'''

TOKEN = '''import secrets

try:
    from google.colab import userdata

    TOKEN = userdata.get("LOCKET_TOKEN")
except Exception:
    TOKEN = secrets.token_urlsafe(24)
    print("No Colab secret LOCKET_TOKEN: using a random token for this session only")'''

SERVER = '''import json
import time

ENV = dict(os.environ, LOCKET_TOKEN=TOKEN, HF_HOME=str(MODELS / "hf"),
           TORCH_HOME=str(MODELS / "torch"), PYTHONWARNINGS="ignore")


def start_server():
    return subprocess.Popen(
        [PY, "-m", "uvicorn", "locket_server.api:app_factory", "--factory",
         "--host", "127.0.0.1", "--port", "8765"],
        cwd=WORK / "server", env=ENV, stdout=open(WORK / "server.log", "a"), stderr=subprocess.STDOUT)


def health(base="http://127.0.0.1:8765"):
    try:
        return json.load(urllib.request.urlopen(base + "/v1/health", timeout=10))
    except Exception:
        return None


def wait_ready(proc, seconds=600):
    deadline = time.time() + seconds
    while time.time() < deadline:
        info = health()
        if info and info.get("models_ready"):
            return info
        if proc.poll() is not None:
            raise RuntimeError("server exited:\\n" + (WORK / "server.log").read_text()[-2000:])
        time.sleep(5)
    raise TimeoutError("models did not load in time, see /content/server.log")


server = start_server()
print(wait_ready(server))'''

TUNNEL = '''import re
import threading

CLOUDFLARED = WORK / "cloudflared"
if not CLOUDFLARED.exists():
    urllib.request.urlretrieve(
        "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64",
        CLOUDFLARED)
    CLOUDFLARED.chmod(0o755)


def start_tunnel():
    proc = subprocess.Popen([str(CLOUDFLARED), "tunnel", "--url", "http://127.0.0.1:8765", "--no-autoupdate"],
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    for line in proc.stdout:
        found = re.search(r"https://[a-z0-9-]+\\.trycloudflare\\.com", line)
        if found:
            break
    else:
        raise RuntimeError("cloudflared did not give an address")
    threading.Thread(target=lambda: [None for _ in proc.stdout], daemon=True).start()  # keep the pipe drained
    url = found.group(0)
    for _ in range(30):                      # the new address needs a few seconds to resolve
        if health(url):
            break
        time.sleep(2)
    return proc, url


def show(url):
    print("=" * 60)
    print("  App -> camera screen -> server icon:")
    print("  Address:", url)
    print("  Token  :", TOKEN)
    print("=" * 60)


tunnel, URL = start_tunnel()
show(URL)'''

KEEPALIVE = '''# Keep this cell running while the app is in use. It restarts the server or the tunnel if either dies.
# A new tunnel means a NEW address: it is printed again, enter it in the app.
beat = 0
while True:
    time.sleep(60)
    beat += 1
    if server.poll() is not None:
        print("server stopped, restarting...")
        server = start_server()
        wait_ready(server)
    if tunnel.poll() is not None:
        print("tunnel stopped, opening a new one...")
        tunnel, URL = start_tunnel()
        show(URL)
    if beat % 10 == 0:
        info = health() or {}
        print(time.strftime("%H:%M"), "alive | gpu:", info.get("gpu"), "| free MB:", info.get("vram_free_mb"))'''


def cell(kind: str, source: str) -> dict:
    base = {"cell_type": kind, "metadata": {}, "source": source.splitlines(keepends=True)}
    if kind == "code":
        base.update(execution_count=None, outputs=[])
    return base


def main() -> None:
    # Imports shared by every later cell live in the first code cell.
    check = "import subprocess\nimport urllib.request\n\n" + CHECK.split("\n", 1)[1]
    notebook = {
        "cells": [cell("markdown", INTRO), cell("code", CHECK), cell("code", DRIVE),
                  cell("code", INSTALL), cell("code", MODELS), cell("code", TOKEN),
                  cell("code", SERVER), cell("code", TUNNEL), cell("code", KEEPALIVE)],
        "metadata": {"kernelspec": {"display_name": "Python 3", "language": "python", "name": "python3"},
                     "language_info": {"name": "python"},
                     "accelerator": "GPU",
                     "colab": {"gpuType": "T4", "provenance": []}},
        "nbformat": 4,
        "nbformat_minor": 5,
    }
    target = Path(__file__).with_name("locket_server.ipynb")
    target.write_text(json.dumps(notebook, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    print("wrote", target)


if __name__ == "__main__":
    main()
