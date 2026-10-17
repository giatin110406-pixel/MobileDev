# Plan: hiệu ứng "máy in nhiệt" khi bấm Post

Mục tiêu: khi người dùng bấm **Post**, màn tờ in chạy một animation kiểu máy in nhiệt: đóng dấu, rồi tờ ảnh được in và đùn ra khỏi khe, kèm tiếng máy in kim và rung theo nhịp. Đây **chỉ là hiệu ứng trình diễn**. Ảnh được đăng lên **không đổi gì**: không có dấu, không bị chỉnh sửa, đi qua đúng luồng đăng bài hiện tại.

## 0. Nguyên tắc

- Animation chạy trên **bản xem** của tờ in (widget), không đụng tới file ảnh. Không ghi dấu vào ảnh, không tạo ảnh mới, không đổi thumbnail hay outbox.
- Việc đăng bài thật (`_postPrint` → `onSendPrint`) chạy **song song** với animation. Animation không được làm chậm hay chặn việc đăng; nếu đăng lỗi thì animation dừng và báo lỗi như hiện tại.
- Chụp xong vẫn vào màn tờ in ngay như bây giờ (không animation lúc bấm shutter).

## 1. Điểm bám vào code hiện có

| Cần | Đã có | File |
|---|---|---|
| Nút Post | `NeoButton(label: printPost)` gọi `_postPrint(photo)` | `lib/features/camera/camera_experience.dart` (`_buildPrint`) |
| Đăng bài | `_postPrint` → `widget.onSendPrint` | cùng file |
| Rung | `Haptics.light/press/heavy/select`, công tắc `Haptics.enabled` | `lib/core/haptics.dart` |
| Âm thanh | `audioplayers` (nhạc quest) | `lib/features/music/quest_music.dart` |
| Cài đặt | `AppSettings` (giữ công tắc rung) | `lib/features/settings/` |
| Viền khung | `NeoPanelClip`, `NeoTheme.panel` | `lib/core/neo_theme.dart` |

Tờ in giữ khung **vuông có viền đen** như hiện tại, chui ra khỏi một khe máy in phía trên.

## 2. Luồng khi bấm Post

1. Người dùng bấm **Post** → nút khóa lại (tránh bấm đôi), `_postPrint` bắt đầu chạy ngầm.
2. **Đóng dấu (khoảng 0.35s):** một con dấu to (ví dụ APPROVED, kèm ngày giờ in) rơi xuống ảnh, thu về đúng cỡ, ảnh rung nhẹ, rung `heavy` một nhịp, "cạch" một tiếng. Dấu chỉ là lớp vẽ tạm phía trên khung ảnh.
3. **In và đùn ra (khoảng 1.0s):** tờ in trượt xuống khỏi khe theo từng nấc (6–8 nấc), mỗi nấc một nhịp rung ngắn, đi kèm tiếng "rẹt... tạch tạch".
4. Khi đăng xong: quay về camera như hiện tại (`_showPrint = false`). Nếu animation xong trước khi đăng xong, hiện trạng thái chờ ngắn; nếu đăng xong trước, đợi animation chạy hết (tối đa khoảng 1.4s) rồi mới chuyển.
5. Chạm màn hình trong lúc animation chạy thì bỏ qua animation (nhảy thẳng tới kết quả); không ảnh hưởng việc đăng.

Dấu chọn thế nào: **giai đoạn 1 dùng một dấu cố định** (APPROVED + ngày giờ). Cho chọn dấu (VERIFIED, TOP SECRET...) là phần mở rộng, cũng chỉ là hiệu ứng.

## 3. Giai đoạn 1: Animation đóng dấu và đùn ảnh, kèm rung (ước tính 1–1.5 ngày)

- Tạo `lib/features/camera/print_post_animation.dart`: widget `PrintPostAnimation` bọc khung ảnh trong `_buildPrint`.
  - Điều khiển bằng `AnimationController` hai pha (dấu rồi đùn), pha đùn dùng `Interval` bậc thang để có nhịp "rẹt".
  - Khe máy in vẽ bằng `Container` đen bo góc, tờ in dùng `ClipRect` + `Transform.translate`; bọc `RepaintBoundary` để mượt.
  - Con dấu vẽ bằng `Text` với font `SpaceGrotesk`, viền dày, xoay nhẹ, màu đỏ/hồng của app.
  - API: `controller`/`play()`, `onStamped`, `onDone`.
