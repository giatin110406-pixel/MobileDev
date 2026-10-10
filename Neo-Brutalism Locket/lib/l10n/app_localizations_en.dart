// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Pocket Portrait';

  @override
  String get backendNotConfigured =>
      'No server configured. The app is running on this device only.';

  @override
  String get retry => 'TRY AGAIN';

  @override
  String get cancel => 'CANCEL';

  @override
  String get ok => 'OK';

  @override
  String get signInTitle => 'SIGN IN';

  @override
  String get signUpTitle => 'CREATE ACCOUNT';

  @override
  String get authTagline => 'Shoot, turn it into art and send it to friends.';

  @override
  String get emailLabel => 'EMAIL';

  @override
  String get passwordLabel => 'PASSWORD';

  @override
  String get signInButton => 'SIGN IN';

  @override
  String get signUpButton => 'SIGN UP';

  @override
  String get switchToSignUp => 'No account yet? Sign up';

  @override
  String get switchToSignIn => 'Have an account? Sign in';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get resetSent => 'Password reset email sent. Check your inbox.';

  @override
  String get resetNeedsEmail => 'Enter your email above first.';

  @override
  String get confirmEmailSent =>
      'Almost done! Tap the link in the email to confirm, then sign in.';

  @override
  String get errInvalidCredentials => 'Wrong email or password.';

  @override
  String get errEmailTaken =>
      'That email already has an account. Sign in instead.';

  @override
  String get errWeakPassword =>
      'That password is too weak. Use at least 8 characters.';

  @override
  String get errInvalidEmail => 'That email does not look right.';

  @override
  String get errNetwork =>
      'Could not connect. Check your network and try again.';

  @override
  String get errUnknown => 'Something went wrong. Please try again.';

  @override
  String get errPasswordShort => 'Password needs at least 8 characters.';

  @override
  String get onboardingTitle => 'WELCOME!';

  @override
  String get onboardingSubtitle => 'Pick a name so friends can find you.';

  @override
  String get displayNameLabel => 'DISPLAY NAME';

  @override
  String get usernameLabel => 'USERNAME';

  @override
  String get usernameHelp =>
      '3-20 characters: lower-case letters, digits, dot or underscore.';

  @override
  String get usernameTaken => 'That username is taken.';

  @override
  String get usernameAvailable => 'Available!';

  @override
  String get usernameChecking => 'Checking...';

  @override
  String get usernameTooShort => 'At least 3 characters.';

  @override
  String get usernameTooLong => 'At most 20 characters.';

  @override
  String get usernameBadCharacters =>
      'Use lower-case letters, digits, dot and underscore only.';

  @override
  String get displayNameRequired => 'Enter a display name.';

  @override
  String get avatarOptional => 'PROFILE PHOTO (OPTIONAL)';

  @override
  String get avatarPick => 'CHOOSE PHOTO';

  @override
  String get continueButton => 'CONTINUE';

  @override
  String get signOut => 'SIGN OUT';

  @override
  String get signOutConfirmTitle => 'SIGN OUT?';

  @override
  String get signOutConfirmBody => 'You can sign back in any time.';

  @override
  String get loadingAccount => 'LOADING ACCOUNT...';

  @override
  String get accountLoadFailed => 'Could not load your account.';

  @override
  String get avatarUploadFailed =>
      'Could not upload your profile photo to the server yet.';

  @override
  String get friendsOnline => 'ONLINE';

  @override
  String get friendsAdd => 'ADD FRIEND';

  @override
  String get friendsRequests => 'REQUESTS';

  @override
  String get friendsIncoming => 'WANT TO BE FRIENDS';

  @override
  String get friendsOutgoing => 'SENT';

  @override
  String get friendsAccept => 'ACCEPT';

  @override
  String get friendsDecline => 'DECLINE';

  @override
  String get friendsCancelRequest => 'CANCEL';

  @override
  String get friendsEmptyTitle => 'NO FRIENDS\nYET';

  @override
  String get friendsEmptyBody =>
      'FIND FRIENDS BY USERNAME OR SEND AN INVITE LINK.';

  @override
  String get friendsRefreshFailed => 'Could not refresh your friends.';

  @override
  String get addFriendTitle => 'ADD FRIEND';

  @override
  String get addFriendHint => 'Type your friend\'s username';

  @override
  String get addFriendNoResults => 'Nobody found.';

  @override
  String get addFriendSend => 'ADD';

  @override
  String get addFriendShare => 'SHARE MY INVITE';

  @override
  String inviteMessage(String username, String link) {
    return 'Add me on Pocket Portrait! @$username\n$link';
  }

  @override
  String requestSentTo(String name) {
    return 'Request sent to $name.';
  }

  @override
  String nowFriendsWith(String name) {
    return 'You and $name are friends now!';
  }

  @override
  String inviteLinkTitle(String username) {
    return 'Add @$username as a friend?';
  }

  @override
  String get friendNotFound => 'We could not find that person.';

  @override
  String get friendSelf => 'That is you.';

  @override
  String get friendAlready => 'You are already friends.';

  @override
  String get friendAlreadySent => 'You already sent a request.';

  @override
  String get friendNotAccepting => 'This person is not accepting new requests.';

  @override
  String get friendTooManyPending =>
      'Too many requests waiting. Cancel a few first.';

  @override
  String get friendLimit => 'You reached the limit of 20 friends.';

  @override
  String get friendTheirLimit => 'This person reached their friend limit.';

  @override
  String get friendsGenericError => 'Something went wrong. Please try again.';

  @override
  String get removeFriendTitle => 'REMOVE FRIEND?';

  @override
  String removeFriendBody(String name) {
    return 'Remove $name from your friends? You can send a request again later.';
  }

  @override
  String get removeFriendConfirm => 'REMOVE';

  @override
  String get composerTitle => 'POST';

  @override
  String get composerCaptionHint => 'Add a caption...';

  @override
  String get composerAllFriends => 'ALL FRIENDS';

  @override
  String get composerSend => 'SEND';

  @override
  String get composerNoFriends => 'Add friends first to send them photos.';

  @override
  String get composerPickAtLeastOne => 'Pick at least one friend.';

  @override
  String composerSentTo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sent to $count friends.',
      one: 'Sent to 1 friend.',
    );
    return '$_temp0';
  }

  @override
  String get composerQueued =>
      'You are offline. The photo will send when you reconnect.';

  @override
  String get composerSending => 'Sending...';

  @override
  String get feedYou => 'You';

  @override
  String get sendPrintButton => 'SEND';

  @override
  String get printDiscard => 'DISCARD';

  @override
  String get printPost => 'POST';

  @override
  String get composerPostAll => 'POST TO ALL FRIENDS';

  @override
  String composerSendToSome(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'SEND TO $count FRIENDS',
      one: 'SEND TO 1 FRIEND',
    );
    return '$_temp0';
  }

  @override
  String get postSaved => 'Saved to your photo library.';

  @override
  String get postSaveFailed => 'Could not save the photo.';

  @override
  String get postShareFailed => 'Could not share the photo.';

  @override
  String get postMenuSave => 'SAVE TO DEVICE';

  @override
  String get postMenuShare => 'SHARE';

  @override
  String get postMenuDelete => 'DELETE POST';

  @override
  String get postDeleteTitle => 'DELETE THIS POST?';

  @override
  String get postDeleteBody =>
      'It disappears for all your friends. This cannot be undone.';

  @override
  String get postDeleted => 'Post deleted.';

  @override
  String reactionSent(String emoji) {
    return 'Sent $emoji';
  }

  @override
  String get replySent => 'Message sent.';

  @override
  String get chatSendFailed => 'Could not send the message.';

  @override
  String get chatNotFriends => 'You are not friends any more.';

  @override
  String get chatTooLong =>
      'That message is too long (500 characters at most).';

  @override
  String get historyTab => 'HISTORY';

  @override
  String get historyTitle => 'History';

  @override
  String get historyAll => 'ALL';

  @override
  String get historyMine => 'MINE';

  @override
  String get historyPosts => 'POSTS';

  @override
  String get historyOnDevice => 'ON DEVICE';

  @override
  String get historyEmpty =>
      'Nothing here yet. Send a photo to a friend, or wait for one!';

  @override
  String get historyLoadFailed =>
      'Could not load your history. Pull down to try again.';

  @override
  String get overlayTime => 'TIME';

  @override
  String get overlayPlace => 'PLACE';

  @override
  String get overlayFindingPlace => 'FINDING PLACE...';

  @override
  String get placeServicesOff =>
      'Location is off. Turn it on in the phone settings.';

  @override
  String get placeDenied => 'The app is not allowed to use your location.';

  @override
  String get placeFailed => 'Could not tell where you are.';

  @override
  String get timerOff => 'Timer off';

  @override
  String timerSeconds(int seconds) {
    return '$seconds-second timer';
  }

  @override
  String get holdForVideo => 'Hold to record a video';

  @override
  String get videoTooShort => 'Too short. Hold the button longer.';

  @override
  String get videoFailed => 'Could not record the video.';

  @override
  String get errSamePassword =>
      'Pick a password different from the current one.';

  @override
  String get resetPasswordTitle => 'NEW PASSWORD';

  @override
  String get resetPasswordSubtitle => 'Choose a new password for your account.';

  @override
  String get newPasswordLabel => 'NEW PASSWORD';

  @override
  String get confirmPasswordLabel => 'REPEAT PASSWORD';

  @override
  String get passwordsDiffer => 'The two passwords do not match.';

  @override
  String get savePassword => 'SAVE PASSWORD';

  @override
  String get passwordChanged => 'Password changed.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAccount => 'ACCOUNT';

  @override
  String get settingsPrivacy => 'PRIVACY';

  @override
  String get settingsLanguage => 'LANGUAGE';

  @override
  String get settingsAbout => 'ABOUT';

  @override
  String get settingsEditProfile => 'Edit name and username';

  @override
  String get settingsChangePassword => 'Change password';

  @override
  String settingsEmail(String email) {
    return 'Email: $email';
  }

  @override
  String get settingsAllowRequests => 'Allow friend requests';

  @override
  String get settingsAllowRequestsHint =>
      'Turn off and nobody can send you new requests.';

  @override
  String get settingsBlocked => 'Blocked people';

  @override
  String get settingsLanguageSystem => 'Same as the phone';

  @override
  String get settingsLanguageVi => 'Tiếng Việt';

  @override
  String get settingsLanguageEn => 'English';

  @override
  String get settingsLaptop => 'Laptop connection (Van Gogh art)';

  @override
  String get settingsPrivacyPolicy => 'Privacy policy';

  @override
  String get settingsTerms => 'Terms of use';

  @override
  String get settingsDeleteAccount => 'DELETE ACCOUNT';

  @override
  String get editProfileTitle => 'EDIT PROFILE';

  @override
  String get saveButton => 'SAVE';

  @override
  String get deleteAccountTitle => 'DELETE ACCOUNT?';

  @override
  String get deleteAccountBody =>
      'All your photos, messages, friends, Sunbit and purchases are deleted for good. This cannot be undone.';

  @override
  String deleteAccountType(String username) {
    return 'Type \"$username\" to confirm';
  }

  @override
  String get deleteAccountConfirm => 'DELETE FOR GOOD';

  @override
  String get deleteAccountFailed =>
      'Could not delete the account. Check your connection and try again.';

  @override
  String get blockedTitle => 'BLOCKED';

  @override
  String get blockedEmpty => 'You have not blocked anyone.';

  @override
  String get unblock => 'UNBLOCK';

  @override
  String get blockPerson => 'BLOCK';

  @override
  String blockTitle(String name) {
    return 'BLOCK $name?';
  }

  @override
  String get blockBody =>
      'You will stop being friends, not see each other\'s photos and not be able to message. They are not told.';

  @override
  String blockedDone(String name) {
    return 'Blocked $name.';
  }

  @override
  String unblockedDone(String name) {
    return 'Unblocked $name.';
  }

  @override
  String get reportPerson => 'REPORT THIS PERSON';

  @override
  String get reportPost => 'REPORT THIS POST';

  @override
  String get reportTitle => 'REPORT';

  @override
  String get reportWhy => 'Reason';

  @override
  String get reportSpam => 'Spam or ads';

  @override
  String get reportInappropriate => 'Inappropriate content';

  @override
  String get reportHarassment => 'Harassment or bullying';

  @override
  String get reportOther => 'Something else';

  @override
  String get reportDetailsHint => 'Add details (optional)';

  @override
  String get reportSend => 'SEND REPORT';

  @override
  String get reportSent => 'Report sent. Thank you.';

  @override
  String get reportTooMany => 'You reported a lot today. Try again tomorrow.';

  @override
  String get safetyFailed =>
      'Could not do that. Check your connection and try again.';

  @override
  String get legalDraftNote => 'Draft: needs legal review before release.';

  @override
  String get settingsNotifications => 'NOTIFICATIONS';

  @override
  String get notifyNewPost => 'New photos from friends';

  @override
  String get notifyMessages => 'Messages';

  @override
  String get notifyReactions => 'Reactions to my photos';

  @override
  String get notifyFriendRequests => 'Friend requests';

  @override
  String get tabShoot => 'SHOOT';

  @override
  String get tabFriends => 'FRIENDS';

  @override
  String get tabInbox => 'INBOX';

  @override
  String get tabPrints => 'PRINTS';

  @override
  String get tabMe => 'ME';

  @override
  String get laptopSettingsTooltip => 'Home laptop settings';

  @override
  String get cameraAccessHint => 'ENABLE CAMERA ACCESS TO START SHOOTING';

  @override
  String get originalLabel => 'ORIGINAL';

  @override
  String get imageNotFound => 'IMAGE NOT FOUND';

  @override
  String get groupsKicker => 'YOUR CIRCLES';

  @override
  String get groupsTitle => 'Groups';

  @override
  String groupsCount(int count) {
    return '$count GROUPS';
  }

  @override
  String get groupCreate => 'NEW GROUP';

  @override
  String get questDataUnreadable => 'QUEST DATA COULD NOT BE READ';

  @override
  String get archiveUnreadable => 'ARCHIVE COULD NOT BE READ';

  @override
  String get friendsLoadFailed => 'FRIENDS COULD NOT BE LOADED';

  @override
  String friendAddedLocally(String name) {
    return '$name ADDED LOCALLY';
  }

  @override
  String get shareNeedsPrint => 'TAKE A PRINT BEFORE SHARING';

  @override
  String get replyWord => 'REPLY';

  @override
  String sentNotice(String what) {
    return '$what SENT';
  }

  @override
  String sentNoticeTo(String what, String name) {
    return '$what SENT TO $name';
  }

  @override
  String removeLocalFriendBody(String name) {
    return 'Remove $name and this local thread from this device?';
  }

  @override
  String get photoNotSaved => 'PHOTO DID NOT SAVE. TRY AGAIN.';

  @override
  String get photoOpenFailed => 'COULD NOT OPEN THAT PHOTO. TRY ANOTHER.';

  @override
  String fallbackUsed(String note) {
    return 'FALLBACK USED: $note';
  }

  @override
  String get styleFailedOriginalSafe => 'STYLE PASS FAILED. ORIGINAL IS SAFE.';

  @override
  String get flashUnavailable => 'FLASH IS NOT AVAILABLE';

  @override
  String get flashTooltip => 'Change flash mode';

  @override
  String get openFeedLabel => 'Open feed';

  @override
  String get feedLabel => 'FEED';

  @override
  String zoomSemantics(String level) {
    return 'Zoom $level';
  }

  @override
  String get uploadPhotoTooltip => 'Upload a photo from this device';

  @override
  String get takePhotoLabel => 'Take photo';

  @override
  String get switchCameraTooltip => 'Switch camera';

  @override
  String get openArchiveLabel => 'Open archive';

  @override
  String get retryShort => 'RETRY';

  @override
  String get newShot => 'NEW SHOT';

  @override
  String get statusInking => 'INKING';

  @override
  String get statusReady => 'READY';

  @override
  String get statusOriginalSafe => 'ORIGINAL SAFE';

  @override
  String get cameraAccessOff => 'CAMERA ACCESS IS OFF';

  @override
  String get cameraUnavailable => 'CAMERA IS NOT AVAILABLE';

  @override
  String get findingCamera => 'FINDING CAMERA';

  @override
  String get cameraReady => 'CAMERA READY';

  @override
  String originalPlusStyle(String style) {
    return 'ORIGINAL + $style';
  }

  @override
  String get legacyEdit => 'LEGACY EDIT';

  @override
  String get editLabel => 'EDIT';

  @override
  String get styleSliderSemantics => 'Style. Swipe to change';

  @override
  String get retryTooltip => 'Retry';

  @override
  String get backToCameraTooltip => 'Back to camera';

  @override
  String get noPostsYet => 'NO POSTS YET';

  @override
  String replyHint(String name) {
    return 'Reply to $name...';
  }

  @override
  String get openPrint => 'OPEN PRINT';

  @override
  String get reactWith => 'REACT WITH';

  @override
  String get sendReplyTooltip => 'Send reply';

  @override
  String reactSemantics(String emoji) {
    return 'React $emoji';
  }

  @override
  String get moreEmojiTooltip => 'More emoji';

  @override
  String get localCollection => 'LOCAL COLLECTION';

  @override
  String get printArchive => 'Print archive';

  @override
  String itemsCount(int count) {
    return '$count ITEMS';
  }

  @override
  String get archiveEmptyBody =>
      'YOUR PHOTOS STAY IN THIS DEVICE-ONLY ARCHIVE.';

  @override
  String get openCamera => 'OPEN CAMERA';

  @override
  String get printReady => 'NEO PRINT READY';

  @override
  String get originalSaved => 'ORIGINAL SAVED';

  @override
  String get serverTesting => 'TESTING…';

  @override
  String serverConnected(String gpu) {
    return 'CONNECTED · $gpu';
  }

  @override
  String get serverModelsLoading => 'CONNECTED · MODELS STILL LOADING';

  @override
  String get serverInvalidAddress => 'INVALID ADDRESS';

  @override
  String get homeLaptop => 'HOME LAPTOP';

  @override
  String get vanGoghOnLaptop => 'VAN GOGH RUNS ON YOUR LAPTOP';

  @override
  String get serverAddressLabel => 'ADDRESS (IP:PORT)';

  @override
  String get serverTokenLabel => 'TOKEN';

  @override
  String get serverTokenHint => 'printed when the server starts';

  @override
  String get serverTestButton => 'TEST';

  @override
  String get shopLabel => 'SHOP';

  @override
  String get sunbitShop => 'SUNBIT SHOP';

  @override
  String get sampleLabel => 'SAMPLE';

  @override
  String get menuTooltip => 'Menu';

  @override
  String get yourPeople => 'YOUR PEOPLE';

  @override
  String get friendsTitle => 'Friends';

  @override
  String peopleCount(int count) {
    return '$count PEOPLE';
  }

  @override
  String get localMode => 'LOCAL MODE';

  @override
  String get noFriendsOnDevice => 'NO FRIENDS\nON THIS DEVICE';

  @override
  String get noFriendsOnDeviceBody =>
      'ADD A LOCAL PROFILE TO START A SAMPLE THREAD.';

  @override
  String get privateThreads => 'PRIVATE THREADS';

  @override
  String get inboxTitle => 'Inbox';

  @override
  String get deviceOnly => 'DEVICE ONLY';

  @override
  String get addFriendToStart => 'ADD A FRIEND TO START A THREAD';

  @override
  String get backToInboxTooltip => 'Back to inbox';

  @override
  String get openProfileLabel => 'Open profile';

  @override
  String get removeFriendTooltip => 'Remove friend';

  @override
  String get localThread => 'LOCAL THREAD';

  @override
  String get sendLatestPrintTooltip => 'Send latest print';

  @override
  String get writeMessageHint => 'Write a message...';

  @override
  String get sendMessageTooltip => 'Send message';

  @override
  String whosePost(String name) {
    return '$name\'S POST';
  }

  @override
  String get yourPost => 'YOUR POST';

  @override
  String get previewStart => 'START A LOCAL THREAD';

  @override
  String previewReacted(String who, String emoji) {
    return '$who REACTED $emoji';
  }

  @override
  String get previewYou => 'YOU';

  @override
  String previewYouReplied(String text) {
    return 'YOU REPLIED: $text';
  }

  @override
  String previewReplied(String text) {
    return 'REPLIED: $text';
  }

  @override
  String get previewSentPrint => 'SENT A PRINT';

  @override
  String previewYouText(String text) {
    return 'YOU: $text';
  }

  @override
  String get localLabel => 'LOCAL';

  @override
  String get addAFriend => 'ADD A FRIEND';

  @override
  String get localProfileOnly => 'LOCAL PROFILE ONLY';

  @override
  String get handleLabel => 'HANDLE';

  @override
  String get friendNameHint => 'A friend name';

  @override
  String get addToFriends => 'ADD TO FRIENDS';

  @override
  String get settingsFeedback => 'FEEL';

  @override
  String get settingsHaptics => 'Vibrate on taps';

  @override
  String get holdToCompare => 'HOLD TO COMPARE';

  @override
  String get styleWorking8bit => 'GRINDING PIXELS…';

  @override
  String get styleWorkingVanGogh => 'SWIRLING VAN GOGH COLOURS…';

  @override
  String get styleWorking => 'WORKING…';
}
