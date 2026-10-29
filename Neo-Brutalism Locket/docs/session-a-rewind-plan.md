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

---

## 7. Sai khác so với plan

Ghi lại những chỗ code khác plan, kèm lý do. Chưa có điều nào trong số này được thử trên máy thật.

1. **Đường dẫn.** Thư mục dự án Flutter nằm trong `Neo-Brutalism Locket/` của kho git, nên file này nằm ở `Neo-Brutalism Locket/docs/`.
2. **Thêm thư viện Gradle.** Ngoài ba gói CameraX 1.5.3, thêm `com.google.guava:guava:33.4.8-android`. Lý do: `ProcessCameraProvider.getInstance` trả về `ListenableFuture`, mà Kotlin cần lớp này trên classpath của app (bản stub `listenablefuture:1.0` không đủ, build báo "Cannot access class 'ListenableFuture'").
3. **`FrameRing` có thêm API.** Thêm `accepts(ts)` (để khỏi nén khung sắp bị bỏ), `freeze()` (hết giờ chờ thì đóng băng sớm), `release()` (trả RAM sau khi đã ghi khung ra file), `size`. Khung đầu tiên có `ts ≥ press + 1000ms` vẫn được giữ rồi mới đóng băng, nên khung cuối có thể ở khoảng `+1,0s` đến `+1,07s`. Khi bấm, các khung cũ hơn `press − 2000ms` bị bỏ ngay.
4. **Độ phân giải.** Cả ba use case dùng tỉ lệ 4:3. Preview và ImageAnalysis bị chặn ở `1440×1080` (`FRAME_SIDE = 1080` trong `RewindCamera.kt`, `FALLBACK_RULE_CLOSEST_LOWER_THEN_HIGHER`). ImageCapture lấy độ phân giải cao nhất. Plan không nói rõ tỉ lệ; 4:3 vì khung vuông cắt giữa từ 4:3 mất ít điểm ảnh nhất và phần cứng LEGACY đảm bảo tổ hợp này.
5. **`finalizeFrame` native** được viết ở Bước 1 cùng `RewindPlugin` (không đợi Bước 3), vì plugin cần đủ bộ method ngay từ đầu.
6. **Lỗi `noPermission`.** `start` trả `PlatformException` mã `noPermission` khi chưa có quyền camera (cần cho màn hình khóa, plan mục 1.3 nói "không xin quyền" nhưng không nói cách báo). Ở màn hình khóa Dart hiện "Chưa có quyền dùng camera" + nút "Mở app để cho phép camera"; nút này gọi `dismissKeyguard` rồi `handoff` với **mảng byte rỗng**, và native hiểu là "chỉ mở MainActivity, không kèm ảnh". Không thêm method mới.
7. **Điểm vào Dart của màn hình khóa.** `RewindLockscreenActivity` đặt `getDartEntrypointLibraryUri()` = `package:neo_brutalism_locket/features/rewind/rewind_lockscreen_main.dart` cùng `getDartEntrypointFunctionName()` = `rewindLockscreenMain`. Để chắc chắn thư viện đó nằm trong bản build, `main.dart` có một dòng `import` kèm `// ignore: unused_import`. **Chưa kiểm** trên máy thật là engine tìm được hàm này ở bản release; nếu không, cách dự phòng là khai báo `@pragma('vm:entry-point') rewindLockscreenMain()` thẳng trong `main.dart` rồi gọi sang file kia và bỏ `getDartEntrypointLibraryUri`.
8. **Dọn file handoff cũ** (`rewind_handoff/*` quá 1 giờ) làm ở phía Dart (`sweepRewindHandoff`, gọi trong `initState` của `app_shell.dart`), vì Dart đã có `path_provider` và phép thử dễ hơn. Thư mục `cacheDir/rewind/*` thì dọn ở native (`RewindPlugin` khi attach), bỏ qua session đang chạy.
9. **Nhánh link rewind** trong `app_shell.dart` nhập ảnh cả khi chạy chế độ cục bộ không có tài khoản (`widget.session == null`), vì chế độ đó là cách dùng hợp lệ của app (không cần Supabase). Khi có Supabase mà chưa đăng nhập thì `AppShell` không tồn tại nên không có đường nào tới nhánh này. Nếu tab camera chưa dựng (khởi động nguội) thì chờ tối đa khoảng 3 giây.
10. **Nút vào** đặt dạng nút tròn nhỏ ở góc khung ngắm, ngay cạnh nút flash (dùng lại `_cornerControl`), chứ không phải một hàng nút phụ mới.
11. **Đóng màn.** Nút Đóng, nút Quay lại và Gửi đều đi qua `_close()`: `await backend.stop()` **rồi mới** `Navigator.pop`, để camera của CameraTab khởi tạo lại không trùng với camera của màn lùi thời gian. Ở màn hình khóa, đóng màn gọi `SystemNavigator.pop()`.
12. **Android 7.x (API 24–25)** không có `requestDismissKeyguard`: dùng cờ `FLAG_DISMISS_KEYGUARD` rồi trả `true`, MainActivity mở ra sau màn mở khóa của hệ thống. Chưa thử.
13. **Overlay số đo** hiện ở bản debug **và profile** (`!kReleaseMode`), không chỉ debug, vì tiêu chí 3 yêu cầu đo giật khi chạy `--profile`. Overlay có thêm dòng `slowFrames` (đếm bằng `addTimingsCallback`, khung > 16,7ms).
14. **Test thêm** ngoài danh sách plan: `test/rewind_screen_test.dart` (màn hình với backend giả) và các test `FrameRing` về `freeze`.
15. **Ảnh HQ.** File `hq.jpg` được ghi lại EXIF orientation theo `rotationDegrees` của CameraX (JPEG từ `OnImageCapturedCallback` không đảm bảo có EXIF xoay). Màn chọn khung dựa vào việc Flutter áp EXIF khi vẽ `Image.file`; chưa kiểm trên máy thật rằng ảnh đứng đúng chiều ở cả camera sau lẫn trước.
16. **Chiều xoay khung phụ.** Khung phụ là JPEG vuông chưa xoay, kèm `rotation` (độ quay thuận chiều kim đồng hồ, lấy từ `imageInfo.rotationDegrees`). Màn chọn xoay bằng `RotatedBox`, `finalizeFrame` xoay bằng `Matrix`. Công thức xoay preview (`rewind_preview.dart`) lấy theo plugin camera với màn khóa portrait (độ xoay màn hình = 0). Chưa kiểm trên máy thật, đặc biệt camera trước (không lật gương ở ảnh, có lật ở khung ngắm theo cách plugin làm).

