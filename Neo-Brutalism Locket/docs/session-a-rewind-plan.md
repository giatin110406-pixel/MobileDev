# Session A: Chụp lùi thời gian — plan chi tiết

Viết ngày 2026-10-29. Người viết plan: Opus. Người code: Sonnet.
Đọc kèm `docs/feature-plan.md` (phần "Nguyên tắc chung" và "Session A").

---

## 0. Kết luận nghiên cứu (đọc trước khi code)

### 0.1 Không dùng `startImageStream` của plugin `camera`
Đã đọc mã `camera_android_camerax 0.6.30` (bản app đang dùng, CameraX 1.5.3):

- Mỗi khung hình đi qua **nhiều lượt gọi Pigeon** từ Dart (`getPlanes`, copy buffer, `close`). Khung chỉ được trả lại cho camera sau khi Dart `close`, nên số khung/giây phụ thuộc UI isolate.
- `ImageAnalysis` dùng **cùng** `ResolutionSelector` với preview (`ResolutionPreset.veryHigh` = 1080p). Không chọn riêng độ phân giải cho luồng hình được.
- Giữ 45 khung YUV 1080p trong heap Dart là khoảng 140MB nằm trong vùng GC của Dart. Đây đúng là rủi ro "hết RAM" và "khung ngắm giật" mà feature-plan đã nêu.

→ Làm thẳng phương án dự phòng của feature-plan: **pipeline native bằng Kotlin + CameraX**, ở một màn hình riêng.

### 0.2 Lưu khung dạng JPEG ngay lúc nhận, không giữ YUV
Feature-plan ghi "giữ YUV, chỉ đổi sang JPEG khung được chọn". Plan này **đổi lại**, vì:

- `maxUploadSide = 1080` (`lib/features/posts/media_encoding.dart`). Ảnh đăng lên tối đa 1080×1080, nên khung 1080×1080 lấy từ luồng hình **có đúng độ phân giải ảnh đăng**. Chỉ kém ảnh chụp chuẩn ở phần xử lý ISP (khử nhiễu nhiều khung), không kém về số điểm ảnh.
- Một khung YUV vuông 1080 tốn khoảng 1,7MB; JPEG q85 chỉ khoảng 150–300KB. 45 khung JPEG ≈ **7–14MB**, thay vì 75–140MB.
- `YuvImage.compressToJpeg(rect, …)` cắt vuông luôn lúc nén, nên không tốn thêm bước cắt.
- Cái giá là CPU: mỗi khung nén mất khoảng 10–30ms trên luồng nền. Bước 1 (bản thử) phải đo con số này.

### 0.3 Các sự thật kỹ thuật đã kiểm
- CameraX 1.5.3 có `ImageAnalysis.OUTPUT_IMAGE_FORMAT_NV21` (từ bản 1.4), nên CameraX tự đổi sang NV21 bằng code native, ta không phải tự viết vòng lặp đổi định dạng.
- Bộ ba Preview (PRIV) + ImageAnalysis (YUV, ≤ kích thước preview) + ImageCapture (JPEG max) **được bảo đảm trên mọi mức phần cứng**, kể cả LEGACY. Không bind VideoCapture ở màn này.
- App phải khai báo CameraX **đúng bản 1.5.3**, trùng với plugin (`camera-core`, `camera-camera2`, `camera-lifecycle`), để Gradle không kéo hai bản khác nhau.
- Plugin `camera` và code native của ta dùng chung singleton `ProcessCameraProvider` và cùng một `LifecycleOwner` (FlutterActivity). **Phải `await _camera.dispose()` của CameraTab trước khi mở màn lùi thời gian**, nếu không CameraX báo lỗi vì có hai camera trên cùng một lifecycle owner. Khi quay về thì khởi tạo lại camera.
- Không bao giờ gọi `unbindAll()`. Chỉ unbind đúng các use case của ta.
- Mốc thời gian của khung là `imageInfo.timestamp` (thời gian cảm biến). Nguồn đồng hồ đọc từ `CameraCharacteristics.SENSOR_INFO_TIMESTAMP_SOURCE` qua `Camera2CameraInfo`: `REALTIME` thì so với `SystemClock.elapsedRealtimeNanos()`, còn `UNKNOWN` thì so với `System.nanoTime()`. Thời điểm bấm được lấy **ở phía native** (ngay khi nhận lệnh `shutter`) bằng đúng đồng hồ đó.
- Ảnh chất lượng cao: `ImageCapture` với `CAPTURE_MODE_MINIMIZE_LATENCY`, dùng `OnImageCapturedCallback` (trong RAM) để đọc được `imageInfo.timestamp` và đặt ảnh này **đúng vị trí theo thời gian** trên dải khung. JPEG của nó được ghi ra file kèm EXIF orientation, rồi cắt vuông bằng `cropShotToSquare` có sẵn (`SquareCrop.kt` đã xử lý EXIF).
- Màn hình khóa: `TileService`. Từ Android 14 (API 34) phải gọi `startActivityAndCollapse(PendingIntent)`; bản nhận `Intent` ném `UnsupportedOperationException` khi target ≥ 34. Activity mở ra phải có `setShowWhenLocked(true)` + `setTurnScreenOn(true)` (API 27+; API 24–26 thì dùng cờ window `FLAG_SHOW_WHEN_LOCKED`/`FLAG_TURN_SCREEN_ON`).

