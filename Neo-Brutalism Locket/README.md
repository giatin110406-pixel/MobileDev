# Pocket Portrait

A Flutter camera and private, on-device photo archive with a neo-brutalist visual system.

## Included

- Camera-first capture flow with flash and front/back camera controls.
- Original photos saved separately from processed PNGs in the app's documents directory.
- Deterministic local palette reduction and edge outlining, executed in a background isolate.
- Original/processed comparison, processing status, retry, and a persistent local archive.
- Neo-brutalist Friends, Inbox, and conversation screens using the local Figma component palette.
- Local friend profiles, unread state, text messages, and messages containing a saved print.
- No photo upload, account, or cloud service.

## Daily quest, Sunbit and shop

- **Daily quest**: one photo quest per user per day (new day at 00:00 Vietnam time), each tied to Van Gogh or 8-bit and a true story (`lib/features/quest/quest_catalog.dart`). Camera only, 3 tries a day; the laptop server checks the subject with CLIP (`POST /v1/verify`, see `server/README.md`). A match is styled, celebrated, captioned (max 80 characters) and posted to the profile and feed, where it plays orchestral (Van Gogh) or chiptune (8-bit) music while on screen (`assets/music/CREDITS.md`).
- **Sunbit**: +25 per completed quest, +50 more when the streak reaches a multiple of 7. Earned only from quests, spent only in the shop, never negative. One reward per day; missing a day resets the streak.
- **Shop**: 10 avatar frames and profile banners (common 50-100, rare 150-250, legendary 400-500), previewed on your own avatar/banner, owned forever, one of each kind equipped at a time, free to swap. Your quest, wallet and shop state is one local record (`lib/features/progress/`).
- Sample friends show frames, banners and quest posts locally; real friends' cosmetics need the sync backend below.

Friends and messages currently live only on this device. The sample conversations are marked `SAMPLE`; adding a handle creates a local profile, not a real remote connection. Cross-device friend requests, delivery, and sync require a backend and authentication service, which are not included.

The current image engine includes Android on-device selfie segmentation, confidence-mask feathering, and selectable palette background replacement with conservative fallbacks. iOS stays on its existing 13.0 deployment target and uses the no-mask poster fallback because current ML Kit segmentation requires iOS 15.5. Face landmarks, region-aware smoothing, XDoG, LAB palette matching, and real-device quality/performance validation are still pending.

## Run

```powershell
flutter pub get
flutter run
```

Run on a physical Android or iOS device to use the camera. Android builds on Windows may need Kotlin incremental compilation disabled when the Flutter pub cache and workspace are on different drives:

```powershell
$env:ORG_GRADLE_PROJECT_kotlin_incremental='false'
flutter build apk --debug
```

## Verify

```powershell
flutter analyze
flutter test
```

