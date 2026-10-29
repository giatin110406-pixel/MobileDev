# Plan: photo search v2 (accuracy first: false positives and misses both low)

Audience: the project owner who approves each gate, and the agent that executes it.
Rule (same as the other plans): measure before trusting; a step that fails its gate is
dropped, not shipped "for now".

Owner decisions (2026-10-29): accuracy before on-device size; no paid / outside API for now, so
everything runs on the laptop (RTX 3050 6 GB) and later on a self-hosted server; a model parses
the query; a vision-language model (VLM) re-checks the candidates.

## 0. Why v1 gives wrong photos

- One cosine from a small model (MobileCLIP2-S0, R@1 68 % on Flickr30k) cannot tell "right" from
  "looks similar"; every cut-off (0.22, 0.23, lift 0.06) patches a symptom.
- Vietnamese goes through ML Kit to English first; 6 of 50 test queries came out wrong.
- Small libraries: the best photo is always shown, so nothing can answer "no such photo".

## 1. Design

```
POSTING (once per photo, background)
  strong image embedding (multilingual) + VLM caption / objects / OCR  -> stored with the post

SEARCH
  1 query parser (small LM + the existing rules as a safety net)
      -> { friend, time, visual (EN + VI), negations, name_only }
  2 hard filters (friend / time / mine)
  3 retrieve top ~30: embedding cosine + text match on caption / OCR / place (rank fusion)
  4 VLM re-check of those 30: "does this photo show <visual>?"  -> yes / no + confidence
  5 calibrated score (small logistic regression) -> probability right; below the cut-off = hidden;
    nothing above it = "no photo found"
  6 list, best first
Offline / server down: v1 on-device search, labelled "quick results".
```

### Decision on speed (2026-10-29, owner)
Asking the VLM about 30 photos at search time costs ~10 s on the RTX 3050 (3 questions/s). So:
1. **Index time (once per photo, background):** the VLM writes a caption and a list of the
   objects / scene / colours / text it sees, stored with the post. Search matches the parsed
   query against these tags and captions, plus the embedding. Target 1-3 s.
2. **Cache:** the VLM answer for a (photo, thing) pair is stored, so it is asked once. At search
   time the VLM is asked only for the few photos that are still doubtful after steps above.

## 2. Steps

### Phase A - measure (no app change)
| Step | Change | Files |
|---|---|---|
| A1 | Eval set from human labels: COCO val (2,476 photos, object boxes), libraries of 20 / 60 / 300; queries = object names in English and Vietnamese; a photo counts as "has it" only if the object covers >= 2 % of the image, 0 < area < 2 % is ignored; queries with no answer in the library; names-only queries | `server/eval/search_fp_eval.py` |
| A2 | Baseline: v1 scoring replicated (cosine, "a photo of", 0.23 / 0.18 / 0.03, lift gate) | same |
| A3 | **Gate A**: baseline numbers written below; they are the bar every later step must beat |

### Phase B - cheap wins, no LM
| Step | Change |
|---|---|
| B1 | Embedding models on the same set: SigLIP2 (several sizes), multilingual ones; English vs Vietnamese queries |
| B2 | Calibration + abstain: logistic regression on cosine, lift, rank gap, query length; cut-off chosen for a target precision |
| B3 | **Gate B**: wrong-photo share and missed-photo share against the baseline, per library size |

### Phase C - VLM re-check (local)
| Step | Change |
|---|---|
| C1 | SmolVLM-500M, Qwen2.5-VL-3B (4-bit) on the top 30: yes / no from the token probabilities |
| C2 | Add the VLM score to the calibration |
| C3 | **Gate C**: kept only if it lowers the wrong-photo share clearly; speed per search noted |

### Phase D - query parser
| Step | Change |
|---|---|
| D1 | Parser test set: ~150 Vietnamese queries (friend, time, negation, name only, long sentence) with expected JSON, built from templates |
| D2 | Qwen3-0.6B (LoRA on the laptop) vs the rules + ML Kit; JSON checked field by field; rules stay as the validator |
| D3 | **Gate D**: field accuracy above the rules, no invalid JSON reaches the search |