### 0.4 Quyết định sản phẩm (Opus chốt, ghi rõ để nhóm có thể đổi)
1. **Trên màn hình khóa chỉ được chụp và chọn khung.** Bấm "Gửi" thì app gọi `KeyguardManager.requestDismissKeyguard`. Mở khóa xong mới vào màn soạn bài bình thường của app (chọn bạn bè, caption). Lý do: không để người cầm máy đang khóa thấy danh sách bạn bè hay feed. Pixel Camera cũng làm vậy với thư viện ảnh.
2. Màn lùi thời gian **không có** flash, hẹn giờ, quay video, quest mode. Flash làm các khung trước lúc bấm tối, nên không khớp với ảnh chụp chuẩn. Có đổi camera trước/sau.
3. Ảnh camera trước **không lật gương**, giống ảnh chụp hiện tại của app (ImageCapture và ImageAnalysis đều không lật). Khung ngắm thì vẫn lật như bình thường.
4. Khung mặc định được chọn khi mở dải là **ảnh chất lượng cao** (lúc bấm). Khung nào đến từ luồng hình thì hiện nhãn nhỏ "Khung phụ" để nói thật là chất lượng thấp hơn một chút.
5. Màn lùi thời gian khóa xoay dọc (portrait) khi mở; lúc thoát thì trả lại cài đặt xoay như trước.

---

## 1. Kiến trúc

```
CameraTab (camera_experience.dart)          ← chỉ thêm 1 nút + 1 hàm
   └─ _openRewind(): dispose camera → push RewindScreen → nhận bytes → khởi tạo lại camera → _startPrint(bytes)

lib/features/rewind/
   rewind_channel.dart      MethodChannel + EventChannel tới native (giao diện mỏng, có interface để fake trong test)
   rewind_timeline.dart     Model thuần Dart: danh sách khung, chèn ảnh HQ theo timestamp, khung mặc định, nhãn thời gian
   rewind_screen.dart       Khung ngắm (Texture) + nút chụp + dải khung để vuốt chọn + nút Gửi/Chụp lại
   rewind_handoff.dart      Tạo/đọc link neolocket://rewind?file=<tên> (kiểm tra tên file, chống path traversal)
   rewind_lockscreen_main.dart  Entry point Dart riêng cho Activity màn hình khóa

android/app/src/main/kotlin/.../rewind/
   RewindCamera.kt          Bind CameraX (Preview → Flutter SurfaceProducer, ImageAnalysis NV21, ImageCapture), vòng đời
   FrameRing.kt             Bộ đệm vòng theo thời gian, Kotlin thuần (không import android.*) để test JVM được
   RewindPlugin.kt          Đăng ký channel, nối RewindCamera ↔ Dart; đăng ký trong MainActivity và RewindLockscreenActivity
   RewindLockscreenActivity.kt  FlutterActivity, showWhenLocked, entrypoint "rewindLockscreenMain"
   RewindTileService.kt     Nút trong cài đặt nhanh
```

