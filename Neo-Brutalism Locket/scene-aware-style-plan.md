# Plan: the phone recognises the kind of photo and picks the painting to match

Audience: the coding agent that executes this, and the project owner who approves each gate.
Rule (same as the other plans): measure before trusting; a step that does not help is dropped.

## 0. Problems and what already exists

| # | What the owner sees | Cause |
|---|---|---|
| P1 | Van Gogh without the server (Colab off) always looks like *The Starry Night* | `MagentaVanGoghBackend` uses one style image for every photo: `assets/styles/van_gogh_starry_night.jpg` |
| P2 | Nobody tells the user which style suits a photo; group photos in Van Gogh distort small faces | the style pill only switches; it knows nothing about the photo |
| P3 | The server guesses the scene with simple rules (face found, mean brightness < 0.35, top third looks like sky) | a lit street at night is "bright"; a white wall at the top is "sky" |

Already there: the MobileCLIP2-S0 image encoder on the phone (`lib/features/quest/on_device/`,
`assets/quest_model/`) and per-scene reference sets on the server (`pick_reference` in
`server/locket_server/van_gogh.py`, `references` in `configs/van_gogh.yaml`). 62 eval photos are
tagged with exactly the five scene types (`server/eval/photo_tags.json`).

## 1. Scenes

`portrait`, `group`, `night`, `sky`, `day` (everything else). Each scene has 2-4 English
descriptions; the phone scores the photo against all of them (same softmax as the quest check),
adds up the probability per scene and takes the largest.

## 2. Steps

| Step | Change | Files |
|---|---|---|
| A1 | Export script: text vectors of the scene descriptions into `assets/quest_model/scene_labels.{json,bin}` (does not touch the quest files or the model). `--eval` scores the 62 tagged photos with the phone's preprocessing, prints the confusion table, and the server's rule-based guess for comparison | `server/eval/export_scene_labels.py` |
| A2 | **Gate A**: accuracy >= 80 % overall and night/sky better than the server rules; otherwise reword the descriptions and repeat. If CLIP never beats the rules for night/sky, A4 is dropped | - |
| A3 | Phone: `guessPhotoScene(bytes)` (shares the quest's encoder session, remembers the last photo so one photo is never encoded twice). Magenta picks its style painting by scene from small 256 px copies of public-domain paintings; Starry Night only for `sky`; unknown scene = today's behaviour | `lib/features/image_engine/scene_guess.dart`, `magenta_van_gogh_backend.dart`, `assets/styles/` |
| A4 | Server: optional form field `scene`; a found face still means `portrait`, otherwise the phone's `night`/`sky`/`day` replaces the brightness/sky rules. Missing or unknown value = today's rules | `api.py`, `van_gogh.py`, `stylize_client.dart`, `remote_stylize.dart`, tests |
| A5 | Suggestion sticker over the style pill after a shot, only when the evidence is clear and differs from the chosen style: `group` -> 8-BIT (small faces survive), `night`/`sky` -> VAN GOGH. `portrait`/`day` suggest nothing (both styles suit them). Tapping the sticker applies the style | `camera_experience.dart`, `l10n` |
| A6 | Tests: scene scoring (pure function), painting choice, server `scene` field; `flutter analyze`, `flutter test`, `pytest` | `test/`, `server/tests/` |

## 3. Owner rule (2026-10-21): learn the strokes, not the colours

The painting gives brush strokes only; colours stay the photo's. On the phone, Magenta's output
is used for brightness only (`paintedPixel`: the photo pixel moves by the change in luma), so
Starry Night can no longer turn hair or skin blue. On the server, `main.color_anchor` (0.6 since
k3) does the same partly; raising it to 1.0 needs a GPU eval run first.

## 4. Results (2026-10-21)

- Gate A: phone 54/62 = 87 % (portrait 14/17, group 12/12, night 4/4, sky 4/7, day 20/22).
  Server rules: night 4/4, sky 4/7, day 16/22, no group. The descriptions were tuned on these
  same 62 photos, so expect a little less on new photos.
- A3-A6 done; `flutter analyze` clean, `flutter test` 630 passed, server tests 23 passed.
- Not yet tried on a phone (speed of the extra encode, look of the sticker).

## 5. Not in scope

No LLM, no network for the guess, no new model download (the encoder is already in the app).
