# Plan: better quality at equal or lower processing time

Audience: the coding agent that will execute this, and the project owner who approves each gate.
Rule for every step: measure before and after on the same fixed photo set. A change that makes
quality or time worse is reverted, not kept "because it is theoretically better".

## 0. Baseline (measured on the RTX 3050 6 GB laptop, 2026-10-03)

| Pipeline | Warm | Notes |
|---|---|---|
| Van Gogh (640 px, 22 steps, face pass, ESRGAN x2) | ~16 s | main 10.2 s, face 4.1 s, upscale 1.6 s, preprocess 0.2 s |
| Van Gogh, first job after server start | +8-12 s | lineart/depth models load lazily (warm-up only loads the diffusion pipe) |
| 8-bit on-device (Dart, laptop CPU) | 0.4-0.5 s | phone time not measured yet |

Known quality defects: (V1) painted faces look smoother/younger than the subject; (V2) square
centre-crop discards the sides of 16:9 photos; (E1) in 8-bit the face is ~30 px wide, so eyes
are 2-3 px and vanish; (E2) busy backgrounds compete with the face.

## 1. Decisions taken

- **One 8-bit engine only.** Remove the Game Boy palette, the PICO-8/Game Boy picker, the
  STANDARD/ENHANCED toggle and the server `pixel_art` path (LoRA, `pixel_art.py`, `palette.py`,
  `configs/pixel_art.yaml`). Remaining engine: on-device, offline, instant, fixed palette (chosen
  in step E4), fixed grid width (decided in E5; the slider is removed with the rest).
  Rationale: the diffusion route cost 9-15 s plus network and looked worse on Game Boy; the
  algorithmic route can be made face-aware for free.
- Old saved photos must still load: `NeoPhoto.fromJson` ignores the removed `palette`,
  `pixelMode`, `pixelWidth` keys.

## 2. Phase A - evaluation harness (prerequisite for everything below)

1. Photo set: 20-30 real photos from the owner's phone (the server already stores uploads in
   `server/eval/captured/` when started with `DEBUG_SAVE=1`): close-up portraits, groups, low
   light, outdoor, rooms, 16:9 and 4:3.
2. `server/eval/run.py`: runs a named config over the set, records per-stage time, saves outputs,
   writes `report.html` (original | variant A | variant B ...).
3. Metrics (tools, not a replacement for looking): face-embedding cosine original vs result
   (facenet-pytorch), Canny-edge SSIM (structure kept), CLIP "oil painting by Van Gogh" minus
   "photograph" (style strength), wall-clock time.
4. Gate: owner confirms the harness report is readable. Acceptance thresholds are set from the
   baseline run, not guessed.

## 3. Phase B - remove 8-bit variants (cleanup, shrinks the app)

Delete: `PixelPalette`, `PixelMode`, game-boy code paths, palette/mode UI in
`camera_experience.dart`, `pixel_art.py`, `palette.py`, pixel LoRA config, `/v1/jobs` style
`pixel_art`, matching tests. Keep `pixel_art/` Dart math modules (reused in Phase E).
Verify: `flutter analyze`, `flutter test`, `pytest`; legacy-metadata test still passes.

## 4. Phase C - Van Gogh: make it faster without losing quality (each step A/B tested)

| Step | Change | Expected effect (unverified) | Risk |
|---|---|---|---|
| C1 | Warm-up also loads lineart + depth and runs one dummy job | removes the +8-12 s on the first photo | none |
| C2 | Precompute IP-Adapter embeddings for the 3 style references; do not run/keep the CLIP-ViT-H image encoder per job | less VRAM (~1.3 GB, fewer offload/OOM events, `vram_free_mb` was 0), small speed gain | low |
| C3 | Phone downsizes the upload to 1024 px long edge before sending (JPEG q90) | faster upload and server decode, esp. on Wi-Fi | none |
| C4 | Keep the photo's aspect ratio (multiples of 8, ~640x360 for 16:9) instead of centre-crop to square | no lost content; fewer pixels than 640x640, so faster | UI must show non-square results (BoxFit) |
| C5 | LCM-LoRA (or Hyper-SD) for SD 1.5: 4-8 steps, guidance ~1-1.5 (CFG off halves per-step cost) | main pass ~10 s -> ~2-4 s | quality may drop; must be checked with ControlNet + IP-Adapter on the eval set; keep the 22-step path as fallback config |
| C6 | Face pass only when the face is small (< ~25 % of frame) or the face-identity metric is below a threshold; run it with the same fast sampler | saves ~4 s on close-ups | low |
| C7 | Spend time saved by C5 only if the eval shows a gain (e.g. 768 px) | quality, not speed | time creeps back |