### 1.1 Luồng dữ liệu
1. `start(lens)` → native bind 3 use case, tạo `SurfaceProducer` từ `flutterEngine.renderer`, trả về `{textureId, previewWidth, previewHeight, sensorOrientation, lensFacing}`.
2. Analyzer chạy trên một `Executor` riêng (một luồng). Với mỗi khung:
   - Bỏ khung nếu cách khung giữ trước **< 60ms** (mục tiêu ~15 khung/giây).
   - `YuvImage(nv21…).compressToJpeg(cropRectVuôngGiữa, 85, stream)`, với cạnh vuông = `min(w,h)` và tối đa 1080. Nếu khung lớn hơn 1080 thì chọn resolution analysis sao cho cạnh ngắn ≈ 1080 (`ResolutionSelector` ưu tiên 1440×1080, fallback gần nhất).
   - Đẩy `Frame(timestampNs, jpeg: ByteArray, rotationDegrees)` vào `FrameRing`.
   - Dùng lại một mảng NV21 cấp phát sẵn, không cấp phát mảng mới cho mỗi khung.
3. `FrameRing` ở trạng thái **ARMED**: chỉ giữ các khung có `ts ≥ newestTs − 2000ms`.
4. `shutter()` → ghi `pressTs` (đồng hồ ở 0.3), gọi `ImageCapture.takePicture` song song, chuyển ring sang **AFTER_PRESS**: không bỏ khung cũ nữa, nhận thêm khung đến khi `ts ≥ pressTs + 1000ms`, rồi **FROZEN**.
5. Khi FROZEN và ảnh HQ đã về (hoặc ảnh HQ lỗi): ghi mọi khung ra `cacheDir/rewind/<sessionId>/f_<idx>.jpg`, ảnh HQ ra `hq.jpg`, rồi gửi về Dart **một lần**: `{frames: [{path, offsetMs (so với pressTs), rotation}], hq: {path, offsetMs} | null, pressTs}`. Sau đó unbind ImageAnalysis để tiết kiệm pin, giữ Preview.
6. Dart dựng `RewindTimeline`. Người dùng vuốt trên dải, khung lớn ở trên hiện khung đang chọn.
7. "Gửi":
   - Nếu là ảnh HQ: `cropShotToSquare(hq.path)`.
   - Nếu là khung phụ: native `finalizeFrame(path, rotation)` xoay bằng `Matrix`, encode JPEG q92, trả về bytes.
   - `Navigator.pop(bytes)` (trong app) hoặc chuyển giao sang app chính (màn hình khóa, mục 1.3).
8. "Chụp lại": xóa thư mục session, bind lại analysis, ring về ARMED.
9. `stop()` / dispose / Activity destroy: unbind use case của ta, giải phóng SurfaceProducer, xóa thư mục session. Lúc khởi động app thì xóa các thư mục `cacheDir/rewind/*` sót lại.

### 1.2 Khung ngắm (preview)
- Dùng `TextureRegistry.SurfaceProducer` (Flutter 3.41). Lấy `Preview.setSurfaceProvider` → `surfaceProducer.setSize(res.width, res.height)` → `request.provideSurface(surfaceProducer.surface, executor) { … }`.
- Xoay: nếu `surfaceProducer.handlesCropAndRotation()` thì không xoay ở Dart; nếu không thì ở Dart xoay `Texture` theo `sensorOrientation` (vì màn đã khóa portrait, độ xoay màn = 0), camera trước thì lật ngang. **Tham khảo cách plugin làm** trong `camera_android_camerax-0.6.30/lib/src/rotated_preview_utils.dart` và `image_reader_rotated_preview.dart` / `surface_texture_rotated_preview.dart` (trong pub cache). Không tự nghĩ ra công thức khác.
- Hiện khung ngắm vuông cắt giữa (cover), giống `CameraTab` hiện tại, để người dùng thấy đúng phần sẽ được lưu.
- Xử lý `SurfaceProducer.Callback` (`onSurfaceAvailable` / `onSurfaceCleanup`): khi surface bị thu hồi (app xuống nền) thì CameraX đã dừng nhờ lifecycle; khi có lại thì gọi lại `setSurfaceProvider`.

