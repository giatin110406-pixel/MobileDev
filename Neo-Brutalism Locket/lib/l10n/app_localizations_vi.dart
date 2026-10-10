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

  @override
  String get holdToCompare => 'GIỮ ĐỂ SO SÁNH';

  @override
  String get styleWorking8bit => 'ĐANG MÀI PIXEL…';

  @override
  String get styleWorkingVanGogh => 'ĐANG QUÉT MÀU VAN GOGH…';

  @override
  String get styleWorking => 'ĐANG XỬ LÝ…';

  @override
  String get backTooltip => 'Quay lại';

  @override
  String get contestTitle => 'Cuộc thi tuần';

  @override
  String get contestLoadFailed => 'Không tải được cuộc thi.';

  @override
  String get contestNone => 'Chưa có cuộc thi nào.';

  @override
  String get contestStale => 'Không cập nhật được. Đang hiện dữ liệu cũ.';

  @override
  String contestEnterGallery(int count) {
    return 'VÀO GALLERY ($count BÀI)';
  }

  @override
  String get contestSeeResults => 'XEM KẾT QUẢ';

  @override
  String contestPrevResults(String title) {
    return 'KẾT QUẢ TUẦN TRƯỚC: $title';
  }

  @override
  String contestEntriesCount(int count, int max) {
    return '$count/$max bài';
  }

  @override
  String contestCountdownUntil(String event) {
    return 'cho đến khi $event';
  }

  @override
  String get contestUntilOpen => 'bắt đầu nhận bài';

  @override
  String get contestUntilJudging => 'hết giờ nhận bài và bắt đầu chấm';

  @override
  String get contestUntilClosed => 'chốt kết quả';

  @override
  String get contestLineOpens => 'Nhận bài từ';

  @override
  String get contestLineJudging => 'Chấm điểm từ';

  @override
  String contestLineJudgingNote(String moment) {
    return '$moment (hoặc khi đủ 100 bài)';
  }

  @override
  String get contestLineEnds => 'Chốt kết quả';

  @override
  String contestLineEndsNote(String moment) {
    return '$moment (23:59 CN giờ Việt Nam)';
  }

  @override
  String contestMyEntry(String group, int seq) {
    return 'Nhóm \"$group\" đã dự thi, bài số $seq.';
  }

  @override
  String get contestNothingToRate => 'Chưa có bài của nhóm khác để chấm.';

  @override
  String contestRatedProgress(int done, int needed) {
    return 'Bạn đã chấm $done/$needed bài';
  }

  @override
  String get contestVoteRule =>
      'Phiếu của bạn chỉ được tính khi chấm đủ số bài này, và tài khoản đã đủ 7 ngày tuổi.';

  @override
  String get contestOnlyOwner =>
      'Chỉ trưởng nhóm mới nộp bài được. Hãy nhờ trưởng nhóm của bạn.';

  @override
  String get contestGroupSubmitted => 'Đã nộp bài tuần này';

  @override
  String get contestOwnerHint => 'Bạn là trưởng nhóm: nộp canvas để dự thi';

  @override
  String contestOpensAt(String moment) {
    return 'Nhận bài vào $moment';
  }

  @override
  String get contestSubmitButton => 'NỘP BÀI';

  @override
  String get contestRulesTitle => 'LUẬT CHƠI';

  @override
  String get contestRules =>
      '• Trưởng nhóm nộp canvas của nhóm, mỗi nhóm một bài.\n• Chỉ 100 bài nộp nhanh nhất được vào Gallery.\n• Thành viên các nhóm có bài dự thi chấm 1–5 sao và bình luận bài của nhóm khác.\n• Điểm xếp hạng là trung bình có hiệu chỉnh (Bayes), nên một vài phiếu 5 sao không đủ để vượt lên.\n• Mọi thời điểm tính theo giờ Việt Nam (UTC+7).';

  @override
  String contestSubmittedSnack(int seq) {
    return 'Đã nộp! Bài của bạn là số $seq.';
  }

  @override
  String get cfNotFound => 'Không tìm thấy bài dự thi.';

  @override
  String get cfNotOwner => 'Chỉ trưởng nhóm mới nộp bài được.';

  @override
  String get cfNotOpen => 'Chưa đến giờ nộp bài, hoặc đã hết giờ nộp.';

  @override
  String get cfNotJudging => 'Hiện chưa phải lúc chấm điểm.';

  @override
  String get cfAlreadySubmitted => 'Nhóm này đã nộp bài tuần này rồi.';

  @override
  String get cfContestFull =>
      'Gallery tuần này đã đủ 100 bài. Hẹn bạn tuần sau!';

  @override
  String get cfCanvasTooEmpty =>
      'Canvas còn quá trống. Hãy vẽ thêm rồi nộp nhé.';

  @override
  String get cfGroupTooSmall => 'Nhóm cần ít nhất 2 người để dự thi.';

  @override
  String get cfNoCanvas => 'Nhóm chưa có canvas.';

  @override
  String get cfNotParticipant =>
      'Chỉ thành viên các nhóm có bài dự thi mới chấm và bình luận được.';

  @override
  String get cfOwnEntry => 'Bạn không chấm được bài của nhóm mình.';

  @override
  String get cfBadScore => 'Điểm phải từ 1 đến 5 sao.';

  @override
  String get cfEmpty => 'Hãy nhập nội dung.';

  @override
  String get cfTooLong => 'Bình luận tối đa 200 ký tự.';

  @override
  String get cfTooFast => 'Chậm lại một chút rồi bình luận tiếp nhé.';

  @override
  String get cfTooMany => 'Bạn đã bình luận đủ số lần cho tuần này.';

  @override
  String get cfBlockedWord => 'Bình luận có từ không phù hợp.';

  @override
  String get cfTooManyReports => 'Hôm nay bạn đã báo cáo quá nhiều.';

  @override
  String get cfNetwork => 'Không kết nối được. Thử lại nhé.';

  @override
  String get cfUnknown => 'Có lỗi xảy ra. Thử lại nhé.';

  @override
  String get phaseUpcoming => 'SẮP DIỄN RA';

  @override
  String get phaseOpen => 'ĐANG NHẬN BÀI';

  @override
  String get phaseJudging => 'ĐANG CHẤM ĐIỂM';

  @override
  String get phaseClosed => 'ĐANG TỔNG KẾT';

  @override
  String get phaseFinalized => 'ĐÃ CÓ KẾT QUẢ';

  @override
  String countdownDays(int days, String clock) {
    return '$days ngày $clock';
  }

  @override
  String get milestoneOpen => 'đến giờ nhận bài';

  @override
  String get milestoneJudging => 'hết giờ nhận bài, bắt đầu chấm';

  @override
  String get milestoneClosed => 'chốt kết quả';

  @override
  String contestTimeLeft(String time, String event) {
    return 'Còn $time $event';
  }

  @override
  String contestBannerTitle(String phase) {
    return 'CUỘC THI TUẦN · $phase';
  }

  @override
  String contestBannerSemantics(String week, String title, String phase) {
    return 'Cuộc thi tuần $week: $title. $phase';
  }

  @override
  String get weekdayMon => 'Th 2';

  @override
  String get weekdayTue => 'Th 3';

  @override
  String get weekdayWed => 'Th 4';

  @override
  String get weekdayThu => 'Th 5';

  @override
  String get weekdayFri => 'Th 6';

  @override
  String get weekdaySat => 'Th 7';

  @override
  String get weekdaySun => 'CN';

  @override
  String entryHeader(int seq, String moment) {
    return 'Bài số $seq · nộp $moment';
  }

  @override
  String get reportEntryTooltip => 'Báo cáo bài này';

  @override
  String entryArtSemantics(String group, int seq) {
    return 'Tranh của nhóm $group, bài số $seq';
  }

  @override
  String get commentsTitle => 'BÌNH LUẬN';

  @override
  String commentsTitleCount(int count) {
    return 'BÌNH LUẬN ($count)';
  }

  @override
  String get noComments => 'Chưa có bình luận.';

  @override
  String get rank1 => 'HẠNG NHẤT';

  @override
  String get rank2 => 'HẠNG NHÌ';

  @override
  String get rank3 => 'HẠNG BA';

  @override
  String get rankTop3 => 'TOP 3';

  @override
  String rankScoreLine(String rank, String score, int votes) {
    return '$rank  ·  $score điểm ($votes phiếu)';
  }

  @override
  String get ratingLoading => 'Đang tải…';

  @override
  String get ratingOwnGroup =>
      'Đây là bài của nhóm bạn. Bạn không tự chấm được.';

  @override
  String get ratingNotParticipant =>
      'Chỉ thành viên các nhóm có bài dự thi mới chấm điểm được.';

  @override
  String get ratingContestOver => 'Cuộc thi đã kết thúc.';

  @override
  String get ratingNotYet => 'Chưa đến giờ chấm điểm.';

  @override
  String get ratingTapStar =>
      'Chạm vào ngôi sao để chấm. Bạn sửa được đến hết cuộc thi.';

  @override
  String ratingYouGave(int stars) {
    return 'Bạn chấm $stars sao. Chạm để đổi.';
  }

  @override
  String rateStars(int stars) {
    return 'Chấm $stars sao';
  }

  @override
  String get commentYou => 'Bạn';

  @override
  String get reportCommentTooltip => 'Báo cáo bình luận';

  @override
  String get writeCommentHint => 'Viết bình luận…';

  @override
  String get sendTooltip => 'Gửi';

  @override
  String get resultsTitle => 'Kết quả';

  @override
  String resultsTitleWeek(String title) {
    return 'Kết quả: $title';
  }

  @override
  String get resultsLater => 'Kết quả sẽ có lúc 23:59 Chủ nhật (giờ Việt Nam).';

  @override
  String get resultsNoEntries => 'Tuần này chưa có bài dự thi nào.';

  @override
  String get resultsNoRanked =>
      'Chưa có bài nào đủ số phiếu hợp lệ để xếp hạng (cần ít nhất 3 phiếu).';

  @override
  String resultsEntryCount(int count, String week) {
    return '$count bài dự thi · $week';
  }

  @override
  String resultsScoreVotes(String score, int votes) {
    return '$score · $votes phiếu';
  }

  @override
  String submitSheetTitle(String group) {
    return 'NỘP BÀI: $group';
  }

  @override
  String get canvasWillBeSubmitted => 'Canvas sẽ được nộp';

  @override
  String get noPreview => 'Không xem trước được.';

  @override
  String submitSpotsLeft(int count, int max) {
    return 'Đã có $count/$max bài. Chỉ $max bài nộp nhanh nhất vào Gallery.';
  }

  @override
  String submitGalleryFull(int max) {
    return 'Gallery đã đủ $max bài.';
  }

  @override
  String get submitSnapshotNote =>
      'Bản chụp canvas được lấy ngay lúc nộp và không đổi được nữa. Mỗi nhóm nộp một bài mỗi tuần.';

  @override
  String get submitting => 'ĐANG NỘP…';

  @override
  String get galleryViewCorridor => 'Xem dạng hành lang';

  @override
  String get galleryViewGrid => 'Xem dạng lưới';

  @override
  String get galleryEmpty =>
      'Hành lang còn trống. Bài dự thi sẽ xuất hiện ở đây khi các nhóm nộp bài.';

  @override
  String get galleryLoadMoreFailed =>
      'Không tải thêm được. Kéo lên để thử lại.';

  @override
  String galleryEntrySemantics(int seq, String group) {
    return 'Bài số $seq, nhóm $group';
  }

  @override
  String corridorSemantics(int count) {
    return 'Hành lang triển lãm với $count bức tranh. Vuốt lên để đi tới, chạm một bức để xem. Dùng nút Xem dạng lưới để duyệt bằng danh sách.';
  }

  @override
  String get walkForward => 'Đi tới';

  @override
  String get walkBack => 'Đi lui';

  @override
  String get groupsInvitesTitle => 'LỜI MỜI VÀO NHÓM';

  @override
  String get groupsStale => 'Không cập nhật được. Đang hiện dữ liệu cũ.';

  @override
  String get groupsLoadFailed => 'Không tải được danh sách nhóm.';

  @override
  String get groupsEmptyTitle => 'Chưa có nhóm nào';

  @override
  String get groupsEmptyBody =>
      'Tạo nhóm với bạn bè để cùng nhắn tin và cùng vẽ một canvas pixel. Mỗi nhiệm vụ hằng ngày cho bạn 10 mực, mỗi ô vẽ tốn 1 mực.';

  @override
  String get groupPreviewNone => 'Chưa có tin nhắn';

  @override
  String get groupPreviewActivity => 'Hoạt động mới trong nhóm';

  @override
  String memberCount(int count) {
    return '$count thành viên';
  }

  @override
  String groupTileSemantics(String name, String members) {
    return 'Nhóm $name, $members';
  }

  @override
  String groupTileSemanticsUnread(String name, String members, int unread) {
    return 'Nhóm $name, $members, $unread tin chưa đọc';
  }

  @override
  String groupMembersLine(int count, int max) {
    return '$count/$max thành viên';
  }

  @override
  String groupMembersLineOwner(int count, int max) {
    return '$count/$max thành viên · trưởng nhóm';
  }

  @override
  String groupJoinedSnack(String name) {
    return 'Đã vào nhóm $name.';
  }

  @override
  String groupInviteFrom(String person) {
    return '$person mời bạn vào nhóm';
  }

  @override
  String get groupJoin => 'THAM GIA';

  @override
  String get groupCreateTitle => 'TẠO NHÓM MỚI';

  @override
  String get groupNameLabel => 'Tên nhóm';

  @override
  String get groupRulesOptional => 'Quy tắc (không bắt buộc)';

  @override
  String get groupMaxMembers => 'Số thành viên tối đa';

  @override
  String get decrease => 'Giảm';

  @override
  String get increase => 'Tăng';

  @override
  String get groupCreating => 'ĐANG TẠO…';

  @override
  String get segmentGroups => 'NHÓM';

  @override
  String get personFriendsNote =>
      'Hai bạn là bạn bè: ảnh mới của nhau hiện trong feed.';

  @override
  String get personNotFriendsNote =>
      'Ở chung nhóm chưa phải là bạn bè. Chỉ khi kết bạn, hai người mới xem được ảnh của nhau.';

  @override
  String get personAlreadyFriends => 'ĐÃ LÀ BẠN BÈ';

  @override
  String get personRequestSent => 'ĐÃ GỬI LỜI MỜI';

  @override
  String get personBefriend => 'KẾT BẠN';

  @override
  String get reportFailed => 'Không gửi được báo cáo. Thử lại nhé.';

  @override
  String get blockFailed => 'Không chặn được. Thử lại nhé.';

  @override
  String sysJoined(String name) {
    return '$name đã tham gia nhóm';
  }

  @override
  String sysLeft(String name) {
    return '$name đã rời nhóm';
  }

  @override
  String sysKicked(String name) {
    return '$name đã bị mời ra khỏi nhóm';
  }

  @override
  String sysOwnerChanged(String name) {
    return '$name là trưởng nhóm mới';
  }

  @override
  String get sysEntrySubmitted => 'Nhóm đã nộp bài dự thi tuần này';

  @override
  String get gfNotFound => 'Không tìm thấy nhóm hoặc người này.';

  @override
  String get gfNotOwner => 'Chỉ trưởng nhóm mới làm được việc này.';

  @override
  String get gfNotMember => 'Bạn không còn ở trong nhóm này.';

  @override
  String get gfSelf => 'Không thể làm việc này với chính mình.';

  @override
  String get gfEmpty => 'Hãy nhập nội dung.';

  @override
  String get gfTooLong => 'Nội dung quá dài.';

  @override
  String get gfBlockedWord =>
      'Có từ không phù hợp. Hãy dùng ngôn từ lịch sự để mọi người cùng vui nhé.';

  @override
  String get gfBadName => 'Tên nhóm cần từ 1 đến 40 ký tự.';

  @override
  String get gfBadSize =>
      'Số thành viên tối đa phải từ 2 đến 12 và không nhỏ hơn số người hiện có.';

  @override
  String get gfGroupLimit =>
      'Bạn chỉ được ở tối đa 5 nhóm và làm trưởng tối đa 3 nhóm.';

  @override
  String get gfMemberLimit => 'Nhóm đã đủ người (kể cả lời mời đang chờ).';

  @override
  String get gfTheirGroupLimit => 'Bạn đang ở quá nhiều nhóm (tối đa 5).';

  @override
  String get gfAlreadyMember => 'Người này đã ở trong nhóm.';

  @override
  String get gfAlreadyInvited => 'Đã mời người này rồi.';

  @override
  String get gfExpired => 'Lời mời đã hết hạn.';

  @override
  String get gfOwnerMustTransfer =>
      'Hãy chuyển quyền trưởng nhóm cho người khác trước khi rời.';

  @override
  String get gfNetwork => 'Không kết nối được. Thử lại nhé.';

  @override
  String get gfUnknown => 'Có lỗi xảy ra. Thử lại nhé.';

  @override
  String get kfInsufficientInk =>
      'Hết mực. Hoàn thành nhiệm vụ hằng ngày để nhận thêm 10 mực.';

  @override
  String get kfRateLimited => 'Vẽ chậm lại một chút (tối đa 30 ô/phút).';

  @override
  String get kfCanvasLocked => 'Canvas này đã được lưu trữ.';

  @override
  String get kfNotFound => 'Không tìm thấy canvas.';

  @override
  String get kfNotOwner => 'Chỉ trưởng nhóm mới làm được việc này.';

  @override
  String get kfBadPixel => 'Ô vẽ không hợp lệ.';

  @override
  String get kfBadSize => 'Kích thước hoặc bảng màu không hợp lệ.';

  @override
  String get kfNetwork => 'Mất kết nối. Canvas chuyển sang chế độ chỉ xem.';

  @override
  String get groupSettingsTooltip => 'Cài đặt nhóm';

  @override
  String get youLabel => 'Bạn';

  @override
  String get someoneLabel => 'Một người';

  @override
  String get chatLoadFailed => 'Không tải được tin nhắn.';

  @override
  String get chatSayHi => 'Hãy chào cả nhóm 👋';

  @override
  String get chatHint => 'Nhắn cho cả nhóm…';

  @override
  String get groupSettingsTitle => 'Cài đặt nhóm';

  @override
  String get ownerBadge => 'TRƯỞNG NHÓM';

  @override
  String get sectionInfo => 'THÔNG TIN';

  @override
  String sectionMembers(int count, int max) {
    return 'THÀNH VIÊN ($count/$max)';
  }

  @override
  String get inviteToGroup => 'MỜI BẠN VÀO NHÓM';

  @override
  String get inviteNote =>
      'Chỉ mời được bạn bè của bạn. Lời mời hết hạn sau 7 ngày.';

  @override
  String get sectionPendingInvites => 'LỜI MỜI ĐANG CHỜ';

  @override
  String get newCanvasButton => 'TẠO CANVAS MỚI';

  @override
  String get leaveGroup => 'RỜI NHÓM';

  @override
  String get dissolveGroup => 'GIẢI TÁN NHÓM';

  @override
  String get rulesNone => 'Nhóm chưa đặt quy tắc.';

  @override
  String get rulesLabel => 'Quy tắc';

  @override
  String memberYou(String name) {
    return '$name (bạn)';
  }

  @override
  String get ownerRole => 'Trưởng nhóm';

  @override
  String get optionsTooltip => 'Tuỳ chọn';

  @override
  String get menuTransfer => 'Chuyển quyền trưởng nhóm';

  @override
  String get menuRollback => 'Hoàn tác nét vẽ (24 giờ)';

  @override
  String get menuKick => 'Mời ra khỏi nhóm';

  @override
  String get revokeInvite => 'THU HỒI';

  @override
  String get inviteFriendsTitle => 'MỜI BẠN BÈ';

  @override
  String get noOneToInvite =>
      'Không còn người bạn nào để mời. Chỉ mời được bạn bè của bạn.';

  @override
  String get newCanvasTitle => 'Canvas mới';

  @override
  String get sizeLabel => 'Kích thước';

  @override
  String get paletteLabel => 'Bảng màu';

  @override
  String get savedSnack => 'Đã lưu.';

  @override
  String kickTitle(String name) {
    return 'Mời $name ra khỏi nhóm?';
  }

  @override
  String get kickBody =>
      'Họ sẽ không đọc được tin nhắn của nhóm nữa. Những ô họ đã vẽ vẫn giữ nguyên.';

  @override
  String get kickAction => 'Mời ra';

  @override
  String get transferTitle => 'Chuyển quyền trưởng nhóm?';

  @override
  String transferBody(String name) {
    return '$name sẽ là trưởng nhóm mới. Bạn trở thành thành viên thường.';
  }

  @override
  String get transferAction => 'Chuyển quyền';

  @override
  String transferDone(String name) {
    return '$name là trưởng nhóm mới.';
  }

  @override
  String rollbackTitle(String name) {
    return 'Hoàn tác nét vẽ của $name?';
  }

  @override
  String get rollbackBody =>
      'Những ô họ vẽ trong 24 giờ qua và chưa bị ai vẽ đè sẽ quay về màu trước đó. Mực của họ không được hoàn lại.';

  @override
  String get rollbackAction => 'Hoàn tác';

  @override
  String rollbackDone(int count) {
    return 'Đã hoàn tác $count ô.';
  }

  @override
  String leaveTitle(String group) {
    return 'Rời nhóm $group?';
  }

  @override
  String get leaveBody =>
      'Bạn sẽ không đọc được tin nhắn và canvas của nhóm nữa.';

  @override
  String get leaveAction => 'Rời nhóm';

  @override
  String dissolveTitle(String group) {
    return 'Giải tán nhóm $group?';
  }

  @override
  String get dissolveBody =>
      'Cả nhóm sẽ mất quyền xem tin nhắn và canvas. Không thể hoàn tác.';

  @override
  String get dissolveAction => 'Giải tán';

  @override
  String invitedSnack(String name) {
    return 'Đã mời $name.';
  }

  @override
  String get newCanvasConfirmTitle => 'Bắt đầu canvas mới?';

  @override
  String get newCanvasConfirmBody =>
      'Canvas hiện tại được lưu lại và không vẽ thêm được nữa. Canvas mới bắt đầu trống.';

  @override
  String get newCanvasConfirmAction => 'Tạo canvas';

  @override
  String get newCanvasDone => 'Đã tạo canvas mới.';

  @override
  String get avatarTitle => 'ẢNH ĐẠI DIỆN';

  @override
  String get avatarTakePhoto => 'CHỤP ẢNH';

  @override
  String get avatarFromLibrary => 'CHỌN TỪ THƯ VIỆN';

  @override
  String get avatarChange => 'ĐỔI ẢNH';

  @override
  String get avatarChangeFailed => 'Không đổi được ảnh đại diện.';

  @override
  String get questsDoneTitle => 'NHIỆM VỤ ĐÃ HOÀN THÀNH';

  @override
  String get questsNoneYet =>
      'Chưa có nhiệm vụ nào. Mở tab CHỤP để làm nhiệm vụ hôm nay và nhận 25 Sunbit!';

  @override
  String get postsTitle => 'BÀI ĐĂNG';

  @override
  String inkAmountSemantics(int amount) {
    return '$amount mực';
  }

  @override
  String inkAmountLabel(int amount) {
    return '$amount MỰC';
  }

  @override
  String streakSemantics(int streak) {
    return 'Streak $streak ngày';
  }

  @override
  String get musicOn => 'Bật nhạc';

  @override
  String get musicOff => 'Tắt nhạc';

  @override
  String get photoMissingRetake => 'KHÔNG TÌM THẤY ẢNH · HÃY CHỤP LẠI';

  @override
  String get newDayQuest => 'ĐÃ SANG NGÀY MỚI · CÓ NHIỆM VỤ MỚI!';

  @override
  String get outOfTriesTitle => 'HẾT LƯỢT HÔM NAY';

  @override
  String get outOfTriesBody =>
      'Không đúng. Bạn đã dùng hết 3 lượt thử hôm nay. Nhiệm vụ mới sẽ đến lúc 00:00.';

  @override
  String wrongTriesLeft(int left, String debug) {
    return 'KHÔNG ĐÚNG · CÒN $left LƯỢT THỬ$debug';
  }

  @override
  String get questModeBanner => 'CHẾ ĐỘ NHIỆM VỤ · CHỈ CHỤP TRỰC TIẾP';

  @override
  String shootSubject(String subject) {
    return 'Chụp $subject';
  }

  @override
  String get exitQuestMode => 'Thoát chế độ nhiệm vụ';

  @override
  String get checkingPhoto => 'ĐANG KIỂM TRA...';

  @override
  String questSemantics(String subject) {
    return 'Nhiệm vụ hôm nay: chụp $subject';
  }

  @override
  String questTodayLabel(String style) {
    return 'NHIỆM VỤ HÔM NAY · $style';
  }

  @override
  String get qsDone => 'XONG ✓';

  @override
  String get qsPostNow => 'ĐĂNG NGAY';

  @override
  String get qsOutOfTries => 'HẾT LƯỢT';

  @override
  String triesLeft(int left) {
    return 'Còn $left lượt thử';
  }

  @override
  String get shootToday => 'HÔM NAY, HÃY CHỤP';

  @override
  String rewardWithBonus(int reward, int bonus, int streak) {
    return '+$reward Sunbit, +$bonus thưởng streak $streak ngày!';
  }

  @override
  String rewardPlain(int reward, int bonus, int every) {
    return '+$reward Sunbit · thêm +$bonus mỗi $every ngày streak';
  }

  @override
  String get questRulesNote =>
      'Chỉ chụp trực tiếp bằng camera · 3 lượt thử mỗi ngày · Ngày mới bắt đầu lúc 00:00 giờ Việt Nam';

  @override
  String get startShooting => 'BẮT ĐẦU CHỤP';

  @override
  String get postQuestPhoto => 'ĐĂNG ẢNH NHIỆM VỤ';

  @override
  String get questCompletedBtn => 'ĐÃ HOÀN THÀNH ✓';

  @override
  String get questNextAt => 'Nhiệm vụ mới sẽ đến lúc 00:00. Hẹn gặp lại!';

  @override
  String get questAllTriesUsed =>
      'Bạn đã dùng hết 3 lượt thử. Nhiệm vụ mới sẽ đến lúc 00:00.';

  @override
  String get postFailedTitle => 'KHÔNG ĐĂNG ĐƯỢC';

  @override
  String get closeAction => 'ĐÓNG';

  @override
  String get postSuccessTitle => 'ĐĂNG THÀNH CÔNG!';

  @override
  String get niceAction => 'TUYỆT!';

  @override
  String get rewardQuest => 'Hoàn thành nhiệm vụ';

  @override
  String rewardStreak(int days) {
    return 'Thưởng streak $days ngày';
  }

  @override
  String get rewardInk => 'Mực để vẽ canvas nhóm';

  @override
  String get streakNew => 'Bắt đầu streak mới. Quay lại vào ngày mai nhé!';

  @override
  String streakDaysRow(int days) {
    return 'Bạn đã hoàn thành $days ngày liên tiếp!';
  }

  @override
  String get laterTooltip => 'Để sau (ảnh vẫn được giữ đến hết hôm nay)';

  @override
  String photoNailedTitle(String emoji) {
    return 'CHUẨN RỒI! $emoji';
  }

  @override
  String get photoAcceptedTitle => 'ẢNH ĐẠT YÊU CẦU';

  @override
  String get transformFailed => 'Chưa biến đổi được ảnh. Ảnh gốc vẫn an toàn.';

  @override
  String get captionLabel => 'CHÚ THÍCH';

  @override
  String get captionHint => 'Viết một dòng ngắn...';

  @override
  String get postingBusy => 'ĐANG ĐĂNG...';

  @override
  String get postToProfile => 'ĐĂNG LÊN TRANG CÁ NHÂN';

  @override
  String get questMusicOrchestral =>
      'Post nhiệm vụ có nhạc giao hưởng riêng khi bạn bè lướt đến.';

  @override
  String get questMusicChiptune =>
      'Post nhiệm vụ có nhạc chiptune riêng khi bạn bè lướt đến.';

  @override
  String get shopDecorate => 'TRANG TRÍ TRANG CÁ NHÂN';

  @override
  String get shopInUse => 'ĐANG DÙNG';

  @override
  String get shopOwned => 'ĐÃ CÓ';

  @override
  String shopBuy(int price) {
    return 'MUA · $price SUNBIT';
  }

  @override
  String shopShort(int missing) {
    return 'CÒN THIẾU $missing SUNBIT';
  }

  @override
  String get shopEquip => 'TRANG BỊ';

  @override
  String get shopUnequip => 'THÁO RA';

  @override
  String get shopHintBuy => 'Mua một lần, dùng mãi mãi.';

  @override
  String get shopHintLocked =>
      'Hoàn thành nhiệm vụ hằng ngày để kiếm thêm Sunbit.';

  @override
  String get shopHintEquip => 'Bạn đã sở hữu món này. Đổi món miễn phí.';

  @override
  String get shopHintUnequip => 'Bạn đang dùng món này.';

  @override
  String get kindFrame => 'KHUNG AVATAR';

  @override
  String get kindBanner => 'BANNER';

  @override
  String get rarityCommon => 'THƯỜNG';

  @override
  String get rarityRare => 'HIẾM';

  @override
  String get rarityLegendary => 'HUYỀN THOẠI';

  @override
  String get itemFrameSunflower => 'Khung hoa hướng dương';

  @override
  String get itemFrameBrush => 'Khung nét cọ xoáy';

  @override
  String get itemFramePixel => 'Khung viền pixel';

  @override
  String get itemFrameHearts => 'Khung trái tim 8-bit';

  @override
  String get itemFrameGoldCoins => 'Khung xu vàng';

  @override
  String get itemBannerStarryNight => 'Banner đêm đầy sao';

  @override
  String get itemBannerWheatField => 'Banner đồng lúa mì';

  @override
  String get itemBannerAlmond => 'Banner hoa hạnh nhân';

  @override
  String get itemBannerRetroSky => 'Banner bầu trời game cổ';

  @override
  String get itemBannerSpace => 'Banner không gian pixel';

  @override
  String canvasWhoNobody(int x, int y) {
    return 'Ô ($x, $y): chưa ai vẽ';
  }

  @override
  String canvasWhoSomeone(int x, int y, String name) {
    return 'Ô ($x, $y): $name vẽ';
  }

  @override
  String get canvasLeftMember => 'một người đã rời nhóm';

  @override
  String get canvasLoadFailed => 'Không tải được canvas.';

  @override
  String get canvasNone => 'Nhóm này chưa có canvas.';

  @override
  String get canvasNoInk => 'Hết mực: hoàn thành nhiệm vụ để nhận 10 mực.';

  @override
  String get canvasInkHint => 'Mỗi ô vẽ tốn 1 mực. Giữ một ô để xem ai vẽ.';

  @override
  String get canvasOffline => 'Mất kết nối: canvas chỉ để xem.';

  @override
  String get canvasArchived => 'Canvas này đã được lưu trữ (chỉ xem).';

  @override
  String canvasSemantics(int w, int h) {
    return 'Canvas $w nhân $h ô. Chạm một ô để vẽ.';
  }

  @override
  String colorSemantics(int n) {
    return 'Màu $n';
  }
}