Target: warm total <= 8 s with equal or better eval scores; stop adding steps when the target and
scores hold. Verify per step with the harness; log stage times.

## 5. Phase D - Van Gogh: raise quality at no runtime cost

- D1 Parameter sweep (strength, lineart/depth scales, IP scale, face-pass IP and strength,
  guidance, scheduler) via the harness; pick winners by metrics then by eye. Runtime cost: zero.
- D2 Identity-preserving blend (cheap post-process, milliseconds): inside the face mask, add back
  a small share of the original's high-frequency detail (frequency separation) and match skin
  tone, to counter the "smoother/younger" drift. Evaluate with the face-cosine metric.
- D3 Prompt/negative-prompt tuning with the same sweep (no artist name; keep the anti-makeup
  negatives that already helped).
- D4 Choose the style-reference set by scene type from the eval, never a painted face.
- D5 Van Gogh style LoRA (30-60 public-domain paintings from Wikimedia). One-off training
  (tens of minutes to ~2 h per run, a few runs while tuning), then a file of tens of MB with
  negligible inference cost; replaces or reduces reliance on IP-Adapter. Start only after A-D4,
  and accept it only if it beats the harness baseline.

## 6. Phase E - the single 8-bit engine (on-device, Dart)

- E1 Face detector on the phone without a new dependency: BlazeFace short-range `.tflite`
  (already used on the server) through the existing `tflite_flutter`; anchor decoding + NMS in
  Dart. No face found -> current centre behaviour.
- E2 Subject-aware crop: crop to face bbox expanded ~2.5-3x (head and shoulders); several
  faces -> union box. A face then spans ~60 px instead of ~30 px.
- E3 Feature-preserving downscale: in the face region, when the minority k-centroid cluster is
  much darker (eyes, brows, lips), keep it; local contrast boost inside the face ellipse.
- E4 Palette study: render 5 portraits with (a) PICO-8, (b) a portrait-friendly free pixel-art
  palette (e.g. Sweetie-16 / DawnBringer 16 - verify licence before release), (c) per-image
  adaptive 16 colours snapped to a fixed set. Owner picks one; the winner is hard-coded.
- E5 Background simplification: MediaPipe selfie-segmentation `.tflite` via `tflite_flutter`
  (soft mask); stronger smoothing/flatter colours outside the subject. Also fix the grid width
  (try 128 and 160 on the eval set).
- E6 Re-tune outline, orphan cleanup, dithering after E2-E5; no dithering on the face.
- E7 Eval: phone timing (target <= 1.5 s), 5 portraits + groups + scenes, owner sign-off.
  No server, no network, no diffusion in this path.

## 7. Phase F - optional, later

Distil the Van Gogh diffusion pipeline into a small on-device image-to-image model (pairs
generated by the laptop on a few thousand photos, trained once). Would give ~1 s offline Van Gogh
but at lower quality and with real training effort. Only if the owner wants no laptop dependency.

## 8. Order of work and gates

A (harness) -> B (cleanup) -> C1-C4 -> C5-C7 -> D1-D4 -> E1-E7 -> D5. Gate after A (report
readable), after C (time target met without score loss), after E4/E7 (owner approves the look).
Rebuild and test on the phone after B, C and E. Unverified numbers above are estimates and must
be replaced by harness measurements.
