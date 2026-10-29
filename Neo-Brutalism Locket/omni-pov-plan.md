# Omni POV: kế hoạch chi tiết

Dựa trên Session C ("Chụp từ xa") trong `feature-plan.md`, đã đối chiếu với code ngày 2026-10-29.
Theo nguyên tắc chung của `feature-plan.md`: chỉ làm Android.

**Cập nhật 2026-10-30: cách vào phiên đổi từ "gửi yêu cầu" sang "mã QR".** A không còn chọn bạn và gửi yêu cầu nữa: A bấm nút, mã QR hiện trên máy A, B quét bằng camera chính của app. Mọi thứ sau đó (WebRTC, màn xem, màn chụp, lưu ảnh) giữ nguyên. Tiến độ ở mục 11.

**Quy ước trong file này:**
- **Máy A** = người **được chụp**. A **hiện mã QR** và **xem**.
- **Máy B** = người **chụp**. B **quét mã**, **cho xem**, và là máy duy nhất bấm chụp.

---

## 1. Tính năng hứa gì

Hai người chụp chung. Người chụp (B) cầm máy hoặc dựng máy. Người được chụp (A) muốn biết mình đang trông thế nào trong khung hình của B.

1. A bấm nút **OMNI POV** (con mắt) trên màn hình chụp của mình. **Một mã QR hiện lên** trên máy A, có hiệu lực 2 phút.
2. B bấm nút **quét mã** trên màn hình chụp của B, hướng camera chính của app vào mã. (Hoặc quét bằng camera hệ thống: mã là một link `neolocket://pov/...` mở thẳng app.)
3. Máy B hỏi: **"LAN MUỐN XEM QUA ỐNG KÍNH CỦA BẠN"** kèm tên, ảnh của A → **CHO XEM** / **TỪ CHỐI**. Quét xong chưa chia sẻ gì cho đến khi B bấm CHO XEM.
4. B bấm CHO XEM. Từ giây đó A thấy **trực tiếp** hình từ camera của B, **đúng khung vuông mà ảnh sẽ được cắt**, để tự chỉnh tư thế và chỗ đứng.
5. **Chỉ B bấm chụp**, như bình thường. A chỉ xem. Mỗi lần B chụp, màn của A nháy trắng và hiện "TÁCH! AN VỪA CHỤP", để A biết tấm đó đã chụp xong.
6. **Phiên được giữ:** B chụp bao nhiêu tấm tùy ý trong lúc A vẫn xem. Mọi ảnh nằm trên máy B và đi vào luồng sẵn có (bản in → style → đăng).
7. Một trong hai bấm **KẾT THÚC**: máy B về màn chụp bình thường, mở tấm vừa chụp gần nhất. Máy A về màn của mình.

**Chỉ bạn bè:** B phải là bạn của A (và không chặn nhau). Mã QR lọt vào ảnh chụp màn hình cũng không mở được camera của người lạ; và B luôn được hỏi (có tên A) trước khi chia sẻ.

**Không làm** (đã chốt):
- A không bấm chụp từ xa.
- Không gửi yêu cầu từ xa nữa: phải ở cạnh nhau để quét mã. (Cách gửi yêu cầu + thông báo đẩy đã làm trước đó đã bỏ.)
- Âm thanh hay gọi thoại (hai người đứng cạnh nhau).
- Ghi hình lại buổi xem, xem nhiều người cùng lúc.
- iOS.

---

## 2. Quyết định kỹ thuật chính

### 2.1 Truyền hình: `flutter_webrtc` (giữ như Session C)

| Cách | Ưu | Nhược | Kết luận |
|---|---|---|---|
| **flutter_webrtc**, P2P, báo hiệu qua Supabase Realtime | Hình mượt 30 khung/giây, trễ thấp (thường 150–400ms cùng Wi‑Fi), mã hóa sẵn (DTLS-SRTP), miễn phí, không phụ thuộc nhà cung cấp | Phải tự lo báo hiệu, kết nối lại, TURN | **Chọn** |
| Agora / ZEGOCLOUD (SDK có cloud) | Lo hết NAT, kết nối lại; 10.000 phút miễn phí mỗi tháng | Hình đi qua server của họ, SDK đóng, cần tài khoản và key, thêm nhà cung cấp mới | Dự phòng nếu WebRTC tự làm không đạt tiêu chí 4G |
| LiveKit | Mã nguồn mở, SDK tốt | Phải tự chạy hoặc thuê server SFU, quá nặng cho 1–1 | Không |
| Gửi ảnh JPEG qua Supabase Realtime broadcast | Đơn giản, qua được mọi NAT | 3–8 khung/giây, tốn quota Realtime, trễ cao hơn | Chỉ là phương án cứu cuối, không làm trước |
| Google Nearby Connections | Không cần internet | Không có codec video thời gian thực, phải tự mã hóa | Không |