### 1.3 Màn hình khóa
- `RewindTileService` (`android:permission="android.permission.BIND_QUICK_SETTINGS_TILE"`, action `android.service.quicksettings.action.QS_TILE`, icon vector đơn sắc mới `ic_tile_rewind`, label từ `strings.xml`). `onClick`: Intent tới `RewindLockscreenActivity` với `FLAG_ACTIVITY_NEW_TASK`; API ≥ 34 dùng `PendingIntent.getActivity(…, FLAG_IMMUTABLE)`, còn dưới 34 dùng bản `Intent` (`@Suppress("DEPRECATION")`).
- `RewindLockscreenActivity : FlutterActivity`: `getDartEntrypointFunctionName() = "rewindLockscreenMain"`, `taskAffinity` riêng, `excludeFromRecents="true"`, `screenOrientation="portrait"`, `launchMode="singleInstance"`. Trong `configureFlutterEngine` đăng ký `RewindPlugin` và `SquareCrop`.
- `rewindLockscreenMain` (có `@pragma('vm:entry-point')`): `MaterialApp` tối giản (theme + localization của app), mở thẳng `RewindScreen(lockscreen: true)`. **Không khởi tạo Supabase**, không đụng tới dữ liệu người dùng.
- Gửi từ màn khóa: channel `dismissKeyguard`, native gọi `requestDismissKeyguard`.
  - `onDismissSucceeded`: lưu bytes khung đã chọn vào `filesDir/rewind_handoff/<timestamp>.jpg`, mở `MainActivity` với data `neolocket://rewind?file=<timestamp>.jpg`, rồi `finish()`.
  - `onDismissCancelled` / `onDismissError`: ở lại màn, giữ nguyên khung đã chọn, hiện thông báo "Mở khóa máy để gửi".
  - Máy không đặt khóa màn hình thì `requestDismissKeyguard` thành công ngay, cùng một đường code.
- Chưa có quyền camera: màn khóa **không** xin quyền. Hiện "Mở app để cho phép camera", bấm vào thì dismiss keyguard rồi mở `MainActivity`.
- Phía app chính: trong `app_shell.dart`, `_onInviteLink` đã nhận mọi link `neolocket://`. Thêm một nhánh: `rewindFileFromLink(uri)` (ở `rewind_handoff.dart`) trả tên file nếu hợp lệ (`^\d+\.jpg$`, nằm trong `rewind_handoff/`). Nếu đã đăng nhập thì `_selectTab(_cameraTab)` → `_camera?.importShot(bytes)` → xóa file handoff. Nếu chưa đăng nhập thì vẫn xóa file và không làm gì thêm.
- `CameraTabState.importShot(Uint8List bytes)`: public, gọi `_startPrint(bytes)` giống đường ảnh thư viện (`_confirmCrop`). Bỏ qua nếu đang `_processing`, `_questMode` hoặc đang trong draft.

### 1.4 Điểm vào trong `camera_experience.dart` (giữ nhỏ, tránh xung đột với Session B/C)
- Một nút icon (ví dụ `Icons.history_toggle_off`) ở hàng nút phụ cạnh nút flash/đổi camera; ẩn khi `_questMode` hoặc `!Platform.isAndroid`.
- `_openRewind()`:
  1. Return nếu `_processing` hoặc `_recording`.
  2. `final old = _camera; _camera = null; setState(loading); await old?.dispose();`
  3. `final bytes = await Navigator.push<Uint8List>(… RewindScreen(initialLens: _cameras[_cameraIndex].lensDirection))`
  4. `await _initializeCamera();`
  5. `if (bytes != null) await _startPrint(bytes);` (bọc try/catch như `_confirmCrop`, lỗi thì `_notify(photoNotSaved)`).
- `importShot` (mục 1.3).
- Tổng thay đổi ở file này nên dưới khoảng 60 dòng.

---

## 2. Các bước làm (theo thứ tự, mỗi bước một commit)

**Nhánh:** `git fetch origin` rồi tạo `feat/rewind-capture` từ `origin/master`. Không làm trên `perf/history-image-cache`.

