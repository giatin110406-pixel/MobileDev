# Neo-Brutalism Camera App — Implementation Plan (Flutter)

> Tài liệu này mô tả đầy đủ kiến trúc, tech stack, thuật toán xử lý ảnh, và roadmap để build một app kiểu Locket, nhưng toàn bộ UI/UX theo aesthetic neo-brutalism, kèm engine chuyển ảnh chụp thành neo-brutalism ngay trên máy (on-device, không gọi AI gen ảnh bên ngoài để đảm bảo privacy).

---

## 0. Tóm tắt yêu cầu sản phẩm

- Nền tảng: Flutter (Android + iOS).
- Chức năng lõi: chụp ảnh (giống Locket) → xử lý on-device để biến thành phong cách neo-brutalism (viền đen, mảng màu phẳng, palette rực rỡ) → lưu lại cả bản gốc và bản đã xử lý → người dùng có thể **toggle qua lại** giữa 2 bản.
- Toàn bộ UI (button, card, input, navigation) dùng design system neo-brutalism: viền đen dày, hard drop-shadow (không blur), màu high-saturation, font sans-serif đậm.
- Privacy: không upload ảnh người dùng lên server AI nào để xử lý. Toàn bộ inference (segmentation, face landmark) và toàn bộ image processing chạy on-device.
- Ưu tiên: độ chính xác/độ trung thực với ảnh gốc (không hallucinate mặt), độ chi tiết, tính thẩm mỹ đúng chất neo-brutalism.

---

## 1. Nguyên tắc kỹ thuật cốt lõi (không thương lượng)

1. **Không dùng diffusion model / ControlNet / API gen ảnh ngoài.** Lý do: hallucinate chi tiết khuôn mặt, nặng, chậm, vi phạm privacy nếu gọi API ngoài, và tạo rủi ro uncanny valley.
2. **Engine ảnh là rule-based computer vision pipeline** (segmentation + landmark + edge-preserving abstraction + color quantization theo palette cố định), không phải generative model học phong cách. Điều này cho kết quả deterministic, giữ 100% cấu trúc ảnh gốc, và tránh uncanny valley (vì không cố "gần giống thật", mà cam kết hoàn toàn vào graphic style).
3. **Xử lý theo vùng (region-based), không xử lý toàn ảnh đồng nhất.** Da mặt, tóc, quần áo, nền phải có tham số quantize riêng để giữ được cấu trúc nhận diện khuôn mặt.
4. **Có cơ chế fallback / graceful degradation** ở mọi bước dùng ML model (segmentation, face landmark). Khi confidence thấp, giảm mức độ can thiệp thay vì ép ra kết quả sai lệch.
5. **Ảnh gốc luôn được giữ nguyên vẹn, không đè lên.** Xử lý luôn ghi ra file mới, không bao giờ ghi đè ảnh gốc, để đảm bảo toggle gốc/xử lý là tức thời (không cần re-render).

---

## 2. Kiến trúc tổng thể & luồng dữ liệu

```
[Camera Capture] 
      │
      ▼
[Original Image File] ──(lưu ngay, hiển thị preview tạm thời)
      │
      ▼
[Processing Queue (background Isolate)]
      │
      ├─► Step A: Selfie Segmentation (person mask)
      ├─► Step B: Face Landmark Detection (nếu phát hiện có mặt)
      ├─► Step C: Region-based smoothing (bilateral/Kuwahara)
      ├─► Step D: Edge extraction (XDoG + landmark-locked strokes)
      ├─► Step E: Color quantization theo Neo-Brutalism palette (LAB space)
      ├─► Step F: Background replacement (pattern/flat color brutalist)
      └─► Step G: Compose layers → Processed Image File
      │
      ▼
[Local Storage: cặp (originalPath, processedPath, metadata)]
      │
      ▼
[UI: Post/Photo Card với Toggle Switch gốc ⇄ xử lý]
```

Nguyên tắc luồng: **capture nhanh, xử lý nặng chạy nền**. Người dùng thấy ảnh gốc ngay lập tức (giống Locket, không delay), rồi bản neo-brutalism "hiện ra" sau vài trăm ms tới ~2s tùy thiết bị, có loading indicator kiểu neo-brutalism (progress bar viền đen).

---

## 3. Tech Stack đầy đủ

### 3.1 Core framework & state management