**Phiên bản:** dùng `flutter_webrtc` bản 1.x mới nhất lúc cài. Kiểm tra `minSdk` nó yêu cầu so với `flutter.minSdkVersion` hiện tại.

### 2.2 Ai dùng camera của máy B: điểm khó nhất

Trên Android, một camera chỉ một bên mở được. Màn chụp hiện tại dùng plugin `camera` (`CameraController`, `ResolutionPreset.veryHigh`) trong `camera_experience.dart`. WebRTC cần tự mở camera để truyền hình.

**Cách làm:** khi B bấm CHO XEM:
1. `CameraTab` **nhả camera**: `dispose` `CameraController`, chờ xong hẳn.
2. Mở một màn riêng **`PovHostScreen`**. Màn này mở camera bằng WebRTC (`getUserMedia`, 1920×1080, 30 khung/giây, không âm thanh), vừa hiện khung ngắm cho B vừa truyền cho A.
3. **Chụp:** B bấm nút chụp, app lấy khung hình từ luồng video (`MediaStreamTrack.captureFrame()`), cắt vuông giữa, ra **1080×1080**. Ảnh đăng lên vốn đã bị thu về tối đa 1080px (`maxUploadSide = 1080` trong `media_encoding.dart`), nên **không mất chất lượng đáng kể** so với chụp thường.
4. **Giữ phiên, chụp nhiều tấm:** mỗi tấm được lưu ngay bằng `PhotoRepository.saveOriginal` (cách app đang lưu ảnh chụp). Vì vậy tấm nào cũng có trong danh sách ảnh của B, kể cả khi app bị tắt giữa chừng. Trên màn POV có một ô đếm nhỏ "ĐÃ CHỤP 3", chạm vào xem nhanh các tấm.
5. **Kết thúc:** đóng camera WebRTC, `CameraTab` gọi lại `_initializeCamera()` và mở **tấm chụp gần nhất** trong bản in, như vừa chụp thường. Các tấm khác vẫn nằm trong ảnh của B để đăng sau.
   *Khi code phải kiểm tra:* ảnh lưu bằng `saveOriginal` có hiện đúng chỗ (lịch sử, bản nháp) như ảnh chụp thường không. Nếu không, đổi sang đưa từng tấm qua `_startPrint` sau khi phiên kết thúc.
6. Nếu camera WebRTC không mở được, phiên kết thúc và màn chụp thường mở lại camera ngay. Không bao giờ để màn đen.

**Giữ được trong POV:** đổi camera trước/sau (`Helper.switchCamera`), zoom (`Helper.setZoom`), đèn (torch thay cho flash: đèn bật liên tục, không nháy), hẹn giờ 3/10 giây (hẹn giờ nằm trên máy B, nên A thấy ô đếm ngược hiện trên hình truyền sang).
**Không có trong POV:** quay clip 3 giây, chế độ quest (quest phải chụp bằng camera thật; POV bị ẩn khi đang ở chế độ quest).

Phương án đã cân nhắc rồi bỏ: giữ plugin `camera` và đẩy khung từ `startImageStream` vào WebRTC. `flutter_webrtc` không có API Dart để đẩy khung tự tạo, phải viết thêm Kotlin. Nhiều rủi ro hơn mà không hơn gì cho người dùng.

### 2.3 Hai máy tìm thấy nhau: mã QR + Supabase

