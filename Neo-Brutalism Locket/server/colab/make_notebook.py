"""Regenerates the two Colab notebooks from the cell sources below (edit them here, then run
`python colab/make_notebook.py`):
  locket_server.ipynb  starts the stylize server on a Colab GPU and opens a public https address
                       for the phone app;
  locket_eval.ipynb    runs the photo-set comparison (eval/) of two configs on the Colab GPU."""
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


def log_tail(chars=2500):
    path = WORK / "server.log"
    return path.read_text(errors="replace")[-chars:] if path.exists() else "(no log yet)"


def wait_ready(proc, seconds=1500):
    deadline = time.time() + seconds
    last_note = time.time()
    while time.time() < deadline:
        info = health()
        if info and info.get("models_ready"):
            return info
        if info and info.get("warmup_error"):
            raise RuntimeError("models failed to load: " + info["warmup_error"] + "\\n--- server.log ---\\n" + log_tail())
        if proc.poll() is not None:
            raise RuntimeError("server exited:\\n" + log_tail())
        if time.time() - last_note > 60:
            last_note = time.time()
            print(f"still loading models ({int(deadline - time.time())} s left)... last log line:",
                  log_tail(300).strip().splitlines()[-1:] or "-")
        time.sleep(5)
    raise TimeoutError("models did not load in time. Last log:\\n" + log_tail())


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


EVAL_INTRO = """# Locket Van Gogh eval on Colab

Runs the photo-set comparison: the config before k3 (`van_gogh_before_k3.yaml`) against the current
`van_gogh.yaml`, on the same engine, same seed. Runtime -> **Change runtime type -> T4 GPU**, then **Run all**.

One-time, in Google Drive `MyDrive/locket/`:
- `server.tar` made by `python colab/pack_code.py` (it contains the eval code too);
- a folder `eval_photos/` with the .jpg files of `server/eval/photos` (the owner's own photos
  are private: they go to your Google Drive, nowhere else).

Results (images, `results.json`, comparison sheets) are written to `MyDrive/locket/eval_out/` and survive the
session: if Colab stops, **Run all** again and it resumes. Roughly 30-60 minutes for 2 x 62 photos
(an estimate, not measured on Colab yet). The last cell prints the tables and shows the sheets."""

EVAL_EXTRAS = '''# Metric libraries the server does not need (CLIP style score, face-embedding similarity).
subprocess.run([sys.executable, "-m", "uv", "pip", "install", "--python", PY,
                "ftfy", "regex", "timm", "tqdm", "requests"], check=True)
subprocess.run([sys.executable, "-m", "uv", "pip", "install", "--python", PY, "--no-deps",
                "open_clip_torch==3.3.0", "facenet-pytorch"], check=True)
print("metric libraries ready")'''

EVAL_PHOTOS = '''import collections
import shutil

# The folder name does not matter: use the folder under MyDrive/locket that holds the most .jpg files.
folders = collections.Counter(p.parent for p in DRIVE.rglob("*") if p.suffix.lower() == ".jpg")
assert folders, ("No .jpg file found under MyDrive/locket/. Upload the .jpg files of server/eval/photos "
                 "there (any folder name). If you just uploaded or renamed them, run the Drive cell "
                 "again. Colab sees: " + str(sorted(p.name for p in DRIVE.iterdir())))
PHOTOS_DRIVE, photo_count = folders.most_common(1)[0]
print("photos folder:", PHOTOS_DRIVE, "->", photo_count, ".jpg files")
EVAL = WORK / "server" / "eval"
if (EVAL / "photos").exists():
    shutil.rmtree(EVAL / "photos")
shutil.copytree(PHOTOS_DRIVE, EVAL / "photos")        # local copy: reading Drive per photo is slow
OUT_DRIVE = DRIVE / "eval_out"
OUT_DRIVE.mkdir(exist_ok=True)
out = EVAL / "out"
if out.is_symlink():
    out.unlink()
elif out.exists():
    shutil.rmtree(out)
os.symlink(OUT_DRIVE, out)                            # results live in Drive: a rerun resumes
print(len(list((EVAL / "photos").glob("*.jpg"))), "photos; already in eval_out:",
      sorted(p.name for p in OUT_DRIVE.iterdir()))'''