| Thành phần | Lựa chọn | Lý do |
|---|---|---|
| Framework | Flutter (kênh stable mới nhất) | Yêu cầu bắt buộc của dự án |
| Ngôn ngữ xử lý ảnh nặng | Dart FFI (gọi OpenCV native) + native platform code khi cần | Xử lý ảnh trong Dart thuần quá chậm cho ảnh full-res |
| State management | `flutter_riverpod` (^2.x) | Tách biệt rõ ràng giữa camera state, processing state, gallery state; dễ test; hỗ trợ tốt cho async pipeline (FutureProvider/StreamProvider cho processing queue) |
| Navigation | `go_router` | Chuẩn hiện tại cho Flutter, hỗ trợ deep link nếu sau này cần share |
| Dependency injection | Riverpod providers (không cần thêm package riêng như get_it) | Giảm số lượng thư viện |

### 3.2 Computer Vision & ML (on-device)

| Thành phần | Package | Ghi chú |
|---|---|---|
| Selfie/person segmentation | `google_mlkit_selfie_segmentation` (^0.11.0 trở lên) | Hỗ trợ cả Android và iOS, on-device, ~4.5MB model, latency thấp (25-65ms trên Pixel 4) |
| Face landmark (chính) | `google_mlkit_face_detection` | Cross-platform (Android + iOS), trả về face contours (đường viền mắt, môi, mũi, hàm khoảng 36 điểm) — đủ để khóa cứng viền đen cho các vùng quan trọng |
| Face landmark (nâng cao, optional) | `google_mlkit_face_mesh_detection` (^0.4.2) | **Chỉ hỗ trợ Android (đang ở Beta)**, cho 468 điểm 3D chi tiết hơn. Dùng như enhancement layer trên Android, iOS fallback về face contours ở trên. Không được coi là dependency bắt buộc vì thiếu iOS support. |
| Xử lý ảnh (blur, filter, threshold, quantization, edge detection) | `opencv_dart` (package `dartcv4`/`opencv_core`, hiện tại bản ổn định gần nhất ~2.2.x, dùng dart:ffi) | Hỗ trợ Android, iOS, macOS, Windows, Linux. **Lưu ý: repo tự nhận là WIP, API có thể đổi** → xem mục 14 (Rủi ro) để biết phương án dự phòng bằng native platform channel (viết thẳng C++/Kotlin/Swift dùng OpenCV SDK gốc) nếu package này không ổn định đủ cho production. |
| Ảnh cơ bản (đọc kích thước, decode nhẹ, không cần OpenCV) | `image` (package thuần Dart) | Dùng cho các thao tác nhẹ, không dùng cho pipeline chính vì chậm |

### 3.3 UI / Design System

| Thành phần | Package | Ghi chú |
|---|---|---|
| Camera | `camera` (package chính thức Flutter) | Capture ảnh full-res, kiểm soát được resolution, flash, lens |
| Font | `google_fonts` | `Archivo Black`, `Public Sans`, `Space Grotesk`/`Lexend Mega` đều có sẵn trên Google Fonts. **Lưu ý: `Mabry Pro` là font thương mại (Mark Simonson), không có trên Google Fonts** — cần mua license hoặc dùng font thay thế miễn phí (đề xuất `Archivo Black` hoặc `Space Grotesk` cho heading, `Public Sans` cho body). "Bebas Kai" trong tài liệu tham khảo nhiều khả năng là `Bebas Neue` (có trên Google Fonts). |
| Animation cho toggle/transition | `flutter` built-in (`AnimatedSwitcher`, `AnimatedContainer`) | Không cần thêm package, hiệu ứng "flip card" giữa ảnh gốc/xử lý làm bằng `AnimatedSwitcher` + custom transition |
| Icon | `flutter` built-in hoặc vẽ icon custom dạng outline dày (SVG) để đúng chất brutalist thay vì Material Icons mặc định | Icon set mặc định của Flutter/Material không có viền đen dày, nên cần custom hoặc dùng icon pack riêng (ví dụ vẽ bằng `flutter_svg` từ file SVG neo-brutalism tự thiết kế) |
| SVG rendering | `flutter_svg` | Cho background pattern (chấm bi, sọc, lưới) và icon custom |

### 3.4 Data & Storage (100% local, không cloud)