- **Mã QR** là link `neolocket://pov/<mã>`: mã ngẫu nhiên 32 ký tự (122 bit), dùng một lần, sống 2 phút, lưu trong bảng `pov_sessions` của server. A tạo mã bằng RPC `create_pov_code`. Thân QR được vẽ bằng gói `qr_flutter` (đen trên trắng, vùng trống rộng để dễ quét).
- **Đọc mã bằng camera chính của app:** camera chính trước đây chỉ chụp ảnh, không đọc được mã. Giờ khi B bấm nút quét, **các khung hình của camera chính đi qua ML Kit Barcode Scanning** (chạy trên máy, không cần mạng, cùng họ ML Kit mà app dùng để dịch) mỗi khoảng 250ms. Camera được cấu hình trả khung NV21 (`imageFormatGroup`), và chế độ quét chỉ bật khi B bấm, tự tắt sau 60 giây, khi B bấm chụp, hoặc khi tìm thấy mã.
- **B xem trước mã** bằng RPC `peek_pov_code` (trả tên và ảnh của A, không tham gia gì), rồi hỏi B. Chỉ khi B bấm CHO XEM mới gọi `join_pov`: A trở thành người xem, B trở thành người chụp, phiên `accepted`. Máy A thấy thay đổi ngay qua Realtime.
- **Link mở từ app khác:** `AndroidManifest.xml` có intent filter cho `neolocket://pov`, nên camera hệ thống hoặc ứng dụng quét QR khác cũng mở được app và đi vào cùng luồng hỏi B.
- **Trao đổi kết nối WebRTC** (SDP offer/answer, ICE candidate): kênh **Realtime broadcast riêng tư** `pov:<session_id>`. Có chính sách RLS trên `realtime.messages`: chỉ hai người của phiên, và phiên đang `accepted`, mới vào được kênh. Ở đây chỉ trao đổi tin nhắn báo hiệu nhỏ, hình đi thẳng P2P.
- **Thông báo "B vừa chụp"** và "kết thúc" gửi qua data channel của WebRTC (tin rất nhỏ), có broadcast làm dự phòng.
- Không còn thông báo đẩy cho Omni POV: không ai bị hỏi từ xa nữa.

### 2.4 Máy chủ STUN/TURN (đã chốt: Edge Function)

- **STUN:** `stun:stun.l.google.com:19302` (miễn phí).
- **TURN:** Metered (gói miễn phí, 20GB/tháng). Cần khi hai máy cùng dùng 4G sau NAT của nhà mạng; cùng Wi‑Fi thì không cần.
- **Edge Function mới `pov-ice`:**
  - chỉ người đã đăng nhập gọi được, và chỉ khi họ có một phiên `pending` hoặc `accepted`;
  - gọi API của Metered để tạo **thông tin TURN ngắn hạn** (hết hạn sau 30 phút);
  - trả về danh sách ICE servers (STUN + TURN);
  - **khóa bí mật của Metered** nằm trong secrets của Supabase (`supabase secrets set METERED_SECRET_KEY=...`), không bao giờ nằm trong app hay repo;
  - giới hạn: mỗi người tối đa 30 lần gọi/giờ.
- **Hình dùng bao nhiêu dữ liệu:** WebRTC tự điều chỉnh. Giới hạn khoảng 1,5 Mbps, nên 5 phút xem tốn khoảng 55MB TURN khi phải đi qua TURN.

---

## 3. Giao diện (theo vibe neo-brutalism của app)

### 3.1 Nút yêu cầu (máy A): đặt ở đâu và vì sao

**Hai nút ở hai góc dưới của khung ngắm**, cùng kiểu nút tròn nhỏ như đèn flash (góc trên trái) và hẹn giờ (góc trên phải), dùng chung hàm `_cornerControl` sẵn có:
- **Góc dưới trái: con mắt** (`Icons.visibility_outlined`), tooltip "Omni POV". Dành cho A: hiện mã QR.
- **Góc dưới phải: quét mã** (`Icons.qr_code_scanner`), tooltip "Quét mã Omni POV của bạn". Dành cho B: bật chế độ quét. Chỉ hiện với camera sau (camera trước là ảnh gương).

```
┌──────────────────────────────┐
│ (⚡)                     (⏱) │  ← flash, hẹn giờ (đã có)
│                              │
│          KHUNG NGẮM          │
│                              │
│ (👁)      [0.5 1× 2×]        │  ← MỚI: Omni POV ở góc dưới trái
└──────────────────────────────┘
   [🖼]        ( ◉ )        [⟲]     ← thư viện · chụp · đổi camera (giữ nguyên)
```

