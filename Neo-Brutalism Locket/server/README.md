# Locket stylize server

Two ways to run it: **in a Google Colab GPU notebook** (free, no NVIDIA card or phone verification needed, you start it by hand each time) or **on a laptop GPU**.
The phone app talks to either through the same API; only the address and token differ.

## Run on Colab (`colab/`)
One-time setup:
1. On your PC: `cd server ; python colab/pack_code.py` -> `colab/_staging/server.tar` (the engine source, ~3 MB).
2. Google Drive: create the folder `MyDrive/locket/` and upload `server.tar` into it.
3. colab.research.google.com -> File -> Upload notebook -> `colab/locket_server.ipynb`.
4. Optional: key icon in the left bar -> add the secret `LOCKET_TOKEN` (a long random string, notebook access on): a fixed token for the app.

Every time you want the engine up: open the notebook -> Runtime -> Change runtime type -> **T4 GPU** -> Runtime -> **Run all** (allow Drive access when asked).
The first run downloads ~6 GB of models (~5-10 min) and saves them to Drive as `models.tar`; later runs restore them (~2 min). Estimated total (not measured on Colab yet): ~15-20 min the first time, ~8-10 min later; one Van Gogh photo then takes ~10-20 s (laptop RTX 3050: ~16 s).
The last cell prints an `https://<random>.trycloudflare.com` address and the token. App: camera screen -> teal server icon -> address + token -> TEST -> SAVE.
Leave the last cell running while people use the app; Runtime -> **Disconnect and delete runtime** when done.
- The address changes every session; the token stays if you set the secret. Whoever is not running the notebook needs the new address each time.
- Colab free can end a session at any time (idle, time limit, no GPU available); then start again and enter the new address.
- After changing the engine (prompts, `configs/`, `locket_server/`): `python colab/pack_code.py`, replace `server.tar` in Drive, restart the notebook. After adding a model to `download_models.py`: also delete `models.tar` from Drive so it is rebuilt.
- Editing the notebook: change the cells in `colab/make_notebook.py`, run it, re-upload the `.ipynb`.
- Teammates: either they use your address + token while your session runs, or they repeat the setup with their own Google account (send them `server.tar`).
- Photos leave the phone for Google's and Cloudflare's servers (processed in memory, never saved). `/v1/verify` is not used there. Check Colab's terms of use before relying on this beyond a demo.

## Run on the laptop

Runs Van Gogh diffusion on the laptop GPU (SD 1.5 + lineart/depth ControlNet + IP-Adapter + face
pass + Real-ESRGAN). The 8-bit style is NOT served here: it runs fully on the phone. The phone app calls it over the LAN. Photos are processed in memory and never
saved, unless you start the server with `DEBUG_SAVE=1` (then they go to `server/eval/captured/`).

## Run
```powershell
cd server
.\run_server.ps1          # prints the token; first start loads models (~1 min)
```
Token is stored in `server/.env` (`LOCKET_TOKEN=`). Check: `curl http://127.0.0.1:8765/v1/health`.

## Connect the phone (pick one)
1. **Same Wi-Fi**: laptop IP from `ipconfig`, address `IP:8765`. Needs an inbound firewall rule
   (admin): `New-NetFirewallRule -DisplayName "Locket Server" -Direction Inbound -Protocol TCP -LocalPort 8765 -Profile Private -Action Allow`
   and the network set to *Private*. Public/cafe Wi-Fi often blocks device-to-device traffic.
2. **USB (no Wi-Fi/firewall needed)**: enable USB debugging, then
   `adb reverse tcp:8765 tcp:8765` and use address `127.0.0.1:8765` in the app.
3. **Phone hotspot**: connect the laptop to it and use method 1.

In the app: camera screen -> teal server icon -> enter address + token -> TEST -> SAVE.

## API
`GET /v1/health` (no token) · `POST /v1/jobs` (multipart `image`, `style=van_gogh`, optional `seed`; header `X-Locket-Token`) -> `{job_id}` · `GET /v1/jobs/{id}` -> state/stage/progress ·
`GET /v1/jobs/{id}/result` -> PNG (repeatable) · `DELETE /v1/jobs/{id}` frees it. Max 15 MB, 4 queued jobs, jobs expire after 10 min.

`POST /v1/verify` (multipart `image`, `positives` = JSON list such as `["a bunch of grapes","grapes"]`,
optional `negatives`; header `X-Locket-Token`) -> `{match, score, top}`. Daily-quest photo check (the app no longer
calls it: the check runs on the phone, `lib/features/quest/on_device/`; this endpoint and its rules in `verify.py` stay
as the reference the phone copy is tested against): zero-shot
CLIP (open_clip ViT-B-32 LAION-2B, on the CPU, loaded in the background at start, ~0.2 s per photo).
The photo matches when one of the positives beats a fixed list of everyday things (see `verify.py`).

## CLI / tests
`python -m locket_server.cli stylize in.jpg -o out.png` · `pytest tests`

## Models and licenses (verify before any public release)
DreamShaper 8 (CreativeML OpenRAIL-M), ControlNet v1.1 lineart/depth (CreativeML OpenRAIL-M),
IP-Adapter SD1.5 (Apache-2.0), Depth-Anything-V2-Small (Apache-2.0), Real-ESRGAN x2plus (BSD-3),
MediaPipe BlazeFace and Face Mesh (Apache-2.0), CrucibleAI/ControlNetMediaPipeFace (OpenRAIL, face pass; downloaded on first use, ~0.7 GB). Style references in `styles/van_gogh/` are public-domain paintings
from Wikimedia Commons. Cleartext HTTP is for personal LAN use only (the Colab address is https).

The phone's quest check ships MobileCLIP2-S0 (`timm/MobileCLIP2-S0-OpenCLIP`, Apple ML Research licence "apple-amlr":
read https://github.com/apple/ml-mobileclip/blob/main/LICENSE_weights_data and confirm it allows your use before any
public release; the earlier server check used OpenCLIP ViT-B-32 LAION-2B, which is MIT).
