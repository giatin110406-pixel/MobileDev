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

## Password-reset link

The "forgot password" email returns to the app through `neolocket://reset-password`.
Add it in the dashboard under Authentication → URL Configuration → Redirect URLs, or the
link in the email will not open the app.

## Checking it from outside

`python supabase/e2e/e2e_check.py` signs up three throw-away accounts, drives every feature through the same calls the app makes, checks what must be refused too, and deletes the accounts. It uses only the publishable key. Needs "Confirm email" off.

`python supabase/e2e/e2e_groups.py` does the same for groups, Ink and the shared canvas (four throw-away accounts: owner, two members who are not friends with each other, and an outsider). It leaves behind one dissolved group named "E2E Painters" per run, because nobody can delete a group from the app; remove those in the dashboard.

## Push notifications

See [PUSH_SETUP.md](PUSH_SETUP.md).