| Thành phần | Package | Ghi chú |
|---|---|---|
| Local database | `isar` (hoặc `hive_ce` nếu muốn đơn giản hơn) | Lưu metadata: cặp đường dẫn (originalPath, processedPath), timestamp, trạng thái xử lý (pending/done/failed) |
| File path | `path_provider` | Lấy thư mục application documents để lưu ảnh |
| Permission | `permission_handler` | Xin quyền camera, photo library |
| Image cache trong UI list | `cached_network_image` **không cần** (vì ảnh là local file, dùng `Image.file` trực tiếp với `FileImage` cache mặc định của Flutter là đủ) | |

### 3.5 Utility

| Thành phần | Package | Ghi chú |
|---|---|---|
| Background processing | `flutter` `Isolate`/`compute()` cho phần Dart, kết hợp native async cho phần OpenCV/ML Kit (các plugin ML Kit đã tự chạy trên platform thread riêng qua platform channel) | |
| Logging | `logger` | Debug pipeline dễ hơn |
| Testing | `flutter_test`, `mocktail` | Unit test cho từng bước pipeline (quantization, palette mapping...) |

---

## 4. Neo-Brutalism Design System (Design Tokens)

Rút ra trực tiếp từ các tài liệu tham khảo bạn cung cấp (cheat sheet + color palette).

### 4.1 Color palette

**Palette rực rỡ (chính, high-saturation)** — dùng cho UI accent, button, badge:
```dart
class NeoColors {
  static const cyan    = Color(0xFF7DF9FF);
  static const green   = Color(0xFF2FFF2F);
  static const magenta = Color(0xFFFF00F5);
  static const blue    = Color(0xFF3300FF);
  static const yellow  = Color(0xFFFFFF00);
  static const orange  = Color(0xFFFF4911);
  static const black   = Color(0xFF000000);
  static const cream   = Color(0xFFFFFDF5); // nền thay cho trắng/xám thuần
}
```

**Palette pastel/muted (biến thể phụ)** — có thể dùng cho theme "soft brutalism" hoặc dark mode:
`#DAF5F0, #B5D2AD, #FDFD96, #F8D6B3, #FCDFFF, #E3DFF2, #A7DBD8, #BAFCA2, #FFDB58, #FFA07A, #FFC0CB, #C4A1FF...` (đầy đủ 24 màu từ ảnh tham khảo, lưu thành `NeoColors.pastelPalette` list).

Cả 2 palette này **chính là palette đích** mà engine xử lý ảnh (mục 5.6) sẽ snap màu ảnh vào, đảm bảo ảnh xử lý và UI xung quanh đồng nhất tông màu.

### 4.2 Typography

- Heading: `GoogleFonts.archivoBlack()` hoặc `GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700)`, cỡ chữ lớn bất thường (theo đúng guideline "Large font sizes as decoration").
- Body: `GoogleFonts.publicSans(fontWeight: FontWeight.w600)`.
- Letter spacing và line height nên chỉnh "thử nghiệm" (hơi rộng hơn mặc định) theo đúng guideline "Experimental: line height, letter spacing".

### 4.3 Shadow & Border system

Theo đúng thông số từ cheat sheet (drop shadow: X=4, Y=6, blur=0, opacity=100%, màu đen hoặc tối hơn màu nền):

```dart
class NeoDecoration {
  static BoxDecoration card({Color fill = NeoColors.cream, Color border = NeoColors.black}) {
    return BoxDecoration(
      color: fill,
      border: Border.all(color: border, width: 3),
      borderRadius: BorderRadius.circular(12),
      boxShadow: const [
        BoxShadow(
          color: NeoColors.black,
          offset: Offset(4, 6),
          blurRadius: 0, // bắt buộc = 0, đây là đặc trưng cốt lõi của brutalism shadow
          spreadRadius: 0,
        ),
      ],
    );
  }
}
```

Widget button/card/input đều dùng chung `NeoDecoration`, chỉ đổi `fill`/`border width` theo kích thước component (border dày hơn cho component lớn, ví dụ 4-5px cho card chính, 2-3px cho badge nhỏ).

### 4.4 Component patterns cần build (custom widget, không có sẵn UI kit neo-brutalism trưởng thành cho Flutter)

- `NeoButton` (có "press" animation: khi nhấn, dịch chuyển theo hướng shadow để tạo cảm giác "lún xuống", shadow biến mất khi pressed).
- `NeoCard`
- `NeoTextField` (viền đen dày, không có underline mặc định của Material).
- `NeoBadge` (dạng sticker tròn méo/sao như trong ảnh tham khảo, dùng CustomPainter hoặc SVG).
- `NeoAppBar`
- `NeoBottomNav`
- `NeoToggleSwitch` (dùng riêng cho tính năng chuyển gốc/xử lý, xem mục 6).