- Thêm `Haptics.tick()` (nhẹ như `select`), gọi mỗi nấc; dấu dùng `Haptics.heavy()`.
- Trong `_buildPrint`:
  - Đổi `onPressed` của Post: bắt đầu animation **và** gọi `_postPrint(photo)` cùng lúc (không `await` animation trước khi đăng).
  - Thêm cờ `_postAnimating` để khóa nút và chặn vuốt quay lại trong lúc chạy.
  - `_postPrint` hiện đặt `_showPrint = false` khi đăng xong; đổi để chờ cả animation xong (đợi cả hai `Future` rồi mới đóng màn).
- Tôn trọng "Reduce motion" (`MediaQuery.disableAnimations`): bỏ animation, đăng như cũ.

**Kiểm thử**
- Widget test: bấm Post thì `onSendPrint` được gọi đúng một lần và ngay lập tức (không đợi animation).
- Test: chạm giữa chừng thì animation kết thúc ngay, `onSendPrint` vẫn chỉ gọi một lần.
- Test: đăng lỗi thì animation dừng, màn tờ in còn nguyên, hiện thông báo lỗi như hiện tại.
- Test: `disableAnimations` thì không có animation.
- Test quan trọng: **file ảnh gửi đi giống hệt file trước khi bấm Post** (cùng đường dẫn và nội dung), chứng minh ảnh đăng không bị đổi.
- Test rung: số lần `Haptics.tick` bằng số nấc.

**Chấp nhận khi**: tổng animation ≤ 1.4s, chạm bỏ qua được, ảnh đăng không đổi, đăng lỗi vẫn xử lý đúng.

## 4. Giai đoạn 2: Âm thanh (ước tính 0.5–1 ngày)

- Một clip ngắn (khoảng 1.2s): tiếng "cạch" của dấu rồi "rẹt... tạch tạch" của máy in. Có thể gồm hai file nhỏ để canh nhịp từng pha. **Kiểm tra giấy phép** (CC0 hoặc tự thu), ghi vào `assets/music/CREDITS.md`.
- Đặt vào `assets/sfx/`, khai báo trong `pubspec.yaml`.
- Tạo `lib/core/print_sound.dart`: `AudioPlayer` riêng ở chế độ `lowLatency`, nạp sẵn khi vào màn tờ in để bấm Post là phát ngay.
- Không chồng với nhạc quest đang phát (hạ nhỏ nhạc nền hoặc bỏ tiếng máy in nếu nhạc đang phát).
- Công tắc "Âm thanh máy in" trong Settings (cạnh công tắc rung), lưu qua `AppSettings`, thêm chuỗi vào `app_vi.arb`/`app_en.arb`.

**Kiểm thử**: công tắc tắt thì không phát; nạp source đúng một lần; không phát khi `disableAnimations`.

## 5. Giai đoạn 3 (tùy chọn): chọn dấu

- Một hàng nhỏ cho chọn dấu trước khi bấm Post (APPROVED, VERIFIED, TOP SECRET), mặc định APPROVED.
- Vẫn chỉ là hiệu ứng: lựa chọn dấu không lưu vào ảnh hay bài đăng. Có thể nhớ lựa chọn cuối trong `shared_preferences` cho tiện.

## 6. Rủi ro và cách giảm

| Rủi ro | Giảm bằng |
|---|---|
| Làm chậm việc đăng | Đăng chạy song song, không chờ animation; test xác nhận |
| Người dùng chán khi lần nào Post cũng chờ | ≤ 1.4s, chạm bỏ qua, có thể tắt trong Settings (công tắc hiệu ứng) |
| Bấm Post hai lần | Khóa nút ngay khi bắt đầu (`_postAnimating`) |
| Rung dồn dập | Tối đa 6–8 nhịp kiểu `select`, theo `Haptics.enabled` |
| Âm thanh trễ hoặc bất ngờ | Nạp sẵn, `lowLatency`, công tắc riêng, không chồng nhạc quest |
| Giật máy yếu | Chỉ dùng `Transform`/`ClipRect`, `RepaintBoundary`, thử máy thật |
| Giấy phép clip âm thanh | CC0 hoặc tự thu, ghi `CREDITS.md` |

