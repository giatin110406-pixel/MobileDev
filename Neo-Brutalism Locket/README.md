# Pocket Portrait (Neo-Brutalism Locket)

A Flutter camera app with a neo-brutalist look. Take a photo, turn it into a Van Gogh painting or 8-bit pixel art, share it with friends, and complete a daily photo quest to earn Sunbit and unlock cosmetics.

## Features

- **Camera and styles**: front/back camera, flash, before/after comparison. Styles: original, **8-bit** (runs fully on the phone) and **Van Gogh** (on-device Magenta TFLite model, or a high-quality diffusion server on a laptop GPU).
- **Accounts and friends** (Supabase): email sign-up, friend requests, blocking and reporting, account deletion.
- **Feed, chat and reactions**: post a print to friends, react, reply, send messages.
- **Daily quest**: one photo quest per user per day (new day at 00:00 Vietnam time), each tied to Van Gogh or 8-bit and a true story (`lib/features/quest/quest_catalog.dart`). Camera only, 3 tries a day. The laptop server checks the subject with CLIP (`POST /v1/verify`, see `server/README.md`). A match is styled, captioned (max 80 characters) and posted to the profile and feed, with orchestral (Van Gogh) or chiptune (8-bit) music (`assets/music/CREDITS.md`).
- **Sunbit**: +25 per completed quest, +50 more when the streak reaches a multiple of 7. Earned only from quests, spent only in the shop, never negative. One reward per day; missing a day resets the streak.
- **Shop**: 10 avatar frames and profile banners (common 50-100, rare 150-250, legendary 400-500). Quest, wallet and shop rules run on the server (`supabase/migrations/`).
- **Home-screen widget** (Android) and **push notifications** (optional, Firebase FCM).
- English and Vietnamese UI.

Without a backend config the app still runs offline: the archive is local and friends/messages are marked `SAMPLE`.

## Repository layout

| Path | Contents |
|---|---|
| `lib/` | Flutter app |
| `test/` | Widget and unit tests |
| `assets/` | TFLite models, style reference, music |
| `supabase/` | Database migrations, RLS, pgTAP tests, `notify` Edge Function. See `supabase/README.md` |
| `server/` | Optional laptop GPU server (Van Gogh diffusion + quest check). See `server/README.md` |
| `env/` | `dev.json.example`; copy to `env/dev.json` (git-ignored) |

## Quick start

Full Vietnamese step-by-step guide: `docs/HUONG_DAN_CHAY_APP.docx`.

Requirements: Flutter SDK (Dart >= 3.11), Android SDK, a physical Android device (the camera does not work well on emulators).

```powershell
flutter pub get
Copy-Item env\dev.json.example env\dev.json   # then fill in the two values below
flutter run --dart-define-from-file=env/dev.json
```

`env/dev.json` needs:

```json
{
  "SUPABASE_URL": "https://YOUR-PROJECT-REF.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_..."
}
```

- **Use the shared database**: ask the project owner for the two values.
- **Use your own database**: create a Supabase project and apply the migrations (`supabase/README.md`), then use your project's URL and publishable key.
- The publishable key is public by design; access is enforced by row-level security. Never put a `service_role` key in this file or in the repo.
- If you skip `--dart-define-from-file`, the app runs offline-only.

`GOOGLE_WEB_CLIENT_ID` in `env/dev.json.example` is reserved for a future Google sign-in and is not used yet. Sign in with email.

### Optional

- **Push notifications**: needs your own `android/app/google-services.json` (git-ignored) and the setup in `supabase/PUSH_SETUP.md`. Without it the app builds and runs normally, just without pushes.
- **Laptop server**: needed for the quest photo check and high-quality Van Gogh. Requires an NVIDIA GPU. See `server/README.md`.

### Building an APK

```powershell
flutter build apk --release --dart-define-from-file=env/dev.json
```

Release builds are currently signed with the debug key; add your own signing config before publishing. On Windows, if the Flutter pub cache and the project are on different drives, disable Kotlin incremental compilation first:

```powershell
$env:ORG_GRADLE_PROJECT_kotlin_incremental='false'
```

## Verify

```powershell
flutter analyze
flutter test
```

## Notes

- Model and music licenses: `assets/models/README.md`, `assets/music/CREDITS.md`, and the "Models and licenses" section of `server/README.md`. Verify them before any public release.
- The server uses cleartext HTTP and is meant for personal LAN/USB use only.