---

## 5. Image Processing Engine — chi tiết thuật toán

### 5.1 Pipeline tổng quan (thứ tự bắt buộc)

1. Selfie segmentation → mask người/nền.
2. Face detection/landmark (nếu có mặt trong khung hình).
3. Region-based smoothing (làm mượt khác nhau theo vùng: da mặt, tóc, quần áo).
4. Edge extraction (viền đen).
5. Color quantization theo palette neo-brutalism (khác số cấp màu theo vùng).
6. Background replacement (thay nền thật bằng flat color hoặc pattern brutalist).
7. Compose layer cuối cùng.

### 5.2 Bước 1: Segmentation

- Dùng `google_mlkit_selfie_segmentation`, mode `SegmenterMode.single_image` (không phải stream mode, vì đây là ảnh tĩnh sau khi chụp → có thể dùng model chính xác hơn/chậm hơn một chút so với real-time).
- Output: confidence mask (giá trị 0.0-1.0 mỗi pixel = xác suất là "người").
- Threshold mask ở 0.5, nhưng **giữ lại raw confidence map** để dùng cho bước feather biên (làm mềm biên silhouette 2-3px tránh viền cắt cứng răng cưa).

### 5.3 Bước 2: Face landmark detection

- Primary (cross-platform): `google_mlkit_face_detection` với `enableContours: true` → trả về danh sách điểm contour cho: face oval, mắt trái/phải, lông mày trái/phải, mũi, môi trên/dưới.
- Enhancement (Android only): nếu chạy trên Android, gọi thêm `google_mlkit_face_mesh_detection` để lấy 468 điểm, dùng để vẽ chi tiết hơn (nếp gấp mí mắt, cấu trúc mũi rõ hơn). iOS luôn dùng contours (36 điểm) làm chuẩn.
- **Luôn đọc `trackingId` và confidence/bounding box size** để quyết định fallback: nếu mặt quá nhỏ trong khung hình (< khoảng 10% chiều rộng ảnh) hoặc bounding box bị cắt ở rìa ảnh, coi như "không tin cậy" → bỏ qua landmark overlay, chỉ dùng edge detection tổng quát cho vùng đó (xem mục 5.9 fallback).

### 5.4 Bước 3: Region-based smoothing

Với từng vùng (suy ra từ mask segmentation + landmark contour):

- **Vùng da mặt** (bên trong face oval, trừ mắt/môi/lông mày): áp **Bilateral filter** nhiều lần lặp (2-3 pass) qua OpenCV (`cv.bilateralFilter`), tham số `d` (đường kính neighborhood) lớn, `sigmaColor`/`sigmaSpace` cao, để xóa hết texture da (lỗ chân lông, nếp nhăn nhỏ) nhưng giữ cạnh cấu trúc lớn (sống mũi, gò má, viền hàm). Đây là bước quan trọng nhất để tránh edge detection ở bước sau bắt phải texture da vụn vặt.
- **Vùng tóc**: Kuwahara filter (giữ cạnh mạnh hơn bilateral, tạo mảng khối rõ hơn, hợp với "tóc kiểu comic" mong muốn).
- **Vùng quần áo/thân**: bilateral filter nhẹ hơn (ít pass hơn da mặt, giữ lại nếp gấp vải lớn).
- **Vùng nền**: **không xử lý ảnh nền thật**, sẽ bị thay thế hoàn toàn ở bước 5.6.

### 5.5 Bước 4: Edge extraction (viền đen — đặc trưng thị giác quan trọng nhất)

- Dùng **XDoG (eXtended Difference of Gaussians)** trên ảnh đã smoothing ở bước 5.4, áp riêng cho vùng person (theo mask), threshold cao để chỉ giữ cạnh cấu trúc lớn, không giữ cạnh nhiễu.
- **Landmark-locked strokes**: bất kể XDoG có bắt được hay không, luôn vẽ cứng đường viền đen (stroke width cố định, ví dụ 3-4px ở ảnh output resolution chuẩn hóa) dọc theo: viền mắt, viền môi, đường lông mày, viền ngoài khuôn mặt (face oval contour) — lấy tọa độ trực tiếp từ landmark ở bước 5.3. Đây là cách đảm bảo "độ chính xác" nhận diện khuôn mặt mà bạn yêu cầu, không phụ thuộc hoàn toàn vào edge detector tự động.
- Viền silhouette toàn thân (ranh giới person/background, lấy từ mask ở bước 5.2) luôn được vẽ dày nhất (ví dụ 5-6px) vì đây là đường viền quan trọng nhất để "đọc" ra bố cục kiểu poster brutalist.

