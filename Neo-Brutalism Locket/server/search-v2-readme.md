# Local Search v2

The signed-in History search now uses this flow when configured:

`typed query -> local Qwen3 parser -> POST /search -> Supabase-visible post IDs -> existing grid`

V1 is the labelled quick-results fallback when the server is unavailable or unconfigured.
An empty successful v2 response stays empty. This is implemented for owner testing; the real
photo, Vietnamese acceptance, live RLS and phone latency release gates are not all closed.

## Server configuration

Set these in server/.env; never put the service role key in the app or git:

```dotenv
LOCKET_TOKEN=<app/server token>
SUPABASE_URL=https://<project>.supabase.co
SUPABASE_ANON_KEY=<publishable or legacy anon key>
SUPABASE_SERVICE_ROLE_KEY=<server-only service role key>
# Set this to index your initially pending posts, 20 per poll:
LOCKET_SEARCH_TAG_OWNER=<owner UUID>
# After owner acceptance, 'all' explicitly enables tagging all app authors for friends' search.
# Optional cache/adapter overrides:
# LOCKET_SEARCH_MODEL_CACHE=D:/data-moved/huggingface/hub
# LOCKET_QUERY_ADAPTER=D:/clip_eval_tmp/search_v2/query_parser_lora
```

From server/, for laptop-only testing:

```powershell
.venv/Scripts/python.exe -m uvicorn locket_server.api:search_app_factory --factory --host 127.0.0.1 --port 8766 --workers 1
```

For a phone on the same LAN use `--host 0.0.0.0`, then the laptop IP and port 8766. Existing
LAN/firewall/USB guidance is in README.md. No firewall/tunnel configuration was changed here.
Run one search process and stop the Van Gogh diffusion process on the 6 GB GPU. The default
Van Gogh factory keeps /search unavailable unless a search service is injected.

In the app: History -> server icon beside the search field -> enter laptop-IP:8766 and
LOCKET_TOKEN -> TEST -> SAVE. Search settings are separate from the Van Gogh settings. The
sheet explains that queries/photos are processed on the connected laptop. Optional build
settings SEARCH_V2_URL / SEARCH_V2_TOKEN provide initial defaults.

## Models and parsing

Qwen2-VL-2B runs in bf16 on the GPU, loaded once and shared by tagging and checks. Tags use
448*28*28 pixels and at most 220 generated tokens. Checks use 320*28*28 pixels, batch up to 8,
and compute logits for the final token only. An OS lease prevents duplicate search processes.
All inference is local; model loading requires files already cached, with no inference API.

Qwen3-0.6B runs on CPU to leave GPU memory for vision. A LoRA adapter was trained locally
on 120 synthetic Vietnamese queries for 3 epochs, with 40 queries held out. This laptop
loads D:/clip_eval_tmp/search_v2/query_parser_lora automatically when present; otherwise set
LOCKET_QUERY_ADAPTER to the trained adapter directory. Reproduce with eval.train_query_parser.
The adapter is outside git; training source and corpus construction are in the repository.
CPU parsing takes seconds, and first use also loads weights. LOCKET_QUERY_THREADS defaults to 4.

Model output is typed JSON. Client rules preserve recognized dates/friends/mine. Invalid
model dates and unknown friends fall back to rule values. Invalid JSON cannot execute a search.
Name-only searches never invoke a photo model. Negation that requires proving absence is
currently declined rather than returning unsupported visual matches. The UI explains this.
Synthetic training does not establish real Vietnamese accuracy or superiority over rules.
Held-out synthetic evaluation completed: 40 queries, 0 invalid JSON, 90% exact term accuracy;
friend/mine/date fields were 100% after rule validation. Four object confusions remain
(umbrella/parking meter, toilet/sink, sink/toilet, teddy bear/bear). This fails a claim of
production Vietnamese reliability; do not treat English COCO accuracy as Vietnamese accuracy.

## HTTP contract

Both POST endpoints require X-Locket-Token and Authorization: Bearer <Supabase access token>.
POST /search/parse takes text, visual_text, now, friends, my_names and the client rules result;
it returns {query, declined}. The app then sends the validated query to POST /search:

```json
{
  "terms": ["dog", "cup"],
  "mine": false,
  "friend_id": null,
  "from_time": "2026-10-01T00:00:00+07:00",
  "until_time": "2026-11-01T00:00:00+07:00",
  "name_only": false
}
```

Dates need offsets (inclusive start, exclusive end). Terms are parsed English object names.
Response: {"post_ids": ["..."], "pending": 0}. A result must match tags AND check >=0.8 for
each term. Terms intersect. Highest minimum check ranks first, newest breaks ties. Empty
terms run metadata filters. Current friend and time-of-day behavior is preserved in the app.
Pending/failed indexing counts appear in results. HTTP 429/503 may use labelled v1 fallback;
a successful empty response never falls back to closest photos.

Supabase verifies the JWT. Posts, relationships and photos use caller JWT. Visible IDs are
rechecked after inference. Only visible candidate cache entries are accessed. Internal
post_checks uses service role; completed batches persist even when a later batch fails.
No query JWT/photo bytes are logged or saved to disk. GET /v1/health supports app setup.

## Worker and backfill

With LOCKET_SEARCH_TAG_OWNER, the dedicated API polls in a background thread. Posting never
waits for it. It uses originals for photos, thumbnails for videos, writes tags and marks done.
Errors increment attempts; three errors mark failed. GPU contention does not spend retries.
Updates compare previous pending status/attempts and exclude deleted posts. Initial rollout
is scoped to the configured author. For a single batch of at most 20, with the API stopped:

```powershell
.venv/Scripts/python.exe -m locket_server.search_worker --owner <owner-UUID>
```

The worker writes to the configured database. It has not been run against the shared project
in this session. No new migration is needed beyond the already-applied photo-search migration.

## Verification and limits

Server tests use HTTP mocks for permission boundaries, not a live Supabase project. Search
Flutter tests cover remote results, authoritative empty answers, caller JWT, ranking, rule
filters and labelled fallback. GPU smoke ran the real VLM tag/check adapter successfully.

Fresh comparison on the same 300-photo pool: short prompt + bf16 check >=0.8 gave 4.40% wrong /
23.33% missed; revised prompt gave 4.30% / 26.57%. The short prompt is selected. Both tested
candidates and raw caches are retained. A large negative-only-library stress test remains
below the 95% empty-result target; real-photo acceptance and phone latency remain unverified.
No claim is made that v2 is production-ready or that all release gates passed.

Final checks: 76 server tests and 51 targeted Flutter search tests passed. Full Flutter run:
879 passed, 2 skipped, 2 failures in Albums/Groups expectations. flutter analyze has one
existing brace-style info in camera/style_art.dart; no new diagnostics in the changed code.

Artifacts/logs: D:/clip_eval_tmp/search_v2/. Adapter report: query_parser_lora/heldout_report.json.
Run server tests with python -m pytest tests; app tests with flutter test; comparison with
PYTHONPATH=.eval_tools python -m eval.compare_tags --offline from server/.