---

## 8. Cách đo trên máy thật

Bước 1 của plan cần người cầm máy. Tất cả số đo dưới đây điền vào bảng ở mục 5. Chưa ai đo, nên mục 5 vẫn để trống.

### 8.0 Chuẩn bị
- Máy Android tầm trung, cắm USB, bật gỡ lỗi USB. Từ thư mục `Neo-Brutalism Locket/`: `flutter run` (để xem số khung, nén, RAM) hoặc `flutter run --profile` (để đo giật, tiêu chí 3). Bản `--release` **không** có overlay.
- Mở app, vào tab chụp, bấm nút tròn nhỏ có hình đồng hồ lùi (cạnh nút flash) để vào màn lùi thời gian.
- Ghi lại tên máy và bản Android vào bảng mục 5.

### 8.1 Đọc overlay số đo
Góc trên bên trái khung vuông có bảng chữ trắng nền đen, cập nhật mỗi 0,5 giây (chỉ hiện khi camera đang chạy):

| Dòng | Ý nghĩa | Ô trong bảng mục 5 / ngưỡng |
|---|---|---|
| `keptPerSecond` | Số khung giữ lại được mỗi giây, tính trong 2 giây gần nhất | Khung/giây, cổng Bước 1: **≥ 12** |
| `compressP50Ms`, `compressP95Ms` | Thời gian đổi một khung sang JPEG (mili giây), trung vị và phân vị 95, trong 150 khung gần nhất | Nén p50/p95, cổng: **p95 ≤ 50** |
| `avgJpegKb` | Kích thước JPEG trung bình (KB) | Ghi chú |
| `ringFrames`, `ringBytes` | Số khung và số byte đang giữ trong bộ đệm | Ring MB = `ringBytes / 1048576`, cổng: **≤ 25MB** (trần cứng 40MB) |
| `dropped` | Số khung bị bỏ vì chạm trần 40MB. Nên bằng 0 | Nếu > 0 thì ghi lại |
| `nativeHeapMb` | `Debug.getNativeHeapAllocatedSize()` | Ghi chú |
| `analysisWidth`, `analysisHeight`, `previewWidth`, `previewHeight` | Độ phân giải thực tế CameraX chọn | Ô "Analysis res" |
| `hqLagMs` | `hq.timestamp − pressTs` (mili giây), có sau lần chụp đầu | Ô "Lệch HQ". Nếu > 300 thì xem xét ZSL (mục 6) |
| `slowFrames a/b (c%)` | Số khung Flutter có build+raster > 16,7ms trên tổng số khung kể từ khi mở màn | Tiêu chí 3: **< 5%**, đọc ở bản `--profile` sau 30 giây |

