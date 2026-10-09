// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'Pocket Portrait';

  @override
  String get backendNotConfigured =>
      'Chưa cấu hình máy chủ. Ứng dụng đang chạy ở chế độ chỉ trên máy.';

  @override
  String get retry => 'THỬ LẠI';

  @override
  String get cancel => 'HỦY';

  @override
  String get ok => 'OK';

  @override
  String get signInTitle => 'ĐĂNG NHẬP';

  @override
  String get signUpTitle => 'TẠO TÀI KHOẢN';

  @override
  String get authTagline => 'Chụp, biến thành tranh và gửi cho bạn bè.';

  @override
  String get emailLabel => 'EMAIL';

  @override
  String get passwordLabel => 'MẬT KHẨU';

  @override
  String get signInButton => 'ĐĂNG NHẬP';

  @override
  String get signUpButton => 'ĐĂNG KÝ';

  @override
  String get switchToSignUp => 'Chưa có tài khoản? Đăng ký';

  @override
  String get switchToSignIn => 'Đã có tài khoản? Đăng nhập';

  @override
  String get forgotPassword => 'Quên mật khẩu?';

  @override
  String get resetSent =>
      'Đã gửi email đặt lại mật khẩu. Hãy kiểm tra hộp thư.';

  @override
  String get resetNeedsEmail => 'Nhập email của bạn ở trên trước.';

  @override
  String get confirmEmailSent =>
      'Gần xong! Hãy bấm vào liên kết trong email để xác nhận, rồi đăng nhập.';

  @override
  String get errInvalidCredentials => 'Sai email hoặc mật khẩu.';

  @override
  String get errEmailTaken => 'Email này đã có tài khoản. Hãy đăng nhập.';

  @override
  String get errWeakPassword => 'Mật khẩu quá yếu. Hãy dùng ít nhất 8 ký tự.';

  @override
  String get errInvalidEmail => 'Email không hợp lệ.';

  @override
  String get errNetwork => 'Không kết nối được. Kiểm tra mạng và thử lại.';

  @override
  String get errUnknown => 'Có lỗi xảy ra. Thử lại nhé.';

  @override
  String get errPasswordShort => 'Mật khẩu cần ít nhất 8 ký tự.';

  @override
  String get onboardingTitle => 'CHÀO MỪNG!';

  @override
  String get onboardingSubtitle => 'Chọn tên để bạn bè tìm thấy bạn.';

  @override
  String get displayNameLabel => 'TÊN HIỂN THỊ';

  @override
  String get usernameLabel => 'TÊN NGƯỜI DÙNG';

  @override
  String get usernameHelp =>
      '3–20 ký tự: chữ thường, số, dấu chấm hoặc gạch dưới.';

  @override
  String get usernameTaken => 'Tên này đã có người dùng.';

  @override
  String get usernameAvailable => 'Dùng được!';

  @override
  String get usernameChecking => 'Đang kiểm tra...';

  @override
  String get usernameTooShort => 'Cần ít nhất 3 ký tự.';

  @override
  String get usernameTooLong => 'Tối đa 20 ký tự.';

  @override
  String get usernameBadCharacters =>
      'Chỉ dùng chữ thường, số, dấu chấm và gạch dưới.';

  @override
  String get displayNameRequired => 'Hãy nhập tên hiển thị.';

  @override
  String get avatarOptional => 'ẢNH ĐẠI DIỆN (TÙY CHỌN)';

  @override
  String get avatarPick => 'CHỌN ẢNH';

  @override
  String get continueButton => 'TIẾP TỤC';

  @override
  String get signOut => 'ĐĂNG XUẤT';

  @override
  String get signOutConfirmTitle => 'ĐĂNG XUẤT?';

  @override
  String get signOutConfirmBody => 'Bạn có thể đăng nhập lại bất cứ lúc nào.';

  @override
  String get loadingAccount => 'ĐANG TẢI TÀI KHOẢN...';

  @override
  String get accountLoadFailed => 'Không tải được tài khoản.';

  @override
  String get avatarUploadFailed => 'Chưa tải được ảnh đại diện lên máy chủ.';

  @override
  String get friendsOnline => 'ONLINE';

  @override
  String get friendsAdd => 'THÊM BẠN';

  @override
  String get friendsRequests => 'LỜI MỜI';

  @override
  String get friendsIncoming => 'ĐÃ MỜI BẠN';

  @override
  String get friendsOutgoing => 'ĐÃ GỬI';

  @override
  String get friendsAccept => 'CHẤP NHẬN';

  @override
  String get friendsDecline => 'TỪ CHỐI';

  @override
  String get friendsCancelRequest => 'HỦY';

  @override
  String get friendsEmptyTitle => 'CHƯA CÓ\nBẠN BÈ';

  @override
  String get friendsEmptyBody =>
      'TÌM BẠN THEO TÊN NGƯỜI DÙNG HOẶC GỬI LIÊN KẾT MỜI.';

  @override
  String get friendsRefreshFailed => 'Không cập nhật được danh sách bạn bè.';

  @override
  String get addFriendTitle => 'THÊM BẠN';

  @override
  String get addFriendHint => 'Nhập tên người dùng của bạn bè';

  @override
  String get addFriendNoResults => 'Không tìm thấy ai.';

  @override
  String get addFriendSend => 'KẾT BẠN';

  @override
  String get addFriendShare => 'CHIA SẺ LỜI MỜI CỦA TÔI';

  @override
  String inviteMessage(String username, String link) {
    return 'Kết bạn với mình trên Pocket Portrait nhé! @$username\n$link';
  }

  @override
  String requestSentTo(String name) {
    return 'Đã gửi lời mời cho $name.';
  }

  @override
  String nowFriendsWith(String name) {
    return 'Bạn và $name đã là bạn bè!';
  }

  @override
  String inviteLinkTitle(String username) {
    return 'Kết bạn với @$username?';
  }

  @override
  String get friendNotFound => 'Không tìm thấy người dùng này.';

  @override
  String get friendSelf => 'Đó chính là bạn mà.';

  @override
  String get friendAlready => 'Hai bạn đã là bạn bè.';

  @override
  String get friendAlreadySent => 'Bạn đã gửi lời mời rồi.';

  @override
  String get friendNotAccepting => 'Người này không nhận lời mời mới.';

  @override
  String get friendTooManyPending =>
      'Bạn đang có quá nhiều lời mời chờ. Hãy hủy bớt.';

  @override
  String get friendLimit => 'Bạn đã đạt giới hạn 20 bạn bè.';

  @override
  String get friendTheirLimit => 'Người này đã đạt giới hạn bạn bè.';

  @override
  String get friendsGenericError => 'Có lỗi xảy ra. Thử lại nhé.';

  @override
  String get removeFriendTitle => 'XÓA BẠN?';

  @override
  String removeFriendBody(String name) {
    return 'Xóa $name khỏi danh sách bạn bè? Bạn có thể gửi lời mời lại sau.';
  }

  @override
  String get removeFriendConfirm => 'XÓA';

  @override
  String get composerTitle => 'ĐĂNG ẢNH';

  @override
  String get composerCaptionHint => 'Thêm chú thích...';

  @override
  String get composerAllFriends => 'TẤT CẢ BẠN BÈ';

  @override
  String get composerSend => 'GỬI';

  @override
  String get composerNoFriends => 'Hãy kết bạn trước để gửi ảnh cho họ.';

  @override
  String get composerPickAtLeastOne => 'Chọn ít nhất một người nhận.';

  @override
  String composerSentTo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Đã gửi cho $count người bạn.',
      one: 'Đã gửi cho 1 người bạn.',
    );
    return '$_temp0';
  }

  @override
  String get composerQueued => 'Chưa có mạng. Ảnh sẽ tự gửi khi kết nối lại.';

  @override
  String get composerSending => 'Đang gửi...';

  @override
  String get feedYou => 'Bạn';

  @override
  String get sendPrintButton => 'GỬI';

  @override
  String get printDiscard => 'HỦY';

  @override
  String get printPost => 'ĐĂNG';

  @override
  String get composerPostAll => 'ĐĂNG CHO TẤT CẢ';

  @override
  String composerSendToSome(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'GỬI CHO $count NGƯỜI',
      one: 'GỬI CHO 1 NGƯỜI',
    );
    return '$_temp0';
  }

  @override
  String get postSaved => 'Đã lưu vào thư viện ảnh.';

  @override
  String get postSaveFailed => 'Không lưu được ảnh.';

  @override
  String get postShareFailed => 'Không chia sẻ được ảnh.';

  @override
  String get postMenuSave => 'LƯU VỀ MÁY';

  @override
  String get postMenuShare => 'CHIA SẺ';

  @override
  String get postMenuDelete => 'XÓA BÀI';

  @override
  String get postDeleteTitle => 'XÓA BÀI NÀY?';

  @override
  String get postDeleteBody =>
      'Bài sẽ biến mất với tất cả bạn bè. Không thể hoàn tác.';

  @override
  String get postDeleted => 'Đã xóa bài.';

  @override
  String reactionSent(String emoji) {
    return 'Đã gửi $emoji';
  }

  @override
  String get replySent => 'Đã gửi tin nhắn.';

  @override
  String get chatSendFailed => 'Không gửi được tin nhắn.';

  @override
  String get chatNotFriends => 'Hai bạn không còn là bạn bè.';

  @override
  String get chatTooLong => 'Tin nhắn quá dài (tối đa 500 ký tự).';

  @override
  String get historyTab => 'LỊCH SỬ';

  @override
  String get historyTitle => 'Lịch sử';

  @override
  String get historyAll => 'TẤT CẢ';

  @override
  String get historyMine => 'CỦA TÔI';

  @override
  String get historyPosts => 'BÀI ĐĂNG';

  @override
  String get historyOnDevice => 'TRÊN MÁY';

  @override
  String get historyEmpty =>
      'Chưa có bài nào. Gửi ảnh cho bạn bè hoặc chờ họ gửi cho bạn nhé!';

  @override
  String get historyLoadFailed =>
      'Không tải được lịch sử. Kéo xuống để thử lại.';

  @override
  String get overlayTime => 'GIỜ';

  @override
  String get overlayPlace => 'ĐỊA ĐIỂM';

  @override
  String get overlayFindingPlace => 'ĐANG TÌM VỊ TRÍ...';

  @override
  String get placeServicesOff =>
      'Định vị đang tắt. Bật định vị trong cài đặt máy.';

  @override
  String get placeDenied => 'Ứng dụng chưa được phép dùng vị trí.';

  @override
  String get placeFailed => 'Không xác định được địa điểm.';

  @override
  String get timerOff => 'Tắt hẹn giờ';

  @override
  String timerSeconds(int seconds) {
    return 'Hẹn giờ $seconds giây';
  }

  @override
  String get holdForVideo => 'Giữ để quay video';

  @override
  String get videoTooShort => 'Video quá ngắn. Giữ nút lâu hơn.';

  @override
  String get videoFailed => 'Không quay được video.';

  @override
  String get errSamePassword => 'Hãy chọn mật khẩu khác mật khẩu hiện tại.';

  @override
  String get resetPasswordTitle => 'MẬT KHẨU MỚI';

  @override
  String get resetPasswordSubtitle =>
      'Chọn mật khẩu mới cho tài khoản của bạn.';

  @override
  String get newPasswordLabel => 'MẬT KHẨU MỚI';

  @override
  String get confirmPasswordLabel => 'NHẬP LẠI MẬT KHẨU';

  @override
  String get passwordsDiffer => 'Hai mật khẩu chưa giống nhau.';

  @override
  String get savePassword => 'LƯU MẬT KHẨU';

  @override
  String get passwordChanged => 'Đã đổi mật khẩu.';

  @override
  String get settingsTitle => 'Cài đặt';

  @override
  String get settingsAccount => 'TÀI KHOẢN';

  @override
  String get settingsPrivacy => 'QUYỀN RIÊNG TƯ';

  @override
  String get settingsLanguage => 'NGÔN NGỮ';

  @override
  String get settingsAbout => 'VỀ ỨNG DỤNG';

  @override
  String get settingsEditProfile => 'Sửa tên và tên người dùng';

  @override
  String get settingsChangePassword => 'Đổi mật khẩu';

  @override
  String settingsEmail(String email) {
    return 'Email: $email';
  }

  @override
  String get settingsAllowRequests => 'Cho phép nhận lời mời kết bạn';

  @override
  String get settingsAllowRequestsHint =>
      'Tắt đi thì không ai gửi được lời mời mới cho bạn.';

  @override
  String get settingsBlocked => 'Danh sách đã chặn';

  @override
  String get settingsLanguageSystem => 'Theo máy';

  @override
  String get settingsLanguageVi => 'Tiếng Việt';

  @override
  String get settingsLanguageEn => 'English';

  @override
  String get settingsLaptop => 'Kết nối laptop (tranh Van Gogh)';

  @override
  String get settingsPrivacyPolicy => 'Chính sách quyền riêng tư';

  @override
  String get settingsTerms => 'Điều khoản sử dụng';

  @override
  String get settingsDeleteAccount => 'XÓA TÀI KHOẢN';

  @override
  String get editProfileTitle => 'SỬA HỒ SƠ';

  @override
  String get saveButton => 'LƯU';

  @override
  String get deleteAccountTitle => 'XÓA TÀI KHOẢN?';

  @override
  String get deleteAccountBody =>
      'Toàn bộ ảnh, tin nhắn, bạn bè, Sunbit và đồ đã mua của bạn sẽ bị xóa vĩnh viễn. Không thể hoàn tác.';

  @override
  String deleteAccountType(String username) {
    return 'Nhập \"$username\" để xác nhận';
  }

  @override
  String get deleteAccountConfirm => 'XÓA VĨNH VIỄN';

  @override
  String get deleteAccountFailed =>
      'Không xóa được tài khoản. Kiểm tra mạng rồi thử lại.';

  @override
  String get blockedTitle => 'ĐÃ CHẶN';

  @override
  String get blockedEmpty => 'Bạn chưa chặn ai.';

  @override
  String get unblock => 'BỎ CHẶN';

  @override
  String get blockPerson => 'CHẶN';

  @override
  String blockTitle(String name) {
    return 'CHẶN $name?';
  }

  @override
  String get blockBody =>
      'Hai bạn sẽ không còn là bạn bè, không thấy ảnh của nhau và không nhắn được cho nhau. Họ không được báo.';

  @override
  String blockedDone(String name) {
    return 'Đã chặn $name.';
  }

  @override
  String unblockedDone(String name) {
    return 'Đã bỏ chặn $name.';
  }

  @override
  String get reportPerson => 'BÁO CÁO NGƯỜI NÀY';

  @override
  String get reportPost => 'BÁO CÁO BÀI NÀY';

  @override
  String get reportTitle => 'BÁO CÁO';

  @override
  String get reportWhy => 'Lý do';

  @override
  String get reportSpam => 'Spam hoặc quảng cáo';

  @override
  String get reportInappropriate => 'Nội dung không phù hợp';

  @override
  String get reportHarassment => 'Quấy rối hoặc bắt nạt';

  @override
  String get reportOther => 'Lý do khác';

  @override
  String get reportDetailsHint => 'Thêm chi tiết (không bắt buộc)';

  @override
  String get reportSend => 'GỬI BÁO CÁO';

  @override
  String get reportSent => 'Đã gửi báo cáo. Cảm ơn bạn.';

  @override
  String get reportTooMany =>
      'Bạn đã báo cáo quá nhiều hôm nay. Thử lại vào ngày mai.';

  @override
  String get safetyFailed => 'Không thực hiện được. Kiểm tra mạng rồi thử lại.';

  @override
  String get legalDraftNote =>
      'Bản nháp: cần được xem xét pháp lý trước khi phát hành.';

  @override
  String get settingsNotifications => 'THÔNG BÁO';

  @override
  String get notifyNewPost => 'Có ảnh mới từ bạn bè';

  @override
  String get notifyMessages => 'Tin nhắn';

  @override
  String get notifyReactions => 'Reaction vào ảnh của tôi';

  @override
  String get notifyFriendRequests => 'Lời mời kết bạn';
}
