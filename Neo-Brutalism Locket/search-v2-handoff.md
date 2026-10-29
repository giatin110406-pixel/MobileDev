# Search v2: handoff (state on 2026-10-29) and plan for what is left

**Continuation: read section 9 for the latest implementation status; sections 1-8 include
historical snapshots.**

Read this first, then `search-v2-plan.md` (design, earlier gates) and `archive-ai-search-plan.md`
(v1, what the app does today). Owner: tinss. Language with the owner: Vietnamese.

## 1. Goal and owner decisions (final)

Photo search in the app gives too many wrong photos (false positives, FP) and misses some (FN).
Owner priority: **fewest wrong photos first**, misses as low as possible after that; production grade.

- Everything runs on the owner's laptop (RTX 3050 6 GB) for now; no outside / paid API. A VPS GPU
  is a later option, not a decision.
- A small model parses the typed query (Qwen3-0.6B, fine-tuned), the existing rules stay as the
  validator. (The owner flipped on this once; the last word is: **use a model to parse**.)
- A local VLM (Qwen2-VL-2B, kept: a bigger one does not fit 6 GB in fp16 and would fix at most
  ~12 points of the misses) does two jobs:
  1. **Tags, once per photo when it is posted**: object list + one scene sentence, stored in the post.
  2. **Check, once per (photo, term), cached**: "Is there a <term> clearly visible?" -> p(Yes).
- Rule that ships: **a photo is shown when its tags name the term AND the check is >= 0.8.**
  Keep 0.8 as a parameter.
- The detailed tagging prompt (`search_v2.TAG_PROMPT`) was chosen **without measuring**, on the
  owner's instruction. It may raise misses down but also wrong photos; measure it before release.

## 2. What was measured (COCO val, 2,476 photos, human boxes, English object searches)

"has it" = the object covers >= 2 % of the photo; smaller = ignored. wrong = shown photos without
the object / shown. missed = photos with the object not shown / photos with it.

| Approach | wrong | missed |
|---|---|---|
| v1 in the app (MobileCLIP2-S0 + cut-offs), library 60 | 20.5 % | 50.0 % |
| v1, library 20 / 300 | 15.1 / 21.8 % | 43.1 / 58.7 % |
| SigLIP2 B/16 or SO400M instead of MobileCLIP | a few points better only | (embedding is not the lever) |
| VLM check at search time, p >= 0.8 (pool of 300, top 40) | 8.6 % | 37.7 % |
| tags only | 13.5 % | 16.4 % |
| **tags AND VLM >= 0.8, VLM asked on every tag match** | **4.4 %** | **26.6 %** |
| tags AND VLM >= 0.9 / 0.95 (asked top 40 only) | 2.6 / 0.8 % | 52.5 / 79.3 % |

Where the 26.6 % missed comes from: ~62 % the tags do not list the object (small objects worst:
54 % missed at 2-5 % of the photo); ~38 % the VLM said no or unsure. Earlier "43.6 %" was inflated
by a test limit (VLM only asked about the top 40 photos by cosine).

**Not measured yet (do not claim v2 is better there):** Vietnamese searches, searches with no
answer in the library (v1 shows nothing only 37 % of the time at library 60), names of people,
the detailed tag prompt, real Locket photos, end-to-end latency.

## 3. Code and data that exist