### Phase E - ship
Server `POST /search`, worker for caption / embedding at posting time, backfill, app wiring with
the v1 fallback. Written as a separate plan after Gate C, from the numbers.

## 3. Results

### Gate A - baseline (2026-10-29, `eval.search_fp_eval --model mobileclip --lang en`)
COCO val 2,476 photos, 30 random libraries per size, English searches (the best case for v1: no
ML Kit errors). "missed" at 300 is inflated because v1 shows at most 60 photos.

| Library | wrong share | missed share | no-answer search shows nothing | searches with >= 1 wrong photo |
|---|---|---|---|---|
| 20 | 15.1 % | 43.1 % | 69.7 % | 15.5 % |
| 60 | 20.5 % | 50.0 % | 36.6 % | 24.5 % |
| 300 | 21.8 % | 58.7 % | 10.0 % | 44.5 % |

### B1 - embedding models (2026-10-29, library 60, English, `--sweep --draws 20`)
Wrong / missed share at similar operating points (fixed cosine cut-off):

| Model | ~20 % wrong | ~7 % wrong |
|---|---|---|
| MobileCLIP2-S0 (v1) | 20.2 / 55.1 | 7.7 / 68.0 |
| SigLIP2 B/16 | 18.8 / 47.9 | 6.2 / 66.4 |
| SigLIP2 SO400M/14 | 17.5 / 50.2 | 5.0 / 67.9 |

**A bigger embedding barely moves the curve** (a few points). A per-library z-score cut-off
(z3.0) is no better than a fixed one. One vector per photo cannot see small things (the "has it"
rule counts objects from 2 % of the image), so the lever is the re-check in Phase C, not the
embedding. SigLIP2-B is the cheapest to keep as the retrieval stage.

### C1/C2 - local VLM re-check (2026-10-29, `eval.vlm_recheck`, `eval.calibrate_combo`)
Pool of 300 COCO photos (one library of 300), SigLIP2-B/16 retrieval, top 40 photos per search
(80 searches, 3,136 questions), Qwen2-VL-2B fp16 on the RTX 3050 at ~3 questions/s, "Is there a
<name> clearly visible in this photo?" -> p(Yes) from the Yes / No token probabilities.

| Policy | wrong share | missed share |
|---|---|---|
| cosine alone, ~10 % wrong | 10.6 % | 65.9 % |
| cosine alone, ~2.5 % wrong | 2.5 % | 81.3 % |
| VLM p(Yes) >= 0.8 | 8.6 % | 37.7 % |
| VLM p(Yes) >= 0.9 | 5.2 % | 48.3 % |
| cosine + VLM + lift + rank, logistic regression, 5-fold by photo, p >= 0.5 | 11.6 % | 38.1 % |
| same, p >= 0.8 | 5.3 % | 52.9 % |

- At the same wrong share the VLM cuts missed photos by ~28 points. **Gate C passed.**
- The logistic combination is about as good as the VLM alone at equal photos shown; its use is a
  probability that means something ("p >= 0.8" ~ 5 % wrong), not extra accuracy.
- Caveats: COCO boxes miss some objects, so "wrong" is somewhat overstated for every row alike;
  15 of 3,200 VLM answers were NaN (fp16 overflow: run the VLM in bf16 / fp32 vision tower next);
  a 2B model is the floor, Qwen2.5-VL-3B (needs 4-bit, `bitsandbytes` not installed) is next.

This is the bar. Note for later readers: this COCO copy numbers its 80 classes 0..79, not the
COCO ids 1..90 (the first run mapped them wrongly and gave 83-96 % wrong).

### C3 - index tags + check (handoff results, 2026-10-29)

Same pool of 300 photos, original short tagging prompt. Historical measurements from the
handoff, not measurements of the detailed `search_v2.TAG_PROMPT`:

