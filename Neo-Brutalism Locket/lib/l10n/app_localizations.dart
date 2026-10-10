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

  /// No description provided for @holdToCompare.
  ///
  /// In vi, this message translates to:
  /// **'GIỮ ĐỂ SO SÁNH'**
  String get holdToCompare;

  /// No description provided for @styleWorking8bit.
  ///
  /// In vi, this message translates to:
  /// **'ĐANG MÀI PIXEL…'**
  String get styleWorking8bit;

  /// No description provided for @styleWorkingVanGogh.
  ///
  /// In vi, this message translates to:
  /// **'ĐANG QUÉT MÀU VAN GOGH…'**
  String get styleWorkingVanGogh;

  /// No description provided for @styleWorking.
  ///
  /// In vi, this message translates to:
  /// **'ĐANG XỬ LÝ…'**
  String get styleWorking;

  /// No description provided for @backTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Quay lại'**
  String get backTooltip;

  /// No description provided for @contestTitle.
  ///
  /// In vi, this message translates to:
  /// **'Cuộc thi tuần'**
  String get contestTitle;

  /// No description provided for @contestLoadFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được cuộc thi.'**
  String get contestLoadFailed;

  /// No description provided for @contestNone.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có cuộc thi nào.'**
  String get contestNone;

  /// No description provided for @contestStale.
  ///
  /// In vi, this message translates to:
  /// **'Không cập nhật được. Đang hiện dữ liệu cũ.'**
  String get contestStale;

  /// No description provided for @contestEnterGallery.
  ///
  /// In vi, this message translates to:
  /// **'VÀO GALLERY ({count} BÀI)'**
  String contestEnterGallery(int count);

  /// No description provided for @contestSeeResults.
  ///
  /// In vi, this message translates to:
  /// **'XEM KẾT QUẢ'**
  String get contestSeeResults;

  /// No description provided for @contestPrevResults.
  ///
  /// In vi, this message translates to:
  /// **'KẾT QUẢ TUẦN TRƯỚC: {title}'**
  String contestPrevResults(String title);

  /// No description provided for @contestEntriesCount.
  ///
  /// In vi, this message translates to:
  /// **'{count}/{max} bài'**
  String contestEntriesCount(int count, int max);

  /// No description provided for @contestCountdownUntil.
  ///
  /// In vi, this message translates to:
  /// **'cho đến khi {event}'**
  String contestCountdownUntil(String event);

  /// No description provided for @contestUntilOpen.
  ///
  /// In vi, this message translates to:
  /// **'bắt đầu nhận bài'**
  String get contestUntilOpen;

  /// No description provided for @contestUntilJudging.
  ///
  /// In vi, this message translates to:
  /// **'hết giờ nhận bài và bắt đầu chấm'**
  String get contestUntilJudging;

  /// No description provided for @contestUntilClosed.
  ///
  /// In vi, this message translates to:
  /// **'chốt kết quả'**
  String get contestUntilClosed;

  /// No description provided for @contestLineOpens.
  ///
  /// In vi, this message translates to:
  /// **'Nhận bài từ'**
  String get contestLineOpens;

  /// No description provided for @contestLineJudging.
  ///
  /// In vi, this message translates to:
  /// **'Chấm điểm từ'**
  String get contestLineJudging;

  /// No description provided for @contestLineJudgingNote.
  ///
  /// In vi, this message translates to:
  /// **'{moment} (hoặc khi đủ 100 bài)'**
  String contestLineJudgingNote(String moment);

  /// No description provided for @contestLineEnds.
  ///
  /// In vi, this message translates to:
  /// **'Chốt kết quả'**
  String get contestLineEnds;

  /// No description provided for @contestLineEndsNote.
  ///
  /// In vi, this message translates to:
  /// **'{moment} (23:59 CN giờ Việt Nam)'**
  String contestLineEndsNote(String moment);

  /// No description provided for @contestMyEntry.
  ///
  /// In vi, this message translates to:
  /// **'Nhóm \"{group}\" đã dự thi, bài số {seq}.'**
  String contestMyEntry(String group, int seq);

  /// No description provided for @contestNothingToRate.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có bài của nhóm khác để chấm.'**
  String get contestNothingToRate;

  /// No description provided for @contestRatedProgress.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã chấm {done}/{needed} bài'**
  String contestRatedProgress(int done, int needed);

  /// No description provided for @contestVoteRule.
  ///
  /// In vi, this message translates to:
  /// **'Phiếu của bạn chỉ được tính khi chấm đủ số bài này, và tài khoản đã đủ 7 ngày tuổi.'**
  String get contestVoteRule;

  /// No description provided for @contestOnlyOwner.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ trưởng nhóm mới nộp bài được. Hãy nhờ trưởng nhóm của bạn.'**
  String get contestOnlyOwner;

  /// No description provided for @contestGroupSubmitted.
  ///
  /// In vi, this message translates to:
  /// **'Đã nộp bài tuần này'**
  String get contestGroupSubmitted;

  /// No description provided for @contestOwnerHint.
  ///
  /// In vi, this message translates to:
  /// **'Bạn là trưởng nhóm: nộp canvas để dự thi'**
  String get contestOwnerHint;

  /// No description provided for @contestOpensAt.
  ///
  /// In vi, this message translates to:
  /// **'Nhận bài vào {moment}'**
  String contestOpensAt(String moment);

  /// No description provided for @contestSubmitButton.
  ///
  /// In vi, this message translates to:
  /// **'NỘP BÀI'**
  String get contestSubmitButton;

  /// No description provided for @contestRulesTitle.
  ///
  /// In vi, this message translates to:
  /// **'LUẬT CHƠI'**
  String get contestRulesTitle;

  /// No description provided for @contestRules.
  ///
  /// In vi, this message translates to:
  /// **'• Trưởng nhóm nộp canvas của nhóm, mỗi nhóm một bài.\n• Chỉ 100 bài nộp nhanh nhất được vào Gallery.\n• Thành viên các nhóm có bài dự thi chấm 1–5 sao và bình luận bài của nhóm khác.\n• Điểm xếp hạng là trung bình có hiệu chỉnh (Bayes), nên một vài phiếu 5 sao không đủ để vượt lên.\n• Mọi thời điểm tính theo giờ Việt Nam (UTC+7).'**
  String get contestRules;

  /// No description provided for @contestSubmittedSnack.
  ///
  /// In vi, this message translates to:
  /// **'Đã nộp! Bài của bạn là số {seq}.'**
  String contestSubmittedSnack(int seq);

  /// No description provided for @cfNotFound.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy bài dự thi.'**
  String get cfNotFound;

  /// No description provided for @cfNotOwner.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ trưởng nhóm mới nộp bài được.'**
  String get cfNotOwner;

  /// No description provided for @cfNotOpen.
  ///
  /// In vi, this message translates to:
  /// **'Chưa đến giờ nộp bài, hoặc đã hết giờ nộp.'**
  String get cfNotOpen;

  /// No description provided for @cfNotJudging.
  ///
  /// In vi, this message translates to:
  /// **'Hiện chưa phải lúc chấm điểm.'**
  String get cfNotJudging;

  /// No description provided for @cfAlreadySubmitted.
  ///
  /// In vi, this message translates to:
  /// **'Nhóm này đã nộp bài tuần này rồi.'**
  String get cfAlreadySubmitted;

  /// No description provided for @cfContestFull.
  ///
  /// In vi, this message translates to:
  /// **'Gallery tuần này đã đủ 100 bài. Hẹn bạn tuần sau!'**
  String get cfContestFull;

  /// No description provided for @cfCanvasTooEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Canvas còn quá trống. Hãy vẽ thêm rồi nộp nhé.'**
  String get cfCanvasTooEmpty;

  /// No description provided for @cfGroupTooSmall.
  ///
  /// In vi, this message translates to:
  /// **'Nhóm cần ít nhất 2 người để dự thi.'**
  String get cfGroupTooSmall;

  /// No description provided for @cfNoCanvas.
  ///
  /// In vi, this message translates to:
  /// **'Nhóm chưa có canvas.'**
  String get cfNoCanvas;

  /// No description provided for @cfNotParticipant.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ thành viên các nhóm có bài dự thi mới chấm và bình luận được.'**
  String get cfNotParticipant;

  /// No description provided for @cfOwnEntry.
  ///
  /// In vi, this message translates to:
  /// **'Bạn không chấm được bài của nhóm mình.'**
  String get cfOwnEntry;

  /// No description provided for @cfBadScore.
  ///
  /// In vi, this message translates to:
  /// **'Điểm phải từ 1 đến 5 sao.'**
  String get cfBadScore;

  /// No description provided for @cfEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Hãy nhập nội dung.'**
  String get cfEmpty;

  /// No description provided for @cfTooLong.
  ///
  /// In vi, this message translates to:
  /// **'Bình luận tối đa 200 ký tự.'**
  String get cfTooLong;

  /// No description provided for @cfTooFast.
  ///
  /// In vi, this message translates to:
  /// **'Chậm lại một chút rồi bình luận tiếp nhé.'**
  String get cfTooFast;

  /// No description provided for @cfTooMany.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã bình luận đủ số lần cho tuần này.'**
  String get cfTooMany;

  /// No description provided for @cfBlockedWord.
  ///
  /// In vi, this message translates to:
  /// **'Bình luận có từ không phù hợp.'**
  String get cfBlockedWord;

  /// No description provided for @cfTooManyReports.
  ///
  /// In vi, this message translates to:
  /// **'Hôm nay bạn đã báo cáo quá nhiều.'**
  String get cfTooManyReports;

  /// No description provided for @cfNetwork.
  ///
  /// In vi, this message translates to:
  /// **'Không kết nối được. Thử lại nhé.'**
  String get cfNetwork;

  /// No description provided for @cfUnknown.
  ///
  /// In vi, this message translates to:
  /// **'Có lỗi xảy ra. Thử lại nhé.'**
  String get cfUnknown;

  /// No description provided for @phaseUpcoming.
  ///
  /// In vi, this message translates to:
  /// **'SẮP DIỄN RA'**
  String get phaseUpcoming;

  /// No description provided for @phaseOpen.
  ///
  /// In vi, this message translates to:
  /// **'ĐANG NHẬN BÀI'**
  String get phaseOpen;

  /// No description provided for @phaseJudging.
  ///
  /// In vi, this message translates to:
  /// **'ĐANG CHẤM ĐIỂM'**
  String get phaseJudging;

  /// No description provided for @phaseClosed.
  ///
  /// In vi, this message translates to:
  /// **'ĐANG TỔNG KẾT'**
  String get phaseClosed;

  /// No description provided for @phaseFinalized.
  ///
  /// In vi, this message translates to:
  /// **'ĐÃ CÓ KẾT QUẢ'**
  String get phaseFinalized;

  /// No description provided for @countdownDays.
  ///
  /// In vi, this message translates to:
  /// **'{days} ngày {clock}'**
  String countdownDays(int days, String clock);

  /// No description provided for @milestoneOpen.
  ///
  /// In vi, this message translates to:
  /// **'đến giờ nhận bài'**
  String get milestoneOpen;

  /// No description provided for @milestoneJudging.
  ///
  /// In vi, this message translates to:
  /// **'hết giờ nhận bài, bắt đầu chấm'**
  String get milestoneJudging;

  /// No description provided for @milestoneClosed.
  ///
  /// In vi, this message translates to:
  /// **'chốt kết quả'**
  String get milestoneClosed;

  /// No description provided for @contestTimeLeft.
  ///
  /// In vi, this message translates to:
  /// **'Còn {time} {event}'**
  String contestTimeLeft(String time, String event);

  /// No description provided for @contestBannerTitle.
  ///
  /// In vi, this message translates to:
  /// **'CUỘC THI TUẦN · {phase}'**
  String contestBannerTitle(String phase);

  /// No description provided for @contestBannerSemantics.
  ///
  /// In vi, this message translates to:
  /// **'Cuộc thi tuần {week}: {title}. {phase}'**
  String contestBannerSemantics(String week, String title, String phase);

  /// No description provided for @weekdayMon.
  ///
  /// In vi, this message translates to:
  /// **'Th 2'**
  String get weekdayMon;

  /// No description provided for @weekdayTue.
  ///
  /// In vi, this message translates to:
  /// **'Th 3'**
  String get weekdayTue;

  /// No description provided for @weekdayWed.
  ///
  /// In vi, this message translates to:
  /// **'Th 4'**
  String get weekdayWed;

  /// No description provided for @weekdayThu.
  ///
  /// In vi, this message translates to:
  /// **'Th 5'**
  String get weekdayThu;

  /// No description provided for @weekdayFri.
  ///
  /// In vi, this message translates to:
  /// **'Th 6'**
  String get weekdayFri;

  /// No description provided for @weekdaySat.
  ///
  /// In vi, this message translates to:
  /// **'Th 7'**
  String get weekdaySat;

  /// No description provided for @weekdaySun.
  ///
  /// In vi, this message translates to:
  /// **'CN'**
  String get weekdaySun;

  /// No description provided for @entryHeader.
  ///
  /// In vi, this message translates to:
  /// **'Bài số {seq} · nộp {moment}'**
  String entryHeader(int seq, String moment);

  /// No description provided for @reportEntryTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Báo cáo bài này'**
  String get reportEntryTooltip;

  /// No description provided for @entryArtSemantics.
  ///
  /// In vi, this message translates to:
  /// **'Tranh của nhóm {group}, bài số {seq}'**
  String entryArtSemantics(String group, int seq);

  /// No description provided for @commentsTitle.
  ///
  /// In vi, this message translates to:
  /// **'BÌNH LUẬN'**
  String get commentsTitle;

  /// No description provided for @commentsTitleCount.
  ///
  /// In vi, this message translates to:
  /// **'BÌNH LUẬN ({count})'**
  String commentsTitleCount(int count);

  /// No description provided for @noComments.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có bình luận.'**
  String get noComments;

  /// No description provided for @rank1.
  ///
  /// In vi, this message translates to:
  /// **'HẠNG NHẤT'**
  String get rank1;

  /// No description provided for @rank2.
  ///
  /// In vi, this message translates to:
  /// **'HẠNG NHÌ'**
  String get rank2;

  /// No description provided for @rank3.
  ///
  /// In vi, this message translates to:
  /// **'HẠNG BA'**
  String get rank3;

  /// No description provided for @rankTop3.
  ///
  /// In vi, this message translates to:
  /// **'TOP 3'**
  String get rankTop3;

  /// No description provided for @rankScoreLine.
  ///
  /// In vi, this message translates to:
  /// **'{rank}  ·  {score} điểm ({votes} phiếu)'**
  String rankScoreLine(String rank, String score, int votes);

  /// No description provided for @ratingLoading.
  ///
  /// In vi, this message translates to:
  /// **'Đang tải…'**
  String get ratingLoading;

  /// No description provided for @ratingOwnGroup.
  ///
  /// In vi, this message translates to:
  /// **'Đây là bài của nhóm bạn. Bạn không tự chấm được.'**
  String get ratingOwnGroup;

  /// No description provided for @ratingNotParticipant.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ thành viên các nhóm có bài dự thi mới chấm điểm được.'**
  String get ratingNotParticipant;

  /// No description provided for @ratingContestOver.
  ///
  /// In vi, this message translates to:
  /// **'Cuộc thi đã kết thúc.'**
  String get ratingContestOver;

  /// No description provided for @ratingNotYet.
  ///
  /// In vi, this message translates to:
  /// **'Chưa đến giờ chấm điểm.'**
  String get ratingNotYet;

  /// No description provided for @ratingTapStar.
  ///
  /// In vi, this message translates to:
  /// **'Chạm vào ngôi sao để chấm. Bạn sửa được đến hết cuộc thi.'**
  String get ratingTapStar;

  /// No description provided for @ratingYouGave.
  ///
  /// In vi, this message translates to:
  /// **'Bạn chấm {stars} sao. Chạm để đổi.'**
  String ratingYouGave(int stars);

  /// No description provided for @rateStars.
  ///
  /// In vi, this message translates to:
  /// **'Chấm {stars} sao'**
  String rateStars(int stars);

  /// No description provided for @commentYou.
  ///
  /// In vi, this message translates to:
  /// **'Bạn'**
  String get commentYou;

  /// No description provided for @reportCommentTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Báo cáo bình luận'**
  String get reportCommentTooltip;

  /// No description provided for @writeCommentHint.
  ///
  /// In vi, this message translates to:
  /// **'Viết bình luận…'**
  String get writeCommentHint;

  /// No description provided for @sendTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Gửi'**
  String get sendTooltip;

  /// No description provided for @resultsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Kết quả'**
  String get resultsTitle;

  /// No description provided for @resultsTitleWeek.
  ///
  /// In vi, this message translates to:
  /// **'Kết quả: {title}'**
  String resultsTitleWeek(String title);

  /// No description provided for @resultsLater.
  ///
  /// In vi, this message translates to:
  /// **'Kết quả sẽ có lúc 23:59 Chủ nhật (giờ Việt Nam).'**
  String get resultsLater;

  /// No description provided for @resultsNoEntries.
  ///
  /// In vi, this message translates to:
  /// **'Tuần này chưa có bài dự thi nào.'**
  String get resultsNoEntries;

  /// No description provided for @resultsNoRanked.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có bài nào đủ số phiếu hợp lệ để xếp hạng (cần ít nhất 3 phiếu).'**
  String get resultsNoRanked;

  /// No description provided for @resultsEntryCount.
  ///
  /// In vi, this message translates to:
  /// **'{count} bài dự thi · {week}'**
  String resultsEntryCount(int count, String week);

  /// No description provided for @resultsScoreVotes.
  ///
  /// In vi, this message translates to:
  /// **'{score} · {votes} phiếu'**
  String resultsScoreVotes(String score, int votes);

  /// No description provided for @submitSheetTitle.
  ///
  /// In vi, this message translates to:
  /// **'NỘP BÀI: {group}'**
  String submitSheetTitle(String group);

  /// No description provided for @canvasWillBeSubmitted.
  ///
  /// In vi, this message translates to:
  /// **'Canvas sẽ được nộp'**
  String get canvasWillBeSubmitted;

  /// No description provided for @noPreview.
  ///
  /// In vi, this message translates to:
  /// **'Không xem trước được.'**
  String get noPreview;

  /// No description provided for @submitSpotsLeft.
  ///
  /// In vi, this message translates to:
  /// **'Đã có {count}/{max} bài. Chỉ {max} bài nộp nhanh nhất vào Gallery.'**
  String submitSpotsLeft(int count, int max);

  /// No description provided for @submitGalleryFull.
  ///
  /// In vi, this message translates to:
  /// **'Gallery đã đủ {max} bài.'**
  String submitGalleryFull(int max);

  /// No description provided for @submitSnapshotNote.
  ///
  /// In vi, this message translates to:
  /// **'Bản chụp canvas được lấy ngay lúc nộp và không đổi được nữa. Mỗi nhóm nộp một bài mỗi tuần.'**
  String get submitSnapshotNote;

  /// No description provided for @submitting.
  ///
  /// In vi, this message translates to:
  /// **'ĐANG NỘP…'**
  String get submitting;

  /// No description provided for @galleryViewCorridor.
  ///
  /// In vi, this message translates to:
  /// **'Xem dạng hành lang'**
  String get galleryViewCorridor;

  /// No description provided for @galleryViewGrid.
  ///
  /// In vi, this message translates to:
  /// **'Xem dạng lưới'**
  String get galleryViewGrid;

  /// No description provided for @galleryEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Hành lang còn trống. Bài dự thi sẽ xuất hiện ở đây khi các nhóm nộp bài.'**
  String get galleryEmpty;

  /// No description provided for @galleryLoadMoreFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không tải thêm được. Kéo lên để thử lại.'**
  String get galleryLoadMoreFailed;

  /// No description provided for @galleryEntrySemantics.
  ///
  /// In vi, this message translates to:
  /// **'Bài số {seq}, nhóm {group}'**
  String galleryEntrySemantics(int seq, String group);

  /// No description provided for @corridorSemantics.
  ///
  /// In vi, this message translates to:
  /// **'Hành lang triển lãm với {count} bức tranh. Vuốt lên để đi tới, chạm một bức để xem. Dùng nút Xem dạng lưới để duyệt bằng danh sách.'**
  String corridorSemantics(int count);

  /// No description provided for @walkForward.
  ///
  /// In vi, this message translates to:
  /// **'Đi tới'**
  String get walkForward;

  /// No description provided for @walkBack.
  ///
  /// In vi, this message translates to:
  /// **'Đi lui'**
  String get walkBack;

  /// No description provided for @groupsInvitesTitle.
  ///
  /// In vi, this message translates to:
  /// **'LỜI MỜI VÀO NHÓM'**
  String get groupsInvitesTitle;

  /// No description provided for @groupsStale.
  ///
  /// In vi, this message translates to:
  /// **'Không cập nhật được. Đang hiện dữ liệu cũ.'**
  String get groupsStale;

  /// No description provided for @groupsLoadFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được danh sách nhóm.'**
  String get groupsLoadFailed;

  /// No description provided for @groupsEmptyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có nhóm nào'**
  String get groupsEmptyTitle;

  /// No description provided for @groupsEmptyBody.
  ///
  /// In vi, this message translates to:
  /// **'Tạo nhóm với bạn bè để cùng nhắn tin và cùng vẽ một canvas pixel. Mỗi nhiệm vụ hằng ngày cho bạn 10 mực, mỗi ô vẽ tốn 1 mực.'**
  String get groupsEmptyBody;

  /// No description provided for @groupPreviewNone.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có tin nhắn'**
  String get groupPreviewNone;

  /// No description provided for @groupPreviewActivity.
  ///
  /// In vi, this message translates to:
  /// **'Hoạt động mới trong nhóm'**
  String get groupPreviewActivity;

  /// No description provided for @memberCount.
  ///
  /// In vi, this message translates to:
  /// **'{count} thành viên'**
  String memberCount(int count);

  /// No description provided for @groupTileSemantics.
  ///
  /// In vi, this message translates to:
  /// **'Nhóm {name}, {members}'**
  String groupTileSemantics(String name, String members);

  /// No description provided for @groupTileSemanticsUnread.
  ///
  /// In vi, this message translates to:
  /// **'Nhóm {name}, {members}, {unread} tin chưa đọc'**
  String groupTileSemanticsUnread(String name, String members, int unread);

  /// No description provided for @groupMembersLine.
  ///
  /// In vi, this message translates to:
  /// **'{count}/{max} thành viên'**
  String groupMembersLine(int count, int max);

  /// No description provided for @groupMembersLineOwner.
  ///
  /// In vi, this message translates to:
  /// **'{count}/{max} thành viên · trưởng nhóm'**
  String groupMembersLineOwner(int count, int max);

  /// No description provided for @groupJoinedSnack.
  ///
  /// In vi, this message translates to:
  /// **'Đã vào nhóm {name}.'**
  String groupJoinedSnack(String name);

  /// No description provided for @groupInviteFrom.
  ///
  /// In vi, this message translates to:
  /// **'{person} mời bạn vào nhóm'**
  String groupInviteFrom(String person);

  /// No description provided for @groupJoin.
  ///
  /// In vi, this message translates to:
  /// **'THAM GIA'**
  String get groupJoin;

  /// No description provided for @groupCreateTitle.
  ///
  /// In vi, this message translates to:
  /// **'TẠO NHÓM MỚI'**
  String get groupCreateTitle;

  /// No description provided for @groupNameLabel.
  ///
  /// In vi, this message translates to:
  /// **'Tên nhóm'**
  String get groupNameLabel;

  /// No description provided for @groupRulesOptional.
  ///
  /// In vi, this message translates to:
  /// **'Quy tắc (không bắt buộc)'**
  String get groupRulesOptional;

  /// No description provided for @groupMaxMembers.
  ///
  /// In vi, this message translates to:
  /// **'Số thành viên tối đa'**
  String get groupMaxMembers;

  /// No description provided for @decrease.
  ///
  /// In vi, this message translates to:
  /// **'Giảm'**
  String get decrease;

  /// No description provided for @increase.
  ///
  /// In vi, this message translates to:
  /// **'Tăng'**
  String get increase;

  /// No description provided for @groupCreating.
  ///
  /// In vi, this message translates to:
  /// **'ĐANG TẠO…'**
  String get groupCreating;

  /// No description provided for @segmentGroups.
  ///
  /// In vi, this message translates to:
  /// **'NHÓM'**
  String get segmentGroups;

  /// No description provided for @personFriendsNote.
  ///
  /// In vi, this message translates to:
  /// **'Hai bạn là bạn bè: ảnh mới của nhau hiện trong feed.'**
  String get personFriendsNote;

  /// No description provided for @personNotFriendsNote.
  ///
  /// In vi, this message translates to:
  /// **'Ở chung nhóm chưa phải là bạn bè. Chỉ khi kết bạn, hai người mới xem được ảnh của nhau.'**
  String get personNotFriendsNote;

  /// No description provided for @personAlreadyFriends.
  ///
  /// In vi, this message translates to:
  /// **'ĐÃ LÀ BẠN BÈ'**
  String get personAlreadyFriends;

  /// No description provided for @personRequestSent.
  ///
  /// In vi, this message translates to:
  /// **'ĐÃ GỬI LỜI MỜI'**
  String get personRequestSent;

  /// No description provided for @personBefriend.
  ///
  /// In vi, this message translates to:
  /// **'KẾT BẠN'**
  String get personBefriend;

  /// No description provided for @reportFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không gửi được báo cáo. Thử lại nhé.'**
  String get reportFailed;

  /// No description provided for @blockFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không chặn được. Thử lại nhé.'**
  String get blockFailed;

  /// No description provided for @sysJoined.
  ///
  /// In vi, this message translates to:
  /// **'{name} đã tham gia nhóm'**
  String sysJoined(String name);

  /// No description provided for @sysLeft.
  ///
  /// In vi, this message translates to:
  /// **'{name} đã rời nhóm'**
  String sysLeft(String name);

  /// No description provided for @sysKicked.
  ///
  /// In vi, this message translates to:
  /// **'{name} đã bị mời ra khỏi nhóm'**
  String sysKicked(String name);

  /// No description provided for @sysOwnerChanged.
  ///
  /// In vi, this message translates to:
  /// **'{name} là trưởng nhóm mới'**
  String sysOwnerChanged(String name);

  /// No description provided for @sysEntrySubmitted.
  ///
  /// In vi, this message translates to:
  /// **'Nhóm đã nộp bài dự thi tuần này'**
  String get sysEntrySubmitted;

  /// No description provided for @gfNotFound.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy nhóm hoặc người này.'**
  String get gfNotFound;

  /// No description provided for @gfNotOwner.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ trưởng nhóm mới làm được việc này.'**
  String get gfNotOwner;

  /// No description provided for @gfNotMember.
  ///
  /// In vi, this message translates to:
  /// **'Bạn không còn ở trong nhóm này.'**
  String get gfNotMember;

  /// No description provided for @gfSelf.
  ///
  /// In vi, this message translates to:
  /// **'Không thể làm việc này với chính mình.'**
  String get gfSelf;

  /// No description provided for @gfEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Hãy nhập nội dung.'**
  String get gfEmpty;

  /// No description provided for @gfTooLong.
  ///
  /// In vi, this message translates to:
  /// **'Nội dung quá dài.'**
  String get gfTooLong;

  /// No description provided for @gfBlockedWord.
  ///
  /// In vi, this message translates to:
  /// **'Có từ không phù hợp. Hãy dùng ngôn từ lịch sự để mọi người cùng vui nhé.'**
  String get gfBlockedWord;

  /// No description provided for @gfBadName.
  ///
  /// In vi, this message translates to:
  /// **'Tên nhóm cần từ 1 đến 40 ký tự.'**
  String get gfBadName;

  /// No description provided for @gfBadSize.
  ///
  /// In vi, this message translates to:
  /// **'Số thành viên tối đa phải từ 2 đến 12 và không nhỏ hơn số người hiện có.'**
  String get gfBadSize;

  /// No description provided for @gfGroupLimit.
  ///
  /// In vi, this message translates to:
  /// **'Bạn chỉ được ở tối đa 5 nhóm và làm trưởng tối đa 3 nhóm.'**
  String get gfGroupLimit;

  /// No description provided for @gfMemberLimit.
  ///
  /// In vi, this message translates to:
  /// **'Nhóm đã đủ người (kể cả lời mời đang chờ).'**
  String get gfMemberLimit;

  /// No description provided for @gfTheirGroupLimit.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đang ở quá nhiều nhóm (tối đa 5).'**
  String get gfTheirGroupLimit;

  /// No description provided for @gfAlreadyMember.
  ///
  /// In vi, this message translates to:
  /// **'Người này đã ở trong nhóm.'**
  String get gfAlreadyMember;

  /// No description provided for @gfAlreadyInvited.
  ///
  /// In vi, this message translates to:
  /// **'Đã mời người này rồi.'**
  String get gfAlreadyInvited;

  /// No description provided for @gfExpired.
  ///
  /// In vi, this message translates to:
  /// **'Lời mời đã hết hạn.'**
  String get gfExpired;

  /// No description provided for @gfOwnerMustTransfer.
  ///
  /// In vi, this message translates to:
  /// **'Hãy chuyển quyền trưởng nhóm cho người khác trước khi rời.'**
  String get gfOwnerMustTransfer;

  /// No description provided for @gfNetwork.
  ///
  /// In vi, this message translates to:
  /// **'Không kết nối được. Thử lại nhé.'**
  String get gfNetwork;

  /// No description provided for @gfUnknown.
  ///
  /// In vi, this message translates to:
  /// **'Có lỗi xảy ra. Thử lại nhé.'**
  String get gfUnknown;

  /// No description provided for @kfInsufficientInk.
  ///
  /// In vi, this message translates to:
  /// **'Hết mực. Hoàn thành nhiệm vụ hằng ngày để nhận thêm 10 mực.'**
  String get kfInsufficientInk;

  /// No description provided for @kfRateLimited.
  ///
  /// In vi, this message translates to:
  /// **'Vẽ chậm lại một chút (tối đa 30 ô/phút).'**
  String get kfRateLimited;

  /// No description provided for @kfCanvasLocked.
  ///
  /// In vi, this message translates to:
  /// **'Canvas này đã được lưu trữ.'**
  String get kfCanvasLocked;

  /// No description provided for @kfNotFound.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy canvas.'**
  String get kfNotFound;

  /// No description provided for @kfNotOwner.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ trưởng nhóm mới làm được việc này.'**
  String get kfNotOwner;

  /// No description provided for @kfBadPixel.
  ///
  /// In vi, this message translates to:
  /// **'Ô vẽ không hợp lệ.'**
  String get kfBadPixel;

  /// No description provided for @kfBadSize.
  ///
  /// In vi, this message translates to:
  /// **'Kích thước hoặc bảng màu không hợp lệ.'**
  String get kfBadSize;

  /// No description provided for @kfNetwork.
  ///
  /// In vi, this message translates to:
  /// **'Mất kết nối. Canvas chuyển sang chế độ chỉ xem.'**
  String get kfNetwork;

  /// No description provided for @groupSettingsTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Cài đặt nhóm'**
  String get groupSettingsTooltip;

  /// No description provided for @youLabel.
  ///
  /// In vi, this message translates to:
  /// **'Bạn'**
  String get youLabel;

  /// No description provided for @someoneLabel.
  ///
  /// In vi, this message translates to:
  /// **'Một người'**
  String get someoneLabel;

  /// No description provided for @chatLoadFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được tin nhắn.'**
  String get chatLoadFailed;

  /// No description provided for @chatSayHi.
  ///
  /// In vi, this message translates to:
  /// **'Hãy chào cả nhóm 👋'**
  String get chatSayHi;

  /// No description provided for @chatHint.
  ///
  /// In vi, this message translates to:
  /// **'Nhắn cho cả nhóm…'**
  String get chatHint;

  /// No description provided for @groupSettingsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Cài đặt nhóm'**
  String get groupSettingsTitle;

  /// No description provided for @ownerBadge.
  ///
  /// In vi, this message translates to:
  /// **'TRƯỞNG NHÓM'**
  String get ownerBadge;

  /// No description provided for @sectionInfo.
  ///
  /// In vi, this message translates to:
  /// **'THÔNG TIN'**
  String get sectionInfo;

  /// No description provided for @sectionMembers.
  ///
  /// In vi, this message translates to:
  /// **'THÀNH VIÊN ({count}/{max})'**
  String sectionMembers(int count, int max);

  /// No description provided for @inviteToGroup.
  ///
  /// In vi, this message translates to:
  /// **'MỜI BẠN VÀO NHÓM'**
  String get inviteToGroup;

  /// No description provided for @inviteNote.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ mời được bạn bè của bạn. Lời mời hết hạn sau 7 ngày.'**
  String get inviteNote;

  /// No description provided for @sectionPendingInvites.
  ///
  /// In vi, this message translates to:
  /// **'LỜI MỜI ĐANG CHỜ'**
  String get sectionPendingInvites;

  /// No description provided for @newCanvasButton.
  ///
  /// In vi, this message translates to:
  /// **'TẠO CANVAS MỚI'**
  String get newCanvasButton;

  /// No description provided for @leaveGroup.
  ///
  /// In vi, this message translates to:
  /// **'RỜI NHÓM'**
  String get leaveGroup;

  /// No description provided for @dissolveGroup.
  ///
  /// In vi, this message translates to:
  /// **'GIẢI TÁN NHÓM'**
  String get dissolveGroup;

  /// No description provided for @rulesNone.
  ///
  /// In vi, this message translates to:
  /// **'Nhóm chưa đặt quy tắc.'**
  String get rulesNone;

  /// No description provided for @rulesLabel.
  ///
  /// In vi, this message translates to:
  /// **'Quy tắc'**
  String get rulesLabel;

  /// No description provided for @memberYou.
  ///
  /// In vi, this message translates to:
  /// **'{name} (bạn)'**
  String memberYou(String name);

  /// No description provided for @ownerRole.
  ///
  /// In vi, this message translates to:
  /// **'Trưởng nhóm'**
  String get ownerRole;

  /// No description provided for @optionsTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Tuỳ chọn'**
  String get optionsTooltip;

  /// No description provided for @menuTransfer.
  ///
  /// In vi, this message translates to:
  /// **'Chuyển quyền trưởng nhóm'**
  String get menuTransfer;

  /// No description provided for @menuRollback.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn tác nét vẽ (24 giờ)'**
  String get menuRollback;

  /// No description provided for @menuKick.
  ///
  /// In vi, this message translates to:
  /// **'Mời ra khỏi nhóm'**
  String get menuKick;

  /// No description provided for @revokeInvite.
  ///
  /// In vi, this message translates to:
  /// **'THU HỒI'**
  String get revokeInvite;

  /// No description provided for @inviteFriendsTitle.
  ///
  /// In vi, this message translates to:
  /// **'MỜI BẠN BÈ'**
  String get inviteFriendsTitle;

  /// No description provided for @noOneToInvite.
  ///
  /// In vi, this message translates to:
  /// **'Không còn người bạn nào để mời. Chỉ mời được bạn bè của bạn.'**
  String get noOneToInvite;

  /// No description provided for @newCanvasTitle.
  ///
  /// In vi, this message translates to:
  /// **'Canvas mới'**
  String get newCanvasTitle;

  /// No description provided for @sizeLabel.
  ///
  /// In vi, this message translates to:
  /// **'Kích thước'**
  String get sizeLabel;

  /// No description provided for @paletteLabel.
  ///
  /// In vi, this message translates to:
  /// **'Bảng màu'**
  String get paletteLabel;

  /// No description provided for @savedSnack.
  ///
  /// In vi, this message translates to:
  /// **'Đã lưu.'**
  String get savedSnack;

  /// No description provided for @kickTitle.
  ///
  /// In vi, this message translates to:
  /// **'Mời {name} ra khỏi nhóm?'**
  String kickTitle(String name);

  /// No description provided for @kickBody.
  ///
  /// In vi, this message translates to:
  /// **'Họ sẽ không đọc được tin nhắn của nhóm nữa. Những ô họ đã vẽ vẫn giữ nguyên.'**
  String get kickBody;

  /// No description provided for @kickAction.
  ///
  /// In vi, this message translates to:
  /// **'Mời ra'**
  String get kickAction;

  /// No description provided for @transferTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chuyển quyền trưởng nhóm?'**
  String get transferTitle;

  /// No description provided for @transferBody.
  ///
  /// In vi, this message translates to:
  /// **'{name} sẽ là trưởng nhóm mới. Bạn trở thành thành viên thường.'**
  String transferBody(String name);

  /// No description provided for @transferAction.
  ///
  /// In vi, this message translates to:
  /// **'Chuyển quyền'**
  String get transferAction;

  /// No description provided for @transferDone.
  ///
  /// In vi, this message translates to:
  /// **'{name} là trưởng nhóm mới.'**
  String transferDone(String name);

  /// No description provided for @rollbackTitle.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn tác nét vẽ của {name}?'**
  String rollbackTitle(String name);

  /// No description provided for @rollbackBody.
  ///
  /// In vi, this message translates to:
  /// **'Những ô họ vẽ trong 24 giờ qua và chưa bị ai vẽ đè sẽ quay về màu trước đó. Mực của họ không được hoàn lại.'**
  String get rollbackBody;

  /// No description provided for @rollbackAction.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn tác'**
  String get rollbackAction;

  /// No description provided for @rollbackDone.
  ///
  /// In vi, this message translates to:
  /// **'Đã hoàn tác {count} ô.'**
  String rollbackDone(int count);

  /// No description provided for @leaveTitle.
  ///
  /// In vi, this message translates to:
  /// **'Rời nhóm {group}?'**
  String leaveTitle(String group);

  /// No description provided for @leaveBody.
  ///
  /// In vi, this message translates to:
  /// **'Bạn sẽ không đọc được tin nhắn và canvas của nhóm nữa.'**
  String get leaveBody;

  /// No description provided for @leaveAction.
  ///
  /// In vi, this message translates to:
  /// **'Rời nhóm'**
  String get leaveAction;

  /// No description provided for @dissolveTitle.
  ///
  /// In vi, this message translates to:
  /// **'Giải tán nhóm {group}?'**
  String dissolveTitle(String group);

  /// No description provided for @dissolveBody.
  ///
  /// In vi, this message translates to:
  /// **'Cả nhóm sẽ mất quyền xem tin nhắn và canvas. Không thể hoàn tác.'**
  String get dissolveBody;

  /// No description provided for @dissolveAction.
  ///
  /// In vi, this message translates to:
  /// **'Giải tán'**
  String get dissolveAction;

  /// No description provided for @invitedSnack.
  ///
  /// In vi, this message translates to:
  /// **'Đã mời {name}.'**
  String invitedSnack(String name);

  /// No description provided for @newCanvasConfirmTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu canvas mới?'**
  String get newCanvasConfirmTitle;

  /// No description provided for @newCanvasConfirmBody.
  ///
  /// In vi, this message translates to:
  /// **'Canvas hiện tại được lưu lại và không vẽ thêm được nữa. Canvas mới bắt đầu trống.'**
  String get newCanvasConfirmBody;

  /// No description provided for @newCanvasConfirmAction.
  ///
  /// In vi, this message translates to:
  /// **'Tạo canvas'**
  String get newCanvasConfirmAction;

  /// No description provided for @newCanvasDone.
  ///
  /// In vi, this message translates to:
  /// **'Đã tạo canvas mới.'**
  String get newCanvasDone;

  /// No description provided for @avatarTitle.
  ///
  /// In vi, this message translates to:
  /// **'ẢNH ĐẠI DIỆN'**
  String get avatarTitle;

  /// No description provided for @avatarTakePhoto.
  ///
  /// In vi, this message translates to:
  /// **'CHỤP ẢNH'**
  String get avatarTakePhoto;

  /// No description provided for @avatarFromLibrary.
  ///
  /// In vi, this message translates to:
  /// **'CHỌN TỪ THƯ VIỆN'**
  String get avatarFromLibrary;

  /// No description provided for @avatarChange.
  ///
  /// In vi, this message translates to:
  /// **'ĐỔI ẢNH'**
  String get avatarChange;

  /// No description provided for @avatarChangeFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không đổi được ảnh đại diện.'**
  String get avatarChangeFailed;

  /// No description provided for @questsDoneTitle.
  ///
  /// In vi, this message translates to:
  /// **'NHIỆM VỤ ĐÃ HOÀN THÀNH'**
  String get questsDoneTitle;

  /// No description provided for @questsNoneYet.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có nhiệm vụ nào. Mở tab CHỤP để làm nhiệm vụ hôm nay và nhận 25 Sunbit!'**
  String get questsNoneYet;

  /// No description provided for @postsTitle.
  ///
  /// In vi, this message translates to:
  /// **'BÀI ĐĂNG'**
  String get postsTitle;

  /// No description provided for @inkAmountSemantics.
  ///
  /// In vi, this message translates to:
  /// **'{amount} mực'**
  String inkAmountSemantics(int amount);

  /// No description provided for @inkAmountLabel.
  ///
  /// In vi, this message translates to:
  /// **'{amount} MỰC'**
  String inkAmountLabel(int amount);

  /// No description provided for @streakSemantics.
  ///
  /// In vi, this message translates to:
  /// **'Streak {streak} ngày'**
  String streakSemantics(int streak);

  /// No description provided for @musicOn.
  ///
  /// In vi, this message translates to:
  /// **'Bật nhạc'**
  String get musicOn;

  /// No description provided for @musicOff.
  ///
  /// In vi, this message translates to:
  /// **'Tắt nhạc'**
  String get musicOff;

  /// No description provided for @photoMissingRetake.
  ///
  /// In vi, this message translates to:
  /// **'KHÔNG TÌM THẤY ẢNH · HÃY CHỤP LẠI'**
  String get photoMissingRetake;

  /// No description provided for @newDayQuest.
  ///
  /// In vi, this message translates to:
  /// **'ĐÃ SANG NGÀY MỚI · CÓ NHIỆM VỤ MỚI!'**
  String get newDayQuest;

  /// No description provided for @outOfTriesTitle.
  ///
  /// In vi, this message translates to:
  /// **'HẾT LƯỢT HÔM NAY'**
  String get outOfTriesTitle;

  /// No description provided for @outOfTriesBody.
  ///
  /// In vi, this message translates to:
  /// **'Không đúng. Bạn đã dùng hết 3 lượt thử hôm nay. Nhiệm vụ mới sẽ đến lúc 00:00.'**
  String get outOfTriesBody;

  /// No description provided for @wrongTriesLeft.
  ///
  /// In vi, this message translates to:
  /// **'KHÔNG ĐÚNG · CÒN {left} LƯỢT THỬ{debug}'**
  String wrongTriesLeft(int left, String debug);

  /// No description provided for @questModeBanner.
  ///
  /// In vi, this message translates to:
  /// **'CHẾ ĐỘ NHIỆM VỤ · CHỈ CHỤP TRỰC TIẾP'**
  String get questModeBanner;

  /// No description provided for @shootSubject.
  ///
  /// In vi, this message translates to:
  /// **'Chụp {subject}'**
  String shootSubject(String subject);

  /// No description provided for @exitQuestMode.
  ///
  /// In vi, this message translates to:
  /// **'Thoát chế độ nhiệm vụ'**
  String get exitQuestMode;

  /// No description provided for @checkingPhoto.
  ///
  /// In vi, this message translates to:
  /// **'ĐANG KIỂM TRA...'**
  String get checkingPhoto;

  /// No description provided for @questSemantics.
  ///
  /// In vi, this message translates to:
  /// **'Nhiệm vụ hôm nay: chụp {subject}'**
  String questSemantics(String subject);

  /// No description provided for @questTodayLabel.
  ///
  /// In vi, this message translates to:
  /// **'NHIỆM VỤ HÔM NAY · {style}'**
  String questTodayLabel(String style);

  /// No description provided for @qsDone.
  ///
  /// In vi, this message translates to:
  /// **'XONG ✓'**
  String get qsDone;

  /// No description provided for @qsPostNow.
  ///
  /// In vi, this message translates to:
  /// **'ĐĂNG NGAY'**
  String get qsPostNow;

  /// No description provided for @qsOutOfTries.
  ///
  /// In vi, this message translates to:
  /// **'HẾT LƯỢT'**
  String get qsOutOfTries;

  /// No description provided for @triesLeft.
  ///
  /// In vi, this message translates to:
  /// **'Còn {left} lượt thử'**
  String triesLeft(int left);

  /// No description provided for @shootToday.
  ///
  /// In vi, this message translates to:
  /// **'HÔM NAY, HÃY CHỤP'**
  String get shootToday;

  /// No description provided for @rewardWithBonus.
  ///
  /// In vi, this message translates to:
  /// **'+{reward} Sunbit, +{bonus} thưởng streak {streak} ngày!'**
  String rewardWithBonus(int reward, int bonus, int streak);

  /// No description provided for @rewardPlain.
  ///
  /// In vi, this message translates to:
  /// **'+{reward} Sunbit · thêm +{bonus} mỗi {every} ngày streak'**
  String rewardPlain(int reward, int bonus, int every);

  /// No description provided for @questRulesNote.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ chụp trực tiếp bằng camera · 3 lượt thử mỗi ngày · Ngày mới bắt đầu lúc 00:00 giờ Việt Nam'**
  String get questRulesNote;

  /// No description provided for @startShooting.
  ///
  /// In vi, this message translates to:
  /// **'BẮT ĐẦU CHỤP'**
  String get startShooting;

  /// No description provided for @postQuestPhoto.
  ///
  /// In vi, this message translates to:
  /// **'ĐĂNG ẢNH NHIỆM VỤ'**
  String get postQuestPhoto;

  /// No description provided for @questCompletedBtn.
  ///
  /// In vi, this message translates to:
  /// **'ĐÃ HOÀN THÀNH ✓'**
  String get questCompletedBtn;

  /// No description provided for @questNextAt.
  ///
  /// In vi, this message translates to:
  /// **'Nhiệm vụ mới sẽ đến lúc 00:00. Hẹn gặp lại!'**
  String get questNextAt;

  /// No description provided for @questAllTriesUsed.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã dùng hết 3 lượt thử. Nhiệm vụ mới sẽ đến lúc 00:00.'**
  String get questAllTriesUsed;

  /// No description provided for @postFailedTitle.
  ///
  /// In vi, this message translates to:
  /// **'KHÔNG ĐĂNG ĐƯỢC'**
  String get postFailedTitle;

  /// No description provided for @closeAction.
  ///
  /// In vi, this message translates to:
  /// **'ĐÓNG'**
  String get closeAction;

  /// No description provided for @postSuccessTitle.
  ///
  /// In vi, this message translates to:
  /// **'ĐĂNG THÀNH CÔNG!'**
  String get postSuccessTitle;

  /// No description provided for @niceAction.
  ///
  /// In vi, this message translates to:
  /// **'TUYỆT!'**
  String get niceAction;

  /// No description provided for @rewardQuest.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn thành nhiệm vụ'**
  String get rewardQuest;

  /// No description provided for @rewardStreak.
  ///
  /// In vi, this message translates to:
  /// **'Thưởng streak {days} ngày'**
  String rewardStreak(int days);

  /// No description provided for @rewardInk.
  ///
  /// In vi, this message translates to:
  /// **'Mực để vẽ canvas nhóm'**
  String get rewardInk;

  /// No description provided for @streakNew.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu streak mới. Quay lại vào ngày mai nhé!'**
  String get streakNew;

  /// No description provided for @streakDaysRow.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã hoàn thành {days} ngày liên tiếp!'**
  String streakDaysRow(int days);

  /// No description provided for @laterTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Để sau (ảnh vẫn được giữ đến hết hôm nay)'**
  String get laterTooltip;

  /// No description provided for @photoNailedTitle.
  ///
  /// In vi, this message translates to:
  /// **'CHUẨN RỒI! {emoji}'**
  String photoNailedTitle(String emoji);

  /// No description provided for @photoAcceptedTitle.
  ///
  /// In vi, this message translates to:
  /// **'ẢNH ĐẠT YÊU CẦU'**
  String get photoAcceptedTitle;

  /// No description provided for @transformFailed.
  ///
  /// In vi, this message translates to:
  /// **'Chưa biến đổi được ảnh. Ảnh gốc vẫn an toàn.'**
  String get transformFailed;

  /// No description provided for @captionLabel.
  ///
  /// In vi, this message translates to:
  /// **'CHÚ THÍCH'**
  String get captionLabel;

  /// No description provided for @captionHint.
  ///
  /// In vi, this message translates to:
  /// **'Viết một dòng ngắn...'**
  String get captionHint;

  /// No description provided for @postingBusy.
  ///
  /// In vi, this message translates to:
  /// **'ĐANG ĐĂNG...'**
  String get postingBusy;

  /// No description provided for @postToProfile.
  ///
  /// In vi, this message translates to:
  /// **'ĐĂNG LÊN TRANG CÁ NHÂN'**
  String get postToProfile;

  /// No description provided for @questMusicOrchestral.
  ///
  /// In vi, this message translates to:
  /// **'Post nhiệm vụ có nhạc giao hưởng riêng khi bạn bè lướt đến.'**
  String get questMusicOrchestral;

  /// No description provided for @questMusicChiptune.
  ///
  /// In vi, this message translates to:
  /// **'Post nhiệm vụ có nhạc chiptune riêng khi bạn bè lướt đến.'**
  String get questMusicChiptune;

  /// No description provided for @shopDecorate.
  ///
  /// In vi, this message translates to:
  /// **'TRANG TRÍ TRANG CÁ NHÂN'**
  String get shopDecorate;

  /// No description provided for @shopInUse.
  ///
  /// In vi, this message translates to:
  /// **'ĐANG DÙNG'**
  String get shopInUse;

  /// No description provided for @shopOwned.
  ///
  /// In vi, this message translates to:
  /// **'ĐÃ CÓ'**
  String get shopOwned;

  /// No description provided for @shopBuy.
  ///
  /// In vi, this message translates to:
  /// **'MUA · {price} SUNBIT'**
  String shopBuy(int price);

  /// No description provided for @shopShort.
  ///
  /// In vi, this message translates to:
  /// **'CÒN THIẾU {missing} SUNBIT'**
  String shopShort(int missing);

  /// No description provided for @shopEquip.
  ///
  /// In vi, this message translates to:
  /// **'TRANG BỊ'**
  String get shopEquip;

  /// No description provided for @shopUnequip.
  ///
  /// In vi, this message translates to:
  /// **'THÁO RA'**
  String get shopUnequip;

  /// No description provided for @shopHintBuy.
  ///
  /// In vi, this message translates to:
  /// **'Mua một lần, dùng mãi mãi.'**
  String get shopHintBuy;

  /// No description provided for @shopHintLocked.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn thành nhiệm vụ hằng ngày để kiếm thêm Sunbit.'**
  String get shopHintLocked;

  /// No description provided for @shopHintEquip.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã sở hữu món này. Đổi món miễn phí.'**
  String get shopHintEquip;

  /// No description provided for @shopHintUnequip.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đang dùng món này.'**
  String get shopHintUnequip;

  /// No description provided for @kindFrame.
  ///
  /// In vi, this message translates to:
  /// **'KHUNG AVATAR'**
  String get kindFrame;

  /// No description provided for @kindBanner.
  ///
  /// In vi, this message translates to:
  /// **'BANNER'**
  String get kindBanner;

  /// No description provided for @rarityCommon.
  ///
  /// In vi, this message translates to:
  /// **'THƯỜNG'**
  String get rarityCommon;

  /// No description provided for @rarityRare.
  ///
  /// In vi, this message translates to:
  /// **'HIẾM'**
  String get rarityRare;

  /// No description provided for @rarityLegendary.
  ///
  /// In vi, this message translates to:
  /// **'HUYỀN THOẠI'**
  String get rarityLegendary;

  /// No description provided for @itemFrameSunflower.
  ///
  /// In vi, this message translates to:
  /// **'Khung hoa hướng dương'**
  String get itemFrameSunflower;

  /// No description provided for @itemFrameBrush.
  ///
  /// In vi, this message translates to:
  /// **'Khung nét cọ xoáy'**
  String get itemFrameBrush;

  /// No description provided for @itemFramePixel.
  ///
  /// In vi, this message translates to:
  /// **'Khung viền pixel'**
  String get itemFramePixel;

  /// No description provided for @itemFrameHearts.
  ///
  /// In vi, this message translates to:
  /// **'Khung trái tim 8-bit'**
  String get itemFrameHearts;

  /// No description provided for @itemFrameGoldCoins.
  ///
  /// In vi, this message translates to:
  /// **'Khung xu vàng'**
  String get itemFrameGoldCoins;

  /// No description provided for @itemBannerStarryNight.
  ///
  /// In vi, this message translates to:
  /// **'Banner đêm đầy sao'**
  String get itemBannerStarryNight;

  /// No description provided for @itemBannerWheatField.
  ///
  /// In vi, this message translates to:
  /// **'Banner đồng lúa mì'**
  String get itemBannerWheatField;

  /// No description provided for @itemBannerAlmond.
  ///
  /// In vi, this message translates to:
  /// **'Banner hoa hạnh nhân'**
  String get itemBannerAlmond;

  /// No description provided for @itemBannerRetroSky.
  ///
  /// In vi, this message translates to:
  /// **'Banner bầu trời game cổ'**
  String get itemBannerRetroSky;

  /// No description provided for @itemBannerSpace.
  ///
  /// In vi, this message translates to:
  /// **'Banner không gian pixel'**
  String get itemBannerSpace;

  /// No description provided for @canvasWhoNobody.
  ///
  /// In vi, this message translates to:
  /// **'Ô ({x}, {y}): chưa ai vẽ'**
  String canvasWhoNobody(int x, int y);

  /// No description provided for @canvasWhoSomeone.
  ///
  /// In vi, this message translates to:
  /// **'Ô ({x}, {y}): {name} vẽ'**
  String canvasWhoSomeone(int x, int y, String name);

  /// No description provided for @canvasLeftMember.
  ///
  /// In vi, this message translates to:
  /// **'một người đã rời nhóm'**
  String get canvasLeftMember;

  /// No description provided for @canvasLoadFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được canvas.'**
  String get canvasLoadFailed;

  /// No description provided for @canvasNone.
  ///
  /// In vi, this message translates to:
  /// **'Nhóm này chưa có canvas.'**
  String get canvasNone;

  /// No description provided for @canvasNoInk.
  ///
  /// In vi, this message translates to:
  /// **'Hết mực: hoàn thành nhiệm vụ để nhận 10 mực.'**
  String get canvasNoInk;

  /// No description provided for @canvasInkHint.
  ///
  /// In vi, this message translates to:
  /// **'Mỗi ô vẽ tốn 1 mực. Giữ một ô để xem ai vẽ.'**
  String get canvasInkHint;

  /// No description provided for @canvasOffline.
  ///
  /// In vi, this message translates to:
  /// **'Mất kết nối: canvas chỉ để xem.'**
  String get canvasOffline;

  /// No description provided for @canvasArchived.
  ///
  /// In vi, this message translates to:
  /// **'Canvas này đã được lưu trữ (chỉ xem).'**
  String get canvasArchived;

  /// No description provided for @canvasSemantics.
  ///
  /// In vi, this message translates to:
  /// **'Canvas {w} nhân {h} ô. Chạm một ô để vẽ.'**
  String canvasSemantics(int w, int h);

  /// No description provided for @colorSemantics.
  ///
  /// In vi, this message translates to:
  /// **'Màu {n}'**
  String colorSemantics(int n);
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
