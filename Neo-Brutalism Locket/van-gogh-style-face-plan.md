# Plan: Van Gogh look, not a Starry Night filter; faces without distortion

Audience: the coding agent that will execute this, and the project owner who approves each gate.
Rule (same as `quality-speed-improvement-plan.md`): measure before and after on the same photo
set; a change that makes the result worse is reverted.

## 0. Problems (owner review, 2026-10-19) and causes found in the code

| # | What the owner sees | Cause |
|---|---|---|
| P1 | Every photo turns into "Starry Night": blue/yellow swirls, black hair becomes cobalt swirls | `main.prompt` names the palette (`vibrant cobalt blue and chrome yellow`) and the stroke (`swirling energetic strokes`); IP-Adapter at 0.6 copies the reference's colours and structure |
| P2 | Same look for every photo | Only two references are used in practice: `portrait` and `bright_scene` both = `wheatfield_cypresses.jpg`, `dark_scene` = `cafe_terrace_night.jpg`. `sky: starry_night.jpg` is never read by the code; `self_portrait_1889.jpg` is unused |
| P3 | Face looks pasted on: smooth photo skin inside a painted image | `face.init: source` + `restore_eyes` (0.7) keep the face close to the photo; `skin_paint` exists in `van_gogh.py` but is off in the config; no colour match between patch and surroundings; paste feather only 0.04 |
| P4 | Face still slightly distorted (eyes / mouth size, shape) | Face is a separate diffusion pass at 512 px on a crop, then resized and pasted; any drift in that pass shows directly. `face_sim` of the current config was never measured (runs `nm`, `m1`, `n1` have null metrics) |

## 1. Phase 0 - baseline of the current config (prerequisite)

1. Photo set: `eval/photos` - the owner's 14 photos plus 48 CC0 / public-domain photos from
   Openverse (sources and licences in `eval/photos/SOURCES.md`), 62 in total: 17 portrait,
   12 group, 22 day scene, 7 sky, 4 night. Tags in `eval/photo_tags.json`; `results.json` has a
   per-tag summary.
2. Run `python -m eval.run --name cur` with metrics on all photos. Record `face_sim`,
   `edge_ssim`, `clip_style`, per-stage time.
3. Add two metrics to `eval/metrics.py`:
   - `palette_shift`: mean distance in Lab between the colour histogram of the photo and the
     result (high = colours replaced by the reference palette, i.e. P1).
   - `style_generic`: CLIP score for "a post-impressionist oil painting" minus "The Starry
     Night" (higher = Van Gogh technique without copying one painting).
4. Add `face_seam`: log(texture energy in a ring around the face / inside the face) in the
   result, minus the same for the photo. 0 = face painted like its surroundings, > 0 = smooth
   "pasted photo" face (P3). Old run `n1` scores 0.38-0.51.
5. Gate: owner looks at the `cur` report and confirms it shows the two problems.

## 2. Phase S - style: Van Gogh technique, colours of the photo (P1, P2)

| Step | Change | Files |
|---|---|---|
| S1 | Prompt describes technique only, no colours, no swirls: e.g. `post-impressionist oil painting, thick impasto, short broken directional brushstrokes, bold dark contour lines, visible canvas texture, {subject}`. Add `swirls, starry night, cobalt blue sky` to the negative prompt for portraits | `configs/van_gogh.yaml` |
| S2 | Reference sets per scene type, 2-3 public-domain paintings each, chosen by seed (deterministic per photo): portrait -> *Portrait of the Postman Roulin*, *Portrait of Dr Gachet*, *La Mousmé*; day scene -> *Wheat Field with Cypresses*, *Irises*, *The Harvest*; night scene -> *Café Terrace at Night*; sky-dominant -> *The Starry Night*. Never a painted face with a beard or Van Gogh's own face (IP-Adapter copies faces) - check each portrait reference on the eval set | `styles/van_gogh/`, `configs/van_gogh.yaml` (`references` becomes lists), `pick_reference` in `locket_server/van_gogh.py` |
| S3 | Sky-dominant detection (cheap): top third of the photo bright and low-texture -> `sky` set. This makes Starry Night an occasional choice instead of the default | `locket_server/preprocess.py`, `pick_reference` |
| S4 | Lower IP-Adapter for portraits (sweep 0.3 / 0.4 / 0.5, current 0.6); keep 0.6 for scenes if metrics agree | `configs/van_gogh.yaml` (`main.ip_adapter_scale_portrait`) |
| S5 | Optional colour anchor: after the main pass, pull the result's mean/std per Lab channel 30-50 % back toward the photo (strokes stay, palette follows the photo). Only if S1-S4 still leave `palette_shift` high | `locket_server/van_gogh.py` |