| Policy | wrong share | missed share | Check coverage |
|---|---|---|---|
| tags only | 13.5 % | 16.4 % | none |
| tags AND VLM >= 0.8 | 4.4 % | 26.6 % | every tag match |
| tags AND VLM >= 0.9 | 2.6 % | 52.5 % | top 40 only |
| tags AND VLM >= 0.95 | 0.8 % | 79.3 % | top 40 only |

The earlier 43.6 % missed figure at 0.8 was inflated by the top-40 limit. About 62 % of the
remaining misses came from missing tags, 38 % from the check. Small objects (2-5 % area) were
missed 54 % of the time. These results do not establish Vietnamese or real-photo accuracy.

The selected policy is tags AND check >= 0.8, configurable. The detailed prompt still needs
measurement: gate = wrong <= 5 % and missed < 26.6 %. No-answer gate = show nothing >= 95 %.

Continuation: `eval.compare_tags` (also `eval.index_tags`) compares both prompts on the same
300 photos, with equal generation settings, shared production synonyms and fresh bf16 checks
on the union of all tag matches. No top-K cap; old fp16 check caches remain untouched. It
reports the full pool plus 30 random sublibraries of 20 and 60 (seed 7), including absent-only
queries. These sublibraries are sampled from the 300-photo pool, whereas Gate A samples from
all 2,476 photos; they are not identical evaluation sets. Cache fingerprints include image
bytes, prompt and inference settings. Raw counts and unavailable denominators are retained in
`D:/clip_eval_tmp/search_v2/tag_comparison_report.json`. New results pending this run.

Additional historical-cache check (same old tags, check >= 0.8, same pool):

| Library | wrong share | missed share | no-answer returns empty | No-answer query count |
|---|---|---|---|---|
| 20 | 2.19 % | 26.18 % | 99.27 % (1360/1370) | 1370 |
| 60 | 3.44 % | 27.14 % | 97.12 % (539/555) | 555 |
| 300 | 4.37 % | 26.57 % | 100 % (1/1) | 1 |

The size-300 no-answer result has only one eligible query, so it provides very little
evidence. The sublibrary counts include repeated draws from the same pool. Seven tag matches
have no finite historical check and are hidden. These are historical-cache results, not the
new bf16 comparison. Existing Flutter tests for name-only queries assert zero photo-encoder
calls; `flutter test test/photo_search_test.dart test/search_query_test.dart` passed 43 tests
during this continuation. That verifies the current app path, not the future v2 endpoint.

An additional **deliberately absent** stress test removes all positive and tiny photos for
each queried term before forming its library. This also tests common categories that random
libraries almost never omit. On the historical cache at 0.8: 20-photo libraries return empty
98.125 % (2355/2400); 60-photo libraries 95.5 % (2292/2400). Using every completely negative
photo per term returns empty 82.5 % (66/80), with library sizes 146-300. This last test is not a
fixed-size 300-photo baseline. It exposes errors for common terms that the single naturally
absent query misses. Fourteen terms fail there: apple, baseball bat, bear, bicycle, car,
dining table, keyboard, kite, laptop, mouse, orange, remote, sandwich, truck.

### Detailed-prompt format failure and revised candidate (continuation)

The original detailed prompt produced repeated nouns in 22/88 photos and no `Scene:` line in
49/88 in a partial run (equal maximum of 220 generated tokens). The old prompt on all 300
photos had 11 repeated-noun outputs and 26 missing scene lines. These are format diagnostics,
not an accuracy comparison on equal-sized sets. The partial original-detailed run was stopped;
its cache `tags_detailed_3b8997b3a26ac41e.json` and `compare_tags.log` remain intact. No full-pool
accuracy claim is made for that prompt. It remains in `search_v2.DETAILED_TAG_PROMPT`.

`TAG_PROMPT` is now a revised candidate: visible objects, each type named once, no guessing
hidden objects, exactly two output lines. It is not released or wired to the app. A new run
compares this candidate with the old prompt on all 300 photos; the completed old-tag cache is
reused, the revised prompt has its own fingerprint. Log: `compare_tags_revised.log`. The
report's `detailed` label refers to the current candidate, and `tag_prompts` records the exact
wording. Accuracy and no-answer gates still apply; results pending.
