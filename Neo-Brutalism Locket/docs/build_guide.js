// Generates docs/HUONG_DAN_CHAY_APP.docx. Values come from env vars so no key is hard-coded here:
//   SUPABASE_URL=... SUPABASE_PUBLISHABLE_KEY=... node docs/build_guide.js
const fs = require('fs');
const path = require('path');
const {
  Document, Packer, Paragraph, TextRun, HeadingLevel, LevelFormat, AlignmentType,
  Table, TableRow, TableCell, WidthType, ShadingType, BorderStyle,
} = require('docx');

const URL_ = process.env.SUPABASE_URL || '<<DIEN_SUPABASE_URL: chu du an gui rieng>>';
const KEY_ = process.env.SUPABASE_PUBLISHABLE_KEY || '<<DIEN_PUBLISHABLE_KEY: chu du an gui rieng>>';
const REPO = 'https://github.com/giatin110406-pixel/MobileDev.git';

const FONT = 'Arial';
const p = (text, opts = {}) =>
  new Paragraph({ spacing: { after: 120 }, ...opts, children: [new TextRun({ text, font: FONT, size: 22, ...(opts.run || {}) })] });
const rich = (parts, opts = {}) =>
  new Paragraph({
    spacing: { after: 120 }, ...opts,
    children: parts.map((t) => (typeof t === 'string'
      ? new TextRun({ text: t, font: FONT, size: 22 })
      : new TextRun({ font: FONT, size: 22, ...t }))),
  });
const h1 = (t) => new Paragraph({ heading: HeadingLevel.HEADING_1, spacing: { before: 300, after: 140 }, children: [new TextRun({ text: t, font: FONT })] });
const h2 = (t) => new Paragraph({ heading: HeadingLevel.HEADING_2, spacing: { before: 200, after: 100 }, children: [new TextRun({ text: t, font: FONT })] });
const bullet = (t) => new Paragraph({ numbering: { reference: 'bul', level: 0 }, spacing: { after: 60 }, children: [new TextRun({ text: t, font: FONT, size: 22 })] });
const step = (parts, ref = 'num') => new Paragraph({ numbering: { reference: ref, level: 0 }, spacing: { after: 80 }, children: (Array.isArray(parts) ? parts : [parts]).map((t) => (typeof t === 'string' ? new TextRun({ text: t, font: FONT, size: 22 }) : new TextRun({ font: FONT, size: 22, ...t }))) });

const border = { style: BorderStyle.SINGLE, size: 4, color: 'BBBBBB' };
const borders = { top: border, bottom: border, left: border, right: border };
// One-cell shaded box per code block (a table, so the background spans the full width).
const code = (lines) => new Table({
  width: { size: 9026, type: WidthType.DXA },
  columnWidths: [9026],
  rows: [new TableRow({
    children: [new TableCell({
      width: { size: 9026, type: WidthType.DXA },
      borders,
      shading: { fill: 'F2F2F2', type: ShadingType.CLEAR, color: 'auto' },
      margins: { top: 80, bottom: 80, left: 140, right: 140 },
      children: lines.map((l) => new Paragraph({ spacing: { after: 0 }, children: [new TextRun({ text: l, font: 'Consolas', size: 20 })] })),
    })],
  })],
});
const gap = () => new Paragraph({ spacing: { after: 80 }, children: [] });

