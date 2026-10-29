# Hướng dẫn chụp cặp ảnh cho "Thêm tôi vào"

Cần khoảng 10 cặp (tốt nhất 20) để đo xem ghép ảnh có ổn không. Không cần chạy app, không cần điện thoại của bạn: webcam laptop, điện thoại của bạn bè, máy ảnh đều được.

## Một cặp là gì
Hai ảnh **cùng khung hình, cùng nền**:
- **Ảnh 1:** cả nhóm đứng đó, **người cầm máy chưa có mặt**.
- **Ảnh 2:** y hệt, nhưng **người cầm máy đã đứng vào** một chỗ trống.

## Cách chụp (mất 10–15 phút cho cả buổi)
1. Tìm 3–4 người (bạn cùng lớp là đủ).
2. Đặt máy cố định: dựa vào chồng sách, ghế, hoặc để trên bàn. Không cầm tay. Không đổi vị trí máy giữa hai ảnh.
3. Đặt máy ở độ cao ngang ngực, thấy đủ người, còn chừa **một khoảng trống** cạnh nhóm để người thứ 4 đứng vào.
4. Dùng hẹn giờ 5–10 giây (hoặc nhờ ai bấm hộ) để không rung máy.
5. **Ảnh 1:** 2–3 người đứng tạo dáng, chụp.
6. **Ảnh 2:** giữ nguyên chỗ đứng của những người đó, thêm một người đứng vào chỗ trống, chụp ngay (trong vòng 1 phút).
7. Đổi người đứng thêm, hoặc đổi chỗ đứng, chụp cặp tiếp. Một buổi dễ ra 5–6 cặp.

## Cần đủ các loại, đừng chụp toàn ca dễ
Tối thiểu mỗi loại 2 cặp:
- **Dễ:** nền trơn hoặc ít chi tiết, người thêm đứng cách nhóm một khoảng.
- **Có chi tiết:** hành lang, quán cà phê, sân trường (có bàn ghế, cây, bảng hiệu).
- **Đứng sát:** người thêm đứng sát cạnh người trong nhóm, vai gần chạm nhau.
- **Tóc và áo dài/xù:** người thêm có tóc xõa, mũ, hoặc áo khoác dày.
- **Ánh sáng yếu:** trong phòng tối hơn, hoặc ngược sáng.
- **Ca nên bị từ chối:** cố ý làm hỏng, ví dụ để một người trong nhóm bước đi, hoặc dịch máy sang bên giữa hai ảnh, hoặc đổi chỗ vài đồ vật. App phải nói "chụp lại" ở các ca này, và ta cần đo là nó nói đúng.

## Đặt tên và bỏ vào thư mục
Bỏ vào `server/eval/add_me_pairs/`:

```
phonghoc_1.jpg   phonghoc_2.jpg
saitruong_1.jpg  saitruong_2.jpg
sat_1.jpg        sat_2.jpg
```

Quy tắc: `TÊN_1.jpg` là ảnh không có người cầm máy, `TÊN_2.jpg` là ảnh có. Tên tự đặt, không dấu, không khoảng trắng. Phải là `.jpg`.

Ghi vào một file `ghi_chu.txt` cùng thư mục cho mỗi cặp: loại nào trong danh sách trên, và có phải ca cố ý làm hỏng không.

## Chạy
Từ thư mục `server/`:

```
pip install opencv-python-headless
python -m eval.add_me_eval
```

Kết quả nằm ở `server/eval/out/add_me/`: mỗi cặp một ảnh ghép [ảnh 1 | ảnh 2 | kết quả], hoặc dòng "REFUSED" kèm lý do. Hãy xem bằng mắt: ghép tốt là không nhìn ra chỗ nối.

## Lưu ý riêng tư
Ảnh người thật chỉ để trên máy bạn. `server/eval/add_me_pairs/` nên nằm trong `.gitignore`, đừng push lên GitHub nếu người trong ảnh chưa đồng ý.