### 5.6 Bước 5: Color quantization theo palette neo-brutalism

- Chuyển ảnh (sau smoothing) sang không gian màu **LAB** (không dùng RGB thô, vì LAB gần với cảm nhận màu sắc của mắt người hơn, tránh việc quantize làm biến dạng tông da).
- Số cấp màu (bands) khác nhau theo vùng:
  - **Da mặt**: chia theo **luminance** (không phải hue) thành 3-4 dải sáng/tối/trung gian (kỹ thuật giống poster "Hope" của Shepard Fairey) → giữ được khối 3D khuôn mặt (gò má, hõm mắt) dù đã phẳng hóa màu. Ngưỡng chia dải phải **adaptive theo range luminance thực tế của ảnh đó** (không hardcode ngưỡng cố định), để không thiên lệch giữa các tông da khác nhau.
  - **Tóc**: 2 tông (sáng/tối).
  - **Quần áo**: 2-3 tông tùy độ phức tạp (dùng k-means với k=2 hoặc 3 trên riêng vùng này).
  - Sau khi có các dải/cụm màu, **map (snap) mỗi cụm sang màu gần nhất trong `NeoColors` palette** bằng nearest-neighbor trong không gian LAB (Euclidean distance trên L*a*b*), không map sang RGB gần nhất (dễ sai lệch tông).

### 5.7 Bước 6: Background replacement

- Xóa hoàn toàn nền thật (dùng mask ở bước 5.2, đã feather biên).
- Thay bằng: (a) màu phẳng đơn sắc từ palette, chọn màu tương phản với màu chủ đạo của người trong ảnh để nổi bật, hoặc (b) pattern hình học neo-brutalism dựng sẵn (chấm bi/lưới/sọc, dùng SVG asset tĩnh, không render lại mỗi lần), do người dùng chọn trong vài preset có sẵn (không cần AI sinh nền).

### 5.8 Bước 7: Compose layer cuối cùng

Thứ tự layer (dưới lên trên):
1. Background (flat color/pattern, bước 5.7)
2. Mảng màu quần áo/tóc đã quantize (bước 5.6)
3. Mảng màu da theo luminance band (bước 5.6)
4. Toàn bộ viền đen: XDoG cạnh cấu trúc lớn + landmark-locked strokes + silhouette outline (bước 5.5), đè lên trên cùng.

Output: encode JPEG/PNG chất lượng cao, lưu vào file `processedPath`.

### 5.9 Fallback / graceful degradation (bắt buộc implement, không optional)

| Tình huống | Hành động |
|---|---|
| Không phát hiện được mặt nào | Bỏ qua toàn bộ bước 5.3 và landmark-locked strokes, chỉ chạy segmentation + edge detection tổng quát + quantization toàn "vùng person" đồng nhất (không chia da/tóc riêng) |
| Landmark confidence thấp hoặc mặt bị che/nghiêng nhiều | Không ép vẽ landmark strokes, dùng XDoG tự động cho toàn vùng mặt thay thế |
| Segmentation mask có lỗ hổng/cắt lẹm (tóc bay, kính) | Áp thêm guided filter refine mask dựa trên ảnh gốc trước khi dùng mask để cắt nền |
| Ảnh quá tối/thiếu sáng nghiêm trọng | Cảnh báo UI cho người dùng chụp lại, không cố xử lý (chất lượng segmentation/landmark sẽ không đáng tin) |
| Thiết bị yếu (xử lý quá lâu, ví dụ > 5-6s) | Giảm resolution xử lý xuống (ví dụ xử lý ở 1080px cạnh dài rồi upscale viền/mask, không xử lý ở full resolution gốc) |

---

## 6. Cơ chế toggle ảnh gốc ⇄ ảnh xử lý