const content = [
  new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 80 }, children: [new TextRun({ text: 'Neo-Brutalism Locket', font: FONT, size: 40, bold: true })] }),
  new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 240 }, children: [new TextRun({ text: 'Hướng dẫn chạy app từng bước (dùng chung database)', font: FONT, size: 26 })] }),

  h1('0. Tổng quan'),
  p('App này là app chụp ảnh Flutter, kết nối tới một database Supabase dùng chung do chủ dự án quản lý. Khi làm đúng hướng dẫn, bạn sẽ đăng ký tài khoản, kết bạn, đăng bài, chat và mua đồ trong shop cùng những người khác trên cùng một hệ thống.'),
  p('Bạn không cần tự tạo Supabase. Chỉ cần đưa đúng 2 giá trị cấu hình vào file env/dev.json (Bước 4). Hai giá trị này (SUPABASE_URL và SUPABASE_PUBLISHABLE_KEY) do chủ dự án gửi riêng cho bạn, không đăng công khai.'),
  rich([{ text: 'Lưu ý: ', bold: true }, 'dữ liệu là dùng chung. Đừng đăng nội dung nhạy cảm hay ảnh riêng tư. Bạn có thể xoá tài khoản của mình trong app.']),

  h1('1. Chuẩn bị máy'),
  bullet('Windows 10/11 (hoặc macOS). Hướng dẫn dưới đây dùng PowerShell trên Windows.'),
  bullet('Git: https://git-scm.com/downloads'),
  bullet('Flutter SDK (bản có Dart ≥ 3.11): https://docs.flutter.dev/get-started/install'),
  bullet('Android Studio (để có Android SDK) và chấp nhận license: flutter doctor --android-licenses'),
  bullet('Một điện thoại Android thật, đã bật Tuỳ chọn nhà phát triển → Gỡ lỗi USB. Camera không chạy tốt trên máy ảo.'),
  p('Kiểm tra môi trường bằng lệnh sau, tất cả mục Flutter và Android toolchain phải có dấu tick:'),
  code(['flutter doctor']),
  gap(),

  h1('2. Tải mã nguồn'),
  p('Repo chứa dự án trong thư mục con "Neo-Brutalism Locket", nên nhớ cd vào đúng thư mục này:'),
  code([`git clone ${REPO}`, 'cd MobileDev', 'cd "Neo-Brutalism Locket"']),
  gap(),

  h1('3. Cài thư viện'),
  code(['flutter pub get']),
  p('Lệnh này cũng tự sinh file đa ngôn ngữ (l10n) và tải plugin ONNX Runtime (flutter_onnxruntime) để chạy AI trên điện thoại. Model AI (kể cả model kiểm tra ảnh quest, khoảng 23 MB, nằm trong assets/quest_model) và nhạc đã có sẵn trong repo, không cần tải thêm.'),
  rich([{ text: 'Lần build đầu sau khi cập nhật: ', bold: true }, 'Gradle sẽ tải thêm thư viện ONNX Runtime cho Android nên cần có mạng. File APK cũng nặng hơn trước (model khoảng 23 MB cộng thư viện ONNX Runtime).']),

  h1('4. Tạo file cấu hình env/dev.json'),
  p('File này bị git ignore nên không có sẵn khi clone. Hãy tạo mới: copy file mẫu env/dev.json.example thành env/dev.json:'),
  code(['Copy-Item env\\dev.json.example env\\dev.json']),
  gap(),
  p('Sau đó mở env/dev.json, xoá nội dung cũ và dán nội dung sau, thay hai giá trị bằng giá trị chủ dự án đã gửi riêng cho bạn:'),
  code([
    '{',
    `  "SUPABASE_URL": "${URL_}",`,
    `  "SUPABASE_PUBLISHABLE_KEY": "${KEY_}"`,
    '}',
  ]),
  gap(),
  rich([{ text: 'Về bảo mật: ', bold: true }, 'publishable key được thiết kế để công khai trong app. Quyền truy cập dữ liệu được kiểm soát bằng Row Level Security trên server, nên bạn chỉ đọc/ghi được dữ liệu mình có quyền. Tuyệt đối không dán "service_role" key hay secret nào khác vào file này.']),

  h1('5. Chạy app'),
  step('Cắm điện thoại Android vào máy, chọn "Cho phép gỡ lỗi USB" trên điện thoại.'),
  step('Kiểm tra máy được nhận: flutter devices'),
  step('Chạy app với cấu hình đã tạo:'),
  code(['flutter run --dart-define-from-file=env/dev.json']),
  gap(),
  p('Lần build đầu mất vài phút. Khi app mở, đăng ký bằng Email để bắt đầu.'),
  rich([{ text: 'Nếu quên cờ --dart-define-from-file ', bold: true }, 'app vẫn chạy nhưng ở chế độ offline: không có tài khoản, bạn bè chỉ là dữ liệu mẫu. Màn hình sẽ không kết nối được database dùng chung.']),
  rich([{ text: 'Dùng VS Code: ', bold: true }, 'mở thư mục dự án, chọn cấu hình "Neo Locket (with Supabase)" trong Run and Debug (đã có sẵn trong .vscode/launch.json).']),

  h1('6. Đăng nhập'),
  p('Đăng ký và đăng nhập bằng Email + mật khẩu. Đăng nhập bằng Google chưa có trong app.'),

  h1('7. Build file APK để cài trên điện thoại'),
  code(['flutter build apk --release --dart-define-from-file=env/dev.json']),
  gap(),
  p('File nằm ở build/app/outputs/flutter-apk/app-release.apk. Nếu build trên Windows báo lỗi Kotlin incremental (thư mục Flutter pub cache và dự án khác ổ đĩa), chạy lệnh này trước:'),
  code(['$env:ORG_GRADLE_PROJECT_kotlin_incremental = "false"']),
  gap(),

  h1('8. Tính năng tuỳ chọn'),
  h2('8.1 Thông báo đẩy (push notification)'),
  p('Cần file google-services.json của dự án Firebase do chủ quản lý, file này không nằm trong repo vì lý do bảo mật. Nếu không có file này, app vẫn build và chạy bình thường, chỉ không có thông báo đẩy.'),
  h2('8.2 Server AI cho Van Gogh chất lượng cao (Google Colab hoặc laptop)'),
  p('Việc duy nhất cần server là chuyển ảnh sang phong cách Van Gogh bằng Stable Diffusion (cần GPU). Có 3 cách, chọn một:'),
  bullet('Cách A, dùng chung (dễ nhất cho thành viên): chủ dự án bật server trên Google Colab (xem "Mỗi lần bật server" bên dưới) và gửi cho bạn địa chỉ https và token. Bạn không cài gì, chỉ nhập hai giá trị đó vào app. Địa chỉ đổi mỗi lần chủ dự án bật lại, nên mỗi lần phải hỏi địa chỉ mới (token thì giữ nguyên nếu chủ dự án đặt secret).'),
  bullet('Cách B, Colab của riêng bạn: làm lại phần "Thiết lập Colab một lần" trên tài khoản Google của bạn (miễn phí, không cần thẻ, không cần xác minh số điện thoại).'),
  bullet('Cách C, chạy trên laptop có card NVIDIA: xem "Dựng server trên laptop" bên dưới.'),
  rich([{ text: 'Không cần server cũng dùng được app: ', bold: true }, 'kiểm tra ảnh quest hằng ngày chạy trên điện thoại (không cần mạng), phong cách 8-bit và bản Van Gogh nhẹ cũng chạy trực tiếp trên điện thoại. App tự dùng bản nhẹ khi chưa nhập server.']),
  rich([{ text: 'Thiết lập Colab một lần. ', bold: true }, 'Cần Python 3.10+ trên máy tính và một tài khoản Google.']),
  step('Đóng gói code engine thành một file nhỏ (khoảng 3 MB):', 'num2'),
  code(['cd server', 'python colab/pack_code.py']),
  gap(),
  step('Mở Google Drive, tạo thư mục tên locket (đường dẫn MyDrive/locket) và tải file server/colab/_staging/server.tar lên đó.', 'num2'),
  step('Mở https://colab.research.google.com → File → Upload notebook → chọn server/colab/locket_server.ipynb.', 'num2'),
  step('(Không bắt buộc) Ở thanh bên trái của Colab, bấm biểu tượng chìa khóa (Secrets), thêm secret tên LOCKET_TOKEN với giá trị là một chuỗi dài ngẫu nhiên (lấy bằng python -c "import secrets;print(secrets.token_urlsafe(24))") và bật "Notebook access". Đây là token cố định để khỏi phải đổi token mỗi lần. Nếu bỏ qua, mỗi phiên sẽ có một token ngẫu nhiên được in ra.', 'num2'),
  rich([{ text: 'Mỗi lần bật server. ', bold: true }, 'Ước tính (chưa đo trên Colab thật): lần đầu khoảng 15-20 phút vì phải tải model; các lần sau khoảng 8-10 phút, phần lớn là cài thư viện và nạp model.']),
  step('Mở notebook trên Colab → Runtime → Change runtime type → chọn T4 GPU → Save.', 'num5'),
  step('Runtime → Run all. Khi được hỏi, cho phép truy cập Google Drive.', 'num5'),
  step('Đợi. Lần đầu notebook tải khoảng 6 GB model và lưu vào Drive (file models.tar) để lần sau không tải lại. Cuối cùng ô cuối in khung "Address" (dạng https://xxxx.trycloudflare.com) và "Token".', 'num5'),
  step('Trong app: màn hình camera → biểu tượng server màu xanh → dán Address và Token → TEST → SAVE. Có thể kiểm tra bằng cách mở <Address>/v1/health trên trình duyệt.', 'num5'),
  step('Để ô cuối của notebook chạy trong lúc dùng app (đừng đóng tab). Dùng xong thì Runtime → Disconnect and delete runtime.', 'num5'),
  bullet('Địa chỉ đổi mỗi lần bật. Token giữ nguyên nếu bạn đã đặt secret LOCKET_TOKEN.'),
  bullet('Giới hạn: Colab miễn phí có thể ngắt phiên bất cứ lúc nào (rảnh quá lâu, hết thời gian tối đa, hoặc hết hạn mức GPU). Khi bị ngắt thì bật lại và nhập địa chỉ mới vào app. Phải bật tay mỗi lần dùng, phù hợp để demo hoặc nhóm nhỏ, không phải dịch vụ chạy 24/7.'),
  bullet('Sau khi sửa engine ảnh (thư mục server): chạy lại python colab/pack_code.py, thay file server.tar trong thư mục locket trên Drive, rồi bật lại notebook. Nếu thêm model mới thì xóa luôn file models.tar trên Drive để nó được tạo lại.'),
  bullet('Muốn thành viên khác tự bật: gửi cho họ file server.tar và notebook, họ làm lại phần thiết lập trên tài khoản Google của họ.'),
  rich([{ text: 'Về bảo mật: ', bold: true }, 'ảnh của người dùng đi qua máy chủ của Google và Cloudflare (đường hầm) để xử lý, không được lưu lại. Chỉ chia sẻ địa chỉ và token cho người bạn tin tưởng, và xem lại điều khoản sử dụng của Colab nếu dùng ngoài mục đích demo.']),
  rich([{ text: 'Notebook Colab nối với app như thế nào. ', bold: true }, 'Điện thoại không nói chuyện trực tiếp với Colab, mà đi qua một địa chỉ công khai do notebook tạo ra:']),
  bullet('Ô 1-2: kiểm tra GPU, nối Google Drive và giải nén code engine từ server.tar.'),
  bullet('Ô 3: cài thư viện vào một môi trường riêng Python 3.12 (Colab dùng Python 3.13 nên không cài trực tiếp được thư viện của server).'),
  bullet('Ô 4: lấy model (từ Drive nếu đã có models.tar, không thì tải về rồi lưu vào Drive).'),
  bullet('Ô 5-6: đọc token (secret LOCKET_TOKEN hoặc tạo ngẫu nhiên) rồi chạy server chính là code trong thư mục server, lắng nghe trong máy Colab.'),
  bullet('Ô 7: bật đường hầm Cloudflare, nó tạo ra địa chỉ dạng https://xxxx.trycloudflare.com trỏ vào server đó. Đây là địa chỉ bạn nhập vào app.'),
  bullet('Ô 8: giữ phiên sống và tự bật lại server hoặc đường hầm nếu một trong hai chết (khi đường hầm bật lại, địa chỉ mới được in ra).'),
  p('Trong app, bạn nhập Address và Token đúng một lần cho mỗi phiên Colab (màn hình camera → biểu tượng server → TEST → SAVE). Từ đó, khi bạn chọn phong cách Van Gogh, app gửi ảnh tới địa chỉ đó, chờ server vẽ xong rồi tải ảnh kết quả về. Không cần sửa code app. Nếu địa chỉ hoặc token sai, hoặc phiên Colab đã tắt, app không tạo được ảnh Van Gogh và dùng lại bản nhẹ trên điện thoại.'),
  rich([{ text: 'Mất bao lâu. ', bold: true }, 'Các con số dưới đây là ước tính, chưa đo trên Colab thật:']),
  bullet('Bật server mỗi phiên: khoảng 8-10 phút (lần đầu khoảng 15-20 phút). Chỉ phải làm khi bắt đầu dùng, không phải mỗi ảnh.'),
  bullet('Một ảnh Van Gogh khi server đã chạy: khoảng 10-20 giây cộng vài giây truyền ảnh qua mạng. Để so sánh, laptop RTX 3050 6 GB đo được khoảng 16 giây mỗi ảnh. GPU T4 của Colab có nhiều bộ nhớ hơn nên thường không chậm hơn, nhưng cần đo lại.'),
  bullet('Ảnh đầu tiên sau khi server vừa bật có thể chậm hơn vài giây. Hàng đợi tối đa 4 ảnh cùng lúc, ảnh thứ 5 sẽ bị báo bận.'),
  bullet('Phong cách 8-bit và bản Van Gogh nhẹ chạy trên điện thoại, mất dưới 1 giây (8-bit) và không phụ thuộc server.'),
  rich([{ text: 'Dựng server trên laptop (Cách C). ', bold: true }, 'Cần Python 3.10+ và driver NVIDIA/CUDA.']),
  step('Tạo môi trường và cài thư viện:', 'num4'),
  code(['cd server', 'python -m venv .venv', '.\.venv\Scripts\pip install -r requirements.txt']),
  gap(),
  step('Tải model (nặng, vài GB, cần kết nối ổn định):', 'num4'),
  code(['.\.venv\Scripts\python download_models.py']),
  gap(),
  step('Chạy server (lần đầu mất khoảng 1 phút để nạp model), ghi lại token được in ra:', 'num4'),
  code(['.\run_server.ps1']),
  gap(),
  step('Kết nối điện thoại. Cách dễ nhất là qua cáp USB:', 'num4'),
  code(['adb reverse tcp:8765 tcp:8765']),
  gap(),
  step('Trong app: màn hình camera → biểu tượng server màu xanh → nhập địa chỉ 127.0.0.1:8765 và token → TEST → SAVE.', 'num4'),
  p('Kết nối qua Wi-Fi cần mở firewall và đặt mạng ở chế độ Private, xem server/README.md.'),
  rich([{ text: 'Lưu ý: ', bold: true }, 'server laptop chạy trên máy của từng người nên token và địa chỉ là riêng của bạn. Server Colab thì cả nhóm có thể dùng chung địa chỉ và token trong lúc chủ dự án đang bật. Chỉ database là luôn dùng chung.']),

  h2('8.3 Dành cho người phát triển: thêm hoặc sửa quest'),
  p('Model kiểm tra ảnh quest dùng bộ mô tả đã được tính sẵn cho từng quest (assets/quest_model/quest_labels.json và quest_labels.bin). Khi bạn thêm quest mới, đổi positives hoặc negatives trong lib/features/quest/quest_catalog.dart, phải tạo lại hai file này, nếu không test quest_on_device_test sẽ báo lỗi và quest mới sẽ báo "chưa có trong bộ kiểm ảnh". Việc này cần chạy trong thư mục server (đã cài môi trường ở Bước 8.2):'),
  step('Cài thêm gói onnx chỉ dùng cho bước xuất model (cài vào thư mục riêng, không đụng môi trường server):', 'num3'),
  code(['.\\.venv\\Scripts\\pip install --target .eval_tools --no-deps onnx==1.17.0']),
  gap(),
  step('Xuất lại model và bộ mô tả vào assets (lần đầu tự tải model MobileCLIP2-S0, vài trăm MB):', 'num3'),
  code(['$env:PYTHONPATH = ".eval_tools"', '.\\.venv\\Scripts\\python -m eval.export_quest_model --out ..\\assets\\quest_model']),
  gap(),
  p('Chỉ có 3 file trong assets/quest_model được đưa vào app (model fp16 khoảng 23 MB, quest_labels.json và quest_labels.bin). Đừng để file .onnx nào khác trong thư mục này vì mọi file ở đó đều bị đóng gói vào APK.'),
  step('Chạy lại test: flutter test test/quest_on_device_test.dart', 'num3'),
  p('Không cần chạy bước này nếu bạn không đổi catalog quest.'),
  h2('8.4 Dành cho người phát triển: bộ đoán loại ảnh của Van Gogh'),
  p('Khi chọn Van Gogh, điện thoại tự đoán ảnh là chân dung, ảnh nhóm, cảnh đêm, bầu trời hay cảnh ngày (dùng lại model của quest, không cần mạng). Từ đó app chọn bức tranh mẫu phù hợp và gửi loại ảnh lên server Colab/laptop. Tranh mẫu chỉ cho nét cọ: màu vẫn là màu của ảnh gốc.'),
  p('Câu mô tả cho từng loại ảnh nằm trong server/eval/export_scene_labels.py (biến SCENES) và đã được tính sẵn vào assets/quest_model/scene_labels.json và scene_labels.bin. Chỉ khi sửa các câu mô tả đó mới phải làm lại các bước sau, trong thư mục server:'),
  step('Đo độ chính xác trên 62 ảnh đã gắn nhãn (cần thư mục eval/photos, xin chủ dự án). Kết quả hiện tại: đúng 54/62 ảnh (87 %). Đừng nhận câu mô tả mới nếu kết quả thấp hơn:', 'num6'),
  code(['.\\.venv\\Scripts\\python -m eval.export_scene_labels --eval eval/photos']),
  gap(),
  step('Xuất lại hai file vào assets:', 'num6'),
  code(['.\\.venv\\Scripts\\python -m eval.export_scene_labels --out ..\\assets\\quest_model']),
  gap(),
  step('Chạy lại test: flutter test test/scene_guess_test.dart', 'num6'),
  p('Sau khi cập nhật code server (đã có trường scene mới), nhớ chạy lại python colab/pack_code.py và thay server.tar trên Drive như ở Bước 8.2. Server cũ vẫn chạy được với app mới, chỉ không nhận gợi ý loại ảnh.'),
  h2('8.5 Dành cho người build iOS'),
  p('Plugin ONNX Runtime yêu cầu iOS 16 trở lên và liên kết tĩnh (static linkage). Dự án hiện đặt iOS tối thiểu là 13 nên cần nâng lên 16 và dùng "use_frameworks! :linkage => :static" trong ios/Podfile trước khi build cho iPhone. Phần này chưa được thử vì nhóm đang build cho Android.'),

  h1('9. Lỗi thường gặp'),
  new Table({
    width: { size: 9026, type: WidthType.DXA },
    columnWidths: [3000, 6026],
    rows: [
      ['Triệu chứng', 'Cách xử lý', true],
      ['App chạy nhưng không đăng nhập/kết bạn được', 'Thiếu cờ --dart-define-from-file=env/dev.json, hoặc sai nội dung env/dev.json. Chạy lại đúng lệnh ở Bước 5.'],
      ['Không tìm thấy env/dev.json', 'Bạn đang đứng sai thư mục. Phải ở trong "Neo-Brutalism Locket" (Bước 2).'],
      ['flutter pub get lỗi version SDK', 'Cập nhật Flutter: flutter upgrade (cần Dart ≥ 3.11).'],
      ['Không thấy thiết bị trong flutter devices', 'Bật Gỡ lỗi USB, cắm lại cáp, chọn "Luôn cho phép" trên điện thoại.'],
      ['Build Android lỗi Kotlin incremental', 'Đặt ORG_GRADLE_PROJECT_kotlin_incremental=false (Bước 7).'],
      ['Quest báo "Không kiểm tra được ảnh trên máy"', 'Model chưa nạp được (thiếu file trong assets/quest_model hoặc thiết bị quá yếu). Lượt thử không bị trừ. Chạy lại flutter pub get rồi build lại.'],
      ['Quest báo "KHÔNG ĐÚNG" dù chụp đúng', 'Chạy bản debug (flutter run, không phải APK release): thông báo sẽ có thêm "DEBUG: nhãn xx%" cho biết model thấy gì và điểm của đáp án đúng. Ghi lại quest, nhãn và điểm rồi gửi cho chủ dự án để chỉnh bộ nhận diện. Bản release không hiện dòng này.'],
      ['Bản debug báo "ORT_NOT_IMPLEMENTED ... Gelu ... float16"', 'Model trong assets/quest_model được xuất với phép tính fp16, điện thoại không chạy được. Xuất lại bằng script hiện tại (Bước 8.3): nó chỉ lưu trọng số dạng fp16, còn phép tính vẫn fp32.'],
      ['Quest báo "chưa có trong bộ kiểm ảnh"', 'Catalog quest mới hơn bộ mô tả đã xuất. Xuất lại theo Bước 8.3.'],
      ['Bản release chạy nhưng quest luôn lỗi, bản debug thì bình thường', 'Thiếu quy tắc giữ lớp ONNX Runtime. File android/app/proguard-rules.pro phải có dòng -keep class ai.onnxruntime.** { *; } (đã có sẵn trong repo).'],
      ['Colab: ô 1 in "NO GPU"', 'Chưa chọn GPU. Runtime → Change runtime type → T4 GPU → Save, rồi chạy lại. Nếu không chọn được GPU thì Colab đang hết hạn mức GPU miễn phí, đợi vài giờ hoặc dùng tài khoản Google khác.'],
      ['Colab: ô 2 báo thiếu server.tar', 'Chưa tải server.tar vào Google Drive đúng thư mục MyDrive/locket (xem phần thiết lập Colab một lần).'],
      ['Colab: ô 3 báo CalledProcessError khi cài thư viện', 'Đọc các dòng lỗi phía trên dòng CalledProcessError để biết thư viện nào lỗi. Thường chỉ cần Disconnect and delete runtime rồi chạy lại từ đầu (mạng bị đứt giữa chừng).'],
      ['Colab: ô 4 báo hết dung lượng Drive', 'Cần khoảng 7 GB trống trên Google Drive cho file models.tar.'],
      ['Van Gogh không dùng server vẫn ra màu xanh kiểu "Starry Night" cho mọi ảnh', 'Bộ đoán loại ảnh không chạy được (thiếu assets/quest_model/scene_labels.json hoặc .bin), nên app dùng tranh mẫu mặc định. Chạy flutter pub get rồi build lại; nếu vẫn lỗi, xuất lại theo Bước 8.4.'],
      ['App báo TEST thất bại với địa chỉ Colab', 'Địa chỉ đã cũ (đổi mỗi phiên), phiên Colab đã bị ngắt, hoặc sai token. Mở lại notebook, xem địa chỉ mới ở ô cuối, nhập lại vào app.'],
      ['Đang dùng thì app không tạo được ảnh Van Gogh nữa', 'Colab free có thể ngắt phiên bất cứ lúc nào. Bật lại notebook (Run all) và nhập địa chỉ mới.'],
      ['Quest Van Gogh không tạo được ảnh tranh', 'Chưa nhập server, notebook Colab chưa chạy hoặc đã bị ngắt phiên (bật lại, địa chỉ sẽ đổi), hoặc sai địa chỉ/token (Bước 8.2). Việc kiểm ảnh quest vẫn chạy được mà không cần server.'],
    ].map(([a, b, head]) => new TableRow({
      tableHeader: !!head,
      children: [a, b].map((t, i) => new TableCell({
        width: { size: i === 0 ? 3000 : 6026, type: WidthType.DXA },
        borders,
        shading: head ? { fill: 'FFD84D', type: ShadingType.CLEAR, color: 'auto' } : undefined,
        margins: { top: 70, bottom: 70, left: 120, right: 120 },
        children: [new Paragraph({ children: [new TextRun({ text: t, font: FONT, size: 20, bold: !!head })] })],
      })),
    })),
  }),
];