## 7. Thứ tự làm đề xuất

1. Giai đoạn 1 (animation + rung): thấy kết quả ngay.
2. Giai đoạn 2 (âm thanh), khi đã có clip hợp lệ.
3. Giai đoạn 3 (chọn dấu), nếu còn thời gian.

Mỗi giai đoạn kết thúc bằng `flutter analyze` sạch, toàn bộ test qua và thử trên máy thật (rung và âm thanh không kiểm chứng được bằng emulator).

## 8. Đã chốt

- Có công tắc tắt hiệu ứng trong Settings ngay từ giai đoạn 1 (Post là hành động lặp lại).
- Dấu mặc định: **APPROVED** (tiếng Anh). Bản tiếng Việt: **ĐÃ DUYỆT**; các dấu mở rộng: VERIFIED / **XÁC THỰC**, TOP SECRET / **TUYỆT MẬT**. Dấu theo ngôn ngữ của app.
- Cần kiểm tra font `SpaceGrotesk` hiển thị đủ dấu tiếng Việt (Đ, Ậ, Ự...); nếu thiếu glyph thì dùng `PublicSans` cho riêng con dấu.

## 9. Trạng thái thực thi

**Đã làm (giai đoạn 1, kèm chọn dấu theo quy tắc):**
- `lib/features/camera/print_post_animation.dart`: `playPrintPost` (hộp thoại phủ toàn màn), khe máy in, tờ in đùn ra 7 nấc, dấu rơi xuống, rung `select` mỗi nấc và `heavy` khi đóng dấu, chạm để bỏ qua, tôn trọng "reduce motion".
- Chạy **sau khi người dùng xác nhận người nhận và bài đã vào hàng đăng** (vì `onSendPrint` mở hộp chọn người nhận rồi mới trả kết quả). Nhờ đó animation không bao giờ chặn hay đổi bài đăng; đăng thất bại thì không chạy animation.
- Quy tắc dấu: bài quest → VERIFIED / XÁC THỰC; bài thường → APPROVED / ĐÃ DUYỆT; bài thường vào đúng ngày streak chia hết cho 7 → TOP SECRET / TUYỆT MẬT. Dấu theo ngôn ngữ app.
- Công tắc "Hiệu ứng in khi đăng" trong Settings (lưu qua `AppSettings`, mặc định bật).
- Dấu dùng font `PublicSans` (có đủ dấu tiếng Việt); chưa kiểm tra bằng mắt trên máy thật.
- Test: `test/print_post_animation_test.dart` (quy tắc dấu, chạy hết/bỏ qua/tắt/reduce motion, đếm nhịp rung, chữ tiếng Việt, lưu cài đặt).

**Đã làm thêm (giai đoạn 2 và 3):**
- Âm thanh: `lib/core/print_sound.dart`, hai file `assets/sfx/printer.wav` (7 đợt "rẹt" khớp 7 nấc) và `stamp.wav` (tiếng "cạch" khi dấu rơi). Hai file được **tổng hợp bằng code** (`tools/gen_print_sounds.py`) nên không vướng giấy phép; ghi chú trong `assets/music/CREDITS.md`. Nạp sẵn khi vào màn tờ in, cắt tiếng nếu bỏ qua animation, nuốt mọi lỗi phát âm.
- Công tắc riêng "Âm thanh máy in khi đăng" trong Settings, tách khỏi công tắc rung và công tắc hiệu ứng. Hiệu ứng tắt hoặc reduce motion thì cũng không có tiếng.
- Chọn dấu: `StampPicker` (3 chip) trên màn tờ in của ảnh thường. Dấu mà bài đăng "xứng đáng" (theo quy tắc) sáng sẵn; bấm chip khác để đổi. Chỉ là hiệu ứng, không ghi vào ảnh. Bài quest luôn là VERIFIED, không có bộ chọn.

**Chưa làm / cần thử trên máy thật:**
- Nghe thử độ hợp lý của hai âm thanh tổng hợp (có thể chỉnh trong `tools/gen_print_sounds.py` rồi chạy lại, hoặc thay bằng file thu thật).
- Nhịp rung, độ mượt, vị trí dấu trên ảnh, và việc bộ chọn dấu có làm khung ảnh quá nhỏ trên máy màn hình thấp.
