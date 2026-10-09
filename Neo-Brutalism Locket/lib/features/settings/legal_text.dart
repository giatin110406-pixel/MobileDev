/// One titled paragraph of a policy.
class LegalSection {
  const LegalSection(this.heading, this.body);

  final String heading;
  final String body;
}

/// A plain-language summary of what the app does with your data. DRAFT: have
/// a lawyer review it, and fill in the contact address, before a public
/// release.
List<LegalSection> privacyPolicy(String languageCode) =>
    languageCode == 'vi' ? _privacyVi : _privacyEn;

/// Draft terms of use (same caveat as the privacy policy).
List<LegalSection> termsOfUse(String languageCode) =>
    languageCode == 'vi' ? _termsVi : _termsEn;

const _privacyVi = [
  LegalSection(
    'Chúng tôi lưu gì',
    'Email và mật khẩu (mật khẩu được mã hóa) để đăng nhập; tên hiển thị, tên người dùng và ảnh đại diện; ảnh, video, chú thích và nhãn giờ/địa điểm bạn gửi; tin nhắn; danh sách bạn bè; Sunbit, streak và đồ trong shop. Nhãn địa điểm chỉ là tên thành phố/quận bạn chọn thêm, không lưu tọa độ.',
  ),
  LegalSection(
    'Ai nhìn thấy',
    'Ảnh và video chỉ những người bạn chọn gửi (hoặc tất cả bạn bè) mới xem được. Tin nhắn chỉ hai người trong cuộc đọc được. Reaction chỉ tác giả bài thấy. Tên, tên người dùng, ảnh đại diện, khung và banner của bạn hiển thị với người dùng khác.',
  ),
  LegalSection(
    'Tranh Van Gogh và kiểm tra nhiệm vụ',
    'Khi bạn chọn phong cách Van Gogh hoặc làm nhiệm vụ hằng ngày, ảnh được gửi tới máy tính của chính bạn (laptop đã kết nối) để xử lý trong bộ nhớ và không được lưu lại.',
  ),
  LegalSection(
    'Xóa dữ liệu',
    'Vào Cài đặt > Xóa tài khoản để xóa vĩnh viễn tài khoản, ảnh, tin nhắn, bạn bè, Sunbit và đồ đã mua. Bài đã gửi và tin nhắn của bạn cũng biến mất khỏi máy bạn bè.',
  ),
  LegalSection(
    'Chặn và báo cáo',
    'Bạn có thể chặn hoặc báo cáo người khác và bài đăng. Báo cáo được lưu để xem xét.',
  ),
  LegalSection('Độ tuổi', 'Ứng dụng dành cho người từ 13 tuổi trở lên.'),
  LegalSection('Liên hệ', '[điền địa chỉ email liên hệ trước khi phát hành]'),
];

const _privacyEn = [
  LegalSection(
    'What we keep',
    'Your email and password (the password is stored hashed) to sign in; your display name, username and profile photo; the photos, videos, captions and time/place labels you send; messages; your friend list; Sunbit, streak and shop items. A place label is only the town or district name you choose to add; coordinates are never stored.',
  ),
  LegalSection(
    'Who sees it',
    'Photos and videos are visible only to the people you send them to (or all your friends). Messages can be read only by the two people in the chat. Reactions are seen only by the post\'s author. Your name, username, profile photo, frame and banner are visible to other users.',
  ),
  LegalSection(
    'Van Gogh art and quest checks',
    'When you pick the Van Gogh style or do the daily quest, the photo is sent to your own computer (the laptop you connected) and processed in memory; it is not kept.',
  ),
  LegalSection(
    'Deleting your data',
    'Settings > Delete account permanently removes your account, photos, messages, friends, Sunbit and purchases. Posts and messages you sent disappear from your friends\' phones too.',
  ),
  LegalSection(
    'Blocking and reporting',
    'You can block or report people and posts. Reports are stored for review.',
  ),
  LegalSection('Age', 'The app is for people aged 13 and over.'),
  LegalSection('Contact', '[add a contact email before release]'),
];

const _termsVi = [
  LegalSection(
    'Cách dùng',
    'Hãy chỉ gửi ảnh và tin nhắn mà bạn có quyền chia sẻ. Không gửi nội dung bất hợp pháp, quấy rối, bạo lực hoặc xâm phạm quyền riêng tư của người khác.',
  ),
  LegalSection(
    'Tài khoản',
    'Bạn chịu trách nhiệm giữ bí mật mật khẩu. Chúng tôi có thể khóa tài khoản vi phạm điều khoản.',
  ),
  LegalSection(
    'Sunbit',
    'Sunbit là điểm thưởng trong ứng dụng: chỉ kiếm bằng nhiệm vụ, chỉ tiêu trong shop, không chuyển nhượng, không mua bằng tiền thật và không có giá trị quy đổi.',
  ),
  LegalSection(
    'Nội dung của bạn',
    'Bạn giữ quyền với ảnh của mình. Bằng việc gửi, bạn cho phép ứng dụng lưu và hiển thị ảnh đó cho những người nhận bạn chọn.',
  ),
];

const _termsEn = [
  LegalSection(
    'Using the app',
    'Only send photos and messages you have the right to share. Do not send anything illegal, harassing, violent or that invades someone else\'s privacy.',
  ),
  LegalSection(
    'Your account',
    'You are responsible for keeping your password secret. We may suspend accounts that break these terms.',
  ),
  LegalSection(
    'Sunbit',
    'Sunbit is an in-app reward: it is earned only by quests, spent only in the shop, cannot be transferred or bought with real money, and has no cash value.',
  ),
  LegalSection(
    'Your content',
    'You keep the rights to your photos. By sending them you let the app store them and show them to the people you chose.',
  ),
];
