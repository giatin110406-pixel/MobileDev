# Locket stylize server

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
optional `negatives`; header `X-Locket-Token`) -> `{match, score, top}`. Daily-quest photo check: zero-shot
CLIP (open_clip ViT-B-32 LAION-2B, on the CPU, loaded in the background at start, ~0.2 s per photo).
The photo matches when one of the positives beats a fixed list of everyday things (see `verify.py`).

## CLI / tests
`python -m locket_server.cli stylize in.jpg -o out.png` · `pytest tests`

## Models and licenses (verify before any public release)
DreamShaper 8 (CreativeML OpenRAIL-M), ControlNet v1.1 lineart/depth (CreativeML OpenRAIL-M),
IP-Adapter SD1.5 (Apache-2.0), Depth-Anything-V2-Small (Apache-2.0), Real-ESRGAN x2plus (BSD-3),
MediaPipe BlazeFace and Face Mesh (Apache-2.0), CrucibleAI/ControlNetMediaPipeFace (OpenRAIL, face pass; downloaded on first use, ~0.7 GB). Style references in `styles/van_gogh/` are public-domain paintings
from Wikimedia Commons. Cleartext HTTP is for personal LAN use only.
