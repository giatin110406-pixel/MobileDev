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

  @override
  String get tabShoot => 'CHỤP';

  @override
  String get tabFriends => 'BẠN BÈ';

  @override
  String get tabInbox => 'HỘP THƯ';

  @override
  String get tabPrints => 'TỦ ẢNH';

  @override
  String get tabMe => 'TÔI';

  @override
  String get laptopSettingsTooltip => 'Cài đặt laptop ở nhà';

  @override
  String get cameraAccessHint => 'BẬT QUYỀN CAMERA ĐỂ BẮT ĐẦU CHỤP';

  @override
  String get originalLabel => 'ẢNH GỐC';

  @override
  String get imageNotFound => 'KHÔNG TÌM THẤY ẢNH';

  @override
  String get groupsKicker => 'NHÓM CỦA BẠN';

  @override
  String get groupsTitle => 'Nhóm';

  @override
  String groupsCount(int count) {
    return '$count NHÓM';
  }

  @override
  String get groupCreate => 'TẠO NHÓM';

  @override
  String get questDataUnreadable => 'KHÔNG ĐỌC ĐƯỢC DỮ LIỆU NHIỆM VỤ';

  @override
  String get archiveUnreadable => 'KHÔNG ĐỌC ĐƯỢC TỦ ẢNH';

  @override
  String get friendsLoadFailed => 'KHÔNG TẢI ĐƯỢC DANH SÁCH BẠN BÈ';

  @override
  String friendAddedLocally(String name) {
    return 'ĐÃ THÊM $name TRÊN MÁY';
  }

  @override
  String get shareNeedsPrint => 'HÃY CHỤP MỘT TẤM TRƯỚC KHI CHIA SẺ';

  @override
  String get replyWord => 'TIN NHẮN';

  @override
  String sentNotice(String what) {
    return 'ĐÃ GỬI $what';
  }

  @override
  String sentNoticeTo(String what, String name) {
    return 'ĐÃ GỬI $what CHO $name';
  }

  @override
  String removeLocalFriendBody(String name) {
    return 'Xóa $name và cuộc trò chuyện này khỏi máy?';
  }

  @override
  String get photoNotSaved => 'ẢNH CHƯA LƯU ĐƯỢC. THỬ LẠI NHÉ.';

  @override
  String get photoOpenFailed => 'KHÔNG MỞ ĐƯỢC ẢNH NÀY. THỬ ẢNH KHÁC.';

  @override
  String fallbackUsed(String note) {
    return 'ĐÃ DÙNG PHƯƠNG ÁN DỰ PHÒNG: $note';
  }

  @override
  String get styleFailedOriginalSafe =>
      'TẠO TRANH THẤT BẠI. ẢNH GỐC VẪN AN TOÀN.';

  @override
  String get flashUnavailable => 'MÁY KHÔNG CÓ ĐÈN FLASH';

  @override
  String get flashTooltip => 'Đổi chế độ flash';

  @override
  String get openFeedLabel => 'Mở bảng tin';

  @override
  String get feedLabel => 'BẢNG TIN';

  @override
  String zoomSemantics(String level) {
    return 'Thu phóng $level';
  }

  @override
  String get uploadPhotoTooltip => 'Tải ảnh lên từ máy';

  @override
  String get takePhotoLabel => 'Chụp ảnh';

  @override
  String get switchCameraTooltip => 'Đổi camera';

  @override
  String get openArchiveLabel => 'Mở tủ ảnh';

  @override
  String get retryShort => 'THỬ LẠI';

  @override
  String get newShot => 'CHỤP MỚI';

  @override
  String get statusInking => 'ĐANG VẼ';

  @override
  String get statusReady => 'XONG';

  @override
  String get statusOriginalSafe => 'ĐÃ GIỮ ẢNH GỐC';

  @override
  String get cameraAccessOff => 'CAMERA ĐANG BỊ TẮT QUYỀN';

  @override
  String get cameraUnavailable => 'KHÔNG DÙNG ĐƯỢC CAMERA';

  @override
  String get findingCamera => 'ĐANG TÌM CAMERA';

  @override
  String get cameraReady => 'CAMERA SẴN SÀNG';

  @override
  String originalPlusStyle(String style) {
    return 'ẢNH GỐC + $style';
  }

  @override
  String get legacyEdit => 'BẢN CHỈNH CŨ';

  @override
  String get editLabel => 'ĐÃ CHỈNH';

  @override
  String get styleSliderSemantics => 'Phong cách. Vuốt để đổi';

  @override
  String get retryTooltip => 'Thử lại';

  @override
  String get backToCameraTooltip => 'Về camera';

  @override
  String get noPostsYet => 'CHƯA CÓ BÀI NÀO';

  @override
  String replyHint(String name) {
    return 'Trả lời $name...';
  }

  @override
  String get openPrint => 'XEM ẢNH';

  @override
  String get reactWith => 'THẢ CẢM XÚC';

  @override
  String get sendReplyTooltip => 'Gửi trả lời';

  @override
  String reactSemantics(String emoji) {
    return 'Thả $emoji';
  }

  @override
  String get moreEmojiTooltip => 'Thêm emoji';

  @override
  String get localCollection => 'BỘ SƯU TẬP TRÊN MÁY';

  @override
  String get printArchive => 'Tủ ảnh';

  @override
  String itemsCount(int count) {
    return '$count ẢNH';
  }

  @override
  String get archiveEmptyBody =>
      'ẢNH CỦA BẠN CHỈ NẰM TRONG TỦ ẢNH TRÊN MÁY NÀY.';

  @override
  String get openCamera => 'MỞ CAMERA';

  @override
  String get printReady => 'TRANH ĐÃ XONG';

  @override
  String get originalSaved => 'ĐÃ LƯU ẢNH GỐC';

  @override
  String get serverTesting => 'ĐANG KIỂM TRA…';

  @override
  String serverConnected(String gpu) {
    return 'ĐÃ KẾT NỐI · $gpu';
  }

  @override
  String get serverModelsLoading => 'ĐÃ KẾT NỐI · MÔ HÌNH ĐANG TẢI';

  @override
  String get serverInvalidAddress => 'ĐỊA CHỈ KHÔNG HỢP LỆ';

  @override
  String get homeLaptop => 'LAPTOP Ở NHÀ';

  @override
  String get vanGoghOnLaptop => 'TRANH VAN GOGH CHẠY TRÊN LAPTOP CỦA BẠN';

  @override
  String get serverAddressLabel => 'ĐỊA CHỈ (IP:CỔNG)';

  @override
  String get serverTokenLabel => 'MÃ TOKEN';

  @override
  String get serverTokenHint => 'in ra khi máy chủ khởi động';

  @override
  String get serverTestButton => 'KIỂM TRA';

  @override
  String get shopLabel => 'CỬA HÀNG';

  @override
  String get sunbitShop => 'CỬA HÀNG SUNBIT';

  @override
  String get sampleLabel => 'MẪU';

  @override
  String get menuTooltip => 'Menu';

  @override
  String get yourPeople => 'BẠN BÈ CỦA BẠN';

  @override
  String get friendsTitle => 'Bạn bè';

  @override
  String peopleCount(int count) {
    return '$count NGƯỜI';
  }

  @override
  String get localMode => 'CHẾ ĐỘ TRÊN MÁY';

  @override
  String get noFriendsOnDevice => 'CHƯA CÓ BẠN\nTRÊN MÁY NÀY';

  @override
  String get noFriendsOnDeviceBody =>
      'THÊM MỘT HỒ SƠ TRÊN MÁY ĐỂ BẮT ĐẦU CUỘC TRÒ CHUYỆN MẪU.';

  @override
  String get privateThreads => 'TIN NHẮN RIÊNG';

  @override
  String get inboxTitle => 'Hộp thư';

  @override
  String get deviceOnly => 'CHỈ TRÊN MÁY';

  @override
  String get addFriendToStart => 'THÊM BẠN ĐỂ BẮT ĐẦU TRÒ CHUYỆN';

  @override
  String get backToInboxTooltip => 'Về hộp thư';

  @override
  String get openProfileLabel => 'Mở hồ sơ';

  @override
  String get removeFriendTooltip => 'Xóa bạn';

  @override
  String get localThread => 'TRÒ CHUYỆN TRÊN MÁY';

  @override
  String get sendLatestPrintTooltip => 'Gửi ảnh mới nhất';

  @override
  String get writeMessageHint => 'Viết tin nhắn...';

  @override
  String get sendMessageTooltip => 'Gửi tin nhắn';

  @override
  String whosePost(String name) {
    return 'BÀI CỦA $name';
  }

  @override
  String get yourPost => 'BÀI CỦA BẠN';

  @override
  String get previewStart => 'BẮT ĐẦU TRÒ CHUYỆN';

  @override
  String previewReacted(String who, String emoji) {
    return '$who ĐÃ THẢ $emoji';
  }

  @override
  String get previewYou => 'BẠN';

  @override
  String previewYouReplied(String text) {
    return 'BẠN ĐÃ TRẢ LỜI: $text';
  }

  @override
  String previewReplied(String text) {
    return 'ĐÃ TRẢ LỜI: $text';
  }

  @override
  String get previewSentPrint => 'ĐÃ GỬI MỘT ẢNH';

  @override
  String previewYouText(String text) {
    return 'BẠN: $text';
  }

  @override
  String get localLabel => 'TRÊN MÁY';

  @override
  String get addAFriend => 'THÊM BẠN';

  @override
  String get localProfileOnly => 'CHỈ LƯU TRÊN MÁY';

  @override
  String get handleLabel => 'TÊN NGƯỜI DÙNG';

  @override
  String get friendNameHint => 'Tên của bạn bè';

  @override
  String get addToFriends => 'THÊM VÀO BẠN BÈ';

  @override
  String get settingsFeedback => 'CẢM GIÁC';

  @override
  String get settingsHaptics => 'Rung khi chạm';
}
