# Supabase backend

Schema, row-level security and (later) Edge Functions for accounts, friends,
posts and sync. The app still runs on this device only until it is built with a
backend config (see "Run the app against it").

## One-time setup

1. Create a project at https://supabase.com/dashboard (region: Singapore is closest to Vietnam).
2. Install the CLI without a global install: `npx supabase --version`.
3. From the repo root:
   ```powershell
   npx supabase login
   npx supabase init          # creates supabase/config.toml (keep the existing migrations)
   npx supabase link --project-ref YOUR-PROJECT-REF
   npx supabase db push       # applies supabase/migrations/*.sql
   ```
4. Auth providers (Dashboard → Authentication → Providers):
   - Email: on. For development you may turn off "Confirm email".
   - Google: create OAuth clients in Google Cloud (a Web client and an Android
     client with this app's package name + SHA-1 from `cd android; ./gradlew signingReport`),
     paste the Web client id/secret into Supabase.
   - Apple: later (needs an Apple Developer account).

## Run the app against it

Copy `env/dev.json.example` to `env/dev.json` (git-ignored), fill in the project
URL, the publishable key (Settings → API Keys) and the Google Web client id, then:

```powershell
flutter run --dart-define-from-file=env/dev.json
```

## Local database (optional)

`npx supabase start` runs Postgres + Auth + Storage locally but needs Docker
Desktop. With it, `npx supabase test db` runs the pgTAP tests in `supabase/tests/`.

## Migrations

| File | Contents |
|---|---|
| `20261007000001_profiles.sql` | `profiles` (auto-created at sign-up), column-level update grants, `avatars` bucket + policies |
| `20261007000002_friends.sql` | `friend_requests`, `friendships`, `blocks` (read-only for clients); RPCs `send_friend_request`, `respond_friend_request`, `cancel_friend_request`, `remove_friend`, `search_profiles`; 20-friend limit |
| `20261007000003_posts.sql` | `posts`, `post_recipients` (readable by author and recipients), private `media` bucket, `create_post` RPC (idempotent by id), realtime on `post_recipients` |
| `20261007000004_interactions.sql` | `post_reactions`, `post_views`, `messages`; RPCs `react_to_post`, `mark_post_viewed`, `delete_post`, `send_message`, `mark_thread_read`; realtime on messages and reactions |
| `20261007000005_player.sql` | `shop_items` (seeded), `player_state`, `sunbit_ledger`, `inventory`; RPCs `get_player_state`, `record_quest_attempt`, `complete_quest`, `buy_item`, `equip_item`, `unequip_item`, `set_music_muted` — all quest/Sunbit/shop rules run on the server |
| `20261007000006_safety.sql` | `reports`; RPCs `block_user`, `unblock_user`, `report_content`, `delete_my_account` |
| `20261007000007_push.sql` | `device_tokens`, `notification_prefs`, `register_device` / `unregister_device`, and the triggers that call the `notify` Edge Function (inert until the Vault secrets exist) |
| `20261007000008_service_role_grants.sql` | read access for the `notify` function's service role (this project does not auto-expose new tables) |
| `20261008000001_groups.sql` | `groups`, `group_members`, `group_invites`, `group_messages`, `group_reads` (readable by members only; same group does not mean friends); RPCs `create_group`, `update_group`, `invite_to_group`, `respond_group_invite`, `revoke_group_invite`, `kick_member`, `transfer_ownership`, `leave_group`, `dissolve_group`, `send_group_message`, `mark_group_read` |
| `20261008000002_ink.sql` | `ink_wallets`, `ink_ledger` (the canvas currency, separate from Sunbit); `complete_quest` now also pays +10 Ink; `player_json` returns `ink_balance`; `get_ink_balance` |
| `20261008000003_canvas.sql` | `palettes` (seeded), `canvases`, `canvas_events`; an empty 32x32 canvas for every new group; RPCs `get_canvas`, `get_group_canvas`, `get_canvas_events`, `paint_pixels` (atomic, 1 Ink per pixel), `new_canvas`, `rollback_user_events`; realtime on `canvas_events` |
| `20261008000004_group_invitee_reads_group.sql` | A person who has been invited can read the name of the group they were invited to |
| `20261009000001_contest.sql` | The weekly contest and the Gallery (Vietnam time, UTC+7): `contest_themes` (16 seeded), `contests`, `contest_entries` (a server-made snapshot of a canvas, first 100 only), `contest_participants`, `entry_votes`, `entry_reactions`, `entry_comments`, `contest_results`, `contest_config`; the lazy `contest_tick()` (also run every minute by pg_cron when available) that creates the weeks and finalizes; the Bayesian result and prizes in `finalize_contest()`; RPCs `get_current_contest`, `submit_entry` (owner only), `get_gallery`, `get_entry`, `get_entry_comments`, `vote_entry`, `react_entry`, `comment_entry`, `report_gallery`, `get_contest_results`, `get_hall_of_fame` |
| `20261009000002_report_entry_cascade.sql` | Reports about an entry go away with the entry (so a reported entry can be deleted) |
| `20261010000001_family_friendly.sql` | A list of refused words (Vietnamese with and without accents, English), matched as whole words only, in `contest_banned_words`; `contains_banned_word()`. Applied to contest comments, group chat messages, and group names and rules. Edit the table in the dashboard to add or remove words |
| `20261011000001_contest_shop.sql` | The three winners of a contest are sold as profile banners: `shop_items` gets `source_entry_id`, `title`, `stock`, `sold`, `royalty_percent`; `contest_make_shop_items()` (called when a contest is finalized, also gives each winner a free copy); `buy_item` now handles limited copies (`sold_out`) and shares 20% of a sale among the winning group (everybody involved is locked in the same order, so no deadlocks); RPCs `get_contest_shop` and `get_banner_art` |

## Password-reset link

The "forgot password" email returns to the app through `neolocket://reset-password`.
Add it in the dashboard under Authentication → URL Configuration → Redirect URLs, or the
link in the email will not open the app.

## Checking it from outside

`python supabase/e2e/e2e_check.py` signs up three throw-away accounts, drives every feature through the same calls the app makes, checks what must be refused too, and deletes the accounts. It uses only the publishable key. Needs "Confirm email" off.

`python supabase/e2e/e2e_groups.py` does the same for groups, Ink and the shared canvas (four throw-away accounts: owner, two members who are not friends with each other, and an outsider). It leaves behind one dissolved group named "E2E Painters" per run, because nobody can delete a group from the app; remove those in the dashboard.

`python supabase/e2e/e2e_contest.py` checks the contest end to end: seven throw-away accounts in three groups, two private test contests whose clock is moved with `supabase db query --linked` (so the CLI must be logged in and linked), the 100-entry cut, rating rules, comments, reports, the Bayesian result (3.7222 / 3.5 / 3.2778 for the votes it casts) and the prizes. It removes its contests, groups and accounts afterwards. With `E2E_DUMP=test/fixtures/contest` it also saves the server's real answers, which `test/contest_fixtures_test.dart` reads to make sure the app still understands them.

## Push notifications

See [PUSH_SETUP.md](PUSH_SETUP.md).