- **Không bao giờ xử lý lại khi toggle.** Cả 2 file (`originalPath`, `processedPath`) đã tồn tại sẵn trên disk ngay sau khi pipeline chạy xong lần đầu.
- Toggle chỉ là đổi `Image.file(currentPath)` đang hiển thị, dùng `AnimatedSwitcher` với transition kiểu "flip" hoặc "hard cut" (hard cut thực ra hợp aesthetic brutalism hơn transition mượt mà) để giữ đúng tinh thần "raw, unrefined" của phong cách.
- State lưu trong model:
```dart
class NeoPhoto {
  final String id;
  final String originalPath;
  final String? processedPath; // null khi đang xử lý (pending)
  final ProcessingStatus status; // pending | done | failed
  final DateTime createdAt;
  bool isShowingOriginal; // state UI, không cần lưu DB
}
```
- Khi `status == pending`, toggle bị disable (chỉ xem được ảnh gốc), có label nhỏ kiểu neo-brutalism ("PROCESSING...", viền đen, background vàng) trên ảnh.
- Khi `status == failed` (ví dụ pipeline lỗi), vẫn cho xem ảnh gốc bình thường, hiện nút "Retry" xử lý lại.

---

## 7. Camera & Capture Flow (tương tự Locket)

1. Mở thẳng vào camera view khi mở app (không qua màn hình chờ), full-screen, UI overlay theo neo-brutalism (nút chụp tròn viền đen dày, không phải nút mặc định của `camera` package).
2. Chụp → lưu file gốc ngay vào local storage (`path_provider` + tên file theo UUID/timestamp) → tạo record `NeoPhoto` với `status = pending` → đẩy vào processing queue.
3. Chuyển ngay sang màn hình "post" hiển thị ảnh gốc trong khi xử lý chạy nền (không block UI, không có loading screen chặn toàn màn hình).
4. Khi xử lý xong, ảnh processed tự động hiện ra (mặc định hiển thị bản neo-brutalism trước, người dùng bấm toggle để xem bản gốc), kèm hiệu ứng nhỏ báo "đã xử lý xong" (ví dụ badge sticker bật ra).

---

## 8. Threading & Performance

- Toàn bộ bước 5.2-5.8 chạy trong **1 background Isolate riêng** (dùng `compute()` hoặc `Isolate.spawn` tùy độ phức tạp truyền dữ liệu — vì cần truyền `Uint8List` ảnh qua isolate, cân nhắc dùng `TransferableTypedData` để tránh copy tốn kém).
- Các lời gọi `google_mlkit_*` đã tự động chạy bất đồng bộ qua platform channel (không block Dart main isolate), nhưng vẫn nên await chúng bên trong cùng background isolate/task queue để tuần tự hóa pipeline cho 1 ảnh, tránh tranh chấp tài nguyên nếu người dùng chụp liên tiếp nhiều ảnh.
- Dùng **queue xử lý tuần tự** (1 ảnh tại 1 thời điểm) thay vì xử lý song song nhiều ảnh, để tránh quá tải CPU/RAM trên thiết bị tầm trung, người dùng vẫn thấy UI mượt vì ảnh gốc đã hiển thị ngay.
- Benchmark mục tiêu (để AI agent test trên thiết bị thật): pipeline hoàn chỉnh nên xong trong **dưới 3 giây** trên thiết bị tầm trung (ví dụ Android RAM 6-8GB đời 2022+), dưới 1.5s trên thiết bị cao cấp.

---

## 9. Data Model & Local Storage

- Isar/Hive collection `NeoPhoto` như mục 6.
- Ảnh lưu trong `ApplicationDocumentsDirectory/photos/{id}_original.jpg` và `{id}_processed.png` (PNG cho bản processed để giữ mảng màu phẳng không bị nén mất chi tiết viền như JPEG).
- Không có bất kỳ network call nào trong toàn bộ luồng capture → process → lưu. Nếu sau này có tính năng "share" hoặc "cloud backup", đó phải là **opt-in rõ ràng, tách biệt hoàn toàn** khỏi luồng xử lý ảnh chính, và cần nói rõ với người dùng trong UI (đúng tinh thần privacy-first bạn đặt ra từ đầu).

---

## 10. Cấu trúc thư mục project (feature-first)

```
lib/
├── main.dart
├── core/
│   ├── theme/                 # NeoColors, NeoDecoration, text theme
│   ├── router/                # go_router config
│   └── utils/
├── features/
│   ├── camera/
│   │   ├── presentation/      # CameraScreen, capture button widget
│   │   └── application/       # camera controller/provider
│   ├── image_engine/
│   │   ├── domain/            # models: SegmentationResult, FaceLandmarks, RegionMask
│   │   ├── data/               # ML Kit wrappers, OpenCV FFI wrappers
│   │   └── pipeline/           # từng step 5.2 → 5.8 as separate, testable functions
│   ├── gallery/
│   │   ├── presentation/       # PhotoCard widget với NeoToggleSwitch
│   │   └── application/
│   └── photo_storage/
│       ├── data/               # Isar/Hive repository
│       └── domain/
├── shared/
│   └── widgets/                 # NeoButton, NeoCard, NeoBadge, NeoTextField...
└── assets/
    ├── fonts/                    # nếu dùng font trả phí (Mabry Pro) cần bundle local
    └── patterns/                 # SVG background pattern brutalist
```