Đợi khoảng 5 giây sau khi mở màn cho số ổn định rồi mới đọc. Đứng yên máy hoặc hướng vào cảnh có chuyển động đều (không hướng vào tường trắng).

Nếu không đạt cổng: đổi `FRAME_SIDE` trong `android/app/src/main/kotlin/com/neobrutalism/neo_brutalism_locket/rewind/RewindCamera.kt` từ 1080 xuống 900, rồi 720; đo lại và ghi mỗi lần thử vào bảng mục 5.

### 8.2 Các phép đo trong mục 4
1. **Bấm trễ 1 giây vẫn đúng khoảnh khắc (tiêu chí 1).** Mở một đồng hồ bấm giờ có phần nghìn giây trên máy khác (hoặc trên máy tính, trang web stopwatch). Hướng camera vào màn hình đó. Khi số hiện T, bấm chụp lúc T+1 giây (bấm trễ có chủ ý). Đợi màn chọn khung, vuốt tìm khung có số T. Ghi: khung nào chứa T, lệch bao nhiêu khung (mỗi khung cách nhau khoảng 67ms). Đạt khi lệch ≤ 1 khung, **10/10 lần**.
2. **Ảnh chất lượng cao đặt đúng chỗ (tiêu chí 2).** Cùng cách đo trên: số trên ảnh HQ (khung được chọn sẵn lúc mở dải, không có nhãn "KHUNG PHỤ") phải nằm giữa số của hai khung kề nó trên dải. 10/10 lần.
3. **Khung ngắm không giật (tiêu chí 3).** `flutter run --profile`, mở màn, để yên 30 giây, đọc dòng `slowFrames`. Đạt khi < 5%.
4. **Số khung (tiêu chí 4).** Đọc `keptPerSecond` ≥ 12.
5. **RAM (tiêu chí 5).** Trong khi app chạy:
   - `adb shell dumpsys meminfo com.neobrutalism.neo_brutalism_locket`, ghi dòng `TOTAL PSS` lúc đang ở tab chụp thường.
   - Vào màn lùi thời gian, bấm chụp, đợi tới khi hiện dải khung (đóng băng), rồi chạy lại lệnh trên và ghi `TOTAL PSS`.
   - Hiệu hai số là "PSS tăng", đạt khi ≤ 80MB.
6. **Không bị hệ điều hành tắt (tiêu chí 6).** Chụp liên tiếp 20 lần (Chụp lại giữa các lần), trong khi chạy `adb logcat | findstr /i lowmemorykiller` (Windows) hoặc `| grep -i lowmemorykiller`. Đạt khi 0 dòng ghi app bị tắt. Có thể chạy thêm `adb shell dumpsys meminfo ...` sau mỗi 5 lần để xem RAM có tăng dần không.
7. **Màn hình khóa (tiêu chí 7).**
   - Thêm nút: kéo thanh cài đặt nhanh xuống, bấm biểu tượng bút chì, kéo ô "Chụp lùi thời gian" vào.
   - Khóa máy (có đặt PIN hoặc vân tay). Kéo cài đặt nhanh từ màn khóa, bấm ô đó. Dùng đồng hồ bấm giờ đo từ lúc bấm tới lúc thấy khung ngắm: **dưới 1,5 giây**.
   - Kiểm tra không có bảng tin hay danh sách bạn bè nào lộ ra khi chưa mở khóa.
   - Chụp, chọn khung, bấm GỬI: máy phải đòi mở khóa; mở xong thì vào tab chụp của app với đúng khung đã chọn đang in. Bấm hủy ở bước mở khóa: ở lại màn, hiện "MỞ KHÓA MÁY ĐỂ GỬI", khung chọn còn nguyên.
   - Thử cả máy không đặt khóa màn hình (phải sang app ngay) và Android 14 trở lên (đường `PendingIntent`).
   - Thử khi đã thu hồi quyền camera của app: phải hiện "CHƯA CÓ QUYỀN DÙNG CAMERA" và nút mở app.
