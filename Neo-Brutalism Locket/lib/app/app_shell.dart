import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:neo_brutalism_locket/core/app_settings.dart';
import 'package:neo_brutalism_locket/core/backend/backend.dart';
import 'package:neo_brutalism_locket/core/backend/media_urls.dart';
import 'package:neo_brutalism_locket/features/canvas/canvas_repository.dart';
import 'package:neo_brutalism_locket/features/contest/banner_art.dart';
import 'package:neo_brutalism_locket/features/contest/contest_repository.dart';
import 'package:neo_brutalism_locket/features/contest/contest_screen.dart';
import 'package:neo_brutalism_locket/features/contest/contest_store.dart';
import 'package:neo_brutalism_locket/features/contest/contest_widgets.dart';
import 'package:neo_brutalism_locket/features/groups/group_home_screen.dart';
import 'package:neo_brutalism_locket/features/groups/groups_repository.dart';
import 'package:neo_brutalism_locket/features/groups/groups_screen.dart';
import 'package:neo_brutalism_locket/features/groups/groups_store.dart';
import 'package:neo_brutalism_locket/features/groups/groups_widgets.dart';
import 'package:neo_brutalism_locket/features/auth/auth_repository.dart';
import 'package:neo_brutalism_locket/features/safety/safety_repository.dart';
import 'package:neo_brutalism_locket/features/safety/safety_widgets.dart';
import 'package:neo_brutalism_locket/features/settings/settings_screen.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/chat/chat_repository.dart';
import 'package:neo_brutalism_locket/features/chat/chat_store.dart';
import 'package:neo_brutalism_locket/features/history/history_screen.dart';
import 'package:neo_brutalism_locket/features/widget/widget_data.dart';
import 'package:neo_brutalism_locket/features/widget/widget_updater.dart';
import 'package:neo_brutalism_locket/features/notifications/push_service.dart';
import 'package:neo_brutalism_locket/features/progress/server_player_repository.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_type.dart';
import 'package:neo_brutalism_locket/features/posts/interactions_repository.dart';
import 'package:neo_brutalism_locket/features/posts/interactions_store.dart';
import 'package:neo_brutalism_locket/features/posts/media_actions.dart';
import 'package:neo_brutalism_locket/features/posts/post_models.dart';
import 'package:neo_brutalism_locket/features/posts/post_composer.dart';
import 'package:neo_brutalism_locket/features/posts/post_outbox.dart';
import 'package:neo_brutalism_locket/features/posts/posts_repository.dart';
import 'package:neo_brutalism_locket/features/posts/posts_store.dart';
import 'package:neo_brutalism_locket/features/auth/account_session.dart';
import 'package:neo_brutalism_locket/features/friends/friends_repository.dart';
import 'package:neo_brutalism_locket/features/friends/friends_store.dart';
import 'package:neo_brutalism_locket/features/friends/friends_widgets.dart';
import 'package:neo_brutalism_locket/core/haptics.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';
import 'package:neo_brutalism_locket/features/camera/camera_experience.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_engine_factory.dart';
import 'package:neo_brutalism_locket/features/photos/archive_screen.dart';
import 'package:neo_brutalism_locket/features/photos/photo_repository.dart';
import 'package:neo_brutalism_locket/features/profile/profile_screen.dart';
import 'package:neo_brutalism_locket/features/progress/player_store.dart';
import 'package:neo_brutalism_locket/features/quest/on_device/on_device_quest_verifier.dart';
import 'package:neo_brutalism_locket/features/quest/quest_card.dart';
import 'package:neo_brutalism_locket/features/quest/quest_catalog.dart';
import 'package:neo_brutalism_locket/features/quest/quest_post_screen.dart';
import 'package:neo_brutalism_locket/features/quest/quest_verifier.dart';
import 'package:neo_brutalism_locket/features/shop/shop_screen.dart';
import 'package:neo_brutalism_locket/features/social/feed_view.dart';
import 'package:neo_brutalism_locket/features/social/social_repository.dart';
import 'package:neo_brutalism_locket/features/social/social_views.dart';
import 'package:neo_brutalism_locket/features/wallet/sunbit_badge.dart';