Nguyên tắc: **mỗi step trong pipeline (5.2-5.8) là 1 pure function** nhận input ảnh + params, trả output ảnh/mask, không side-effect, để dễ unit test độc lập và dễ để AI agent implement/refactor từng phần mà không phá vỡ phần khác.

---

## 11. `pubspec.yaml` — danh sách dependency đầy đủ

```yaml
dependencies:
  flutter:
    sdk: flutter

  # State management & navigation
  flutter_riverpod: ^2.5.0
  go_router: ^14.0.0

  # Camera
  camera: ^0.11.0

  # ML on-device
  google_mlkit_selfie_segmentation: ^0.11.0
  google_mlkit_face_detection: ^0.13.0
  google_mlkit_face_mesh_detection: ^0.4.2   # Android-only, optional enhancement

  # Computer vision / image processing
  opencv_dart: ^2.2.1                         # theo dõi changelog vì package còn WIP
  image: ^4.2.0

  # UI / design system
  google_fonts: ^6.2.0
  flutter_svg: ^2.0.10

  # Storage
  isar: ^3.1.0
  isar_flutter_libs: ^3.1.0
  path_provider: ^2.1.0
  permission_handler: ^11.3.0

  # Utility
  logger: ^2.4.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  isar_generator: ^3.1.0
  build_runner: ^2.4.0
  mocktail: ^1.0.0
```

> Ghi chú cho AI agent: kiểm tra lại version mới nhất tương thích trên pub.dev tại thời điểm implement, vì các package ML Kit và opencv_dart cập nhật khá thường xuyên. Version ghi ở đây là mốc tham chiếu tại thời điểm viết plan này, không phải version cứng bắt buộc.

---

## 12. Native platform-specific notes

**Android** (`android/app/build.gradle`):
- `minSdkVersion` tối thiểu 21 (yêu cầu của ML Kit selfie segmentation), khuyến nghị set 23+ để tương thích tốt hơn với face mesh detection.
- Thêm Google Maven repository (đã có sẵn trong Flutter template mới, nhưng cần double-check).

**iOS** (`ios/Podfile`):
- `platform :ios, '13.0'` trở lên (yêu cầu chung của ML Kit + opencv_dart).
- Cần thêm `NSCameraUsageDescription` và `NSPhotoLibraryUsageDescription` vào `Info.plist`.
- **Quan trọng**: Face Mesh Detection (468 điểm) KHÔNG chạy trên iOS, code phải có nhánh riêng dùng `google_mlkit_face_detection` (contours) làm chuẩn chung cho cả 2 platform, face mesh chỉ là "extra" khi `Platform.isAndroid`.

---

## 13. Testing Plan

- **Unit test** cho từng pure function trong `image_engine/pipeline/`: test riêng LAB color quantization (input mock pixel array → verify output snap đúng màu gần nhất trong palette), test luminance banding với input synthetic gradient.
- **Golden/visual test**: chuẩn bị một bộ ảnh test đa dạng: nhiều tông da khác nhau, nhiều điều kiện ánh sáng, mặt nghiêng, mặt bị che (kính, tóc, mũ), ảnh không có người, ảnh nhiều người → chạy qua pipeline, review output thủ công để tune tham số (ngưỡng XDoG, số bilateral pass, ngưỡng adaptive luminance).
- **Performance test**: đo thời gian pipeline trên tối thiểu 1 thiết bị Android tầm trung + 1 iPhone tầm trung, so với mục tiêu ở mục 8.
- **Widget test**: `NeoToggleSwitch`, `NeoButton` press state, `AnimatedSwitcher` transition giữa 2 ảnh.

---

## 14. Rủi ro kỹ thuật & phương án dự phòng