Download the paintings from Wikimedia Commons (public domain), store the source URL of each in
`styles/van_gogh/SOURCES.md`.

Sweep: add variants `s1`, `s1s2`, `s1s2s4_ip03`, `s1s2s4_ip04`, `s1s2s4_ip05` to
`eval/sweep.py`. Winner = lowest `palette_shift` with `clip_style` not below `cur`, then by eye.

Gate S: owner compares `cur` vs winner side by side; the look must read as "Van Gogh", not
"Starry Night", on portraits and scenes.

## 3. Phase F - faces: painted like the rest, shape kept (P3, P4)

Run after Phase S (the face pass uses the same prompt and reference).

| Step | Change | Risk |
|---|---|---|
| F1 | Turn on `skin_paint` (oil filter on skin only, features masked out); sweep amount 0.3 / 0.5 / 0.7 | none for shape: no feature moves |
| F2 | Colour match before paste: match the patch's Lab mean/std to the painted ring just outside the face mask | low |
| F3 | Wider paste feather (`mask_feather` 0.04 -> 0.08 / 0.12) | low; too wide shows the old main-pass face |
| F4 | Lower `eye_detail` (0.7 -> 0.4) once F1-F3 are in, so eyes are painted but still placed by landmarks | eyes may lose sharpness; check `face_sim` |
| F5 | Shape guard: compare face-mesh landmarks of the patch with the source crop (eye width, eye-mouth distance, mouth width, normalised by face width); if any deviates > 4 %, retry with another seed, then fall back to `face.strength - 0.1` | adds one pass on failure (~10 s) |
| F6 | Experiment, only if F1-F5 do not reach the gate: no separate face pass; paint the whole image with [lineart, face-landmark] ControlNets in the main pass at 768 px for portraits. Removes the seam by design, saves ~10 s per face, but needs its own sweep | larger change; keep the current face pass as fallback config |

Targets (set from Phase 0 numbers, then fixed):
- `face_sim` >= `cur` value on every face photo (no photo may drop more than 0.03).
- `face_seam` clearly below `cur`.
- Shape guard (F5) passes on all faces without retry on at least 80 % of faces.

Gate F: owner looks at close-ups of every face in `photo_02/08/10/12` and the group photo:
face must read as the same person and as painted, with no visible paste edge.

## 4. Out of scope here

Speed (C1-C7 in `quality-speed-improvement-plan.md`), aspect-ratio crop (C4), style LoRA (D5).
Do not change timing-relevant settings in this plan except where noted (F5 retry, F6).
Expected time effect: S and F1-F4 add < 0.5 s; F5 adds ~10 s only on failures.

## 5. Order and verification

Phase 0 -> S1 -> S2+S3 -> S4 -> (S5) -> Gate S -> F1-F3 -> F4 -> F5 -> Gate F -> (F6).
After each step: `pytest server/tests`, harness run, report saved under `eval/out/<name>/`.
Write the winning values into `configs/van_gogh.yaml` with a comment naming the eval run, as
the file already does (e.g. `# eval h1`). Rebuild the app and test on the phone after Gate F.

## 6. Status (2026-10-20)

Adopted in `server/configs/van_gogh.yaml`: variant **k3** of `server/eval/sweep.py` (the previous
config is kept as `server/configs/van_gogh_before_k3.yaml`; copy it back to roll back).

| Eval on 8 hard photos (7 with data in every variant) | cur (old yaml) | k3 |
|---|---|---|
| face_sim (higher = same person) | 0.45 | 0.71 |
| face_seam (0 = painted like the surroundings) | 0.11 | 0.06 |
| palette_shift (lower = colours follow the photo) | 14.6 | 8.1 |
| clip_style (higher = more "painting") | -0.023 | -0.072 |

Known gaps: faces under ~70 px still change hair type (curly -> straight) and skin tone slightly;
brush strokes on faces are weak (clip_style fell); k3 was only run on 10 + 8 photos, not on all 62
(do it on Colab: the laptop GPU faults every few photos). The portrait references still include
Almond Blossom, which may leave white blotches on backgrounds (suspected, not proven).
Output checks (`locket_server/output_check.py`) redo a frame when a GPU fault blanks part of it.