### Bước 1: Bản thử native + số đo (cổng đi tiếp)
- `build.gradle.kts`: thêm `androidx.camera:camera-core|camera-camera2|camera-lifecycle:1.5.3`, `testImplementation("junit:junit:4.13.2")`.
- `FrameRing.kt` + test JVM (`android/app/src/test/kotlin/...`): giữ đúng cửa sổ 2s khi ARMED; AFTER_PRESS nhận tới `press+1000ms` rồi FROZEN; bỏ khung cách nhau < 60ms; khung đến sau FROZEN bị bỏ; `reset()` về ARMED và giải phóng hết; tổng byte không vượt trần (trần cứng 40MB, vượt thì bỏ khung cũ nhất và tăng bộ đếm `dropped`).
- `RewindCamera.kt` + `RewindPlugin.kt` + màn Dart tạm (chỉ preview + nút chụp + chữ số đo).
- **Số đo** (native tính, gửi qua method `stats`, chỉ hiện ở debug build): số khung giữ được trên giây, p50/p95 thời gian nén một khung, kích thước JPEG trung bình, tổng byte ring, `Debug.getNativeHeapAllocatedSize()`, độ phân giải analysis và preview thực tế, khoảng lệch giữa `hq.timestamp` và `pressTs`.
- **Cổng:** trên máy thật tầm trung, ≥ 12 khung/giây giữ được, p95 nén ≤ 50ms, ring ≤ 25MB. Nếu không đạt: hạ cạnh vuông về 900, rồi 720 (một hằng số `FRAME_SIDE`), ghi lại số đo vào mục 5 của file này. **Bước này cần người thật cầm máy** (Sonnet không chạy được máy thật). Sonnet làm xong code và hướng dẫn đo, rồi đi tiếp các bước sau; con số được điền sau.

### Bước 2: Dải khung + model thời gian
- `rewind_timeline.dart` (Dart thuần) + `test/rewind_timeline_test.dart`:
  - sắp xếp khung theo `offsetMs`; chèn HQ đúng vị trí theo `offsetMs` của nó;
  - `defaultIndex` = HQ, nếu không có HQ thì khung gần `offset 0` nhất;
  - nhãn hiển thị `-1,2s` / `0` / `+0,6s` (một chữ số thập phân, dấu phẩy theo locale vi, dấu chấm theo en);
  - HQ lỗi → timeline vẫn dùng được, chỉ gồm khung phụ; không có khung nào → trạng thái lỗi rõ ràng.
- `rewind_screen.dart`: sau khi FROZEN, khung lớn hiện khung đang chọn; bên dưới là dải ảnh nhỏ cuộn ngang. Vuốt ngang trên ảnh lớn cũng đổi khung, có haptic nhẹ mỗi khung (dùng `Haptics` sẵn có). Nút: **Gửi**, **Chụp lại**, **Đóng**.
- Trong lúc chờ 1 giây sau khi bấm: hiện vòng đếm "Đang giữ khoảnh khắc…" và khóa nút chụp.
- Dùng style neo-brutalism sẵn có (viền đen dày, `NeoPress`…). Xem các widget trong `lib/features/camera/` và `lib/core/` để dùng lại, không tạo hệ style mới.

### Bước 3: Nối vào CameraTab (mục 1.4)
- `finalizeFrame` native + `importShot` + `_openRewind`.
- Chuỗi l10n vào **cả** `app_vi.arb` và `app_en.arb` (có `l10n_parity_test.dart`), rồi `flutter gen-l10n`.

### Bước 4: Màn hình khóa (mục 1.3)
- Tile, Activity, entry point, `rewind_handoff.dart` + `test/rewind_handoff_test.dart` (link hợp lệ; `../x.jpg`, `a.png`, thiếu `file`, sai host đều trả `null`).
- Nhánh link trong `app_shell.dart`.

### Bước 5: Dọn dẹp và chống lỗi
- Xóa `cacheDir/rewind/*` lúc khởi động (`RewindPlugin` khi attach) và khi đóng màn.
- Xóa file `rewind_handoff/*` cũ hơn 1 giờ lúc app chính khởi động.
- App xuống nền khi đang ở AFTER_PRESS thì vẫn hoàn tất với những khung đã có. Nếu ảnh HQ bị hủy do camera đóng thì `hq = null`.
- Lỗi camera (`CameraState.ERROR`, bind thất bại) → Dart hiện "Camera đang bận" + nút thử lại; không crash, không treo.
- `onTrimMemory(TRIM_MEMORY_RUNNING_LOW)` khi ARMED → `reset()` ring.

