import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi'),
  ];

  /// App name in the task switcher.
  ///
  /// In vi, this message translates to:
  /// **'Pocket Portrait'**
  String get appTitle;

  /// Shown when SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY were not passed at build time.
  ///
  /// In vi, this message translates to:
  /// **'Chưa cấu hình máy chủ. Ứng dụng đang chạy ở chế độ chỉ trên máy.'**
  String get backendNotConfigured;

  /// No description provided for @retry.
  ///
  /// In vi, this message translates to:
  /// **'THỬ LẠI'**
  String get retry;

  /// No description provided for @cancel.
  ///
  /// In vi, this message translates to:
  /// **'HỦY'**
  String get cancel;

  /// No description provided for @ok.
  ///
  /// In vi, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @signInTitle.
  ///
  /// In vi, this message translates to:
  /// **'ĐĂNG NHẬP'**
  String get signInTitle;

  /// No description provided for @signUpTitle.
  ///
  /// In vi, this message translates to:
  /// **'TẠO TÀI KHOẢN'**
  String get signUpTitle;

  /// No description provided for @authTagline.
  ///
  /// In vi, this message translates to:
  /// **'Chụp, biến thành tranh và gửi cho bạn bè.'**
  String get authTagline;

  /// No description provided for @emailLabel.
  ///
  /// In vi, this message translates to:
  /// **'EMAIL'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In vi, this message translates to:
  /// **'MẬT KHẨU'**
  String get passwordLabel;

  /// No description provided for @signInButton.
  ///
  /// In vi, this message translates to:
  /// **'ĐĂNG NHẬP'**
  String get signInButton;

  /// No description provided for @signUpButton.
  ///
  /// In vi, this message translates to:
  /// **'ĐĂNG KÝ'**
  String get signUpButton;

  /// No description provided for @switchToSignUp.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có tài khoản? Đăng ký'**
  String get switchToSignUp;

  /// No description provided for @switchToSignIn.
  ///
  /// In vi, this message translates to:
  /// **'Đã có tài khoản? Đăng nhập'**
  String get switchToSignIn;

  /// No description provided for @forgotPassword.
  ///
  /// In vi, this message translates to:
  /// **'Quên mật khẩu?'**
  String get forgotPassword;

  /// No description provided for @resetSent.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi email đặt lại mật khẩu. Hãy kiểm tra hộp thư.'**
  String get resetSent;

  /// No description provided for @resetNeedsEmail.
  ///
  /// In vi, this message translates to:
  /// **'Nhập email của bạn ở trên trước.'**
  String get resetNeedsEmail;

  /// No description provided for @confirmEmailSent.
  ///
  /// In vi, this message translates to:
  /// **'Gần xong! Hãy bấm vào liên kết trong email để xác nhận, rồi đăng nhập.'**
  String get confirmEmailSent;

  /// No description provided for @errInvalidCredentials.
  ///
  /// In vi, this message translates to:
  /// **'Sai email hoặc mật khẩu.'**
  String get errInvalidCredentials;

  /// No description provided for @errEmailTaken.
  ///
  /// In vi, this message translates to:
  /// **'Email này đã có tài khoản. Hãy đăng nhập.'**
  String get errEmailTaken;

  /// No description provided for @errWeakPassword.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu quá yếu. Hãy dùng ít nhất 8 ký tự.'**
  String get errWeakPassword;

  /// No description provided for @errInvalidEmail.
  ///
  /// In vi, this message translates to:
  /// **'Email không hợp lệ.'**
  String get errInvalidEmail;

  /// No description provided for @errNetwork.
  ///
  /// In vi, this message translates to:
  /// **'Không kết nối được. Kiểm tra mạng và thử lại.'**
  String get errNetwork;

  /// No description provided for @errUnknown.
  ///
  /// In vi, this message translates to:
  /// **'Có lỗi xảy ra. Thử lại nhé.'**
  String get errUnknown;

  /// No description provided for @errPasswordShort.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu cần ít nhất 8 ký tự.'**
  String get errPasswordShort;

  /// No description provided for @onboardingTitle.
  ///
  /// In vi, this message translates to:
  /// **'CHÀO MỪNG!'**
  String get onboardingTitle;

  /// No description provided for @onboardingSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Chọn tên để bạn bè tìm thấy bạn.'**
  String get onboardingSubtitle;

  /// No description provided for @displayNameLabel.
  ///
  /// In vi, this message translates to:
  /// **'TÊN HIỂN THỊ'**
  String get displayNameLabel;

  /// No description provided for @usernameLabel.
  ///
  /// In vi, this message translates to:
  /// **'TÊN NGƯỜI DÙNG'**
  String get usernameLabel;

  /// No description provided for @usernameHelp.
  ///
  /// In vi, this message translates to:
  /// **'3–20 ký tự: chữ thường, số, dấu chấm hoặc gạch dưới.'**
  String get usernameHelp;

  /// No description provided for @usernameTaken.
  ///
  /// In vi, this message translates to:
  /// **'Tên này đã có người dùng.'**
  String get usernameTaken;

  /// No description provided for @usernameAvailable.
  ///
  /// In vi, this message translates to:
  /// **'Dùng được!'**
  String get usernameAvailable;

  /// No description provided for @usernameChecking.
  ///
  /// In vi, this message translates to:
  /// **'Đang kiểm tra...'**
  String get usernameChecking;

  /// No description provided for @usernameTooShort.
  ///
  /// In vi, this message translates to:
  /// **'Cần ít nhất 3 ký tự.'**
  String get usernameTooShort;

  /// No description provided for @usernameTooLong.
  ///
  /// In vi, this message translates to:
  /// **'Tối đa 20 ký tự.'**
  String get usernameTooLong;

  /// No description provided for @usernameBadCharacters.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ dùng chữ thường, số, dấu chấm và gạch dưới.'**
  String get usernameBadCharacters;

  /// No description provided for @displayNameRequired.
  ///
  /// In vi, this message translates to:
  /// **'Hãy nhập tên hiển thị.'**
  String get displayNameRequired;

  /// No description provided for @avatarOptional.
  ///
  /// In vi, this message translates to:
  /// **'ẢNH ĐẠI DIỆN (TÙY CHỌN)'**
  String get avatarOptional;

  /// No description provided for @avatarPick.
  ///
  /// In vi, this message translates to:
  /// **'CHỌN ẢNH'**
  String get avatarPick;

  /// No description provided for @continueButton.
  ///
  /// In vi, this message translates to:
  /// **'TIẾP TỤC'**
  String get continueButton;

  /// No description provided for @signOut.
  ///
  /// In vi, this message translates to:
  /// **'ĐĂNG XUẤT'**
  String get signOut;

  /// No description provided for @signOutConfirmTitle.
  ///
  /// In vi, this message translates to:
  /// **'ĐĂNG XUẤT?'**
  String get signOutConfirmTitle;

  /// No description provided for @signOutConfirmBody.
  ///
  /// In vi, this message translates to:
  /// **'Bạn có thể đăng nhập lại bất cứ lúc nào.'**
  String get signOutConfirmBody;

  /// No description provided for @loadingAccount.
  ///
  /// In vi, this message translates to:
  /// **'ĐANG TẢI TÀI KHOẢN...'**
  String get loadingAccount;

  /// No description provided for @accountLoadFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được tài khoản.'**
  String get accountLoadFailed;

  /// No description provided for @avatarUploadFailed.
  ///
  /// In vi, this message translates to:
  /// **'Chưa tải được ảnh đại diện lên máy chủ.'**
  String get avatarUploadFailed;

  /// No description provided for @friendsOnline.
  ///
  /// In vi, this message translates to:
  /// **'ONLINE'**
  String get friendsOnline;

  /// No description provided for @friendsAdd.
  ///
  /// In vi, this message translates to:
  /// **'THÊM BẠN'**
  String get friendsAdd;

  /// No description provided for @friendsRequests.
  ///
  /// In vi, this message translates to:
  /// **'LỜI MỜI'**
  String get friendsRequests;

  /// No description provided for @friendsIncoming.
  ///
  /// In vi, this message translates to:
  /// **'ĐÃ MỜI BẠN'**
  String get friendsIncoming;

  /// No description provided for @friendsOutgoing.
  ///
  /// In vi, this message translates to:
  /// **'ĐÃ GỬI'**
  String get friendsOutgoing;

  /// No description provided for @friendsAccept.
  ///
  /// In vi, this message translates to:
  /// **'CHẤP NHẬN'**
  String get friendsAccept;

  /// No description provided for @friendsDecline.
  ///
  /// In vi, this message translates to:
  /// **'TỪ CHỐI'**
  String get friendsDecline;

  /// No description provided for @friendsCancelRequest.
  ///
  /// In vi, this message translates to:
  /// **'HỦY'**
  String get friendsCancelRequest;

  /// No description provided for @friendsEmptyTitle.
  ///
  /// In vi, this message translates to:
  /// **'CHƯA CÓ\nBẠN BÈ'**
  String get friendsEmptyTitle;

  /// No description provided for @friendsEmptyBody.
  ///
  /// In vi, this message translates to:
  /// **'TÌM BẠN THEO TÊN NGƯỜI DÙNG HOẶC GỬI LIÊN KẾT MỜI.'**
  String get friendsEmptyBody;

  /// No description provided for @friendsRefreshFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không cập nhật được danh sách bạn bè.'**
  String get friendsRefreshFailed;

  /// No description provided for @addFriendTitle.
  ///
  /// In vi, this message translates to:
  /// **'THÊM BẠN'**
  String get addFriendTitle;

  /// No description provided for @addFriendHint.
  ///
  /// In vi, this message translates to:
  /// **'Nhập tên người dùng của bạn bè'**
  String get addFriendHint;

  /// No description provided for @addFriendNoResults.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy ai.'**
  String get addFriendNoResults;

  /// No description provided for @addFriendSend.
  ///
  /// In vi, this message translates to:
  /// **'KẾT BẠN'**
  String get addFriendSend;

  /// No description provided for @addFriendShare.
  ///
  /// In vi, this message translates to:
  /// **'CHIA SẺ LỜI MỜI CỦA TÔI'**
  String get addFriendShare;

  /// No description provided for @inviteMessage.
  ///
  /// In vi, this message translates to:
  /// **'Kết bạn với mình trên Pocket Portrait nhé! @{username}\n{link}'**
  String inviteMessage(String username, String link);

  /// No description provided for @requestSentTo.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi lời mời cho {name}.'**
  String requestSentTo(String name);

  /// No description provided for @nowFriendsWith.
  ///
  /// In vi, this message translates to:
  /// **'Bạn và {name} đã là bạn bè!'**
  String nowFriendsWith(String name);

  /// No description provided for @inviteLinkTitle.
  ///
  /// In vi, this message translates to:
  /// **'Kết bạn với @{username}?'**
  String inviteLinkTitle(String username);

  /// No description provided for @friendNotFound.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy người dùng này.'**
  String get friendNotFound;

  /// No description provided for @friendSelf.
  ///
  /// In vi, this message translates to:
  /// **'Đó chính là bạn mà.'**
  String get friendSelf;

  /// No description provided for @friendAlready.
  ///
  /// In vi, this message translates to:
  /// **'Hai bạn đã là bạn bè.'**
  String get friendAlready;

  /// No description provided for @friendAlreadySent.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã gửi lời mời rồi.'**
  String get friendAlreadySent;

  /// No description provided for @friendNotAccepting.
  ///
  /// In vi, this message translates to:
  /// **'Người này không nhận lời mời mới.'**
  String get friendNotAccepting;

  /// No description provided for @friendTooManyPending.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đang có quá nhiều lời mời chờ. Hãy hủy bớt.'**
  String get friendTooManyPending;

  /// No description provided for @friendLimit.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã đạt giới hạn 20 bạn bè.'**
  String get friendLimit;

  /// No description provided for @friendTheirLimit.
  ///
  /// In vi, this message translates to:
  /// **'Người này đã đạt giới hạn bạn bè.'**
  String get friendTheirLimit;

  /// No description provided for @friendsGenericError.
  ///
  /// In vi, this message translates to:
  /// **'Có lỗi xảy ra. Thử lại nhé.'**
  String get friendsGenericError;

  /// No description provided for @removeFriendTitle.
  ///
  /// In vi, this message translates to:
  /// **'XÓA BẠN?'**
  String get removeFriendTitle;

  /// No description provided for @removeFriendBody.
  ///
  /// In vi, this message translates to:
  /// **'Xóa {name} khỏi danh sách bạn bè? Bạn có thể gửi lời mời lại sau.'**
  String removeFriendBody(String name);

  /// No description provided for @removeFriendConfirm.
  ///
  /// In vi, this message translates to:
  /// **'XÓA'**
  String get removeFriendConfirm;

  /// No description provided for @composerTitle.
  ///
  /// In vi, this message translates to:
  /// **'ĐĂNG ẢNH'**
  String get composerTitle;

  /// No description provided for @composerCaptionHint.
  ///
  /// In vi, this message translates to:
  /// **'Thêm chú thích...'**
  String get composerCaptionHint;

  /// No description provided for @composerAllFriends.
  ///
  /// In vi, this message translates to:
  /// **'TẤT CẢ BẠN BÈ'**
  String get composerAllFriends;

  /// No description provided for @composerSend.
  ///
  /// In vi, this message translates to:
  /// **'GỬI'**
  String get composerSend;

  /// No description provided for @composerNoFriends.
  ///
  /// In vi, this message translates to:
  /// **'Hãy kết bạn trước để gửi ảnh cho họ.'**
  String get composerNoFriends;

  /// No description provided for @composerPickAtLeastOne.
  ///
  /// In vi, this message translates to:
  /// **'Chọn ít nhất một người nhận.'**
  String get composerPickAtLeastOne;

  /// No description provided for @composerSentTo.
  ///
  /// In vi, this message translates to:
  /// **'{count, plural, =1{Đã gửi cho 1 người bạn.} other{Đã gửi cho {count} người bạn.}}'**
  String composerSentTo(int count);

  /// No description provided for @composerQueued.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có mạng. Ảnh sẽ tự gửi khi kết nối lại.'**
  String get composerQueued;

  /// No description provided for @composerSending.
  ///
  /// In vi, this message translates to:
  /// **'Đang gửi...'**
  String get composerSending;

  /// No description provided for @feedYou.
  ///
  /// In vi, this message translates to:
  /// **'Bạn'**
  String get feedYou;

  /// No description provided for @sendPrintButton.
  ///
  /// In vi, this message translates to:
  /// **'GỬI'**
  String get sendPrintButton;

  /// No description provided for @printDiscard.
  ///
  /// In vi, this message translates to:
  /// **'HỦY'**
  String get printDiscard;

  /// No description provided for @printPost.
  ///
  /// In vi, this message translates to:
  /// **'ĐĂNG'**
  String get printPost;

  /// No description provided for @composerPostAll.
  ///
  /// In vi, this message translates to:
  /// **'ĐĂNG CHO TẤT CẢ'**
  String get composerPostAll;

  /// No description provided for @composerSendToSome.
  ///
  /// In vi, this message translates to:
  /// **'{count, plural, =1{GỬI CHO 1 NGƯỜI} other{GỬI CHO {count} NGƯỜI}}'**
  String composerSendToSome(int count);

  /// No description provided for @postSaved.
  ///
  /// In vi, this message translates to:
  /// **'Đã lưu vào thư viện ảnh.'**
  String get postSaved;

  /// No description provided for @postSaveFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không lưu được ảnh.'**
  String get postSaveFailed;

  /// No description provided for @postShareFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không chia sẻ được ảnh.'**
  String get postShareFailed;

  /// No description provided for @postMenuSave.
  ///
  /// In vi, this message translates to:
  /// **'LƯU VỀ MÁY'**
  String get postMenuSave;

  /// No description provided for @postMenuShare.
  ///
  /// In vi, this message translates to:
  /// **'CHIA SẺ'**
  String get postMenuShare;

  /// No description provided for @postMenuDelete.
  ///
  /// In vi, this message translates to:
  /// **'XÓA BÀI'**
  String get postMenuDelete;

  /// No description provided for @postDeleteTitle.
  ///
  /// In vi, this message translates to:
  /// **'XÓA BÀI NÀY?'**
  String get postDeleteTitle;

  /// No description provided for @postDeleteBody.
  ///
  /// In vi, this message translates to:
  /// **'Bài sẽ biến mất với tất cả bạn bè. Không thể hoàn tác.'**
  String get postDeleteBody;

  /// No description provided for @postDeleted.
  ///
  /// In vi, this message translates to:
  /// **'Đã xóa bài.'**
  String get postDeleted;

  /// No description provided for @reactionSent.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi {emoji}'**
  String reactionSent(String emoji);

  /// No description provided for @replySent.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi tin nhắn.'**
  String get replySent;

  /// No description provided for @chatSendFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không gửi được tin nhắn.'**
  String get chatSendFailed;

  /// No description provided for @chatNotFriends.
  ///
  /// In vi, this message translates to:
  /// **'Hai bạn không còn là bạn bè.'**
  String get chatNotFriends;

  /// No description provided for @chatTooLong.
  ///
  /// In vi, this message translates to:
  /// **'Tin nhắn quá dài (tối đa 500 ký tự).'**
  String get chatTooLong;

  /// No description provided for @historyTab.
  ///
  /// In vi, this message translates to:
  /// **'LỊCH SỬ'**
  String get historyTab;

  /// No description provided for @historyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Lịch sử'**
  String get historyTitle;

  /// No description provided for @historyAll.
  ///
  /// In vi, this message translates to:
  /// **'TẤT CẢ'**
  String get historyAll;

  /// No description provided for @historyMine.
  ///
  /// In vi, this message translates to:
  /// **'CỦA TÔI'**
  String get historyMine;

  /// No description provided for @historyPosts.
  ///
  /// In vi, this message translates to:
  /// **'BÀI ĐĂNG'**
  String get historyPosts;

  /// No description provided for @historyOnDevice.
  ///
  /// In vi, this message translates to:
  /// **'TRÊN MÁY'**
  String get historyOnDevice;

  /// No description provided for @historyEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có bài nào. Gửi ảnh cho bạn bè hoặc chờ họ gửi cho bạn nhé!'**
  String get historyEmpty;

  /// No description provided for @historyLoadFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được lịch sử. Kéo xuống để thử lại.'**
  String get historyLoadFailed;

  /// No description provided for @overlayTime.
  ///
  /// In vi, this message translates to:
  /// **'GIỜ'**
  String get overlayTime;

  /// No description provided for @overlayPlace.
  ///
  /// In vi, this message translates to:
  /// **'ĐỊA ĐIỂM'**
  String get overlayPlace;

  /// No description provided for @overlayFindingPlace.
  ///
  /// In vi, this message translates to:
  /// **'ĐANG TÌM VỊ TRÍ...'**
  String get overlayFindingPlace;

  /// No description provided for @placeServicesOff.
  ///
  /// In vi, this message translates to:
  /// **'Định vị đang tắt. Bật định vị trong cài đặt máy.'**
  String get placeServicesOff;

  /// No description provided for @placeDenied.
  ///
  /// In vi, this message translates to:
  /// **'Ứng dụng chưa được phép dùng vị trí.'**
  String get placeDenied;

  /// No description provided for @placeFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không xác định được địa điểm.'**
  String get placeFailed;

  /// No description provided for @timerOff.
  ///
  /// In vi, this message translates to:
  /// **'Tắt hẹn giờ'**
  String get timerOff;

  /// No description provided for @timerSeconds.
  ///
  /// In vi, this message translates to:
  /// **'Hẹn giờ {seconds} giây'**
  String timerSeconds(int seconds);

  /// No description provided for @holdForVideo.
  ///
  /// In vi, this message translates to:
  /// **'Giữ để quay video'**
  String get holdForVideo;

  /// No description provided for @videoTooShort.
  ///
  /// In vi, this message translates to:
  /// **'Video quá ngắn. Giữ nút lâu hơn.'**
  String get videoTooShort;

  /// No description provided for @videoFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không quay được video.'**
  String get videoFailed;

  /// No description provided for @errSamePassword.
  ///
  /// In vi, this message translates to:
  /// **'Hãy chọn mật khẩu khác mật khẩu hiện tại.'**
  String get errSamePassword;

  /// No description provided for @resetPasswordTitle.
  ///
  /// In vi, this message translates to:
  /// **'MẬT KHẨU MỚI'**
  String get resetPasswordTitle;

  /// No description provided for @resetPasswordSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Chọn mật khẩu mới cho tài khoản của bạn.'**
  String get resetPasswordSubtitle;

  /// No description provided for @newPasswordLabel.
  ///
  /// In vi, this message translates to:
  /// **'MẬT KHẨU MỚI'**
  String get newPasswordLabel;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In vi, this message translates to:
  /// **'NHẬP LẠI MẬT KHẨU'**
  String get confirmPasswordLabel;

  /// No description provided for @passwordsDiffer.
  ///
  /// In vi, this message translates to:
  /// **'Hai mật khẩu chưa giống nhau.'**
  String get passwordsDiffer;

  /// No description provided for @savePassword.
  ///
  /// In vi, this message translates to:
  /// **'LƯU MẬT KHẨU'**
  String get savePassword;

  /// No description provided for @passwordChanged.
  ///
  /// In vi, this message translates to:
  /// **'Đã đổi mật khẩu.'**
  String get passwordChanged;

  /// No description provided for @settingsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Cài đặt'**
  String get settingsTitle;

  /// No description provided for @settingsAccount.
  ///
  /// In vi, this message translates to:
  /// **'TÀI KHOẢN'**
  String get settingsAccount;

  /// No description provided for @settingsPrivacy.
  ///
  /// In vi, this message translates to:
  /// **'QUYỀN RIÊNG TƯ'**
  String get settingsPrivacy;

  /// No description provided for @settingsLanguage.
  ///
  /// In vi, this message translates to:
  /// **'NGÔN NGỮ'**
  String get settingsLanguage;

  /// No description provided for @settingsAbout.
  ///
  /// In vi, this message translates to:
  /// **'VỀ ỨNG DỤNG'**
  String get settingsAbout;

  /// No description provided for @settingsEditProfile.
  ///
  /// In vi, this message translates to:
  /// **'Sửa tên và tên người dùng'**
  String get settingsEditProfile;

  /// No description provided for @settingsChangePassword.
  ///
  /// In vi, this message translates to:
  /// **'Đổi mật khẩu'**
  String get settingsChangePassword;

  /// No description provided for @settingsEmail.
  ///
  /// In vi, this message translates to:
  /// **'Email: {email}'**
  String settingsEmail(String email);

  /// No description provided for @settingsAllowRequests.
  ///
  /// In vi, this message translates to:
  /// **'Cho phép nhận lời mời kết bạn'**
  String get settingsAllowRequests;

  /// No description provided for @settingsAllowRequestsHint.
  ///
  /// In vi, this message translates to:
  /// **'Tắt đi thì không ai gửi được lời mời mới cho bạn.'**
  String get settingsAllowRequestsHint;

  /// No description provided for @settingsBlocked.
  ///
  /// In vi, this message translates to:
  /// **'Danh sách đã chặn'**
  String get settingsBlocked;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In vi, this message translates to:
  /// **'Theo máy'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageVi.
  ///
  /// In vi, this message translates to:
  /// **'Tiếng Việt'**
  String get settingsLanguageVi;

  /// No description provided for @settingsLanguageEn.
  ///
  /// In vi, this message translates to:
  /// **'English'**
  String get settingsLanguageEn;

  /// No description provided for @settingsLaptop.
  ///
  /// In vi, this message translates to:
  /// **'Kết nối laptop (tranh Van Gogh)'**
  String get settingsLaptop;

  /// No description provided for @settingsPrivacyPolicy.
  ///
  /// In vi, this message translates to:
  /// **'Chính sách quyền riêng tư'**
  String get settingsPrivacyPolicy;

  /// No description provided for @settingsTerms.
  ///
  /// In vi, this message translates to:
  /// **'Điều khoản sử dụng'**
  String get settingsTerms;

  /// No description provided for @settingsDeleteAccount.
  ///
  /// In vi, this message translates to:
  /// **'XÓA TÀI KHOẢN'**
  String get settingsDeleteAccount;

  /// No description provided for @editProfileTitle.
  ///
  /// In vi, this message translates to:
  /// **'SỬA HỒ SƠ'**
  String get editProfileTitle;

  /// No description provided for @saveButton.
  ///
  /// In vi, this message translates to:
  /// **'LƯU'**
  String get saveButton;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In vi, this message translates to:
  /// **'XÓA TÀI KHOẢN?'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountBody.
  ///
  /// In vi, this message translates to:
  /// **'Toàn bộ ảnh, tin nhắn, bạn bè, Sunbit và đồ đã mua của bạn sẽ bị xóa vĩnh viễn. Không thể hoàn tác.'**
  String get deleteAccountBody;

  /// No description provided for @deleteAccountType.
  ///
  /// In vi, this message translates to:
  /// **'Nhập \"{username}\" để xác nhận'**
  String deleteAccountType(String username);

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In vi, this message translates to:
  /// **'XÓA VĨNH VIỄN'**
  String get deleteAccountConfirm;

  /// No description provided for @deleteAccountFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không xóa được tài khoản. Kiểm tra mạng rồi thử lại.'**
  String get deleteAccountFailed;

  /// No description provided for @blockedTitle.
  ///
  /// In vi, this message translates to:
  /// **'ĐÃ CHẶN'**
  String get blockedTitle;

  /// No description provided for @blockedEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Bạn chưa chặn ai.'**
  String get blockedEmpty;

  /// No description provided for @unblock.
  ///
  /// In vi, this message translates to:
  /// **'BỎ CHẶN'**
  String get unblock;

  /// No description provided for @blockPerson.
  ///
  /// In vi, this message translates to:
  /// **'CHẶN'**
  String get blockPerson;

  /// No description provided for @blockTitle.
  ///
  /// In vi, this message translates to:
  /// **'CHẶN {name}?'**
  String blockTitle(String name);

  /// No description provided for @blockBody.
  ///
  /// In vi, this message translates to:
  /// **'Hai bạn sẽ không còn là bạn bè, không thấy ảnh của nhau và không nhắn được cho nhau. Họ không được báo.'**
  String get blockBody;

  /// No description provided for @blockedDone.
  ///
  /// In vi, this message translates to:
  /// **'Đã chặn {name}.'**
  String blockedDone(String name);

  /// No description provided for @unblockedDone.
  ///
  /// In vi, this message translates to:
  /// **'Đã bỏ chặn {name}.'**
  String unblockedDone(String name);

  /// No description provided for @reportPerson.
  ///
  /// In vi, this message translates to:
  /// **'BÁO CÁO NGƯỜI NÀY'**
  String get reportPerson;

  /// No description provided for @reportPost.
  ///
  /// In vi, this message translates to:
  /// **'BÁO CÁO BÀI NÀY'**
  String get reportPost;

  /// No description provided for @reportTitle.
  ///
  /// In vi, this message translates to:
  /// **'BÁO CÁO'**
  String get reportTitle;

  /// No description provided for @reportWhy.
  ///
  /// In vi, this message translates to:
  /// **'Lý do'**
  String get reportWhy;

  /// No description provided for @reportSpam.
  ///
  /// In vi, this message translates to:
  /// **'Spam hoặc quảng cáo'**
  String get reportSpam;

  /// No description provided for @reportInappropriate.
  ///
  /// In vi, this message translates to:
  /// **'Nội dung không phù hợp'**
  String get reportInappropriate;

  /// No description provided for @reportHarassment.
  ///
  /// In vi, this message translates to:
  /// **'Quấy rối hoặc bắt nạt'**
  String get reportHarassment;

  /// No description provided for @reportOther.
  ///
  /// In vi, this message translates to:
  /// **'Lý do khác'**
  String get reportOther;

  /// No description provided for @reportDetailsHint.
  ///
  /// In vi, this message translates to:
  /// **'Thêm chi tiết (không bắt buộc)'**
  String get reportDetailsHint;

  /// No description provided for @reportSend.
  ///
  /// In vi, this message translates to:
  /// **'GỬI BÁO CÁO'**
  String get reportSend;

  /// No description provided for @reportSent.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi báo cáo. Cảm ơn bạn.'**
  String get reportSent;

  /// No description provided for @reportTooMany.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã báo cáo quá nhiều hôm nay. Thử lại vào ngày mai.'**
  String get reportTooMany;

  /// No description provided for @safetyFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không thực hiện được. Kiểm tra mạng rồi thử lại.'**
  String get safetyFailed;

  /// No description provided for @legalDraftNote.
  ///
  /// In vi, this message translates to:
  /// **'Bản nháp: cần được xem xét pháp lý trước khi phát hành.'**
  String get legalDraftNote;

  /// No description provided for @settingsNotifications.
  ///
  /// In vi, this message translates to:
  /// **'THÔNG BÁO'**
  String get settingsNotifications;

  /// No description provided for @notifyNewPost.
  ///
  /// In vi, this message translates to:
  /// **'Có ảnh mới từ bạn bè'**
  String get notifyNewPost;

  /// No description provided for @notifyMessages.
  ///
  /// In vi, this message translates to:
  /// **'Tin nhắn'**
  String get notifyMessages;

  /// No description provided for @notifyReactions.
  ///
  /// In vi, this message translates to:
  /// **'Reaction vào ảnh của tôi'**
  String get notifyReactions;

  /// No description provided for @notifyFriendRequests.
  ///
  /// In vi, this message translates to:
  /// **'Lời mời kết bạn'**
  String get notifyFriendRequests;

  /// No description provided for @tabShoot.
  ///
  /// In vi, this message translates to:
  /// **'CHỤP'**
  String get tabShoot;

  /// No description provided for @tabFriends.
  ///
  /// In vi, this message translates to:
  /// **'BẠN BÈ'**
  String get tabFriends;

  /// No description provided for @tabInbox.
  ///
  /// In vi, this message translates to:
  /// **'HỘP THƯ'**
  String get tabInbox;

  /// No description provided for @tabPrints.
  ///
  /// In vi, this message translates to:
  /// **'TỦ ẢNH'**
  String get tabPrints;

  /// No description provided for @tabMe.
  ///
  /// In vi, this message translates to:
  /// **'TÔI'**
  String get tabMe;

  /// No description provided for @laptopSettingsTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Cài đặt laptop ở nhà'**
  String get laptopSettingsTooltip;

  /// No description provided for @cameraAccessHint.
  ///
  /// In vi, this message translates to:
  /// **'BẬT QUYỀN CAMERA ĐỂ BẮT ĐẦU CHỤP'**
  String get cameraAccessHint;

  /// No description provided for @originalLabel.
  ///
  /// In vi, this message translates to:
  /// **'ẢNH GỐC'**
  String get originalLabel;

  /// No description provided for @imageNotFound.
  ///
  /// In vi, this message translates to:
  /// **'KHÔNG TÌM THẤY ẢNH'**
  String get imageNotFound;

  /// No description provided for @groupsKicker.
  ///
  /// In vi, this message translates to:
  /// **'NHÓM CỦA BẠN'**
  String get groupsKicker;

  /// No description provided for @groupsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Nhóm'**
  String get groupsTitle;

  /// No description provided for @groupsCount.
  ///
  /// In vi, this message translates to:
  /// **'{count} NHÓM'**
  String groupsCount(int count);

  /// No description provided for @groupCreate.
  ///
  /// In vi, this message translates to:
  /// **'TẠO NHÓM'**
  String get groupCreate;

  /// No description provided for @questDataUnreadable.
  ///
  /// In vi, this message translates to:
  /// **'KHÔNG ĐỌC ĐƯỢC DỮ LIỆU NHIỆM VỤ'**
  String get questDataUnreadable;

  /// No description provided for @archiveUnreadable.
  ///
  /// In vi, this message translates to:
  /// **'KHÔNG ĐỌC ĐƯỢC TỦ ẢNH'**
  String get archiveUnreadable;

  /// No description provided for @friendsLoadFailed.
  ///
  /// In vi, this message translates to:
  /// **'KHÔNG TẢI ĐƯỢC DANH SÁCH BẠN BÈ'**
  String get friendsLoadFailed;

  /// No description provided for @friendAddedLocally.
  ///
  /// In vi, this message translates to:
  /// **'ĐÃ THÊM {name} TRÊN MÁY'**
  String friendAddedLocally(String name);

  /// No description provided for @shareNeedsPrint.
  ///
  /// In vi, this message translates to:
  /// **'HÃY CHỤP MỘT TẤM TRƯỚC KHI CHIA SẺ'**
  String get shareNeedsPrint;

  /// No description provided for @replyWord.
  ///
  /// In vi, this message translates to:
  /// **'TIN NHẮN'**
  String get replyWord;

  /// No description provided for @sentNotice.
  ///
  /// In vi, this message translates to:
  /// **'ĐÃ GỬI {what}'**
  String sentNotice(String what);

  /// No description provided for @sentNoticeTo.
  ///
  /// In vi, this message translates to:
  /// **'ĐÃ GỬI {what} CHO {name}'**
  String sentNoticeTo(String what, String name);

  /// No description provided for @removeLocalFriendBody.
  ///
  /// In vi, this message translates to:
  /// **'Xóa {name} và cuộc trò chuyện này khỏi máy?'**
  String removeLocalFriendBody(String name);

  /// No description provided for @photoNotSaved.
  ///
  /// In vi, this message translates to:
  /// **'ẢNH CHƯA LƯU ĐƯỢC. THỬ LẠI NHÉ.'**
  String get photoNotSaved;

  /// No description provided for @photoOpenFailed.
  ///
  /// In vi, this message translates to:
  /// **'KHÔNG MỞ ĐƯỢC ẢNH NÀY. THỬ ẢNH KHÁC.'**
  String get photoOpenFailed;

  /// No description provided for @fallbackUsed.
  ///
  /// In vi, this message translates to:
  /// **'ĐÃ DÙNG PHƯƠNG ÁN DỰ PHÒNG: {note}'**
  String fallbackUsed(String note);

  /// No description provided for @styleFailedOriginalSafe.
  ///
  /// In vi, this message translates to:
  /// **'TẠO TRANH THẤT BẠI. ẢNH GỐC VẪN AN TOÀN.'**
  String get styleFailedOriginalSafe;

  /// No description provided for @flashUnavailable.
  ///
  /// In vi, this message translates to:
  /// **'MÁY KHÔNG CÓ ĐÈN FLASH'**
  String get flashUnavailable;

  /// No description provided for @flashTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Đổi chế độ flash'**
  String get flashTooltip;

  /// No description provided for @openFeedLabel.
  ///
  /// In vi, this message translates to:
  /// **'Mở bảng tin'**
  String get openFeedLabel;

  /// No description provided for @feedLabel.
  ///
  /// In vi, this message translates to:
  /// **'BẢNG TIN'**
  String get feedLabel;

  /// No description provided for @zoomSemantics.
  ///
  /// In vi, this message translates to:
  /// **'Thu phóng {level}'**
  String zoomSemantics(String level);

  /// No description provided for @uploadPhotoTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Tải ảnh lên từ máy'**
  String get uploadPhotoTooltip;

  /// No description provided for @takePhotoLabel.
  ///
  /// In vi, this message translates to:
  /// **'Chụp ảnh'**
  String get takePhotoLabel;

  /// No description provided for @switchCameraTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Đổi camera'**
  String get switchCameraTooltip;

  /// No description provided for @openArchiveLabel.
  ///
  /// In vi, this message translates to:
  /// **'Mở tủ ảnh'**
  String get openArchiveLabel;

  /// No description provided for @retryShort.
  ///
  /// In vi, this message translates to:
  /// **'THỬ LẠI'**
  String get retryShort;

  /// No description provided for @newShot.
  ///
  /// In vi, this message translates to:
  /// **'CHỤP MỚI'**
  String get newShot;

  /// No description provided for @statusInking.
  ///
  /// In vi, this message translates to:
  /// **'ĐANG VẼ'**
  String get statusInking;

  /// No description provided for @statusReady.
  ///
  /// In vi, this message translates to:
  /// **'XONG'**
  String get statusReady;

  /// No description provided for @statusOriginalSafe.
  ///
  /// In vi, this message translates to:
  /// **'ĐÃ GIỮ ẢNH GỐC'**
  String get statusOriginalSafe;

  /// No description provided for @cameraAccessOff.
  ///
  /// In vi, this message translates to:
  /// **'CAMERA ĐANG BỊ TẮT QUYỀN'**
  String get cameraAccessOff;

  /// No description provided for @cameraUnavailable.
  ///
  /// In vi, this message translates to:
  /// **'KHÔNG DÙNG ĐƯỢC CAMERA'**
  String get cameraUnavailable;

  /// No description provided for @findingCamera.
  ///
  /// In vi, this message translates to:
  /// **'ĐANG TÌM CAMERA'**
  String get findingCamera;

  /// No description provided for @cameraReady.
  ///
  /// In vi, this message translates to:
  /// **'CAMERA SẴN SÀNG'**
  String get cameraReady;

  /// No description provided for @originalPlusStyle.
  ///
  /// In vi, this message translates to:
  /// **'ẢNH GỐC + {style}'**
  String originalPlusStyle(String style);

  /// No description provided for @legacyEdit.
  ///
  /// In vi, this message translates to:
  /// **'BẢN CHỈNH CŨ'**
  String get legacyEdit;

  /// No description provided for @editLabel.
  ///
  /// In vi, this message translates to:
  /// **'ĐÃ CHỈNH'**
  String get editLabel;

  /// No description provided for @styleSliderSemantics.
  ///
  /// In vi, this message translates to:
  /// **'Phong cách. Vuốt để đổi'**
  String get styleSliderSemantics;

  /// No description provided for @retryTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Thử lại'**
  String get retryTooltip;

  /// No description provided for @backToCameraTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Về camera'**
  String get backToCameraTooltip;

  /// No description provided for @noPostsYet.
  ///
  /// In vi, this message translates to:
  /// **'CHƯA CÓ BÀI NÀO'**
  String get noPostsYet;

  /// No description provided for @replyHint.
  ///
  /// In vi, this message translates to:
  /// **'Trả lời {name}...'**
  String replyHint(String name);

  /// No description provided for @openPrint.
  ///
  /// In vi, this message translates to:
  /// **'XEM ẢNH'**
  String get openPrint;

  /// No description provided for @reactWith.
  ///
  /// In vi, this message translates to:
  /// **'THẢ CẢM XÚC'**
  String get reactWith;

  /// No description provided for @sendReplyTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Gửi trả lời'**
  String get sendReplyTooltip;

  /// No description provided for @reactSemantics.
  ///
  /// In vi, this message translates to:
  /// **'Thả {emoji}'**
  String reactSemantics(String emoji);

  /// No description provided for @moreEmojiTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Thêm emoji'**
  String get moreEmojiTooltip;

  /// No description provided for @localCollection.
  ///
  /// In vi, this message translates to:
  /// **'BỘ SƯU TẬP TRÊN MÁY'**
  String get localCollection;

  /// No description provided for @printArchive.
  ///
  /// In vi, this message translates to:
  /// **'Tủ ảnh'**
  String get printArchive;

  /// No description provided for @itemsCount.
  ///
  /// In vi, this message translates to:
  /// **'{count} ẢNH'**
  String itemsCount(int count);

  /// No description provided for @archiveEmptyBody.
  ///
  /// In vi, this message translates to:
  /// **'ẢNH CỦA BẠN CHỈ NẰM TRONG TỦ ẢNH TRÊN MÁY NÀY.'**
  String get archiveEmptyBody;

  /// No description provided for @openCamera.
  ///
  /// In vi, this message translates to:
  /// **'MỞ CAMERA'**
  String get openCamera;

  /// No description provided for @printReady.
  ///
  /// In vi, this message translates to:
  /// **'TRANH ĐÃ XONG'**
  String get printReady;

  /// No description provided for @originalSaved.
  ///
  /// In vi, this message translates to:
  /// **'ĐÃ LƯU ẢNH GỐC'**
  String get originalSaved;

  /// No description provided for @serverTesting.
  ///
  /// In vi, this message translates to:
  /// **'ĐANG KIỂM TRA…'**
  String get serverTesting;

  /// No description provided for @serverConnected.
  ///
  /// In vi, this message translates to:
  /// **'ĐÃ KẾT NỐI · {gpu}'**
  String serverConnected(String gpu);

  /// No description provided for @serverModelsLoading.
  ///
  /// In vi, this message translates to:
  /// **'ĐÃ KẾT NỐI · MÔ HÌNH ĐANG TẢI'**
  String get serverModelsLoading;

  /// No description provided for @serverInvalidAddress.
  ///
  /// In vi, this message translates to:
  /// **'ĐỊA CHỈ KHÔNG HỢP LỆ'**
  String get serverInvalidAddress;

  /// No description provided for @homeLaptop.
  ///
  /// In vi, this message translates to:
  /// **'LAPTOP Ở NHÀ'**
  String get homeLaptop;

  /// No description provided for @vanGoghOnLaptop.
  ///
  /// In vi, this message translates to:
  /// **'TRANH VAN GOGH CHẠY TRÊN LAPTOP CỦA BẠN'**
  String get vanGoghOnLaptop;

  /// No description provided for @serverAddressLabel.
  ///
  /// In vi, this message translates to:
  /// **'ĐỊA CHỈ (IP:CỔNG)'**
  String get serverAddressLabel;

  /// No description provided for @serverTokenLabel.
  ///
  /// In vi, this message translates to:
  /// **'MÃ TOKEN'**
  String get serverTokenLabel;

  /// No description provided for @serverTokenHint.
  ///
  /// In vi, this message translates to:
  /// **'in ra khi máy chủ khởi động'**
  String get serverTokenHint;

  /// No description provided for @serverTestButton.
  ///
  /// In vi, this message translates to:
  /// **'KIỂM TRA'**
  String get serverTestButton;

  /// No description provided for @shopLabel.
  ///
  /// In vi, this message translates to:
  /// **'CỬA HÀNG'**
  String get shopLabel;

  /// No description provided for @sunbitShop.
  ///
  /// In vi, this message translates to:
  /// **'CỬA HÀNG SUNBIT'**
  String get sunbitShop;

  /// No description provided for @sampleLabel.
  ///
  /// In vi, this message translates to:
  /// **'MẪU'**
  String get sampleLabel;

  /// No description provided for @menuTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Menu'**
  String get menuTooltip;

  /// No description provided for @yourPeople.
  ///
  /// In vi, this message translates to:
  /// **'BẠN BÈ CỦA BẠN'**
  String get yourPeople;

  /// No description provided for @friendsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bạn bè'**
  String get friendsTitle;

  /// No description provided for @peopleCount.
  ///
  /// In vi, this message translates to:
  /// **'{count} NGƯỜI'**
  String peopleCount(int count);

  /// No description provided for @localMode.
  ///
  /// In vi, this message translates to:
  /// **'CHẾ ĐỘ TRÊN MÁY'**
  String get localMode;

  /// No description provided for @noFriendsOnDevice.
  ///
  /// In vi, this message translates to:
  /// **'CHƯA CÓ BẠN\nTRÊN MÁY NÀY'**
  String get noFriendsOnDevice;

  /// No description provided for @noFriendsOnDeviceBody.
  ///
  /// In vi, this message translates to:
  /// **'THÊM MỘT HỒ SƠ TRÊN MÁY ĐỂ BẮT ĐẦU CUỘC TRÒ CHUYỆN MẪU.'**
  String get noFriendsOnDeviceBody;

  /// No description provided for @privateThreads.
  ///
  /// In vi, this message translates to:
  /// **'TIN NHẮN RIÊNG'**
  String get privateThreads;

  /// No description provided for @inboxTitle.
  ///
  /// In vi, this message translates to:
  /// **'Hộp thư'**
  String get inboxTitle;

  /// No description provided for @deviceOnly.
  ///
  /// In vi, this message translates to:
  /// **'CHỈ TRÊN MÁY'**
  String get deviceOnly;

  /// No description provided for @addFriendToStart.
  ///
  /// In vi, this message translates to:
  /// **'THÊM BẠN ĐỂ BẮT ĐẦU TRÒ CHUYỆN'**
  String get addFriendToStart;

  /// No description provided for @backToInboxTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Về hộp thư'**
  String get backToInboxTooltip;

  /// No description provided for @openProfileLabel.
  ///
  /// In vi, this message translates to:
  /// **'Mở hồ sơ'**
  String get openProfileLabel;

  /// No description provided for @removeFriendTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Xóa bạn'**
  String get removeFriendTooltip;

  /// No description provided for @localThread.
  ///
  /// In vi, this message translates to:
  /// **'TRÒ CHUYỆN TRÊN MÁY'**
  String get localThread;

  /// No description provided for @sendLatestPrintTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Gửi ảnh mới nhất'**
  String get sendLatestPrintTooltip;

  /// No description provided for @writeMessageHint.
  ///
  /// In vi, this message translates to:
  /// **'Viết tin nhắn...'**
  String get writeMessageHint;

  /// No description provided for @sendMessageTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Gửi tin nhắn'**
  String get sendMessageTooltip;

  /// No description provided for @whosePost.
  ///
  /// In vi, this message translates to:
  /// **'BÀI CỦA {name}'**
  String whosePost(String name);

  /// No description provided for @yourPost.
  ///
  /// In vi, this message translates to:
  /// **'BÀI CỦA BẠN'**
  String get yourPost;

  /// No description provided for @previewStart.
  ///
  /// In vi, this message translates to:
  /// **'BẮT ĐẦU TRÒ CHUYỆN'**
  String get previewStart;

  /// No description provided for @previewReacted.
  ///
  /// In vi, this message translates to:
  /// **'{who} ĐÃ THẢ {emoji}'**
  String previewReacted(String who, String emoji);

  /// No description provided for @previewYou.
  ///
  /// In vi, this message translates to:
  /// **'BẠN'**
  String get previewYou;

  /// No description provided for @previewYouReplied.
  ///
  /// In vi, this message translates to:
  /// **'BẠN ĐÃ TRẢ LỜI: {text}'**
  String previewYouReplied(String text);

  /// No description provided for @previewReplied.
  ///
  /// In vi, this message translates to:
  /// **'ĐÃ TRẢ LỜI: {text}'**
  String previewReplied(String text);

  /// No description provided for @previewSentPrint.
  ///
  /// In vi, this message translates to:
  /// **'ĐÃ GỬI MỘT ẢNH'**
  String get previewSentPrint;

  /// No description provided for @previewYouText.
  ///
  /// In vi, this message translates to:
  /// **'BẠN: {text}'**
  String previewYouText(String text);

  /// No description provided for @localLabel.
  ///
  /// In vi, this message translates to:
  /// **'TRÊN MÁY'**
  String get localLabel;

  /// No description provided for @addAFriend.
  ///
  /// In vi, this message translates to:
  /// **'THÊM BẠN'**
  String get addAFriend;

  /// No description provided for @localProfileOnly.
  ///
  /// In vi, this message translates to:
  /// **'CHỈ LƯU TRÊN MÁY'**
  String get localProfileOnly;

  /// No description provided for @handleLabel.
  ///
  /// In vi, this message translates to:
  /// **'TÊN NGƯỜI DÙNG'**
  String get handleLabel;

  /// No description provided for @friendNameHint.
  ///
  /// In vi, this message translates to:
  /// **'Tên của bạn bè'**
  String get friendNameHint;

  /// No description provided for @addToFriends.
  ///
  /// In vi, this message translates to:
  /// **'THÊM VÀO BẠN BÈ'**
  String get addToFriends;

  /// No description provided for @settingsFeedback.
  ///
  /// In vi, this message translates to:
  /// **'CẢM GIÁC'**
  String get settingsFeedback;

  /// No description provided for @settingsHaptics.
  ///
  /// In vi, this message translates to:
  /// **'Rung khi chạm'**
  String get settingsHaptics;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