/// The app frame: status strip (streak + Sunbit), the five tabs and the state
/// they share (prints, friends, the player). The camera lives in [CameraTab].
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    this.playerStore,
    this.questVerifier,
    this.session,
    this.friendsRepository,
    this.inviteLinks,
    this.postsRepository,
    this.outbox,
    this.mediaUrls,
    this.chatRepository,
    this.interactionsRepository,
    this.mediaActions,
    this.safetyRepository,
    this.authRepository,
    this.settings,
    this.push,
    this.notificationPrefs,
    this.widgetUpdater,
    this.groupsRepository,
    this.canvasRepository,
    this.contestRepository,
  });

  /// The weekly contest and the Gallery (same rule as [groupsRepository]).
  final ContestRepository? contestRepository;

  /// Groups on the server (built from [session] when not given and a backend
  /// is configured).
  final GroupsRepository? groupsRepository;

  /// The shared canvas on the server (same rule as [groupsRepository]).
  final CanvasRepository? canvasRepository;

  /// The home-screen widget (the phone's by default).
  final WidgetUpdater? widgetUpdater;

  /// Push notifications (Firebase when not given).
  final PushGateway? push;

  /// Saved notification choices (built from [session] when not given).
  final NotificationPrefsRepository? notificationPrefs;

  /// Block / report on the server (built from [session] when not given).
  final SafetyRepository? safetyRepository;

  /// Used for changing the password (the real one when not given).
  final AuthRepository? authRepository;

  /// Phone-wide choices such as the language.
  final AppSettings? settings;

  /// Chat on the server (built from [session] when not given).
  final ChatRepository? chatRepository;

  /// Reactions and views on the server (built from [session] when not given).
  final InteractionsRepository? interactionsRepository;

  /// Save / share a picture (the phone's by default).
  final MediaActions? mediaActions;

  /// Posts on the server (built from [session] when not given).
  final PostsRepository? postsRepository;

  /// Posts waiting to be sent (built from [session] when not given).
  final PostOutbox? outbox;

  /// Resolves picture URLs (Supabase signed URLs when not given).
  final MediaUrls? mediaUrls;

  /// Friends from the server (built from [session] when not given).
  final FriendsRepository? friendsRepository;

  /// Invite links opened while the app runs (the system's by default).
  final Stream<Uri>? inviteLinks;

  /// The signed-in account; null when running without a backend.
  final AccountSession? session;

  /// Quest, Sunbit and shop state (created here when not given).
  final PlayerStore? playerStore;

  /// Checks quest photos (on the phone by default).
  final QuestVerifier? questVerifier;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  final PhotoRepository _repository = PhotoRepository();
  final SocialRepository _socialRepository = SocialRepository();
  final StyleEngineFactory _styleEngineFactory = const StyleEngineFactory();
  final GlobalKey<CameraTabState> _cameraKey = GlobalKey<CameraTabState>();
  late final QuestVerifier _questVerifier =
      widget.questVerifier ?? OnDeviceQuestVerifier();
  late final PlayerStore _player =
      widget.playerStore ??
      PlayerStore(
        // With an account Sunbit, streak and the shop live on the server.
        repository: widget.session == null
            ? null
            : ServerPlayerRepository(userId: widget.session!.user.id),
      );
  Timer? _dayTimer;
  int? _shownDay;
  List<NeoPhoto> _photos = [];
  List<PocketFriend> _friends = [];
  List<PocketMessage> _messages = [];
  List<FriendPost> _posts = [];
  PocketFriend? _activeFriend;
  int _tabIndex = 0;
  bool _showFeed = false;
  FriendsStore? _friendsStore;
  GroupsStore? _groupsStore;
  CanvasRepository? _canvasRepository;
  ContestStore? _contestStore;
  ContestArtCache? _artCache;

  /// Which list the FRIENDS tab shows: friends (false) or groups (true).
  bool _showGroups = false;
  PostsStore? _postsStore;
  ChatStore? _chat;
  InteractionsStore? _interactions;
  SafetyRepository? _safety;
  WidgetUpdater? _widget;
  Future<void> Function()? _beforeSignOut;
  StreamSubscription<PushTap>? _pushSubscription;
  PostOutbox? _outbox;
  MediaUrls? _mediaUrls;
  Timer? _outboxTimer;
  StreamSubscription<Uri>? _linkSubscription;

  /// True with a real account: friends come from the server.
  bool get _online => widget.session != null;

  CameraTabState? get _camera => _cameraKey.currentState;

  @override
  void initState() {
    super.initState();
    _player.addListener(_onPlayerChanged);
    _loadPlayer();
    _loadArchive();
    final session = widget.session;
    if (session != null) {
      final store = FriendsStore(
        widget.friendsRepository ??
            SupabaseFriendsRepository(myId: session.user.id),
      );
      _friendsStore = store..addListener(_onFriendsChanged);
      store.refresh();
      final groupsRepository =
          widget.groupsRepository ??
          (Backend.isReady
              ? SupabaseGroupsRepository(myId: session.user.id)
              : null);
      if (groupsRepository != null) {
        _groupsStore = GroupsStore(groupsRepository)
          ..addListener(_onGroupsChanged)
          ..refresh();
      }
      _canvasRepository =
          widget.canvasRepository ??
          (Backend.isReady ? SupabaseCanvasRepository() : null);
      final contestRepository =
          widget.contestRepository ??
          (Backend.isReady ? SupabaseContestRepository() : null);
      if (contestRepository != null) {
        // No listener here: the banner and the contest screen listen themselves,
        // and the countdown must not rebuild the whole shell every second.
        _contestStore = ContestStore(contestRepository)..refresh();
        _artCache = ContestArtCache(contestRepository);
      }
      final posts = PostsStore(
        widget.postsRepository ??
            SupabasePostsRepository(myId: session.user.id),
      );
      _postsStore = posts
        ..addListener(_onPostsChanged)
        ..addListener(_onPostsLoaded);
      _chat =
          ChatStore(
              widget.chatRepository ??
                  SupabaseChatRepository(myId: session.user.id),
              myId: session.user.id,
            )
            ..addListener(_onChatChanged)
            ..refresh();
      _safety =
          widget.safetyRepository ??
          SupabaseSafetyRepository(myId: session.user.id);
      final updater = widget.widgetUpdater ?? WidgetUpdater();
      _widget = updater;
      final push =
          widget.push ??
          FirebasePushGateway(
            devices: SupabaseDeviceRepository(),
            onData: (data) => updater.applyData(data),
          );
      _pushSubscription = push.taps.listen(_onPushTap);
      // Before signing out: stop pushes to this phone (still signed in then)
      // and take the account's photo off the home screen.
      _beforeSignOut = () async {
        await push.stop();
        await updater.clear();
      };
      session.beforeSignOut = _beforeSignOut;
      push.start();
      _interactions = InteractionsStore(
        widget.interactionsRepository ??
            SupabaseInteractionsRepository(myId: session.user.id),
        myId: session.user.id,
      )..addListener(_onPostsChanged);
      _outbox =
          widget.outbox ??
          PostOutbox(repository: posts.repository, userId: session.user.id);
      _mediaUrls = widget.mediaUrls ?? SupabaseMediaUrls();
      WidgetsBinding.instance.addObserver(this);
      _syncPosts();
      _outboxTimer = Timer.periodic(
        const Duration(seconds: 60),
        (_) => _flushOutbox(),
      );
      _listenForInviteLinks();
    } else {
      _loadSocial();
    }
    // A new quest day starts at 00:00 Vietnam time, even with the app open.
    _dayTimer = Timer.periodic(const Duration(seconds: 30), (_) => _checkDay());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pushSubscription?.cancel();
    if (widget.session?.beforeSignOut == _beforeSignOut) {
      widget.session?.beforeSignOut = null;
    }
    _outboxTimer?.cancel();
    _postsStore
      ?..removeListener(_onPostsChanged)
      ..removeListener(_onPostsLoaded)
      ..dispose();
    _outbox?.dispose();
    _chat
      ?..removeListener(_onChatChanged)
      ..dispose();
    _interactions
      ?..removeListener(_onPostsChanged)
      ..dispose();
    _linkSubscription?.cancel();
    _friendsStore
      ?..removeListener(_onFriendsChanged)
      ..dispose();
    _groupsStore
      ?..removeListener(_onGroupsChanged)
      ..dispose();
    _contestStore?.dispose();
    _dayTimer?.cancel();
    _player.removeListener(_onPlayerChanged);
    if (widget.playerStore == null) _player.dispose();
    super.dispose();
  }

  void _onPlayerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadPlayer() async {
    try {
      await _player.load();
      _shownDay = _player.today;
    } catch (_) {
      if (mounted) _notify(AppLocalizations.of(context).questDataUnreadable);
    }
  }

  void _checkDay() {
    final day = _player.today;
    if (_shownDay == null || day == _shownDay) return;
    _shownDay = day;
    _player.refreshDay();
    _camera?.onNewDay();
  }

  Future<void> _openQuestSheet() async {
    if (!_player.isLoaded) return;
    final action = await showQuestSheet(context, _player);
    if (!mounted || action == null) return;
    switch (action) {
      case QuestSheetAction.start:
        final quest = _player.todayQuest;
        if (quest == null) return;
        _showCamera();
        _camera?.startQuest(quest);
      case QuestSheetAction.post:
        await _resumeQuestPost();
    }
  }

  /// Opens the styling + caption + post screen for a photo that passed.
  Future<void> _openQuestPost(Quest quest, NeoPhoto photo, int day) async {
    final posted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => QuestPostScreen(
          store: _player,
          quest: quest,
          photo: photo,
          questDay: day,
          photoRepository: _repository,
          styleEngineFactory: _styleEngineFactory,
        ),
      ),
    );
    await _loadArchive();
    if (!mounted) return;
    if (posted == true) {
      // With an account the quest post also goes to all friends.
      final mine = _player.lastCompletedPost;
      if (_online && mine != null && mine.photoId == photo.id) {
        await _queuePost(
          file: File(mine.imagePath),
          caption: mine.caption,
          style: mine.style,
          questId: mine.questId,
          friendCount: _friendsStore?.friends.length,
        );
      }
      // Show the new post in the feed, with its music.
      if (mounted) setState(() => _showFeed = true);
    }
  }

  /// "Post now": the photo passed earlier today but was not posted yet.
  Future<void> _resumeQuestPost() async {
    final quest = _player.todayQuest;
    final photoId = _player.passedPhotoId;
    if (quest == null || photoId == null) return;
    await _loadArchive();
    final photo = _photos.where((photo) => photo.id == photoId).firstOrNull;
    if (photo == null) {
      _showCamera();
      _camera?.startQuest(quest);
      _notify('KHÔNG TÌM THẤY ẢNH · HÃY CHỤP LẠI');
      return;
    }
    await _openQuestPost(quest, photo, _player.today);
  }

  Future<void> _openFriendProfile(
    PocketFriend friend,
  ) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) {
        final page = FriendProfileScreen(
          friend: friend,
          posts: _posts.where((post) => post.friendId == friend.id).toList(),
          store: _player,
          onBlock: _online
              ? () async {
                  if (await _blockFriend(friend) && context.mounted) {
                    Navigator.of(context).pop();
                  }
                }
              : null,
          onReport: _online ? () => _reportPerson(friend) : null,
        );
        return _withScopes(page);
      },
    ),
  );

  Future<void> _loadArchive() async {
    try {
      final photos = await _repository.loadPhotos();
      if (mounted) setState(() => _photos = photos);
    } catch (_) {
      if (mounted) _notify(AppLocalizations.of(context).archiveUnreadable);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the background: send what waited, and see what friends sent
    // meanwhile (realtime only reports what happens while the app is open).
    if (state == AppLifecycleState.resumed && _online) {
      _syncPosts();
      _chat?.refresh();
      _friendsStore?.refresh();
      _groupsStore?.refresh();
      _contestStore?.refresh();
    }
  }

  void _onGroupsChanged() {
    if (mounted) setState(() {});
  }

  void _openContest() {
    final contest = _contestStore;
    final canvas = _canvasRepository;
    if (contest == null || canvas == null) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            ContestScreen(store: contest, canvases: canvas, safety: _safety),
      ),
    );
  }

  void _openGroup(GroupSummary summary) {
    final groups = _groupsStore;
    final friends = _friendsStore;
    final canvas = _canvasRepository;
    if (groups == null || friends == null || canvas == null) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => GroupHomeScreen(
          groupId: summary.group.id,
          groups: groups,
          friends: friends,
          canvasRepository: canvas,
          myId: widget.session!.user.id,
          safety: _safety,
        ),
      ),
    );
  }

  void _onPostsChanged() {
    if (mounted) setState(() {});
  }

  int _lastLoadedPosts = -1;

  /// New posts: also load who reacted to / saw them.
  void _onPostsLoaded() {
    final posts = _postsStore?.posts ?? const [];
    final signature = Object.hashAll(posts.map((p) => p.id));
    if (signature == _lastLoadedPosts) return;
    _lastLoadedPosts = signature;
    _interactions?.load(posts);
    _refreshWidget();
  }

  /// Puts the newest friend photo on the home-screen widget.
  void _refreshWidget() {
    final updater = _widget;
    final urls = _mediaUrls;
    final me = widget.session?.user.id;
    if (updater == null || urls == null || me == null) return;
    updater
        .refreshFromFeed(
          posts: _postsStore?.posts ?? const [],
          myId: me,
          friendNames: {for (final f in _friends) f.id: f.name},
          urls: urls,
        )
        .catchError((Object _) {});
  }

  void _onChatChanged() {
    final open = _activeFriend;
    // A message arrives in the conversation that is on screen: it is read.
    if (open != null && _tabIndex == 2) _chat?.markRead(open.id);
    if (mounted) setState(() {});
  }

  /// Messages for the chat screens: the server's with an account, else local.
  List<PocketMessage> get _allMessages {
    final chat = _chat;
    if (chat == null) return _messages;
    return chat.asPocketMessages(
      captionOf: (postId) {
        final post = _postsStore?.posts
            .where((p) => p.id == postId)
            .firstOrNull;
        if (post == null) return '';
        return post.caption.isEmpty ? '📷' : post.caption;
      },
    );
  }

  /// Sends queued posts, then reloads the feed.
  Future<void> _syncPosts() async {
    await _flushOutbox();
    await _postsStore?.refresh();
  }

  Future<void> _flushOutbox() async {
    final sent = await _outbox?.flush() ?? 0;
    if (sent > 0) await _postsStore?.refresh();
  }

  /// Encodes [file], queues it and tries to send it right away. True once it
  /// is sent or safely queued.
  Future<bool> _queuePost({
    required File file,
    required String caption,
    StyleType? style,
    String? questId,
    Map<String, dynamic>? overlay,
    List<String>? recipients,
    int? friendCount,
  }) => _queueAndSend(
    (outbox) => outbox.enqueue(
      source: file,
      caption: caption,
      style: style,
      questId: questId,
      overlay: overlay,
      recipients: recipients,
    ),
    recipients: recipients,
    friendCount: friendCount,
  );

  /// Queues a post with [enqueue], tries to send it, and says how it went.
  /// True once it is sent or safely queued.
  Future<bool> _queueAndSend(
    Future<String> Function(PostOutbox outbox) enqueue, {
    List<String>? recipients,
    int? friendCount,
  }) async {
    final outbox = _outbox;
    if (outbox == null) return false;
    final l10n = AppLocalizations.of(context);
    try {
      final id = await enqueue(outbox);
      await outbox.flush();
      final stillWaiting = (await outbox.pending()).any((p) => p.id == id);
      if (!mounted) return true;
      if (stillWaiting) {
        _notify(l10n.composerQueued);
      } else {
        final count = friendCount ?? recipients?.length ?? 0;
        if (count > 0) _notify(l10n.composerSentTo(count));
        await _postsStore?.refresh();
      }
      return true;
    } catch (_) {
      if (mounted) _notify(l10n.errUnknown);
      return false;
    }
  }

  /// POST on a shot: caption + who gets it, then queue it. True once it is
  /// sent or queued (false when the person backed out).
  Future<bool> _sendPrint(NeoPhoto photo) async {
    final store = _friendsStore;
    if (store == null) return false;
    final processed = photo.status == ProcessingStatus.done
        ? photo.processedPath
        : null;
    final path = processed ?? photo.originalPath;
    final result = await Navigator.of(context).push<ComposerResult>(
      MaterialPageRoute(
        builder: (context) =>
            PostComposerScreen(imagePath: path, friends: store.friends),
      ),
    );
    if (result == null || !mounted) return false;
    return _queuePost(
      file: File(path),
      caption: result.caption,
      style: processed == null ? StyleType.none : photo.styleType,
      overlay: result.overlay,
      recipients: result.recipients,
      friendCount: result.recipients?.length ?? store.friends.length,
    );
  }

  /// A clip from the camera: caption, labels and who gets it, then queue it.
  Future<void> _sendVideo(File video) async {
    final store = _friendsStore;
    if (store == null) return;
    final result = await Navigator.of(context).push<ComposerResult>(
      MaterialPageRoute(
        builder: (context) => PostComposerScreen(
          imagePath: video.path,
          friends: store.friends,
          isVideo: true,
        ),
      ),
    );
    if (result == null || !mounted) return;
    await _queueAndSend(
      (outbox) => outbox.enqueueVideo(
        video: video,
        caption: result.caption,
        overlay: result.overlay,
        recipients: result.recipients,
      ),
      recipients: result.recipients,
      friendCount: result.recipients?.length ?? store.friends.length,
    );
  }

  /// The server's friend list changed: mirror it locally and refresh the UI.
  Future<void> _onFriendsChanged() async {
    final store = _friendsStore;
    if (store == null) return;
    if (!store.isLoaded) {
      if (mounted) setState(() {});
      return;
    }
    try {
      final friends = [
        for (final friend in store.friends)
          friend.person.toPocketFriend(since: friend.since),
      ];
      final snapshot = await _socialRepository.replaceFriends(friends);
      if (!mounted) return;
      setState(() {
        _friends = snapshot.friends;
        _messages = snapshot.messages;
        _posts = snapshot.posts;
        final active = _activeFriend;
        if (active != null && !friends.any((f) => f.id == active.id)) {
          _activeFriend = null;
        }
      });
      _refreshWidget(); // friends are known now: the widget can name the sender
    } catch (_) {
      _notify(AppLocalizations.of(context).friendsLoadFailed);
    }
  }

  Future<void> _listenForInviteLinks() async {
    final injected = widget.inviteLinks;
    if (injected != null) {
      _linkSubscription = injected.listen(_onInviteLink);
      return;
    }
    try {
      final links = AppLinks();
      _linkSubscription = links.uriLinkStream.listen(_onInviteLink);
      final initial = await links.getInitialLink();
      if (initial != null) _onInviteLink(initial);
    } catch (_) {
      // No link support on this platform: invites just do not open the app.
    }
  }

  /// The home-screen widget was tapped: show that post (or the feed when it
  /// is not loaded yet).
  Future<void> _openPostById(String postId) async {
    if (!mounted || widget.session == null) return;
    _selectTab(0);
    var post = _postsStore?.posts.where((p) => p.id == postId).firstOrNull;
    if (post == null) {
      await _syncPosts();
      post = _postsStore?.posts.where((p) => p.id == postId).firstOrNull;
    }
    if (!mounted) return;
    if (post != null) {
      _openHistoryPost([post], 0);
    } else {
      setState(() => _showFeed = true);
    }
  }

  /// Someone opened an invite link (neolocket://add/NAME): offer to add them.
  void _onInviteLink(Uri uri) {
    final postId = postIdFromLink(uri);
    if (postId != null) {
      _openPostById(postId);
      return;
    }
    final username = usernameFromInviteLink(uri);
    final session = widget.session;
    final store = _friendsStore;
    if (username == null ||
        session == null ||
        store == null ||
        !mounted ||
        username == session.profile.username) {
      return;
    }
    _selectTab(1);
    showAddFriendOnlineSheet(
      context,
      store: store,
      myUsername: session.profile.username ?? '',
      initialUsername: username,
    );
  }

  Future<void> _loadSocial() async {
    if (_online) {
      await Future.wait([
        _friendsStore?.refresh() ?? Future<void>.value(),
        _chat?.refresh() ?? Future<void>.value(),
      ]);
      return;
    }
    try {
      final snapshot = await _socialRepository.load();
      if (!mounted) return;
      setState(() {
        _friends = snapshot.friends;
        _messages = snapshot.messages;
        _posts = snapshot.posts;
      });
    } catch (_) {
      _notify(AppLocalizations.of(context).friendsLoadFailed);
    }
  }

  Future<void> _addFriend() async {
    final session = widget.session;
    final store = _friendsStore;
    if (session != null && store != null) {
      await showAddFriendOnlineSheet(
        context,
        store: store,
        myUsername: session.profile.username ?? '',
      );
      return;
    }
    final draft = await showAddFriendSheet(context);
    if (draft == null) return;
    try {
      final snapshot = await _socialRepository.addFriend(
        name: draft.name,
        handle: draft.handle,
      );
      if (!mounted) return;
      setState(() {
        _friends = snapshot.friends;
        _messages = snapshot.messages;
      });
      _notify(
        AppLocalizations.of(
          context,
        ).friendAddedLocally(draft.name.toUpperCase()),
      );
    } on FormatException catch (error) {
      _notify(error.message.toUpperCase());
    }
  }

  Future<void> _openFriend(PocketFriend friend) async {
    final chat = _chat;
    if (chat != null) {
      setState(() {
        _activeFriend = friend;
        _tabIndex = 2;
      });
      chat.markRead(friend.id);
      // Anything that came in meanwhile (the listener marks it read).
      chat.refresh();
      return;
    }
    final snapshot = await _socialRepository.markThreadRead(friend.id);
    if (!mounted) return;
    setState(() {
      _activeFriend = friend;
      _friends = snapshot.friends;
      _messages = snapshot.messages;
      _tabIndex = 2;
    });
  }

  Future<void> _sendSocialMessage(String text, String? photoPath) async {
    final friend = _activeFriend;
    if (friend == null) return;
    final chat = _chat;
    if (chat != null) {
      await _sendChat(friend.id, text);
      return;
    }
    try {
      final snapshot = await _socialRepository.sendMessage(
        friendId: friend.id,
        text: text,
        photoPath: photoPath,
      );
      if (!mounted) return;
      setState(() {
        _friends = snapshot.friends;
        _messages = snapshot.messages;
      });
    } on FormatException catch (error) {
      _notify(error.message.toUpperCase());
    }
  }

  /// Sends a chat message (about [postId], when replying to a post).
  Future<bool> _sendChat(String toId, String text, {String? postId}) async {
    final chat = _chat;
    if (chat == null) return false;
    final l10n = AppLocalizations.of(context);
    try {
      await chat.send(toId: toId, body: text, postId: postId);
      return true;
    } on ChatFailure catch (failure) {
      if (mounted) {
        _notify(switch (failure.kind) {
          ChatFailureKind.notFound => l10n.chatNotFriends,
          ChatFailureKind.tooLong => l10n.chatTooLong,
          ChatFailureKind.network => l10n.errNetwork,
          _ => l10n.chatSendFailed,
        });
      }
      return false;
    }
  }

  /// Text reply to a friend's post on the feed: lands in the chat with them.
  Future<void> _replyToRemote(RemotePost post, String text) async {
    final sent = await _sendChat(post.authorId, text, postId: post.id);
    if (sent && mounted) _notify(AppLocalizations.of(context).replySent);
  }

  /// Emoji on a friend's post: only the author sees it.
  Future<void> _reactToRemote(RemotePost post, String emoji) async {
    final l10n = AppLocalizations.of(context);
    try {
      await _interactions?.react(post.id, emoji);
      if (mounted) _notify(l10n.reactionSent(emoji));
    } on InteractionFailure {
      if (mounted) _notify(l10n.errUnknown);
    }
  }

  /// A post stayed on screen: tell its author (not for my own posts).
  void _onFeedViewed(FeedEntry entry) {
    final post = entry.remote;
    if (post == null || post.authorId == widget.session?.user.id) return;
    _interactions?.markViewed(post.id);
  }

  /// Block [friend] after confirming. True when they are blocked.
  Future<bool> _blockFriend(PocketFriend friend) async {
    final safety = _safety;
    if (safety == null) return false;
    final l10n = AppLocalizations.of(context);
    if (!await confirmBlock(context, friend.name) || !mounted) return false;
    try {
      await safety.block(friend.id);
    } on SafetyFailure catch (failure) {
      if (mounted) _notify(safetyFailureText(l10n, failure));
      return false;
    }
    await _afterBlocksChanged();
    if (mounted) {
      setState(() {
        if (_activeFriend?.id == friend.id) _activeFriend = null;
      });
      _notify(l10n.blockedDone(friend.name));
    }
    return true;
  }

  /// Friends, feed and chat change when someone is blocked or unblocked.
  Future<void> _afterBlocksChanged() async {
    await _friendsStore?.refresh();
    await _postsStore?.refresh();
    await _chat?.refresh();
  }

  Future<void> _reportPerson(PocketFriend friend) =>
      _sendReport(userId: friend.id, offerBlock: friend);

  Future<void> _reportPost(RemotePost post) => _sendReport(postId: post.id);

  Future<void> _sendReport({
    String? userId,
    String? postId,
    PocketFriend? offerBlock,
  }) async {
    final safety = _safety;
    if (safety == null) return;
    final l10n = AppLocalizations.of(context);
    final draft = await showReportSheet(context);
    if (draft == null || !mounted) return;
    try {
      await safety.report(
        userId: userId,
        postId: postId,
        reason: draft.reason,
        details: draft.details,
      );
      if (mounted) _notify(l10n.reportSent);
    } on SafetyFailure catch (failure) {
      if (mounted) _notify(safetyFailureText(l10n, failure));
    }
  }

  /// A notification was tapped: take the person to what it is about.
  void _onPushTap(PushTap tap) {
    if (!mounted) return;
    switch (tap.type) {
      case 'message':
        final friend = _friends.where((f) => f.id == tap.fromId).firstOrNull;
        if (friend != null) {
          _openFriend(friend);
        } else {
          _selectTab(2); // the inbox, if the friend list is not loaded yet
        }
      case 'friend_request' || 'friend_accepted':
        _selectTab(1);
      default:
        _selectTab(0);
        setState(() => _showFeed = true);
        _syncPosts();
    }
  }

  void _openSettings() {
    final session = widget.session;
    final settings = widget.settings;
    final safety = _safety;
    if (session == null || settings == null || safety == null) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (routeContext) {
          final page = SettingsScreen(
            session: session,
            settings: settings,
            auth: widget.authRepository ?? SupabaseAuthRepository(),
            safety: safety,
            onBlocksChanged: _afterBlocksChanged,
            notifications:
                widget.notificationPrefs ??
                SupabaseNotificationPrefsRepository(userId: session.user.id),
          );
          return _withScopes(page);
        },
      ),
    );
  }

  /// Long-press on a post: save, share, and (my posts) delete.
  Future<void> _showPostMenu(RemotePost post) async {
    final l10n = AppLocalizations.of(context);
    final mine = post.authorId == widget.session?.user.id;
    final urls = _mediaUrls;
    final actions = widget.mediaActions ?? MediaActions(urls);
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.all(18),
        decoration: NeoTheme.panel(color: NeoColors.surface, radius: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NeoButton(
              expand: true,
              label: l10n.postMenuSave,
              icon: Icons.download_rounded,
              variant: NeoButtonVariant.accent,
              onPressed: () => Navigator.pop(context, 'save'),
            ),
            const SizedBox(height: 12),
            NeoButton(
              expand: true,
              label: l10n.postMenuShare,
              icon: Icons.ios_share,
              variant: NeoButtonVariant.outline,
              onPressed: () => Navigator.pop(context, 'share'),
            ),
            if (mine) ...[
              const SizedBox(height: 12),
              NeoButton(
                expand: true,
                label: l10n.postMenuDelete,
                icon: Icons.delete_outline,
                variant: NeoButtonVariant.primary,
                onPressed: () => Navigator.pop(context, 'delete'),
              ),
            ] else ...[
              const SizedBox(height: 12),
              NeoButton(
                expand: true,
                label: l10n.reportPost,
                icon: Icons.flag_outlined,
                variant: NeoButtonVariant.outline,
                onPressed: () => Navigator.pop(context, 'report'),
              ),
            ],
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case 'save':
        final ok = await actions.save(post.mediaPath);
        if (mounted) _notify(ok ? l10n.postSaved : l10n.postSaveFailed);
      case 'share':
        final ok = await actions.share(post.mediaPath, text: post.caption);
        if (!ok && mounted) _notify(l10n.postShareFailed);
      case 'delete':
        await _confirmDeletePost(post);
      case 'report':
        await _reportPost(post);
    }
  }

  Future<void> _confirmDeletePost(RemotePost post) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: NeoColors.surface,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: NeoColors.ink, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        title: Text(
          l10n.postDeleteTitle,
          style: const TextStyle(
            color: NeoColors.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          l10n.postDeleteBody,
          style: const TextStyle(color: NeoColors.ink),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.removeFriendConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _interactions?.deletePost(post);
      await _postsStore?.refresh();
      if (mounted) _notify(l10n.postDeleted);
    } on InteractionFailure {
      if (mounted) _notify(l10n.errUnknown);
    }
  }

  /// Reply to a friend's post from the feed (text or emoji). It is saved to
  /// the conversation with the person who posted (on this device only).
  Future<void> _replyToPost(
    FriendPost post, {
    String text = '',
    String? reaction,
  }) async {
    try {
      final snapshot = await _socialRepository.replyToPost(
        postId: post.id,
        text: text,
        reaction: reaction,
      );
      if (!mounted) return;
      setState(() {
        _friends = snapshot.friends;
        _messages = snapshot.messages;
        _posts = snapshot.posts;
      });
      final name = _friends
          .where((friend) => friend.id == post.friendId)
          .map((friend) => friend.name.split(' ').first)
          .firstOrNull;
      final l10n = AppLocalizations.of(context);
      final what = reaction ?? l10n.replyWord;
      _notify(
        name == null
            ? l10n.sentNotice(what)
            : l10n.sentNoticeTo(what, name.toUpperCase()),
      );
    } on FormatException catch (error) {
      _notify(error.message.toUpperCase());
    }
  }

  void _openFeed() {
    if (_camera?.busy ?? false) return;
    setState(() => _showFeed = true);
    _loadSocial();
    if (_online) _syncPosts();
  }

  Future<void> _sendLatestPrint() async {
    final friend = _activeFriend;
    if (friend == null) return;
    if (_photos.isEmpty) {
      _notify(AppLocalizations.of(context).shareNeedsPrint);
      return;
    }
    final photo = _photos.first;
    await _sendSocialMessage('', photo.processedPath ?? photo.originalPath);
  }

  Future<void> _removeActiveFriend() async {
    final friend = _activeFriend;
    if (friend == null) return;
    if (_online) return _removeOnlineFriend(friend);
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          backgroundColor: NeoColors.surface,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: NeoColors.ink, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          title: Text(
            l10n.removeFriendTitle,
            style: const TextStyle(
              color: NeoColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            l10n.removeLocalFriendBody(friend.name),
            style: const TextStyle(color: NeoColors.ink),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.removeFriendConfirm),
            ),
          ],
        );
      },
    );
    if (remove != true) return;
    final snapshot = await _socialRepository.removeFriend(friend.id);
    if (!mounted) return;
    setState(() {
      _friends = snapshot.friends;
      _messages = snapshot.messages;
      _posts = snapshot.posts;
      _activeFriend = null;
      _tabIndex = 1;
    });
  }

  Future<void> _removeOnlineFriend(PocketFriend friend) async {
    final l10n = AppLocalizations.of(context);
    final store = _friendsStore;
    final person = store?.friendById(friend.id)?.person;
    if (store == null || person == null) return;
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: NeoColors.surface,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: NeoColors.ink, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        title: Text(
          l10n.removeFriendTitle,
          style: const TextStyle(
            color: NeoColors.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          l10n.removeFriendBody(friend.name),
          style: const TextStyle(color: NeoColors.ink),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.removeFriendConfirm),
          ),
        ],
      ),
    );
    if (remove != true || !mounted) return;
    try {
      await store.removeFriend(person);
      if (mounted) setState(() => _tabIndex = 1);
    } on FriendsFailure catch (failure) {
      if (mounted) _notify(friendsFailureText(l10n, failure));
    }
  }

  void _selectTab(int index) {
    Haptics.select();
    setState(() {
      _tabIndex = index;
      _activeFriend = null;
      if (index == 0) _showFeed = false;
    });
    if (index == 0) _camera?.closePrint();
    if (index != 0) _camera?.leaveQuestMode();
    if (index == 1 || index == 2) _loadSocial();
    if (index == 3) _loadArchive();
  }

  void _openPhoto(NeoPhoto photo) {
    _showCamera();
    _camera?.openPhoto(photo);
  }

  /// Switches to the SHOOT tab's camera page.
  void _showCamera() {
    setState(() {
      _tabIndex = 0;
      _showFeed = false;
      _activeFriend = null;
    });
  }

  /// A shot was posted or thrown away: it is no longer on this phone.
  void _onPhotoRemoved(NeoPhoto photo) {
    setState(() {
      _photos = _photos.where((item) => item.id != photo.id).toList();
    });
  }

  /// Keeps the shell's list in sync when the camera saves or styles a print.
  void _onPhotoChanged(NeoPhoto photo) {
    setState(() {
      _photos = [photo, ..._photos.where((item) => item.id != photo.id)];
    });
  }

  void _notify(String message) => showNeoSnack(context, message);

  @override
  Widget build(BuildContext context) {
    final cameraVisible = _tabIndex == 0 && !_showFeed;
    final page = switch (_tabIndex) {
      0 when _showFeed => _feedScreen(
        key: const ValueKey('feed'),
        entries: _online
            ? buildRemoteFeed(
                _postsStore?.posts ?? const [],
                myId: widget.session!.user.id,
                friendIds: {for (final f in _friends) f.id},
              )
            : buildFeed(
                _posts,
                _photos,
                questPosts: _player.state?.questPosts ?? const [],
              ),
        onClose: () => setState(() => _showFeed = false),
      ),
      0 => const SizedBox.shrink(key: ValueKey('camera')),
      1 => _buildFriends(),
      2 =>
        _activeFriend == null
            ? InboxScreen(
                key: const ValueKey('inbox'),
                friends: _friends,
                messages: _allMessages,
                onOpenFriend: _openFriend,
              )
            : ConversationScreen(
                key: ValueKey('thread-${_activeFriend!.id}'),
                friend: _activeFriend!,
                messages: _allMessages
                    .where((message) => message.friendId == _activeFriend!.id)
                    .toList(),
                onBack: () => setState(() => _activeFriend = null),
                onSend: _sendSocialMessage,
                onSendLatestPhoto: _sendLatestPrint,
                onRemoveFriend: _removeActiveFriend,
                posts: _posts,
                onOpenProfile: () => _openFriendProfile(_activeFriend!),
                allowPhoto: !_online,
              ),
      3 when _online => _buildHistoryTab(),
      3 => ArchiveScreen(
        key: const ValueKey('archive'),
        photos: _photos,
        onOpenPhoto: _openPhoto,
        onOpenCamera: () => _selectTab(0),
      ),
      _ => ProfileScreen(
        key: const ValueKey('profile'),
        store: _player,
        session: widget.session,
        onOpenSettings: _online && widget.settings != null
            ? _openSettings
            : null,
        remoteQuestPosts: _online
            ? [
                for (final post in _postsStore?.posts ?? const <RemotePost>[])
                  if (post.authorId == widget.session!.user.id &&
                      post.questId != null)
                    post,
              ]
            : null,
        onOpenRemote: _openHistoryPost,
      ),
    };
    final scaffold = Scaffold(
      backgroundColor: NeoColors.paper,
      body: SafeArea(
        child: Column(
          children: [
            _buildStatusStrip(),
            Expanded(
              child: Stack(
                // Fill the area even while the camera is off-stage (size 0).
                fit: StackFit.expand,
                children: [
                  // Always mounted, so the camera does not restart per tab.
                  Offstage(
                    offstage: !cameraVisible,
                    child: TickerMode(
                      enabled: cameraVisible,
                      child: CameraTab(
                        key: _cameraKey,
                        player: _player,
                        photos: _photos,
                        repository: _repository,
                        styleEngineFactory: _styleEngineFactory,
                        questVerifier: _questVerifier,
                        onPhotoChanged: _onPhotoChanged,
                        onOpenFeed: _openFeed,
                        onOpenArchive: () => _selectTab(3),
                        onOpenQuestSheet: _openQuestSheet,
                        onQuestPassed: _openQuestPost,
                        onSendPrint: _online ? _sendPrint : null,
                        onPhotoRemoved: _onPhotoRemoved,
                        onVideoRecorded: _online ? _sendVideo : null,
                      ),
                    ),
                  ),
                  if (!cameraVisible)
                    Positioned.fill(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 140),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: page,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildTabs(),
    );
    return _withScopes(scaffold);
  }

  /// What every page of the app needs below it: where pictures come from, and the
  /// paintings of the contest (a painting-banner is drawn from them).
  Widget _withScopes(Widget page) {
    var wrapped = page;
    final art = _artCache;
    if (art != null) wrapped = ContestArtScope(cache: art, child: wrapped);
    final urls = _mediaUrls;
    if (urls != null) wrapped = MediaUrlsScope(urls: urls, child: wrapped);
    return wrapped;
  }

  Widget _buildFriends() {
    final store = _friendsStore;
    if (store == null) {
      return FriendsScreen(
        key: const ValueKey('friends'),
        friends: _friends,
        messages: _messages,
        onAddFriend: _addFriend,
        onOpenFriend: _openFriend,
      );
    }
    final l10n = AppLocalizations.of(context);
    final groups = _groupsStore;
    final segment = groups == null
        ? null
        : FriendsGroupsSwitch(
            showGroups: _showGroups,
            groupUnread: groups.totalUnread,
            onChanged: (value) => setState(() => _showGroups = value),
          );
    if (groups != null && _showGroups) {
      return GroupsScreen(
        key: const ValueKey('groups'),
        store: groups,
        segment: segment,
        header: _contestStore == null
            ? null
            : ContestBanner(store: _contestStore!, onTap: _openContest),
        onOpenGroup: _openGroup,
      );
    }
    return FriendsScreen(
      key: const ValueKey('friends'),
      segment: segment,
      friends: _friends,
      messages: _allMessages,
      onAddFriend: _addFriend,
      onOpenFriend: _openFriend,
      online: true,
      onRefresh: store.refresh,
      addLabel: l10n.friendsAdd,
      onlineLabel: l10n.friendsOnline,
      emptyTitle: l10n.friendsEmptyTitle,
      emptyBody: l10n.friendsEmptyBody,
      requests: RequestsSection(
        incoming: store.incoming,
        outgoing: store.outgoing,
        onRespond: _respondToRequest,
        onCancel: _cancelRequest,
      ),
    );
  }

  Future<void> _respondToRequest(FriendRequest request, bool accept) async {
    final l10n = AppLocalizations.of(context);
    try {
      await _friendsStore?.respond(request, accept: accept);
      if (accept && mounted) {
        _notify(l10n.nowFriendsWith(request.person.displayName));
      }
    } on FriendsFailure catch (failure) {
      if (mounted) _notify(friendsFailureText(l10n, failure));
      await _friendsStore?.refresh();
    }
  }

  Future<void> _cancelRequest(FriendRequest request) async {
    final l10n = AppLocalizations.of(context);
    try {
      await _friendsStore?.cancel(request);
    } on FriendsFailure catch (failure) {
      if (mounted) _notify(friendsFailureText(l10n, failure));
    }
  }

  /// The feed UI, for the feed itself and for the history viewer.
  FeedScreen _feedScreen({
    Key? key,
    required List<FeedEntry> entries,
    required VoidCallback onClose,
    int initialPage = 0,
  }) => FeedScreen(
    key: key,
    entries: entries,
    initialPage: initialPage,
    friends: _friends,
    onClose: onClose,
    onReplyText: (post, text) => _replyToPost(post, text: text),
    onReact: (post, emoji) => _replyToPost(post, reaction: emoji),
    onOpenPrint: _openPhoto,
    self: FeedSelf(
      avatarPath: _player.state?.avatarPath,
      frameId: _player.state?.equippedFrame,
      userId: widget.session?.user.id,
    ),
    onOpenFriend: _openFriendProfile,
    onOpenSelf: () => _selectTab(4),
    musicMuted: _player.state?.musicMuted ?? false,
    onMuteChanged: _player.setMusicMuted,
    onReplyRemote: _online ? _replyToRemote : null,
    onReactRemote: _online ? _reactToRemote : null,
    onViewed: _online ? _onFeedViewed : null,
    onPostMenu: _online ? _showPostMenu : null,
    activity: _interactions?.activity ?? const {},
  );

  bool _historyOnDevice = false;

  /// Tab 3 with an account: posts sent and received, or the prints kept on
  /// this phone.
  Widget _buildHistoryTab() {
    final l10n = AppLocalizations.of(context);
    final posts = _postsStore;
    Widget chip(String label, bool selected, VoidCallback onTap) => Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 36,
            alignment: Alignment.center,
            decoration: NeoTheme.panel(
              color: selected ? NeoColors.teal : NeoColors.surface,
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: NeoColors.ink,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
    return Column(
      key: const ValueKey('history'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 22, 0),
          child: Row(
            children: [
              chip(
                l10n.historyPosts,
                !_historyOnDevice,
                () => setState(() => _historyOnDevice = false),
              ),
              const SizedBox(width: 12),
              chip(
                l10n.historyOnDevice,
                _historyOnDevice,
                () => setState(() => _historyOnDevice = true),
              ),
            ],
          ),
        ),
        Expanded(
          child: _historyOnDevice
              ? ArchiveScreen(
                  photos: _photos,
                  onOpenPhoto: _openPhoto,
                  onOpenCamera: () => _selectTab(0),
                )
              : HistoryScreen(
                  posts: posts?.posts ?? const [],
                  friends: _friends,
                  myId: widget.session!.user.id,
                  onOpen: _openHistoryPost,
                  hasMore: posts?.hasMore ?? false,
                  loadingMore: posts?.isLoadingMore ?? false,
                  failed: posts?.failed ?? false,
                  onLoadMore: posts?.loadMore,
                  onRefresh: _syncPosts,
                ),
        ),
      ],
    );
  }

  /// A picture from the history grid: swipe through the (filtered) posts.
  void _openHistoryPost(List<RemotePost> posts, int index) {
    final urls = _mediaUrls;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (routeContext) {
          Widget page = Scaffold(
            backgroundColor: NeoColors.paper,
            body: SafeArea(
              child: _feedScreen(
                entries: [for (final post in posts) FeedEntry.remote(post)],
                initialPage: index,
                onClose: () => Navigator.of(routeContext).pop(),
              ),
            ),
          );
          if (urls != null) page = MediaUrlsScope(urls: urls, child: page);
          return page;
        },
      ),
    );
  }

  /// Always on top: the streak (opens today's quest) and the Sunbit balance
  /// (opens the shop).
  Widget _buildStatusStrip() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
      child: Row(
        children: [
          StreakChip(streak: _player.streak, onTap: _openQuestSheet),
          const Spacer(),
          SunbitBadge(
            balance: _player.balance,
            onTap: () => openShop(context, _player),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 22, 12),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: NeoColors.surface,
            border: Border.all(color: NeoColors.ink, width: 2),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: NeoColors.ink,
                offset: Offset(4, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: Row(
            children: [
              _tab(
                index: 0,
                icon: Icons.photo_camera_outlined,
                label: l10n.tabShoot,
              ),
              Container(width: 1.5, height: 30, color: NeoColors.ink),
              _tab(
                index: 1,
                icon: Icons.people_alt_outlined,
                label: l10n.tabFriends,
              ),
              Container(width: 1.5, height: 30, color: NeoColors.ink),
              _tab(
                index: 2,
                icon: Icons.chat_bubble_outline,
                label: l10n.tabInbox,
              ),
              Container(width: 1.5, height: 30, color: NeoColors.ink),
              _tab(
                index: 3,
                icon: Icons.grid_view_rounded,
                label: _online ? l10n.historyTab : l10n.tabPrints,
              ),
              Container(width: 1.5, height: 30, color: NeoColors.ink),
              _tab(index: 4, icon: Icons.person_outline, label: l10n.tabMe),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final selected = _tabIndex == index;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          onTap: () => _selectTab(index),
          borderRadius: BorderRadius.circular(6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            height: double.infinity,
            decoration: BoxDecoration(
              color: selected ? NeoColors.teal : NeoColors.surface,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: NeoColors.ink, size: 18),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    color: NeoColors.ink,
                    fontFamily: NeoFont.display,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