| Rủi ro | Mức độ | Phương án dự phòng |
|---|---|---|
| `opencv_dart` còn WIP, API có thể breaking change giữa các version | Trung bình-cao | Wrap toàn bộ lời gọi OpenCV qua 1 abstraction layer riêng (`ImageProcessingBackend` interface) trong `image_engine/data/`, để nếu cần đổi sang native platform channel (viết C++/Kotlin/Swift thẳng bằng OpenCV SDK gốc) thì chỉ cần thay implementation của interface này, không đụng tới phần pipeline logic ở trên |
| Face Mesh Detection không có trên iOS | Chắc chắn xảy ra (giới hạn của thư viện, không phải bug) | Thiết kế pipeline mặc định dùng face contours (cross-platform) làm baseline, face mesh chỉ là optional enhancement, không bao giờ để logic core phụ thuộc vào việc có mesh hay không |
| Segmentation/landmark model không chính xác 100% với mọi tông da, góc mặt, điều kiện ánh sáng | Chắc chắn xảy ra ở mức độ nào đó | Toàn bộ mục 5.9 (fallback) phải implement từ đầu, không phải "thêm sau"; luôn ưu tiên graceful degradation hơn là ép output "đẹp" mà có thể sai |
| Thiết bị cũ/yếu xử lý quá chậm | Trung bình | Resolution scaling như mục 5.9, và có thể thêm giới hạn: chỉ hỗ trợ chính thức thiết bị từ khoảng 2020 trở lên, thiết bị cũ hơn có cảnh báo "trải nghiệm có thể chậm" |
| App size tăng do bundle nhiều model ML Kit + OpenCV native libs | Thấp-trung bình | Chấp nhận được vì đổi lại là on-device processing/privacy; có thể cân nhắc Android App Bundle (dynamic delivery) để giảm size install ban đầu nếu cần |

---

## 15. Roadmap theo Phase (để giao cho AI coding agent implement từng phần)

**Phase 0 — Setup & Design System**
- Setup project, folder structure (mục 10), design tokens (mục 4), các widget `Neo*` cơ bản (button, card, badge, toggle switch) chưa cần logic ảnh, dùng ảnh mock để review UI trước.

**Phase 1 — Camera & Capture flow cơ bản**
- Tích hợp `camera` package, capture flow (mục 7), lưu ảnh gốc + Isar record, chưa có xử lý neo-brutalism (toggle chỉ hiện được 1 bản = gốc).

**Phase 2 — Segmentation + Background replacement**
- Implement bước 5.2 và 5.7 trước (dễ nhất, giá trị thị giác cao ngay: tách người khỏi nền, thay nền flat color). Đây là milestone demo được sớm.

**Phase 3 — Edge extraction + toàn thân (chưa xử lý mặt riêng)**
- Implement bước 5.4 (XDoG) áp dụng chung cho toàn vùng person, bước 5.6 quantization đơn giản (chưa chia vùng da/tóc/quần áo riêng).
- Kết hợp bước 6 (toggle mechanism) hoàn chỉnh ở đây.

**Phase 4 — Face-aware refinement**
- Implement bước 5.3 (face landmark), 5.5 landmark-locked strokes, 5.6 luminance banding riêng cho da mặt, toàn bộ fallback logic mục 5.9.
- Đây là phase phức tạp nhất, nên tách riêng, test kỹ với bộ ảnh đa dạng (mục 13).

**Phase 5 — Region-based smoothing chi tiết + polish**
- Bilateral/Kuwahara filter riêng theo vùng (mục 5.4), tune tham số cho đẹp.
- Polish UI, animation, background pattern preset (mục 5.7 mở rộng).

**Phase 6 — Performance & device testing**
- Benchmark, resolution scaling fallback, test trên nhiều thiết bị thật.

---

## 16. Cách dùng tài liệu này với AI coding agent

- Nên giao từng **Phase** ở mục 15 thành 1 task/conversation riêng cho AI agent, kèm theo đúng phần mục 3/4/5 liên quan tới phase đó, thay vì dán toàn bộ file 1 lần cho 1 task nhỏ (tránh agent bị loãng context).
- Với Phase 4 (phức tạp nhất), nên yêu cầu agent viết pipeline step dưới dạng pure function có input/output rõ ràng (như nguyên tắc ở mục 10) và viết kèm unit test ngay, thay vì viết 1 hàm xử lý khổng lồ.
- Luôn nhắc agent tuân thủ mục 5.9 (fallback) như một **acceptance criteria bắt buộc**, không phải nice-to-have, vì đây chính là phần quyết định app có bị uncanny/glitchy hay không.