Vì sao chỗ này:
- **Đúng lúc cần:** người được chụp mở app là vào màn chụp (tab mặc định). Ý định "xem mình trên máy bạn" gắn với chụp ảnh, không gắn với chat hay hồ sơ.
- **Không phá bố cục:** hàng nút dưới (thư viện, chụp, đổi camera) đã đủ cân. Góc dưới trái khung ngắm đang trống. Pill zoom nằm giữa nên không đụng.
- **Nhất quán:** cùng hình dạng và hành vi với hai nút góc sẵn có. Mờ khi tắt, đặc khi đang chờ hoặc đang xem.
- **Ẩn khi** đang quay clip, đang ở chế độ quest, hoặc chưa đăng nhập (POV cần tài khoản).

### 3.2 Hiện mã (máy A)

Bấm 👁 mở bottom sheet kiểu panel neo (viền đen, bóng cứng, nền kem):
- Tiêu đề **"XEM MÌNH QUA MÁY CỦA BẠN"**.
- **Mã QR** to (220), đen trên nền trắng, trong khung viền dày 3px.
- Nhãn **"Còn hiệu lực 1:42"** đếm ngược.
- Một câu hướng dẫn: bạn đang cầm máy quét mã bằng camera trong app Omni POV.
- Nút **ĐÓNG** (đóng sheet là đóng mã).
- Khi mã hết hạn: "Mã đã hết hạn." và nút **MÃ MỚI**. Lỗi từ server (đang bận, tạo quá nhiều mã, mất mạng) hiện bằng chữ rõ ràng cùng nút **MÃ MỚI**.
- Khi B quét và đồng ý, sheet tự đóng và máy A mở màn xem.

### 3.3 Quét mã (máy B)

- Bấm nút quét: khung ngắm hiện **bốn góc ngắm** màu vàng (viền đen) và dòng **"Hướng vào mã Omni POV của bạn"**; có nút ✕ ở giữa phía trên để tắt.
- Thấy một mã QR **không phải của Omni POV**: dòng chữ đổi màu san hô, "Đây không phải mã Omni POV."
- Thấy đúng mã: rung nhẹ, tắt chế độ quét, hiện hộp xác nhận (panel vàng): ảnh và tên A, **"LAN MUỐN XEM QUA ỐNG KÍNH CỦA BẠN"**, ghi chú "Họ sẽ thấy trực tiếp những gì camera của bạn thấy. Bạn là người chụp, và có thể dừng bất cứ lúc nào." và hai nút **CHO XEM** / **TỪ CHỐI**.
- Không phải bạn, mã hết hạn, mã đã dùng, đang bận: một dòng thông báo ngắn, không hiện hộp xác nhận.
- Không mở camera cho ai khi B chưa bấm CHO XEM.

### 3.4 Màn xem (máy A): `PovViewerScreen`

```
┌──────────────────────────────┐
│ [←]  QUA ỐNG KÍNH CỦA AN  ●LIVE│
│ ┌──────────────────────────┐ │
│ │                          │ │
│ │  hình trực tiếp từ máy B │ │  ← đúng khung vuông ảnh sẽ ra
│ │                          │ │
│ └──────────────────────────┘ │
│  ĐÂY LÀ ĐÚNG KHUNG ẢNH SẼ CHỤP │
│  AN ĐÃ CHỤP 2 TẤM             │
│            [ KẾT THÚC ]        │
└──────────────────────────────┘
```

- Hiện **đúng phần ảnh sẽ được cắt** (vuông, giữa). Không lật gương nếu ảnh thật không lật. Nguyên tắc chung của `feature-plan.md` là "nói thật": thứ A thấy phải là thứ sẽ ra.
- Nhãn trạng thái: **LIVE** (xanh), **ĐANG NỐI LẠI…** (vàng), **MẤT KẾT NỐI** (coral, kèm nút thử lại).
- Mỗi lần B chụp: khung nháy trắng, hiện **"TÁCH! AN VỪA CHỤP"**, tăng số tấm.
- Không có nút chụp (đã chốt: chỉ xem).
- Camera của chính máy A tắt trong lúc xem, cho đỡ tốn pin, và bật lại khi kết thúc.

### 3.5 Màn chụp có người xem (máy B): `PovHostScreen`