---

## 3. Giao diện channel (chốt tên, đừng đổi)

`MethodChannel("com.neobrutalism.neo_brutalism_locket/rewind")`

| Method | Tham số | Trả về |
|---|---|---|
| `start` | `{lens: "back"\|"front"}` | `{textureId, previewWidth, previewHeight, sensorOrientation, lensFacing, handlesCropAndRotation}` |
| `shutter` | – | `null` (kết quả đến qua event) |
| `rearm` | – | `null` |
| `finalizeFrame` | `{path, rotation}` | `Uint8List` JPEG vuông, đã xoay đứng |
| `stats` | – | map số đo (debug) |
| `stop` | – | `null` |
| `dismissKeyguard` | – | `bool` (true = đã mở khóa) |
| `handoff` | `{bytes}` | `null` (chỉ ở Activity màn khóa: lưu file, mở MainActivity, finish) |

`EventChannel("com.neobrutalism.neo_brutalism_locket/rewind_events")`: `{type: "holding"}`, `{type: "frozen", frames: […], hq: {…}|null}`, `{type: "error", code, message}`.

Phía Dart bọc trong `abstract class RewindBackend` + `MethodChannelRewindBackend`, để widget test dùng `FakeRewindBackend` (giống cách repo đang fake ở `test/fakes_backend.dart`).

---

## 4. Tiêu chí đạt (đo được)

| # | Tiêu chí | Cách đo | Ngưỡng |
|---|---|---|---|
| 1 | Bấm trễ 1 giây vẫn lấy lại đúng khoảnh khắc | Quay camera vào màn hình máy khác đang chạy đồng hồ bấm giờ có phần nghìn giây. Nhìn số T, bấm lúc T+1s. Trên dải phải có khung hiện T | Sai ≤ 1 khung (≤ 70ms), 10/10 lần |
| 2 | Ảnh HQ đặt đúng chỗ | Cùng cách đo trên: số trên ảnh HQ nằm giữa số của hai khung kề nó | 10/10 lần |
| 3 | Khung ngắm không giật | `SchedulerBinding.addTimingsCallback` đếm khung có build+raster > 16,7ms trong 30s mở màn (debug overlay, chạy `--profile`) | < 5% khung chậm |
| 4 | Số khung | `stats` | ≥ 12 khung/giây giữ được |
| 5 | RAM | `adb shell dumpsys meminfo com.neobrutalism.neo_brutalism_locket`, so TOTAL PSS ở màn camera thường và ở màn lùi thời gian ngay sau FROZEN | Tăng ≤ 80MB |
| 6 | Không bị hệ điều hành tắt | Chụp liên tiếp 20 lần trên máy tầm trung, `adb logcat \| grep -i lowmemorykiller` | 0 lần bị tắt |
| 7 | Màn hình khóa | Khóa máy → kéo cài đặt nhanh → bấm tile | Camera mở dưới 1,5s; không thấy feed/bạn bè khi chưa mở khóa; Gửi → mở khóa → vào màn soạn bài với đúng khung đã chọn |
| 8 | Quay về camera thường | Mở/đóng màn lùi 10 lần liền | Camera thường hoạt động lại mỗi lần, không có lỗi "camera in use" |
| 9 | Test tự động | `flutter test`, `flutter analyze`, `./gradlew :app:testDebugUnitTest` | Đều sạch |

---

## 5. Số đo trên máy thật (điền sau Bước 1)

| Máy | Android | Analysis res | Khung/giây | Nén p50/p95 | Ring MB | PSS tăng | Lệch HQ |
|---|---|---|---|---|---|---|---|
| | | | | | | | |

---

## 6. Ngoài phạm vi
- iOS (feature-plan: chỉ làm Android).
- Zoom, flash, hẹn giờ, video trong màn lùi thời gian.
- ZSL (`CAPTURE_MODE_ZERO_SHUTTER_LAG`). Chỉ thử nếu số đo "Lệch HQ" > 300ms.
- Ghi H.264 vòng tròn (MediaCodec). Chỉ cân nhắc nếu Bước 1 không đạt ngay cả ở 720.