const doc = new Document({
  styles: {
    default: { document: { run: { font: FONT, size: 22 } } },
    paragraphStyles: [
      { id: 'Heading1', name: 'Heading 1', basedOn: 'Normal', next: 'Normal', quickFormat: true, run: { size: 30, bold: true, font: FONT }, paragraph: { spacing: { before: 300, after: 140 }, outlineLevel: 0 } },
      { id: 'Heading2', name: 'Heading 2', basedOn: 'Normal', next: 'Normal', quickFormat: true, run: { size: 25, bold: true, font: FONT }, paragraph: { spacing: { before: 200, after: 100 }, outlineLevel: 1 } },
    ],
  },
  numbering: {
    config: [
      { reference: 'bul', levels: [{ level: 0, format: LevelFormat.BULLET, text: '•', alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 540, hanging: 270 } } } }] },
      { reference: 'num2', levels: [{ level: 0, format: LevelFormat.DECIMAL, text: '%1.', alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 540, hanging: 360 } } } }] },
      { reference: 'num3', levels: [{ level: 0, format: LevelFormat.DECIMAL, text: '%1.', alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 540, hanging: 360 } } } }] },
      { reference: 'num4', levels: [{ level: 0, format: LevelFormat.DECIMAL, text: '%1.', alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 540, hanging: 360 } } } }] },
      { reference: 'num5', levels: [{ level: 0, format: LevelFormat.DECIMAL, text: '%1.', alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 540, hanging: 360 } } } }] },
      { reference: 'num6', levels: [{ level: 0, format: LevelFormat.DECIMAL, text: '%1.', alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 540, hanging: 360 } } } }] },
      { reference: 'num', levels: [{ level: 0, format: LevelFormat.DECIMAL, text: '%1.', alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 540, hanging: 360 } } } }] },
    ],
  },
  sections: [{
    properties: { page: { size: { width: 11906, height: 16838 }, margin: { top: 1440, right: 1440, bottom: 1440, left: 1440 } } },
    children: content,
  }],
});

Packer.toBuffer(doc).then((buf) => {
  const out = path.join(__dirname, 'HUONG_DAN_CHAY_APP.docx');
  fs.writeFileSync(out, buf);
  console.log('wrote', out, 'placeholders:', [URL_, KEY_].filter((v) => v.startsWith('<<')).length);
});