- Cùng bố cục với màn chụp thường (khung vuông, nút chụp to ở giữa, đổi camera, zoom, đèn, hẹn giờ), để B không phải làm quen lại.
- Nhãn trên khung ngắm: **👁 LAN ĐANG XEM** (panel teal).
- Ô **ĐÃ CHỤP n** ở góc dưới; chạm để xem nhanh các tấm trong phiên.
- Nút **KẾT THÚC** (coral). Nút back của hệ thống cũng là kết thúc.
- Khi kết thúc: về màn chụp thường, mở tấm gần nhất trong bản in. Ô gắn thẻ "với…" gợi ý sẵn tên A (tính năng gắn thẻ đã có).

---

## 4. Backend (Supabase)

Hai migration: `20261029000001_pov.sql` (bảng, kênh riêng tư, `end_pov`, `pov_shot`; bản đầu có cách gửi yêu cầu, đã thay) và `20261030000001_pov_qr.sql` (chuyển sang mã QR). Thêm `20261030000002_pov_qr_expired.sql` (một mã hết hạn luôn báo "hết hạn").

**Bảng `pov_sessions`**
- `id uuid`, `viewer_id` (A), `host_id` (B, **để trống cho đến khi B quét**), `status`: `pending` (mã đang hiện, chưa ai quét) | `accepted` | `cancelled` | `expired` | `ended`.
- `code text unique` (mã trong QR; xóa khi đã dùng), `created_at`, `expires_at` (= tạo + 2 phút, chỉ áp cho `pending`), `answered_at`, `ended_at`, `shots int` (số tấm B đã chụp, để A thấy), `ice_calls int`.
- **RLS:** chỉ A hoặc B đọc được dòng của mình. Không ai ghi trực tiếp, mọi thay đổi đi qua RPC.
- Có trong publication `supabase_realtime`: máy A nhận thay đổi khi B quét.

**RPC**
- `create_pov_code() → {session_id, code, expires_at}`. Mã cũ còn chờ của A bị đóng. Mỗi người tối đa một phiên đang sống, 30 mã/giờ. Lỗi: `not_signed_in`, `busy`, `too_many`.
- `peek_pov_code(p_code) → {session_id, viewer_id, display_name, avatar_path}`. B xem mã của ai, chưa tham gia. Lỗi: `not_found` (không có, đã dùng, đã đóng), `expired`, `self`, `not_friends` (cũng khi bị chặn, và người lạ không biết được gì).
- `join_pov(p_code) → {session_id, viewer_id}`. B đã xác nhận: A thành người xem, B thành người chụp, phiên `accepted`, mã bị xóa (dùng một lần). Lỗi như trên, thêm `busy` khi B đang trong một phiên.
- `cancel_pov(p_session)`: A đóng mã còn chờ.
- `end_pov(p_session)`: một trong hai kết thúc phiên `accepted`. `pov_shot(p_session)`: B báo vừa chụp một tấm.
- Phiên `accepted` quá **30 phút** không ai kết thúc thì tự coi là `ended` (đề phòng app chết giữa chừng).

**Kênh báo hiệu riêng tư**: chính sách trên `realtime.messages` cho topic `pov:<id>`: chỉ `viewer_id`/`host_id` của phiên đang `accepted`.

**Edge Function `pov-ice`** (mục 2.4): `supabase/functions/pov-ice/index.ts`, kèm test cho phần logic. Triển khai bằng `supabase functions deploy pov-ice` và đặt secret `METERED_SECRET_KEY`.

**Kiểm thử**: `supabase/tests/pov.test.sql` (pgTAP): mã mới thay mã cũ, chỉ bạn bè quét được, không tự quét mã của mình, mã dùng một lần, mã hết hạn, ai được báo tấm chụp hay kết thúc. `supabase/e2e/e2e_pov.py`: bốn tài khoản thật đi hết vòng mở mã → xem trước → quét → chụp → kết thúc; kênh riêng tư; `pov-ice` chỉ trả thông tin cho người có phiên.

---

## 5. Code app

