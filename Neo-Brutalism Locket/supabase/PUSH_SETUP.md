# Push notifications: one-time setup

Supabase has no way to wake a closed phone, so pushes go through Google's
Firebase Cloud Messaging (FCM). Firebase is used for nothing else: sign-in, data
and pictures all stay on Supabase. FCM is free.

How it flows:

```
something happens (new post, message, reaction, friend request)
  → a database trigger calls the `notify` Edge Function
  → the function checks blocks and the person's notification settings
  → it asks FCM to push to that person's phones
  → the phone shows the notification; tapping it opens the right screen
```

Until you finish the steps below the app works exactly as before, just without
pushes (the database triggers do nothing, and the app skips Firebase).

## 1. Firebase project (5 minutes)

1. https://console.firebase.google.com → **Add project** (Google Analytics can be off).
2. In the project: **Add app → Android**.
   - Package name: `com.neobrutalism.neo_brutalism_locket`
   - Download **`google-services.json`** and put it in `android/app/`.
     (It is git-ignored.)
3. **Project settings → Service accounts → Generate new private key**. Keep that
   JSON file somewhere safe **outside** the repository. It can send pushes as
   your project; treat it like a password.

## 2. Supabase secrets

In PowerShell, from the repository folder (replace the path):

```powershell
$b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\keys\firebase-service-account.json"))
$secret = -join ((48..57)+(97..122) | Get-Random -Count 40 | ForEach-Object {[char]$_})
npx supabase secrets set FCM_SERVICE_ACCOUNT_B64=$b64 NOTIFY_SECRET=$secret
$secret   # keep this value for step 4
```

## 3. Deploy the function and the database changes

```powershell
npx supabase functions deploy notify --no-verify-jwt --use-api
npx supabase db push
```

(`--no-verify-jwt`: the database calls the function with `NOTIFY_SECRET`, not a
user login. `--use-api` means Docker is not needed.)

## 4. Tell the database where the function is (Vault)

Dashboard → **SQL Editor**, with your project address and the secret from step 2:

```sql
select vault.create_secret('https://YOUR-PROJECT-REF.supabase.co', 'project_url');
select vault.create_secret('THE-SECRET-FROM-STEP-2', 'notify_secret');
```

These are stored encrypted in Vault, not in any file in the repository.

## 5. Try it

1. Run the app on a phone with `flutter run --dart-define-from-file=env/dev.json`;
   sign in and **allow notifications** when asked.
2. On a second account (another phone, or the emulator), send that person a
   message or a photo.
3. The first phone should show a notification. Tapping it opens the chat, the
   feed or the friend list.

Each person chooses which kinds they want in **Settings → Notifications**.

## Checking the whole chain without a phone

`python supabase/e2e/e2e_check.py --push-probe` registers a fake phone, sends a message to
it, and prints a SQL query for `net._http_response`. A healthy chain answers
`200 {"sent":0,"removed":0,"rejected":[400]}`: the database trigger, Vault, the function and
your Firebase key all worked, and Google only refused the fake phone token.

## If nothing arrives

- **Phone side**: no `google-services.json` in `android/app/` means Firebase
  never starts (look for "Push notifications are off" in `flutter run` output).
  On Android 13+, notifications must be allowed in the phone's app settings.
- **Is the phone registered?** SQL Editor: `select user_id, platform, updated_at from device_tokens;`
- **Did the database call the function?**
  `select status_code, content from net._http_response order by created desc limit 5;`
  (401 = the Vault `notify_secret` differs from the function's `NOTIFY_SECRET`.)
- **What did the function say?** Dashboard → Edge Functions → `notify` → Logs.
  A message about the token exchange or `PERMISSION_DENIED` usually means the
  service account JSON is for a different Firebase project, or the **Firebase
  Cloud Messaging API (V1)** is off (Project settings → Cloud Messaging).
- `{"sent":0,"skipped":"no devices"}` although a phone is registered, or a 500 naming a query: the
  function's service role lacks access to a table (migration 8 grants it; this project does not auto-expose tables).
- A friend who blocked you, a switched-off setting and a person with no phones
  are skipped on purpose.

## Checks that run without any of this

- `node --test supabase/functions/notify/logic.test.ts` — message texts, settings,
  the FCM request and the Google sign-in token (signed and verified for real).
- `python supabase/e2e/e2e_check.py` — phone registration and settings rules.

## Home-screen widget (Android)

The widget shows the newest photo a friend sent. Nothing new to set up in
Firebase or the database, but **redeploy the function** so it also sends the
silent "widget_update" message (photo link, name, caption):

    npx supabase functions deploy notify --no-verify-jwt --use-api

On the phone: long-press the home screen → Widgets → "Ảnh của bạn bè" (2×2,
resizable). Tapping it opens that post.

- The widget updates when a friend posts (even with the app closed), and when
  the app is opened. It is cleared on sign-out.
- The photo link in the message lasts an hour; the app downloads the picture
  at once, so the widget keeps showing it afterwards.
- Not done: a widget limited to one friend; iOS widget.
