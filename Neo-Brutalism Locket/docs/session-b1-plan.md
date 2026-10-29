# Session B1: Chụp hộ — thuật toán canh khung và kế hoạch đưa lên điện thoại

Viết ngày 2026-10-29. Nhánh `feat/hold-frame`, tách từ `feat/rewind-everywhere`.
Đọc kèm `docs/feature-plan.md` (phần B1) và `docs/session-a-rewind-plan.md`.

**Hứa:** khóa khung hình, đưa máy cho người khác; họ thấy lớp mờ của khung kèm mũi tên chỉ hướng, và app tự chụp khi khớp. Khi không chắc thì nói "không nhận ra khung", không đoán.

---

## 1. Đã làm: thuật toán canh khung (Python, đo được)

`server/eval/frame_align.py`: so khung đã khóa với khung hiện tại.
- ORB (800 điểm) trên ảnh xám 320px, làm đều sáng bằng CLAHE, ghép điểm có kiểm tra tỉ lệ (0,75).
- RANSAC ước lượng phép đồng dạng (dịch, xoay, co giãn) bằng `estimateAffinePartial2D`.
- Ra `Alignment` (dx, dy, xoay, co giãn) và `Guidance` (mũi tên trái/phải, lên/xuống, xoay cùng/ngược chiều kim đồng hồ, lùi/lại gần, hoặc "đã khớp").
- **Nói thật khi không chắc**, kèm lý do: `few_features` (tường trơn, tối, nhòe), `no_match` (cảnh khác), `implausible` (biến đổi quá phi lý), `concentrated` (các điểm khớp chỉ dồn vào một chỗ nhỏ, ví dụ một người đang đi).
- Quy ước: `dx` dương nghĩa là cảnh đang nằm lệch sang phải, nên người cầm máy phải đưa khung nhìn sang phải. Cuộn (`roll`) dương: cảnh xoay thuận chiều kim đồng hồ, nên xoay máy thuận chiều. Co giãn lớn hơn 1: đang quá gần, lùi lại.

`server/eval/frame_align_synth.py` + `frame_align_eval.py`: tạo cặp khung từ ảnh có sẵn với đáp án biết trước. Khó hơn một phép biến đổi chính xác: máy nghiêng (méo phối cảnh), đổi độ sáng, nhòe do rung tay, nhiễu, nén JPEG, người đi ngang che một phần khung, và người trong khung di chuyển (tạo chuyển động ngược với nền).

Chạy: `cd server` rồi `python -m eval.frame_align_eval` (thêm tên thư mục ảnh để dùng cảnh khác, ví dụ ảnh nền AI). `python -m pytest tests/test_frame_align.py` cho test.

### Kết quả (11 cảnh, 275 cặp, chế độ khó)
| Chỉ số | Kết quả | Mục tiêu |
|---|---|---|
| Hướng mũi tên đúng khi đã chắc | 96,9% | ≥ 95% |
| Chắc chắn trả lời được | 83,3% | không đặt mục tiêu; lúc không chắc app nói "không nhận ra" |
| Sai số dịch chuyển | trung vị 0,4% khung, phân vị 95 là 1,5% | |
| Sai số xoay | trung vị 0,4°, phân vị 95 là 1,8° | |
| Tường trơn → "không chắc" | 100% | |
| Cảnh khác hẳn → "không chắc" | 100% | |
| Ca "chắc nhưng sai số" | 3,1% | |

**Đọc kết quả cho đúng:** đây là cảnh thật nhưng *máy ảnh mô phỏng*. Nó chưa có thị sai (người cầm máy ở vị trí khác nên vật gần và vật xa xê dịch khác nhau), ống kính, hay tay người che camera. Tiêu chí của plan (khoảng 50 cặp thật, có cả ca khó, mũi tên đúng ≥ 95%) phải đo lại bằng ảnh chụp thật từ điện thoại; con số trên chỉ cho biết thuật toán đủ tốt để đáng đưa lên máy.

Ngưỡng `MIN_SPREAD` (các điểm khớp phải phủ ít nhất 10% khung) là nút điều chỉnh chính: 0,25 cho độ đúng 98% nhưng chỉ trả lời được 65% số lần; 0,10 cân bằng như bảng trên.

---

## 2. Quyết định: không dùng ARCore ở bản đầu

Feature-plan ghi ARCore là phương án chính, OpenCV là dự phòng. **Mình đề xuất đảo lại**, lý do:
- Camera chính của app nay là CameraX trong Kotlin (Session A) và đã có luồng khung hình. ARCore chiếm quyền camera: phải dùng Shared Camera (chỉ một số máy) hoặc dừng ARCore rồi chụp, và nó phá cách camera chính đang chạy.
- Thứ cần là "khung hiện tại khác khung đã khóa thế nào", tức một phép so ảnh. Thuật toán trên làm đúng việc đó trực tiếp, chạy trên mọi máy, không cần thêm quyền hay dịch vụ.
- ARCore cho vị trí máy trong không gian 3D nhưng không cho biết cảnh có còn giống lúc khóa không; ta vẫn phải so ảnh để biết "khớp chưa".
- Gia tốc kế/con quay (rotation vector) bổ sung sau để giữ mũi tên mượt khi mất điểm đặc trưng trong tích tắc.

ARCore có thể thêm sau nếu số đo thật cho thấy so ảnh thuần thất bại ở cảnh ít kết cấu mà con người vẫn canh được.

## 3. Việc tiếp theo (đưa lên Android)

1. **`FrameAligner.kt`** trong `android/.../rewind/` (hoặc package mới `holdframe/`): cùng thuật toán bằng OpenCV Android (`org.opencv:opencv` trên Maven, `Calib3d.estimateAffinePartial2D`). Cùng ngưỡng với bản Python; kiểm tra bằng test JVM với vài cặp ảnh mẫu đã xuất sẵn từ Python.
2. **Nhập khung từ luồng có sẵn:** `RewindCamera` đã nhận NV21 từ CameraX; thêm một nhánh lấy mặt phẳng Y, thu về 320px, gửi cho `FrameAligner` khoảng 10 lần/giây (không dùng chung vòng JPEG của bộ đệm).
3. **Kênh Dart:** `lockFrame()` (lưu khung đã khóa), `alignment` stream (dx, dy, roll, scale, trạng thái), `unlock()`.
4. **Màn "Chụp hộ" (Dart):** lớp mờ của khung đã khóa dịch theo phép biến đổi đang ước lượng, mũi tên chỉ hướng, chữ "không nhận ra khung" khi không chắc. Tự chụp khi đã khớp liên tục khoảng 0,3 giây (dùng `RewindCamera.shoot`).
5. **Điểm vào:** một mục mới trong menu "Công cụ ảnh"? Không: đây là chế độ trước khi chụp. Gợi ý: một nút nhỏ trên khung ngắm. Cần chốt cùng bạn.
6. **Đo trên máy thật:** ~50 cặp (khóa khung, đổi tay, đo mũi tên có chỉ đúng không), gồm cảnh khó (tường trơn, chỗ tối, cảnh nhiều chuyển động).

B2 (Thêm tôi vào) dùng lại đúng `FrameAligner` để hai tấm trùng khung, nên bước này làm xong thì B2 có nền để dựng tiếp.