**Thư mục mới `lib/features/pov/`**:
| File | Việc |
|---|---|
| `pov_repository.dart` | Gọi RPC (`createCode`, `peek`, `join`…), nghe `pov_sessions` qua Realtime, mở kênh broadcast riêng tư, gọi `pov-ice`; cách đọc và viết link `neolocket://pov/<mã>` |
| `pov_store.dart` (ChangeNotifier) | Trạng thái: rảnh / đang hiện mã / đang xem / đang cho xem / lỗi; mã hết hạn sau 2 phút; số tấm đã chụp |
| `pov_connection.dart` | Bọc `RTCPeerConnection`: ICE servers từ `pov-ice`, giới hạn bitrate, data channel (`shot`), báo hiệu qua kênh riêng tư, tự nối lại (ICE restart, tối đa 15 giây) |
| `pov_qr_sheet.dart` | Sheet hiện mã QR (máy A) |
| `pov_scan.dart` | Đọc mã từ khung camera bằng ML Kit; khung ngắm; hộp xác nhận và việc tham gia (máy B) |
| `pov_text.dart` | Câu thông báo lỗi và lý do kết thúc |
| `pov_host_screen.dart` | Màn máy B: camera WebRTC, khung vuông, chụp `captureFrame`, cắt vuông, lưu từng tấm, ô ĐÃ CHỤP |
| `pov_viewer_screen.dart` | Màn máy A: hình từ xa cắt vuông, trạng thái kết nối, TÁCH! |

**Chạm vào code sẵn có (giữ ở mức tối thiểu, theo lưu ý của `feature-plan.md` về `camera_experience.dart`):**
- `camera_experience.dart`: hai nút góc (👁 hiện mã, quét mã); chế độ quét (camera chính trả khung NV21, `startImageStream`, tắt khi chụp, khi đổi camera, sau 60 giây); hàm "nhả camera → mở `PovHostScreen` → mở lại camera → mở tấm gần nhất"; tạm ngưng camera khi A mở màn xem.
- `app_shell.dart`: tạo `PovStore` khi có tài khoản; một link `neolocket://pov/...` mở từ app khác đi vào cùng luồng hỏi B.
- `AndroidManifest.xml`: thêm intent filter cho `neolocket://pov`. Không thêm quyền nào (đã kiểm tra bản build: `RECORD_AUDIO` vốn có từ plugin camera; WebRTC chỉ thêm `MODIFY_AUDIO_SETTINGS`).
- `pubspec.yaml`: thêm `flutter_webrtc`, `qr_flutter`, `google_mlkit_barcode_scanning`.
- `app_en.arb`, `app_vi.arb`: chuỗi mới, đủ hai thứ tiếng.

**Không đụng:** feed, chat, nhóm, cuộc thi, shop, quest (ngoài việc ẩn nút trong chế độ quest), tìm ảnh, luồng đăng bài (ảnh POV đi vào luồng sẵn có).

---

## 6. Các trường hợp phải xử lý đúng

| Tình huống | Hành vi |
|---|---|
| Không ai quét mã trong 2 phút | Mã hết hạn; A thấy "Mã đã hết hạn." và nút MÃ MỚI |
| B quét mã của người không phải bạn, hoặc đã chặn nhau | Không hiện hộp xác nhận; B thấy "Chỉ chia sẻ camera được cho bạn bè của bạn." Người lạ không biết được gì về chủ mã |
| Mã đã dùng, đã đóng, hoặc B đang trong phiên khác | B thấy lý do ngắn gọn, không chia sẻ gì |
| B quét một mã QR khác (không phải Omni POV) | Dòng chữ "Đây không phải mã Omni POV." và tiếp tục quét |
| B quét rồi bấm TỪ CHỐI | Không chia sẻ gì; mã của A vẫn còn hiệu lực đến hết 2 phút |
| Mạng chập chờn | Nhãn "ĐANG NỐI LẠI…"; ICE restart; quá 15 giây thì kết thúc, cả hai thấy lý do |
| B đưa app xuống nền hoặc khóa màn hình | Android không cho dùng camera ở nền: kết thúc phiên ngay, các tấm đã chụp vẫn được lưu, A thấy "An đã rời" |
| A đưa app xuống nền | Dừng nhận hình; quay lại trong 15 giây thì tiếp tục, quá thì kết thúc |
| Camera của B không nhả kịp hoặc WebRTC không mở được camera | Kết thúc phiên, mở lại camera thường, báo lỗi; không bao giờ để màn chụp đen |
| App của B bị tắt giữa phiên | Các tấm đã chụp vẫn còn (đã lưu từng tấm); phiên tự hết sau 30 phút hoặc khi A kết thúc |
| A hoặc B mất đăng nhập, hoặc hủy kết bạn trong lúc xem | Phiên kết thúc (RPC và chính sách kênh từ chối) |
| Hai máy cùng 4G | Đi qua TURN; nếu `pov-ice` lỗi hoặc TURN hết quota thì báo "không kết nối được qua mạng di động" |

