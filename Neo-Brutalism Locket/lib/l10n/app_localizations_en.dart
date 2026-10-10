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

  @override
  String get backTooltip => 'Back';

  @override
  String get contestTitle => 'Weekly contest';

  @override
  String get contestLoadFailed => 'Could not load the contest.';

  @override
  String get contestNone => 'No contest yet.';

  @override
  String get contestStale => 'Could not refresh. Showing old data.';

  @override
  String contestEnterGallery(int count) {
    return 'ENTER GALLERY ($count ENTRIES)';
  }

  @override
  String get contestSeeResults => 'SEE RESULTS';

  @override
  String contestPrevResults(String title) {
    return 'LAST WEEK\'S RESULTS: $title';
  }

  @override
  String contestEntriesCount(int count, int max) {
    return '$count/$max entries';
  }

  @override
  String contestCountdownUntil(String event) {
    return 'until $event';
  }

  @override
  String get contestUntilOpen => 'submissions open';

  @override
  String get contestUntilJudging => 'submissions close and judging starts';

  @override
  String get contestUntilClosed => 'results are final';

  @override
  String get contestLineOpens => 'Submissions open';

  @override
  String get contestLineJudging => 'Judging from';

  @override
  String contestLineJudgingNote(String moment) {
    return '$moment (or once 100 entries are in)';
  }

  @override
  String get contestLineEnds => 'Results final';

  @override
  String contestLineEndsNote(String moment) {
    return '$moment (23:59 Sunday, Vietnam time)';
  }

  @override
  String contestMyEntry(String group, int seq) {
    return 'Group \"$group\" has entered, entry no. $seq.';
  }

  @override
  String get contestNothingToRate =>
      'No entries from other groups to rate yet.';

  @override
  String contestRatedProgress(int done, int needed) {
    return 'You rated $done/$needed entries';
  }

  @override
  String get contestVoteRule =>
      'Your votes only count once you have rated this many entries and your account is at least 7 days old.';

  @override
  String get contestOnlyOwner =>
      'Only a group owner can submit. Ask your group owner.';

  @override
  String get contestGroupSubmitted => 'Submitted this week';

  @override
  String get contestOwnerHint =>
      'You own this group: submit its canvas to enter';

  @override
  String contestOpensAt(String moment) {
    return 'Submissions open $moment';
  }

  @override
  String get contestSubmitButton => 'SUBMIT';

  @override
  String get contestRulesTitle => 'RULES';

  @override
  String get contestRules =>
      '• A group owner submits the group canvas, one entry per group.\n• Only the first 100 entries make it into the Gallery.\n• Members of groups with an entry rate other groups 1–5 stars and comment.\n• The ranking score is an adjusted average (Bayes), so a few 5-star votes are not enough to jump ahead.\n• All times are Vietnam time (UTC+7).';

  @override
  String contestSubmittedSnack(int seq) {
    return 'Submitted! Your entry is no. $seq.';
  }

  @override
  String get cfNotFound => 'Entry not found.';

  @override
  String get cfNotOwner => 'Only a group owner can submit.';

  @override
  String get cfNotOpen => 'Submissions are not open, or have closed.';

  @override
  String get cfNotJudging => 'It is not judging time yet.';

  @override
  String get cfAlreadySubmitted => 'This group already submitted this week.';

  @override
  String get cfContestFull =>
      'This week\'s Gallery already has 100 entries. See you next week!';

  @override
  String get cfCanvasTooEmpty =>
      'The canvas is too empty. Draw a bit more, then submit.';

  @override
  String get cfGroupTooSmall => 'A group needs at least 2 people to enter.';

  @override
  String get cfNoCanvas => 'The group has no canvas yet.';

  @override
  String get cfNotParticipant =>
      'Only members of groups with an entry can rate and comment.';

  @override
  String get cfOwnEntry => 'You cannot rate your own group\'s entry.';

  @override
  String get cfBadScore => 'The score must be 1 to 5 stars.';

  @override
  String get cfEmpty => 'Write something first.';

  @override
  String get cfTooLong => 'Comments can be 200 characters at most.';

  @override
  String get cfTooFast => 'Slow down a little, then comment again.';

  @override
  String get cfTooMany => 'You have used all your comments for this week.';

  @override
  String get cfBlockedWord => 'That comment has a word that is not allowed.';

  @override
  String get cfTooManyReports => 'You have reported a lot today.';

  @override
  String get cfNetwork => 'Could not connect. Please try again.';

  @override
  String get cfUnknown => 'Something went wrong. Please try again.';

  @override
  String get phaseUpcoming => 'COMING UP';

  @override
  String get phaseOpen => 'OPEN FOR ENTRIES';

  @override
  String get phaseJudging => 'JUDGING';

  @override
  String get phaseClosed => 'WRAPPING UP';

  @override
  String get phaseFinalized => 'RESULTS ARE IN';

  @override
  String countdownDays(int days, String clock) {
    return '${days}d $clock';
  }

  @override
  String get milestoneOpen => 'until submissions open';

  @override
  String get milestoneJudging => 'until submissions close, then judging';

  @override
  String get milestoneClosed => 'until results are final';

  @override
  String contestTimeLeft(String time, String event) {
    return '$time left $event';
  }

  @override
  String contestBannerTitle(String phase) {
    return 'WEEKLY CONTEST · $phase';
  }

  @override
  String contestBannerSemantics(String week, String title, String phase) {
    return 'Weekly contest $week: $title. $phase';
  }

  @override
  String get weekdayMon => 'Mon';

  @override
  String get weekdayTue => 'Tue';

  @override
  String get weekdayWed => 'Wed';

  @override
  String get weekdayThu => 'Thu';

  @override
  String get weekdayFri => 'Fri';

  @override
  String get weekdaySat => 'Sat';

  @override
  String get weekdaySun => 'Sun';

  @override
  String entryHeader(int seq, String moment) {
    return 'Entry no. $seq · submitted $moment';
  }

  @override
  String get reportEntryTooltip => 'Report this entry';

  @override
  String entryArtSemantics(String group, int seq) {
    return '$group\'s painting, entry no. $seq';
  }

  @override
  String get commentsTitle => 'COMMENTS';

  @override
  String commentsTitleCount(int count) {
    return 'COMMENTS ($count)';
  }

  @override
  String get noComments => 'No comments yet.';

  @override
  String get rank1 => '1ST PLACE';

  @override
  String get rank2 => '2ND PLACE';

  @override
  String get rank3 => '3RD PLACE';

  @override
  String get rankTop3 => 'TOP 3';

  @override
  String rankScoreLine(String rank, String score, int votes) {
    return '$rank  ·  $score points ($votes votes)';
  }

  @override
  String get ratingLoading => 'Loading…';

  @override
  String get ratingOwnGroup =>
      'This is your group\'s entry. You cannot rate it.';

  @override
  String get ratingNotParticipant =>
      'Only members of groups with an entry can rate.';

  @override
  String get ratingContestOver => 'The contest is over.';

  @override
  String get ratingNotYet => 'It is not judging time yet.';

  @override
  String get ratingTapStar =>
      'Tap a star to rate. You can change it until the contest ends.';

  @override
  String ratingYouGave(int stars) {
    return 'You gave $stars stars. Tap to change.';
  }

  @override
  String rateStars(int stars) {
    return 'Rate $stars stars';
  }

  @override
  String get commentYou => 'You';

  @override
  String get reportCommentTooltip => 'Report this comment';

  @override
  String get writeCommentHint => 'Write a comment…';

  @override
  String get sendTooltip => 'Send';

  @override
  String get resultsTitle => 'Results';

  @override
  String resultsTitleWeek(String title) {
    return 'Results: $title';
  }

  @override
  String get resultsLater => 'Results come at 23:59 on Sunday (Vietnam time).';

  @override
  String get resultsNoEntries => 'No entries this week.';

  @override
  String get resultsNoRanked =>
      'No entry has enough valid votes to be ranked (at least 3 votes needed).';

  @override
  String resultsEntryCount(int count, String week) {
    return '$count entries · $week';
  }

  @override
  String resultsScoreVotes(String score, int votes) {
    return '$score · $votes votes';
  }

  @override
  String submitSheetTitle(String group) {
    return 'SUBMIT: $group';
  }

  @override
  String get canvasWillBeSubmitted => 'The canvas that will be submitted';

  @override
  String get noPreview => 'No preview available.';

  @override
  String submitSpotsLeft(int count, int max) {
    return '$count/$max entries so far. Only the first $max make it into the Gallery.';
  }

  @override
  String submitGalleryFull(int max) {
    return 'The Gallery already has $max entries.';
  }

  @override
  String get submitSnapshotNote =>
      'The canvas is captured the moment you submit and cannot be changed. Each group submits one entry per week.';

  @override
  String get submitting => 'SUBMITTING…';

  @override
  String get galleryViewCorridor => 'Switch to corridor view';

  @override
  String get galleryViewGrid => 'Switch to grid view';

  @override
  String get galleryEmpty =>
      'The corridor is empty. Entries show up here once groups submit.';

  @override
  String get galleryLoadMoreFailed =>
      'Could not load more. Pull up to try again.';

  @override
  String galleryEntrySemantics(int seq, String group) {
    return 'Entry no. $seq, group $group';
  }

  @override
  String corridorSemantics(int count) {
    return 'Exhibition corridor with $count paintings. Swipe up to walk forward, tap one to view it. Use the grid view button to browse as a list.';
  }

  @override
  String get walkForward => 'Walk forward';

  @override
  String get walkBack => 'Walk back';

  @override
  String get groupsInvitesTitle => 'GROUP INVITES';

  @override
  String get groupsStale => 'Could not refresh. Showing old data.';

  @override
  String get groupsLoadFailed => 'Could not load your groups.';

  @override
  String get groupsEmptyTitle => 'No groups yet';

  @override
  String get groupsEmptyBody =>
      'Start a group with friends to chat and draw one pixel canvas together. Each daily quest gives you 10 ink, and each cell you draw costs 1 ink.';

  @override
  String get groupPreviewNone => 'No messages yet';

  @override
  String get groupPreviewActivity => 'New activity in the group';

  @override
  String memberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return '$_temp0';
  }

  @override
  String groupTileSemantics(String name, String members) {
    return 'Group $name, $members';
  }

  @override
  String groupTileSemanticsUnread(String name, String members, int unread) {
    return 'Group $name, $members, $unread unread';
  }

  @override
  String groupMembersLine(int count, int max) {
    return '$count/$max members';
  }

  @override
  String groupMembersLineOwner(int count, int max) {
    return '$count/$max members · owner';
  }

  @override
  String groupJoinedSnack(String name) {
    return 'Joined $name.';
  }

  @override
  String groupInviteFrom(String person) {
    return '$person invited you to a group';
  }

  @override
  String get groupJoin => 'JOIN';

  @override
  String get groupCreateTitle => 'CREATE A NEW GROUP';

  @override
  String get groupNameLabel => 'Group name';

  @override
  String get groupRulesOptional => 'Rules (optional)';

  @override
  String get groupMaxMembers => 'Max members';

  @override
  String get decrease => 'Decrease';

  @override
  String get increase => 'Increase';

  @override
  String get groupCreating => 'CREATING…';

  @override
  String get segmentGroups => 'GROUPS';

  @override
  String get personFriendsNote =>
      'You are friends: each other\'s new photos show up in the feed.';

  @override
  String get personNotFriendsNote =>
      'Being in the same group does not make you friends. Only once you are friends can you see each other\'s photos.';

  @override
  String get personAlreadyFriends => 'ALREADY FRIENDS';

  @override
  String get personRequestSent => 'REQUEST SENT';

  @override
  String get personBefriend => 'ADD FRIEND';

  @override
  String get reportFailed => 'Could not send the report. Please try again.';

  @override
  String get blockFailed => 'Could not block. Please try again.';

  @override
  String sysJoined(String name) {
    return '$name joined the group';
  }

  @override
  String sysLeft(String name) {
    return '$name left the group';
  }

  @override
  String sysKicked(String name) {
    return '$name was removed from the group';
  }

  @override
  String sysOwnerChanged(String name) {
    return '$name is the new group owner';
  }

  @override
  String get sysEntrySubmitted => 'The group submitted an entry this week';

  @override
  String get gfNotFound => 'Could not find that group or person.';

  @override
  String get gfNotOwner => 'Only the group owner can do this.';

  @override
  String get gfNotMember => 'You are no longer in this group.';

  @override
  String get gfSelf => 'You cannot do this to yourself.';

  @override
  String get gfEmpty => 'Write something first.';

  @override
  String get gfTooLong => 'That is too long.';

  @override
  String get gfBlockedWord =>
      'That has a word that is not allowed. Please keep it friendly so everyone has fun.';

  @override
  String get gfBadName => 'A group name needs 1 to 40 characters.';

  @override
  String get gfBadSize =>
      'Max members must be 2 to 12, and not less than the people already in.';

  @override
  String get gfGroupLimit =>
      'You can be in 5 groups at most and own 3 at most.';

  @override
  String get gfMemberLimit => 'The group is full (pending invites count too).';

  @override
  String get gfTheirGroupLimit => 'You are in too many groups (5 at most).';

  @override
  String get gfAlreadyMember => 'That person is already in the group.';

  @override
  String get gfAlreadyInvited => 'You already invited that person.';

  @override
  String get gfExpired => 'That invite has expired.';

  @override
  String get gfOwnerMustTransfer =>
      'Hand the group over to someone else before you leave.';

  @override
  String get gfNetwork => 'Could not connect. Please try again.';

  @override
  String get gfUnknown => 'Something went wrong. Please try again.';

  @override
  String get kfInsufficientInk =>
      'Out of ink. Finish the daily quest to get 10 more.';

  @override
  String get kfRateLimited => 'Draw a bit slower (30 cells a minute at most).';

  @override
  String get kfCanvasLocked => 'This canvas has been archived.';

  @override
  String get kfNotFound => 'Could not find the canvas.';

  @override
  String get kfNotOwner => 'Only the group owner can do this.';

  @override
  String get kfBadPixel => 'That cell is not valid.';

  @override
  String get kfBadSize => 'The size or palette is not valid.';

  @override
  String get kfNetwork => 'Connection lost. The canvas is now view-only.';

  @override
  String get groupSettingsTooltip => 'Group settings';

  @override
  String get youLabel => 'You';

  @override
  String get someoneLabel => 'Someone';

  @override
  String get chatLoadFailed => 'Could not load the messages.';

  @override
  String get chatSayHi => 'Say hi to the group 👋';

  @override
  String get chatHint => 'Message the group…';

  @override
  String get groupSettingsTitle => 'Group settings';

  @override
  String get ownerBadge => 'OWNER';

  @override
  String get sectionInfo => 'INFO';

  @override
  String sectionMembers(int count, int max) {
    return 'MEMBERS ($count/$max)';
  }

  @override
  String get inviteToGroup => 'INVITE TO GROUP';

  @override
  String get inviteNote =>
      'You can only invite your friends. Invites expire after 7 days.';

  @override
  String get sectionPendingInvites => 'PENDING INVITES';

  @override
  String get newCanvasButton => 'NEW CANVAS';

  @override
  String get leaveGroup => 'LEAVE GROUP';

  @override
  String get dissolveGroup => 'DISBAND GROUP';

  @override
  String get rulesNone => 'This group has no rules yet.';

  @override
  String get rulesLabel => 'Rules';

  @override
  String memberYou(String name) {
    return '$name (you)';
  }

  @override
  String get ownerRole => 'Owner';

  @override
  String get optionsTooltip => 'Options';

  @override
  String get menuTransfer => 'Transfer ownership';

  @override
  String get menuRollback => 'Undo their drawing (24 h)';

  @override
  String get menuKick => 'Remove from group';

  @override
  String get revokeInvite => 'REVOKE';

  @override
  String get inviteFriendsTitle => 'INVITE FRIENDS';

  @override
  String get noOneToInvite =>
      'No friends left to invite. You can only invite your friends.';

  @override
  String get newCanvasTitle => 'New canvas';

  @override
  String get sizeLabel => 'Size';

  @override
  String get paletteLabel => 'Palette';

  @override
  String get savedSnack => 'Saved.';

  @override
  String kickTitle(String name) {
    return 'Remove $name from the group?';
  }

  @override
  String get kickBody =>
      'They will no longer see the group messages. The cells they drew stay.';

  @override
  String get kickAction => 'Remove';

  @override
  String get transferTitle => 'Transfer ownership?';

  @override
  String transferBody(String name) {
    return '$name becomes the new owner. You become a regular member.';
  }

  @override
  String get transferAction => 'Transfer';

  @override
  String transferDone(String name) {
    return '$name is the new owner.';
  }

  @override
  String rollbackTitle(String name) {
    return 'Undo $name\'s drawing?';
  }

  @override
  String get rollbackBody =>
      'Cells they drew in the last 24 hours that nobody painted over go back to their earlier colour. Their ink is not refunded.';

  @override
  String get rollbackAction => 'Undo';

  @override
  String rollbackDone(int count) {
    return 'Undid $count cells.';
  }

  @override
  String leaveTitle(String group) {
    return 'Leave $group?';
  }

  @override
  String get leaveBody =>
      'You will no longer see the group messages and canvas.';

  @override
  String get leaveAction => 'Leave';

  @override
  String dissolveTitle(String group) {
    return 'Disband $group?';
  }

  @override
  String get dissolveBody =>
      'Everyone loses access to the messages and canvas. This cannot be undone.';

  @override
  String get dissolveAction => 'Disband';

  @override
  String invitedSnack(String name) {
    return 'Invited $name.';
  }

  @override
  String get newCanvasConfirmTitle => 'Start a new canvas?';

  @override
  String get newCanvasConfirmBody =>
      'The current canvas is saved and can no longer be drawn on. The new canvas starts empty.';

  @override
  String get newCanvasConfirmAction => 'Create canvas';

  @override
  String get newCanvasDone => 'New canvas created.';

  @override
  String get avatarTitle => 'PROFILE PHOTO';

  @override
  String get avatarTakePhoto => 'TAKE PHOTO';

  @override
  String get avatarFromLibrary => 'CHOOSE FROM LIBRARY';

  @override
  String get avatarChange => 'CHANGE PHOTO';

  @override
  String get avatarChangeFailed => 'Could not change the profile photo.';

  @override
  String get questsDoneTitle => 'COMPLETED QUESTS';

  @override
  String get questsNoneYet =>
      'No quests yet. Open the SHOOT tab to do today\'s quest and earn 25 Sunbit!';

  @override
  String get postsTitle => 'POSTS';

  @override
  String inkAmountSemantics(int amount) {
    return '$amount ink';
  }

  @override
  String inkAmountLabel(int amount) {
    return '$amount INK';
  }

  @override
  String streakSemantics(int streak) {
    return '$streak-day streak';
  }

  @override
  String get musicOn => 'Turn music on';

  @override
  String get musicOff => 'Turn music off';

  @override
  String get photoMissingRetake => 'PHOTO NOT FOUND · PLEASE SHOOT AGAIN';

  @override
  String get newDayQuest => 'NEW DAY · NEW QUEST!';

  @override
  String get outOfTriesTitle => 'NO TRIES LEFT TODAY';

  @override
  String get outOfTriesBody =>
      'Not quite. You used all 3 tries today. A new quest arrives at 00:00.';

  @override
  String wrongTriesLeft(int left, String debug) {
    return 'NOT QUITE · $left TRIES LEFT$debug';
  }

  @override
  String get questModeBanner => 'QUEST MODE · LIVE CAMERA ONLY';

  @override
  String shootSubject(String subject) {
    return 'Shoot $subject';
  }

  @override
  String get exitQuestMode => 'Leave quest mode';

  @override
  String get checkingPhoto => 'CHECKING...';

  @override
  String questSemantics(String subject) {
    return 'Today\'s quest: shoot $subject';
  }

  @override
  String questTodayLabel(String style) {
    return 'TODAY\'S QUEST · $style';
  }

  @override
  String get qsDone => 'DONE ✓';

  @override
  String get qsPostNow => 'POST NOW';

  @override
  String get qsOutOfTries => 'NO TRIES';

  @override
  String triesLeft(int left) {
    String _temp0 = intl.Intl.pluralLogic(
      left,
      locale: localeName,
      other: '$left tries left',
      one: '1 try left',
    );
    return '$_temp0';
  }

  @override
  String get shootToday => 'TODAY, SHOOT';

  @override
  String rewardWithBonus(int reward, int bonus, int streak) {
    return '+$reward Sunbit, +$bonus streak bonus for $streak days!';
  }

  @override
  String rewardPlain(int reward, int bonus, int every) {
    return '+$reward Sunbit · plus +$bonus every $every streak days';
  }

  @override
  String get questRulesNote =>
      'Live camera only · 3 tries a day · A new day starts at 00:00 Vietnam time';

  @override
  String get startShooting => 'START SHOOTING';

  @override
  String get postQuestPhoto => 'POST QUEST PHOTO';

  @override
  String get questCompletedBtn => 'COMPLETED ✓';

  @override
  String get questNextAt => 'A new quest arrives at 00:00. See you then!';

  @override
  String get questAllTriesUsed =>
      'You used all 3 tries. A new quest arrives at 00:00.';

  @override
  String get postFailedTitle => 'COULD NOT POST';

  @override
  String get closeAction => 'CLOSE';

  @override
  String get postSuccessTitle => 'POSTED!';

  @override
  String get niceAction => 'NICE!';

  @override
  String get rewardQuest => 'Quest completed';

  @override
  String rewardStreak(int days) {
    return '$days-day streak bonus';
  }

  @override
  String get rewardInk => 'Ink for the group canvas';

  @override
  String get streakNew => 'A new streak starts. Come back tomorrow!';

  @override
  String streakDaysRow(int days) {
    return 'You have completed $days days in a row!';
  }

  @override
  String get laterTooltip =>
      'Later (your photo is kept until the end of today)';

  @override
  String photoNailedTitle(String emoji) {
    return 'NAILED IT! $emoji';
  }

  @override
  String get photoAcceptedTitle => 'PHOTO ACCEPTED';

  @override
  String get transformFailed =>
      'Could not transform the photo. The original is safe.';

  @override
  String get captionLabel => 'CAPTION';

  @override
  String get captionHint => 'Write a short line...';

  @override
  String get postingBusy => 'POSTING...';

  @override
  String get postToProfile => 'POST TO MY PROFILE';

  @override
  String get questMusicOrchestral =>
      'Quest posts play their own orchestral music when friends scroll to them.';

  @override
  String get questMusicChiptune =>
      'Quest posts play their own chiptune music when friends scroll to them.';

  @override
  String get shopDecorate => 'DECORATE YOUR PROFILE';

  @override
  String get shopInUse => 'IN USE';

  @override
  String get shopOwned => 'OWNED';

  @override
  String shopBuy(int price) {
    return 'BUY · $price SUNBIT';
  }

  @override
  String shopShort(int missing) {
    return '$missing SUNBIT SHORT';
  }

  @override
  String get shopEquip => 'EQUIP';

  @override
  String get shopUnequip => 'REMOVE';

  @override
  String get shopHintBuy => 'Buy once, keep forever.';

  @override
  String get shopHintLocked => 'Finish the daily quest to earn more Sunbit.';

  @override
  String get shopHintEquip => 'You own this one. Swapping is free.';

  @override
  String get shopHintUnequip => 'You are using this one.';

  @override
  String get kindFrame => 'AVATAR FRAME';

  @override
  String get kindBanner => 'BANNER';

  @override
  String get rarityCommon => 'COMMON';

  @override
  String get rarityRare => 'RARE';

  @override
  String get rarityLegendary => 'LEGENDARY';

  @override
  String get itemFrameSunflower => 'Sunflower frame';

  @override
  String get itemFrameBrush => 'Swirling brush frame';

  @override
  String get itemFramePixel => 'Pixel border frame';

  @override
  String get itemFrameHearts => '8-bit heart frame';

  @override
  String get itemFrameGoldCoins => 'Gold coin frame';

  @override
  String get itemBannerStarryNight => 'Starry night banner';

  @override
  String get itemBannerWheatField => 'Wheat field banner';

  @override
  String get itemBannerAlmond => 'Almond blossom banner';

  @override
  String get itemBannerRetroSky => 'Retro game sky banner';

  @override
  String get itemBannerSpace => 'Pixel space banner';

  @override
  String canvasWhoNobody(int x, int y) {
    return 'Cell ($x, $y): nobody drew here yet';
  }

  @override
  String canvasWhoSomeone(int x, int y, String name) {
    return 'Cell ($x, $y): drawn by $name';
  }

  @override
  String get canvasLeftMember => 'someone who left the group';

  @override
  String get canvasLoadFailed => 'Could not load the canvas.';

  @override
  String get canvasNone => 'This group has no canvas yet.';

  @override
  String get canvasNoInk => 'Out of ink: finish a quest to get 10 ink.';

  @override
  String get canvasInkHint =>
      'Each cell costs 1 ink. Hold a cell to see who drew it.';

  @override
  String get canvasOffline => 'Connection lost: the canvas is view-only.';

  @override
  String get canvasArchived => 'This canvas is archived (view-only).';

  @override
  String canvasSemantics(int w, int h) {
    return 'Canvas $w by $h cells. Tap a cell to draw.';
  }

  @override
  String colorSemantics(int n) {
    return 'Colour $n';
  }

  @override
  String get peQuestExpired =>
      'The quest expired at 00:00. Today has a new one!';

  @override
  String get peAlreadyDone => 'You already finished the quest today.';

  @override
  String get peNoAttempts => 'No tries left today. Come back tomorrow!';

  @override
  String get peNotPassed => 'The quest photo has not passed the check.';

  @override
  String peCaptionTooLong(int max) {
    return 'Captions can be $max characters at most.';
  }

  @override
  String get peAlreadyOwned => 'You already own this item.';

  @override
  String get peNotOwned => 'Buy this item first.';

  @override
  String get peItemNotFound => 'Could not find that item.';

  @override
  String get peNeedsNetwork => 'You need a connection to do this.';

  @override
  String peNotEnoughSunbit(int missing) {
    return '$missing Sunbit short';
  }

  @override
  String get peUnknown => 'Something went wrong. Please try again.';

  @override
  String get qcNeedsLaptop =>
      'Connect to your laptop to check the photo. Tap the server button (the blue one) to set it up.';

  @override
  String qcLaptopFailed(String detail) {
    return 'Could not check the photo ($detail). The try is not used up.';
  }

  @override
  String get qcQuestUnknown =>
      'This quest is not in the photo checker yet. Please update the app.';

  @override
  String get qcUnreadable =>
      'Could not read the photo. The try is not used up.';

  @override
  String get qcDeviceFailed =>
      'Could not check the photo on this phone. The try is not used up.';

  @override
  String get seNotSetUp => 'The laptop server is not set up';

  @override
  String get seTooLong => 'The laptop took too long';

  @override
  String get seWrongToken => 'Wrong server token';

  @override
  String get sePhotoTooLarge => 'The photo is too large for the server';

  @override
  String get seBusy => 'The laptop is busy';

  @override
  String get seNoAnswer => 'The laptop did not answer';

  @override
  String get seUnreachable => 'The laptop is not reachable';

  @override
  String get seFailed => 'The laptop could not make the picture';

  @override
  String get appTagline => 'NEO BRUTAL CAMERA CLUB';

  @override
  String get archiveEmptyTitle => 'NOTHING\nPRINTED YET';

  @override
  String get galleryRoomTitle => 'GALLERY ROOM';

  @override
  String get styleNone => 'NO STYLE';

  @override
  String get sourceLaptop => 'LAPTOP · DIFFUSION';

  @override
  String get sourceOnDevice => 'ON DEVICE';

  @override
  String get sourceMagenta => 'FALLBACK · MAGENTA';

  @override
  String get sourceMock => 'FALLBACK · MOCK';

  @override
  String get sourceOriginal => 'ORIGINAL';

  @override
  String get timeNow => 'now';

  @override
  String timeMinutes(int n) {
    return '${n}m';
  }

  @override
  String timeHours(int n) {
    return '${n}h';
  }

  @override
  String timeDays(int n) {
    return '${n}d';
  }

  @override
  String get periodAm => 'AM';

  @override
  String get periodPm => 'PM';

  @override
  String get sendMessageHint => 'Send a message...';

  @override
  String get youUpper => 'YOU';

  @override
  String get lfNeedNameHandle => 'Enter a name and handle.';

  @override
  String get lfHandleTaken => 'That handle is already in your friends.';

  @override
  String get lfWriteSomething => 'Write a message or attach a print.';

  @override
  String get lfFriendMissing => 'Friend not found.';

  @override
  String get lfWriteReply => 'Write a reply or pick an emoji.';

  @override
  String get lfPostGone => 'That post is gone.';

  @override
  String seStatus(String code) {
    return 'The server answered $code';
  }

  @override
  String seFailedDetail(String detail) {
    return 'The laptop failed: $detail';
  }

  @override
  String get seError => 'Laptop error';

  @override
  String get seMagentaFailed => 'The on-device Van Gogh model failed';

  @override
  String styleBadge(String style) {
    return 'STYLE: $style';
  }

  @override
  String get sampleCaptionAva => 'Morning light looked unreal';

  @override
  String get sampleCaptionJules => 'Coffee walk after class';

  @override
  String get sampleCaptionRemy => 'Fresh print from the darkroom';

  @override
  String get sampleMessageAva => 'Morning light looked unreal today.';

  @override
  String get sampleMessageJules => 'Coffee walk after class?';

  @override
  String get sampleMessageRemy => 'That print turned out so good.';

  @override
  String quoteReactedTo(String whose) {
    return 'REACTED TO $whose';
  }

  @override
  String quoteRepliedTo(String whose) {
    return 'REPLIED TO $whose';
  }

  @override
  String sayHelloTo(String name) {
    return 'SAY HELLO TO $name';
  }

  @override
  String printNumber(String n) {
    return 'PRINT NO. $n';
  }

  @override
  String printListTitle(String n) {
    return 'PRINT $n';
  }

  @override
  String get peSoldOut => 'Sold out. See you next week!';

  @override
  String get contestEnterGalleryEmpty => 'ENTER GALLERY';

  @override
  String get hallOfFameButton => 'HALL OF FAME';

  @override
  String get hallOfFameTitle => 'Hall of Fame';

  @override
  String get hallViewRoom => 'Switch to room view';

  @override
  String get hallEmpty =>
      'Nothing has been honoured yet. The top three of every week hang here for good.';

  @override
  String hallSemantics(int count) {
    return 'Hall of Fame room with $count paintings. Swipe up to walk forward and tap one to look closer. Use the grid button to browse as a list.';
  }

  @override
  String get entrySavePhoto => 'SAVE PHOTO';

  @override
  String get entrySavedSnack => 'Saved to your photo library.';

  @override
  String get entrySaveFailed =>
      'Could not save the painting. Please try again.';

  @override
  String get entryShareFailed =>
      'Could not share the painting. Please try again.';

  @override
  String entryShareText(String group) {
    return '$group\'s painting in the Gallery Room';
  }

  @override
  String bannerArtSemantics(String group) {
    return 'Painting banner of the group $group';
  }

  @override
  String get shopPaintingsTab => 'PAINTINGS';

  @override
  String get shopPaintingsFailed => 'Could not load the winning paintings.';

  @override
  String get shopPaintingsEmpty =>
      'No painting has won yet. The top three entries of every week are sold here as banners for your profile.';

  @override
  String shopCopiesLeft(int count) {
    return '$count LEFT';
  }

  @override
  String get shopSoldOut => 'SOLD OUT';

  @override
  String shopLimitedNote(int left, int total) {
    return 'Limited edition: $left of $total left. 20% of every sale is shared by the group that painted it.';
  }
}