8. **Quay về camera thường (tiêu chí 8).** Mở và đóng màn lùi thời gian 10 lần liền. Mỗi lần quay về, khung ngắm camera thường phải hiện lại, không có thông báo "camera đang bận" hay lỗi "camera in use" trong `adb logcat`.
9. **Các điểm cần xem bằng mắt (mục 7, số 15 và 16).** Với cả camera sau và camera trước, chụp một vật có chiều rõ ràng (chữ, khuôn mặt): khung ngắm, khung phụ trên dải, ảnh HQ và ảnh in ra phải cùng đứng đúng chiều. Ghi lại nếu chiều nào sai.

### 8.3 Ghi kết quả
Điền hàng cho từng máy vào bảng mục 5. Nếu có tiêu chí không đạt, ghi số đo và thử đổi `FRAME_SIDE` theo mục 8.1 trước khi kết luận.

---

## 9. Chụp lùi tự động cho mọi ảnh (nhánh feat/rewind-everywhere)

Quyết định ngày 2026-10-29: không còn nút "Chụp lùi thời gian" riêng trong app. Trên Android, camera chính chạy bằng bộ Kotlin (CameraX) ở `RewindCamera.kt`, và **mọi ảnh** đều kèm các khung hình quanh lúc bấm. Ảnh mặc định là ảnh chụp chuẩn tại lúc bấm; nếu người dùng bấm hụt thì bấm **ĐỔI KHUNG** để chọn khung khác. Màn "chụp lùi" riêng vẫn còn, chỉ để dùng từ ô cài đặt nhanh trên màn hình khóa.

### Cách chạy
- `RewindCamera.start(..., continuous = true)`: bộ đệm khung không bao giờ dừng. Mỗi lần bấm (`shoot`) trả ảnh chuẩn ngay khi ghi xong file; khoảng 1 giây sau, các khung quanh lúc bấm gửi về bằng sự kiện `burst`, rồi bộ đệm tự theo dõi lại cho ảnh sau.
- Ảnh chuẩn **không** còn đặt theo mốc thời gian (đã bỏ lỗi lệch đồng hồ ở mục 7): nó là ô đầu tiên của dải, chọn sẵn.
- Phía Kotlin có thêm: flash, zoom, quay video (không tiếng; khi quay thì bộ đệm nghỉ, vì CameraX chỉ đảm bảo 3 use case cùng lúc), xin quyền camera, `releaseShot`.
- Phía Dart: `ShotCamera` (`lib/features/camera/shot_camera.dart`) có hai bản, `NativeShotCamera` (Android) và `PluginShotCamera` (nơi khác, test; không giữ khung). `CameraTab` chỉ nói chuyện với `ShotCamera`.
- Dải chọn khung: `lib/features/rewind/rewind_picker.dart`. Chọn khung thì ảnh nháp được thay bằng khung đó và chạy lại hiệu ứng (như đổi style).
- Chế độ nhiệm vụ (quest): không giữ khung, ảnh được kiểm tra như cũ.
- Khung của một ảnh được xóa khi đăng, bỏ, hoặc chụp ảnh khác; còn lại tối đa 3 thư mục ảnh trong cache.

### Chưa làm / cần biết
- Chưa có công tắc tắt bộ đệm trong cài đặt (nên có: bộ đệm chạy liên tục tốn pin và CPU).
- `NeoPhoto.createdAt` của ảnh đã đổi khung là lúc đổi, không phải lúc bấm.
- Chưa chạy trên máy thật: xem mục 10.

## 10. Việc cần thử trên máy thật cho mục 9
1. Mở app, vào tab chụp: khung ngắm hiện, đúng chiều, không giật; zoom, flash, đổi camera trước/sau hoạt động; giữ nút chụp để quay video, quay xong ra clip.
2. Lần đầu cài (chưa cấp quyền): hộp xin quyền camera hiện ra, cấp xong camera lên.
3. Chụp, đợi khoảng 1 giây: nút **ĐỔI KHUNG** hiện trên trang soạn bài. Bấm vào, chọn khung, **DÙNG KHUNG NÀY**: ảnh đổi đúng khung.
4. Quay lại "ẢNH ĐÃ CHỤP" thì ảnh về như cũ.
5. Chụp liên tiếp 20 lần, vừa chụp vừa xem `adb shell dumpsys meminfo com.neobrutalism.neo_brutalism_locket`: RAM không tăng dần.
6. Chụp với hiệu ứng (Van Gogh, pixel) rồi đổi khung: hiệu ứng chạy lại trên khung mới.