All paths are under `D:\Neo-Brutalism Locket` (the git root is `D:\`; tracked paths carry the
prefix `Neo-Brutalism Locket/`).

| Path | What |
|---|---|
| `search-v2-plan.md` | design + gate results (A, B1, C1/C2). Tag results are NOT in it yet: table above |
| `server/eval/search_fp_eval.py` | COCO FP/FN harness, v1 policy replicated, `--sweep` for operating points |
| `server/eval/vlm_recheck.py` | pool of 300 (`pool_indices`, seed 1), VLM p(Yes) per (photo, term) with cache |
| `server/eval/calibrate_combo.py` | logistic combination of cosine + VLM (in torch, no sklearn): about as good as VLM alone |
| `server/eval/index_tags.py` | tag generation with the OLD prompt, tags-vs-VLM policies. Has its own copy of the synonym table |
| `server/locket_server/search_terms.py` | shared synonym table + `has_term` |
| `server/locket_server/search_v2.py` | `TAG_PROMPT`, `CHECK_PROMPT`, `check_shows`, `CheckCache`, `search()`; the model is an injected callable (`Asker`) |
| `server/tests/test_search_v2.py` | 7 tests; `pytest tests` in `server/` = 30 pass |
| `supabase/migrations/20261031000001_photo_search_v2.sql` | **applied to the shared DB (2026-10-29)**: `posts.ai_tags`, `ai_status` (pending/done/failed), `ai_attempts`, partial index, table `post_checks (post_id, term, probability)` with RLS on and no policy (service role only) |

Caches in `D:\clip_eval_tmp\search_v2\`: `ViT-B-16-SigLIP2_coco.npy` (image vectors),
`vlm_Qwen2-VL-2B-Instruct_k40.npz` (p(Yes), top 40), `vlm_all_tagged.npz` (p(Yes) for every tag
match), `tags_Qwen2-VL-2B-Instruct.json` (300 photo tags). Logs: `D:\data-moved\`.

Original handoff: nothing in `lib/` (the app) or `api.py` used v2. Continuation: the app still
uses v1; an opt-in server API/worker implementation now exists (section 8). It is not deployed.

## 4. Environment gotchas (these cost hours)

- Run from `server/`: `$env:PYTHONPATH=".eval_tools"; .venv/Scripts/python.exe -m eval.<name>`.
  The venv has torch 2.6 + CUDA, transformers 5.18, open_clip 3.3; **no sklearn, no bitsandbytes**.
- **Import `torch` before `pyarrow`** (pyarrow lives in `.eval_tools`); the other order segfaults.
- This COCO copy numbers its 80 classes **0..79**, not COCO ids 1..90 (`ev.IDS` maps them).
- Load Qwen2-VL in **bf16**: fp16 gave NaN for 15 of 3,200 answers (the cached p(Yes) file still
  has them; `calibrate_combo` skips them).
- Qwen2-VL-2B speed on the 3050: ~3 yes/no questions per second, ~1 photo per second for tags.
- HF models are cached through a junction: `C:\Users\USER\.cache\huggingface` -> `D:\data-moved\huggingface`
  (same for `.android\avd`). C: was full (0 GB) and is ~25 GB free now; do not delete there without asking.
- Flutter was upgraded to 3.47.8 (Omni needs Dart 3.12). The app build needed a Gradle workaround
  (uncommitted, see section 5).

## 5. Git state (nothing of v2 is committed)

- Local branch `master` = `origin/master` `61369fe0` (contains Omni POV and MISCAPTURED).
- The owner's earlier uncommitted camera edit is saved on branch `wip/camera-local` (`594adb49`).
- Uncommitted on master, **build fixes (belong in their own PR)**: `pubspec.lock`,
  `analysis_options.yaml`, `android/gradle.properties`, `android/build.gradle.kts` (sets Java and
  Kotlin of every module to 17). Suggested: branch `fix/android-build-flutter-3-47`, PR to master.
  Never push to master directly.
- Untracked, **v2 work (put on a branch such as `feat/search-v2`)**: everything in section 3 plus
  `search-v2-plan.md`, this file. Do not mix it with the build PR.
- Teammate PLHieu1212's Omni migrations (`20261029000001_pov`, `20261030000001/2`) are in master
  and applied. Mine was renamed to `20261031000001` because `20261029000001` was taken.
- `docs/session-a-rewind-plan.local-backup.md` is the owner's own draft; leave it.
- `supabase db push` against the shared project is blocked for the agent by the permission system:
  the owner runs it (`npx supabase db push --linked`). Always `--dry-run` first.

## 6. Plan for what is left (in this order)

### Step 1 - close the open measurements (no app change, ~1 day)
1. Point `index_tags.py` at `search_v2.TAG_PROMPT` and `search_terms`; regenerate tags (cache
   name must change); compare old vs detailed prompt on the same 300 photos with the same policies.
   Gate: wrong share <= 5 % and missed lower than 26.6 %; if wrong goes up, tighten the prompt or
   raise the check threshold.
2. Searches with no answer and names: extend the harness. For each library, searches for objects
   absent from it must show nothing; a search that is only a person's name must not look at photos
   (the app's `search_query.dart` already handles names). Gate: no-answer shows nothing >= 95 %.
3. Add the tag results table above to `search-v2-plan.md` section 3.

### Step 2 - Vietnamese (~1-2 days)
- Compare on the Vietnamese names in `search_fp_eval.CATEGORIES` (second column): ML Kit
  translation (cannot run on PC: use the English names with the known mistakes from
  `archive-ai-search-plan.md` A6 as a proxy) vs a multilingual embedding (SigLIP2 handles Vietnamese)
  vs the query parser below producing English terms. The check and tags are matched on **English
  terms**, so the parser must output a term from `SYNONYMS` keys. Gate: Vietnamese within 3 points
  of English.

### Step 3 - query parser (Phase D of the plan, ~2-3 days)
- Build ~150 Vietnamese queries from templates: friend ("với Lan"), time ("hôm qua", "tháng 10"),
  mine, negation, name-only, long sentence, objects. Expected JSON fields: `friend`, `time`,
  `mine`, `terms` (English terms from `SYNONYMS`), `name_only`.
- Qwen3-0.6B with LoRA (peft is installed) on the laptop; compare per field with the rules in
  `lib/features/search/search_query.dart`. Rules stay as validator (invalid date, unknown friend
  name -> use the rule result). Gate: field accuracy above the rules, no invalid JSON passes.

### Step 4 - real Locket photos (the owner needs ~15 minutes)
- 50-100 owner photos, 20-30 Vietnamese searches; script prints the pairs where tags and the check
  disagree with the owner, the owner marks right / wrong in a small HTML page. Gate: wrong share of
  shown photos <= 5 % there too. This is the real acceptance test; COCO is only a proxy.

### Step 5 - server (~3-5 days)
- Put the model behind `search_v2.Asker`: load Qwen2-VL-2B in bf16 (see `vlm_recheck.load_vlm`,
  `p_yes`; use bf16), batch 8, `max_pixels = 320*28*28` for the check and `448*28*28` for tags.
- **Worker**: poll `posts` where `ai_status='pending'` (index exists), download the photo, run
  `TAG_PROMPT`, write `ai_tags`, set `done`; on error `ai_attempts += 1`, `failed` after 3.
  Posting must never wait for it.
- **`POST /search`** in `locket_server/api.py` (FastAPI, today it is the Van Gogh service with an
  `X-Locket-Token` header): body = parsed terms + filters. Must respect RLS: read posts with the
  **caller's Supabase JWT** (not the service key) so only photos the user may see are searched;
  use the service role only for `post_checks`. Call `search_v2.search(term, tags, cache, ask)` per
  term, intersect for several terms, return post ids best first. To confirm with the owner: how
  the laptop is reachable from phones (tunnel / same Wi-Fi) - this is the weakest point of the
  "laptop as server" choice.
- Backfill: same worker over old posts (owner's first, 20 per run like the v1 backfill).
- Tests: fake `Asker` (no GPU), RLS (a stranger gets nothing), worker retry. Latency target:
  tags matched -> result in 1-3 s; first search of a new term with cold cache 5-10 s on the 3050.

### Step 6 - app (`lib/features/search/`, ~3-5 days)
- Today: `photo_search.dart` (v1: translate -> text vector -> cut-offs), `search_query.dart` (rules),
  `search_index.dart`, wired in `history_screen.dart`. Add a v2 path: parse -> `POST /search` ->
  results; keep v1 as the **fallback** when offline / server down, labelled "quick results"; show
  "no photo found" when v2 returns nothing (do not fall back to "closest photo" on a v2 answer).
- Tests in `test/` (the repo has search tests to copy from); `flutter analyze`, `flutter test`.

### Step 7 - release
- Run v1 and v2 side by side for the owner and friends, log searches that ended without a tap,
  check `post_checks` growth, re-run the eval on the new logs. Then switch the default.

## 7. Risks to keep in front of the owner

- **Privacy:** v2 sends photos to the owner's own laptop (not to a third party). Say so in the app.
- **Availability:** a laptop that sleeps is a search that falls back to v1.
- **Misses ~25 %** on small objects: the tagger is the limit; a second tagging pass with another
  prompt, or a larger VLM on a rented GPU, are the next levers, not the embedding.
- Tag and check are English-term based; anything outside the 80-ish `SYNONYMS` terms (food names,
  places, "áo dài") has no tag match yet. A free-text term path (match the parser's English words in
  the tag text without the synonym table, then check) is needed before real use; measure it.

## 8. Continuation by Codex (2026-10-29)

Branch: `feat/search-v2`, no commit/push. Existing Android build fixes and other untracked
owner/teammate files are preserved. No shared DB writes or migration commands were executed.

- `eval.compare_tags` replaces the old top-40 evaluator used by `eval.index_tags`. Shared
  matching/prompts, cache fingerprints, incremental saves, bf16 full tag-match checks,
  absent-query stress tests, raw counts/errors and format diagnostics. Historical results and
  the partial original-detailed prompt failure are documented in `search-v2-plan.md`.
- Original detailed prompt is retained as `DETAILED_TAG_PROMPT`. A revised candidate is under
  evaluation as `TAG_PROMPT`; it is not approved for release. The original detailed run was
  stopped at 88 photos after 49 missing scene lines and 22 repeated-noun outputs. Raw cache
  remains intact. Full revised run log: `D:/clip_eval_tmp/search_v2/compare_tags_revised.log`.
- `search_v2` rejects nonfinite/out-of-range probabilities and invalid thresholds/batches;
  a model that returns the wrong number of answers is rejected before caching that batch.
- Server: `search_service.py`, `search_store.py`, `search_models.py`, `search_api.py`,
  `search_worker.py`; `api.search_app_factory` is a dedicated local search process. Normal
  Van Gogh app returns 503 for unconfigured `/search`. Local-only bf16 model, one model shared
  between worker/checks, one local search process lease, optional owner-scoped poller.
- `/search` accepts already-parsed English terms and metadata filters. It verifies the caller
  with Supabase, reads posts/relationships/photos with caller JWT, uses service role for
  `post_checks`, intersects terms, ranks by weakest check descending, rechecks visibility.
  Worker uses service role for its owner-scoped indexing operations, 20 pending posts per
  poll/run; three failures mark failed. No post creation path waits for tagging.
- Server tests use HTTP mocks to verify permission boundaries, not the real project's RLS.
  Flutter search/query tests passed 43. Full server test count is updated after final checks.
- Startup/API details: `server/search-v2-readme.md`. No real worker/server has been started.

To keep implementation moving while GPU measurement ran, the server foundation was built
ahead of the original step order. It remains opt-in and unshipped. Query-model parsing,
Vietnamese evaluation, real-photo acceptance, phone connectivity and app integration remain.

## 9. Latest implementation (2026-10-29, after owner requested app integration)

- Signed-in History now prefers v2 when its separate server address/token are configured.
  `search_v2_client.dart` calls `/search/parse` then `/search`. AppShell injects this client.
  IDs are resolved through caller-scoped Supabase reads and retain server ranking. Empty v2
  answers are final. Unavailable/unconfigured server -> labelled QUICK RESULTS from v1.
- History has a search-server setup button, pending-index and unsupported-query notices;
  setup explains local laptop processing. Existing metadata, names, hour filters and v1
  fallback remain. Stale searches cannot overwrite results after a newer search/clear.
- `query_parser.py`: local Qwen3-0.6B, CPU, typed JSON with rules as validator; name-only and
  unsupported negation never invoke vision. `eval.train_query_parser`: LoRA trained for 3
  epochs on 120 synthetic Vietnamese queries, 40 held out. Artifacts automatically detected
  at `D:/clip_eval_tmp/search_v2/query_parser_lora` or `LOCKET_QUERY_ADAPTER`. Held-out CPU
  evaluation writes `heldout_report.json`. This is not real Vietnamese acceptance.
- Selected `TAG_PROMPT` is the short prompt: fresh bf16 full-coverage check gave 4.40% wrong /
  23.33% missed, revised prompt 4.30% / 26.57%. Detailed/revised constants and caches remain
  available for reproduction. The larger negative-only no-answer stress test still fails
  95%; this is owner-test implementation, not a completed production release gate.
- 76 server tests and 51 targeted Flutter search tests passed before final formatting.
  Full Flutter suite: 879 passed, 2 skipped, 2 failures in Albums/Groups expectations outside
  the search changes. Analyzer initially identified one existing style_art.dart lint plus
  new brace-style infos; the new infos were corrected. Final check logs are in eval cache.
- Real GPU smoke passed tag/check; final-token logits optimization avoids wasted VRAM.
  CPU parser currently takes seconds and may be slow on first load. Phone latency, real
  Locket-photo acceptance and live Supabase RLS verification remain outstanding.
- Run/setup instructions: `server/search-v2-readme.md`. No shared DB writes, worker indexing,
  phone installation, deployment, commits or pushes were performed. Branch `feat/search-v2`.

Final results: 76 server tests and 51 targeted search Flutter tests passed. Full Flutter:
879 passed, 2 skipped, 2 Albums/Groups failures outside search. Analyzer: one existing
`camera/style_art.dart` brace-style info; no new diagnostics. Qwen3 held-out synthetic eval
completed (40): 0 invalid JSON, exact terms 90%, friend/mine/date 100% after rule validation.
Remaining confusions: umbrella->parking meter, toilet->sink, sink->toilet, teddy bear->bear.
No production Vietnamese accuracy claim: this still needs correction and real acceptance.
Worker supports explicit `LOCKET_SEARCH_TAG_OWNER=all` after owner rollout; default stays off.