---

## 7. Các bước làm (có cổng kiểm tra)

**Bước 0: thử nghiệm trên 2 máy thật (làm trước, ½–1 ngày).**
Một màn thử: `flutter_webrtc` 2 máy, báo hiệu tạm qua broadcast. Đo:
- độ trễ (quay một đồng hồ bấm giờ, chụp màn hình cả hai máy);
- độ nét của `captureFrame` 1080p;
- thời gian nhả camera plugin rồi WebRTC mở lại (mục tiêu < 1 giây);
- chạy trên máy A52 và một máy Android khác.

**Cổng:** trễ < 0,5 giây cùng Wi‑Fi, và chuyển camera không lỗi 20/20 lần. Không đạt thì dừng lại, cân nhắc Agora/ZEGOCLOUD.

**Bước 1: backend.** Migration + RPC + pgTAP + Edge Function `pov-ice` + e2e. Tạo tài khoản Metered, đặt secret. Áp lên Supabase sau khi nhóm đồng ý.

**Bước 2: luồng yêu cầu.** Nút 👁, sheet chọn bạn, thẻ yêu cầu đến, `PovStore` và các test widget/store (chưa có hình).

**Bước 3: hình trực tiếp.** `PovConnection`, màn B, màn A, chuyển camera qua lại.

**Bước 4: chụp trong phiên.** Chụp nhiều tấm trên máy B, lưu từng tấm, ô ĐÃ CHỤP, TÁCH! trên máy A, mở tấm gần nhất khi kết thúc, gợi ý gắn thẻ A.

**Bước 5: thông báo đẩy + nối lại + TURN.** Thử 4G–4G, Wi‑Fi–4G, rớt mạng 5 giây.

**Bước 6: hoàn thiện.** Chuỗi song ngữ, accessibility (Semantics cho nút, nhãn trạng thái), chạy lâu 30 phút xem nhiệt và pin.

---

## 8. Tiêu chí đạt (đo được)

- Trễ hình **< 0,5 giây** cùng Wi‑Fi (đo bằng đồng hồ bấm giờ), **< 1 giây** qua 4G/TURN.
- Từ lúc B bấm CHO XEM đến lúc A thấy hình: **< 3 giây** cùng Wi‑Fi, **< 6 giây** qua 4G.
- Kết nối được **4G–4G** trong 9/10 lần thử (nhờ TURN).
- Tự nối lại sau mất mạng **5 giây** trong 9/10 lần.
- Ảnh chụp trong POV ra **1080×1080**, đúng khung A đã thấy (so hai ảnh chụp màn hình).
- Chụp **10 tấm** trong một phiên: cả 10 tấm có trong ảnh của B, A thấy đủ 10 lần TÁCH!.
- Sau mỗi lần kết thúc, camera thường của máy B (và của máy A) hoạt động lại **20/20 lần**, không màn đen.
- Không crash trong buổi xem 30 phút; khi app máy B xuống nền thì phiên luôn kết thúc và ảnh đã chụp không mất.
- `pov-ice` không bao giờ trả thông tin TURN cho người không có phiên; khóa Metered không xuất hiện trong APK hay repo.
- Test tự động: pgTAP cho mọi luật của RPC; test store/widget cho mọi trạng thái của yêu cầu; test logic của `pov-ice`; e2e 2 tài khoản qua Supabase thật.

---

## 9. Đã chốt (2026-10-29, đổi cách vào phiên 2026-10-30)

1. **Vai:** A (người được chụp) gửi yêu cầu, B (người chụp) cho xem.
2. **Giữ phiên:** chụp nhiều tấm trong một phiên.
3. **Chỉ bạn bè** được gửi yêu cầu.
4. **Chỉ xem** qua ống kính của máy chụp: A không bấm chụp từ xa, B không mời ngược lại.
5. **TURN qua Edge Function** `pov-ice`, khóa Metered nằm trong secrets của Supabase.
6. **Vào phiên bằng mã QR thay cho gửi yêu cầu** (2026-10-30): A hiện mã, B quét bằng camera chính của app (đã chỉnh để đọc được QR bằng ML Kit), B được hỏi trước khi chia sẻ. Vẫn chỉ bạn bè.

---

## 10. Rủi ro