EVAL_RUN = '''import collections

ENV = dict(os.environ, HF_HOME=str(MODELS / "hf"), TORCH_HOME=str(MODELS / "torch"),
           PYTHONWARNINGS="ignore", PYTHONUNBUFFERED="1", MPLBACKEND="Agg")  # Colab's own backend breaks mediapipe

# "name:config file" = that whole config; a bare name = overrides from eval/sweep.py on van_gogh.yaml.
# new = k3 (today's yaml, brush relief off); imp1 = + brush relief; fast1 = fewer steps; imp1_fast1 = both.
VARIANTS = ["new:van_gogh.yaml", "imp1", "fast1", "imp1_fast1"]
# None = all photos. For a quick first look, e.g.:
# SUBSET = ["photo_02", "photo_08", "photo_12", "photo_17", "photo_31"]
SUBSET = None

env = dict(ENV)
if SUBSET:
    subset_dir = EVAL / "photos_subset"
    shutil.rmtree(subset_dir, ignore_errors=True)
    subset_dir.mkdir()
    for name in SUBSET:
        shutil.copy(EVAL / "photos" / f"{name}.jpg", subset_dir)
    env["SWEEP_PHOTOS"] = str(subset_dir)

SHOW = ("[", "SUMMARY", "Traceback") + tuple(v.split(":")[0] + " " for v in VARIANTS)


def run_stream(cmd):
    proc = subprocess.Popen(cmd, cwd=WORK / "server", env=env, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, text=True)
    tail = collections.deque(maxlen=40)
    for line in proc.stdout:
        tail.append(line.rstrip()[:200])
        if line.startswith(SHOW) or "FAILED" in line:
            print(line.rstrip()[:180])
    code = proc.wait()
    if any(line.startswith("Traceback") for line in tail):
        print("--- last lines of the output (a chunk crashed) ---")
        print(chr(10).join(tail))
    return code


print("exit code", run_stream([PY, "-m", "eval.sweep_chunked", *VARIANTS]))'''

EVAL_SUMMARY = '''from IPython.display import Image, display

for other in [v.split(":")[0] for v in VARIANTS][1:]:
    print("=" * 30, "new vs", other)
    done = subprocess.run([PY, "-m", "eval.summary", "new", other, "--sheets", "2"], cwd=WORK / "server",
                          env=ENV, capture_output=True, text=True)
    print(done.stdout)
    if done.returncode:
        print(done.stderr[-2000:])
    for sheet in sorted((EVAL / "out").glob(f"compare_{other}_*.png")):
        print(sheet.name)
        display(Image(str(sheet)))'''


def cell(kind: str, source: str) -> dict:
    base = {"cell_type": kind, "metadata": {}, "source": source.splitlines(keepends=True)}
    if kind == "code":
        base.update(execution_count=None, outputs=[])
    return base


def notebook(cells: list[dict]) -> dict:
    return {
        "cells": cells,
        "metadata": {"kernelspec": {"display_name": "Python 3", "language": "python", "name": "python3"},
                     "language_info": {"name": "python"},
                     "accelerator": "GPU",
                     "colab": {"gpuType": "T4", "provenance": []}},
        "nbformat": 4,
        "nbformat_minor": 5,
    }


def write(name: str, nb: dict) -> None:
    target = Path(__file__).with_name(name)
    target.write_text(json.dumps(nb, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    print("wrote", target)


def main() -> None:
    write("locket_server.ipynb", notebook([
        cell("markdown", INTRO), cell("code", CHECK), cell("code", DRIVE), cell("code", INSTALL),
        cell("code", MODELS), cell("code", TOKEN), cell("code", SERVER), cell("code", TUNNEL),
        cell("code", KEEPALIVE)]))
    write("locket_eval.ipynb", notebook([
        cell("markdown", EVAL_INTRO), cell("code", CHECK), cell("code", DRIVE), cell("code", INSTALL),
        cell("code", EVAL_EXTRAS), cell("code", MODELS), cell("code", EVAL_PHOTOS),
        cell("code", EVAL_RUN), cell("code", EVAL_SUMMARY)]))


if __name__ == "__main__":
    main()
