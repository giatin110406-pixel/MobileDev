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
  h2('8.2 Server AI trên laptop (chỉ cho Van Gogh chất lượng cao)'),
  p('Việc duy nhất cần server Python trên laptop có card NVIDIA là chuyển ảnh sang phong cách Van Gogh bằng Stable Diffusion.'),
  rich([{ text: 'Kiểm tra ảnh quest hằng ngày không cần server nữa: ', bold: true }, 'app chạy model nhận diện ngay trên điện thoại (không cần mạng, không cần laptop). Phong cách 8-bit và bản Van Gogh nhẹ cũng chạy trực tiếp trên điện thoại.']),
  p('Các bước dựng server (cần Python 3.10+ và driver NVIDIA/CUDA):'),
  step('Tạo môi trường và cài thư viện:', 'num2'),
  code(['cd server', 'python -m venv .venv', '.\\.venv\\Scripts\\pip install -r requirements.txt']),
  gap(),
  step('Tải model (nặng, vài GB, cần kết nối ổn định):', 'num2'),
  code(['.\\.venv\\Scripts\\python download_models.py']),
  gap(),
  step('Chạy server (lần đầu mất khoảng 1 phút để nạp model), ghi lại token được in ra:', 'num2'),
  code(['.\\run_server.ps1']),
  gap(),
  step('Kết nối điện thoại. Cách dễ nhất là qua cáp USB:', 'num2'),
  code(['adb reverse tcp:8765 tcp:8765']),
  gap(),
  step('Trong app: màn hình camera → biểu tượng server màu xanh → nhập địa chỉ 127.0.0.1:8765 và token → TEST → SAVE.', 'num2'),
  p('Kết nối qua Wi-Fi cần mở firewall và đặt mạng ở chế độ Private, xem server/README.md.'),
  rich([{ text: 'Lưu ý: ', bold: true }, 'server chạy trên máy của từng người, nên token và địa chỉ là riêng của bạn. Chỉ database là dùng chung.']),

  h2('8.3 Dành cho người phát triển: thêm hoặc sửa quest'),
  p('Model kiểm tra ảnh quest dùng bộ mô tả đã được tính sẵn cho từng quest (assets/quest_model/quest_labels.json và quest_labels.bin). Khi bạn thêm quest mới, đổi positives hoặc negatives trong lib/features/quest/quest_catalog.dart, phải tạo lại hai file này, nếu không test quest_on_device_test sẽ báo lỗi và quest mới sẽ báo "chưa có trong bộ kiểm ảnh". Việc này cần chạy trong thư mục server (đã cài môi trường ở Bước 8.2):'),
  step('Cài thêm 2 gói chỉ dùng cho bước xuất model (cài vào thư mục riêng, không đụng môi trường server):', 'num3'),
  code(['.\\.venv\\Scripts\\pip install --target .eval_tools --no-deps onnx==1.17.0 onnxconverter-common==1.14.0']),
  gap(),
  step('Xuất lại model và bộ mô tả vào assets (lần đầu tự tải model MobileCLIP2-S0, vài trăm MB):', 'num3'),
  code(['$env:PYTHONPATH = ".eval_tools"', '.\\.venv\\Scripts\\python -m eval.export_quest_model --out ..\\assets\\quest_model']),
  gap(),
  p('Chỉ có 3 file trong assets/quest_model được đưa vào app (model fp16 khoảng 23 MB, quest_labels.json và quest_labels.bin). Đừng để file .onnx nào khác trong thư mục này vì mọi file ở đó đều bị đóng gói vào APK.'),
  step('Chạy lại test: flutter test test/quest_on_device_test.dart', 'num3'),
  p('Không cần chạy bước này nếu bạn không đổi catalog quest.'),
  h2('8.4 Dành cho người build iOS'),
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
      ['Quest báo "chưa có trong bộ kiểm ảnh"', 'Catalog quest mới hơn bộ mô tả đã xuất. Xuất lại theo Bước 8.3.'],
      ['Bản release chạy nhưng quest luôn lỗi, bản debug thì bình thường', 'Thiếu quy tắc giữ lớp ONNX Runtime. File android/app/proguard-rules.pro phải có dòng -keep class ai.onnxruntime.** { *; } (đã có sẵn trong repo).'],
      ['Quest Van Gogh không tạo được ảnh tranh', 'Server laptop chưa chạy hoặc chưa nhập đúng địa chỉ/token (Bước 8.2). Việc kiểm ảnh quest vẫn chạy được mà không cần server.'],
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