- **Chuyển camera** giữa plugin `camera` và WebRTC trên một số máy có thể chậm hoặc lỗi. Bước 0 phải đo trước.
- **Chất lượng `captureFrame`** kém hơn `takePicture` (không HDR, không xử lý ảnh của hãng). Chấp nhận được vì ảnh đăng tối đa 1080px, nhưng phải xem bằng mắt ở bước 0.
- **TURN miễn phí** 20GB/tháng: đủ cho demo và lớp học, không đủ nếu nhiều người dùng.
- **Realtime Authorization** (kênh riêng tư) cần bật trong dự án. Nếu chưa dùng được thì tạm dùng tên kênh ngẫu nhiên khó đoán (id phiên), vì chỉ là tin nhắn báo hiệu, hình vẫn mã hóa P2P.
- **Pin và nhiệt** máy B khi vừa mở camera vừa mã hóa video, nhất là khi giữ phiên lâu. Giới hạn 1,5 Mbps và 30 khung/giây, phiên tự hết sau 30 phút.
- **Lưu ảnh khi giữ phiên:** cần xác nhận `saveOriginal` đưa ảnh vào đúng chỗ như chụp thường (mục 2.2 bước 4).
- **Xung đột merge** với Session A/B (cùng sửa `camera_experience.dart`). Giữ phần sửa ở đó thật nhỏ và làm trên nhánh riêng.

---

## 11. Tiến độ (cập nhật 2026-10-30)

**Đã làm và đã kiểm tra:**
- Backend (đã áp lên Supabase): `20261029000001_pov.sql` (bảng, kênh riêng tư), `20261030000001_pov_qr.sql` (chuyển sang mã QR: `create_pov_code`, `peek_pov_code`, `join_pov`; bỏ `request_pov`, `answer_pov` và thông báo đẩy) và `20261030000002_pov_qr_expired.sql`. `pov-ice` (8 test Node), `notify` đã trả về như cũ (20 test Node).
- App: `lib/features/pov/` (repository, store, kết nối WebRTC, sheet mã QR, đọc mã bằng ML Kit và hộp xác nhận, màn xem, màn chụp); camera chính đọc được mã QR; link `neolocket://pov/...` mở được app từ camera hệ thống. 26 test store và link, 16 test giao diện. Toàn bộ test của dự án: 837 pass, không có lỗi mới (còn 2 lỗi cũ của teammate). APK debug build được.
- Mã QR do app vẽ ra được một bộ giải mã độc lập (OpenCV) đọc đúng, kể cả khi thu nhỏ còn khoảng 88 điểm ảnh và hơi nhòe.
- Kiểm tra với Supabase thật: `e2e_pov.py` qua **48/48** kiểm tra (đã áp cả migration `20261030000002_pov_qr_expired.sql`: một mã hết hạn luôn báo "hết hạn").

**Khác với plan ban đầu:**
- Phiên tự hết sau 30 phút (không phải 15).
- Mỗi tấm B chụp được lưu ngay thành một bản in không style; **tấm cuối** được xóa bản lưu nhanh rồi mở lại như ảnh mới chụp (có style, chú thích, người nhận), với A đã được gắn thẻ nếu A nằm trong danh sách bạn của B.
- WebRTC không thêm quyền nhạy cảm nào (`RECORD_AUDIO` vốn có từ plugin camera; WebRTC chỉ thêm `MODIFY_AUDIO_SETTINGS`); quét QR và vẽ QR không thêm quyền nào.

**Chưa làm hoặc chưa đo được (cần điện thoại, và 2 máy cho phần hình):**
- Quét mã bằng camera chính trên máy thật: ML Kit đọc khung NV21 của camera có nhận được không, có làm viewfinder giật không, có làm `takePicture` lỗi khi vừa quét xong không.
- Bước 0 với 2 máy: độ trễ hình, độ nét `captureFrame`, hướng ảnh, thời gian chuyển camera, kênh riêng tư thật.
- TURN: cần tài khoản Metered và hai secret `METERED_APP`, `METERED_SECRET_KEY` (`npx supabase secrets set ...`); khi chưa có, `pov-ice` chỉ trả STUN.
- `supabase/tests/pov.test.sql` đã viết nhưng chưa chạy được (không có Docker); e2e trên Supabase thật đã kiểm tra cùng các luật.
- Thử 4G–4G, rớt mạng, chạy lâu 30 phút, pin và nhiệt.
