# Omni POV: live video and network setup

Omni POV sends the photographer's camera as a continuous WebRTC video track.
The viewer must see this track before any photo is taken. The shutter only saves
a photo locally and sends a separate count notification.

## Fixed signaling failure

The phone log contained:

```text
Unable to RTCPeerConnection::setRemoteDescription:
No enum constant org.webrtc.SessionDescription.Type.BROADCAST
```

`realtime_client` 2.13 writes its transport `type` and `event` into the outer
map passed to `sendBroadcastMessage`. Passing a WebRTC SDP at that level changed
its `type: offer/answer` into `type: broadcast`. Signals now go inside `payload`;
the native SDP type is also derived from the application discriminator `t`.

Regression tests cover the installed SDK's serialization and the native SDP call:

```powershell
flutter test test/pov_signaling_test.dart test/pov_store_test.dart test/pov_ui_test.dart
```

The native camera/video check can be run separately:

```powershell
flutter run -d <device-id> -t test/tools_device/pov_live_video_probe.dart
```

On SM A528B it received two decoded remote frames before any photo notification
(`POV_VIDEO_PASS`, 0 photos). This is a local loopback test of two WebRTC peers
on one phone; it does not prove cross-network connectivity or QR authorization.
After this diagnostic, restore the real app:

```powershell
flutter run -d <device-id> --dart-define-from-file=env/dev.json
```

## Wi-Fi to 4G/5G

The linked Supabase project's secret names were checked on 2026-10-29:
`METERED_APP` and `METERED_SECRET_KEY` were absent. The existing `pov-ice`
function therefore returns STUN only. Cross-network connections may fail behind
carrier NAT. Configure a TURN relay before treating Wi-Fi to mobile data as ready.

1. Create a Metered account and obtain the app name and TURN secret API key.
   Official setup: https://www.metered.ca/tools/openrelay/
2. From the project root, run the helper below. It prompts for the key with input
   hidden, uploads it as Supabase secrets, removes its temporary file and deploys
   the existing `pov-ice` function. Do not paste the key into chat or commit it.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/setup-pov-turn.ps1
```

3. End any current POV session. Start a new QR session on both phones so they fetch
   fresh ICE servers. Verify moving video while the shot counter remains zero,
   first on the same Wi-Fi and then with one phone on mobile data.

The backend currently permits one viewer and one photographer per session.
Multiple simultaneous viewers require a separate session/backend change.
