import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:neo_brutalism_locket/app/neo_bottom_nav.dart';
import 'package:neo_brutalism_locket/app/shutter_flight.dart';
import 'package:neo_brutalism_locket/app/tab_swipe_detector.dart';
import 'package:neo_brutalism_locket/core/app_settings.dart';
import 'package:neo_brutalism_locket/core/backend/backend.dart';
import 'package:neo_brutalism_locket/core/backend/media_urls.dart';
import 'package:neo_brutalism_locket/features/albums/albums_repository.dart';
import 'package:neo_brutalism_locket/features/albums/albums_store.dart';
import 'package:neo_brutalism_locket/features/canvas/canvas_repository.dart';
import 'package:neo_brutalism_locket/features/contest/banner_art.dart';
import 'package:neo_brutalism_locket/features/contest/contest_repository.dart';
import 'package:neo_brutalism_locket/features/contest/contest_screen.dart';
import 'package:neo_brutalism_locket/features/contest/contest_store.dart';
import 'package:neo_brutalism_locket/features/contest/contest_widgets.dart';
import 'package:neo_brutalism_locket/features/contest/contest_backdrops.dart';
import 'package:neo_brutalism_locket/features/export/media_export.dart';
import 'package:neo_brutalism_locket/features/groups/group_home_screen.dart';
import 'package:neo_brutalism_locket/features/groups/groups_repository.dart';
import 'package:neo_brutalism_locket/features/groups/groups_screen.dart';
import 'package:neo_brutalism_locket/features/groups/groups_store.dart';
import 'package:neo_brutalism_locket/features/groups/groups_widgets.dart';
import 'package:neo_brutalism_locket/features/auth/auth_repository.dart';
import 'package:neo_brutalism_locket/features/rewind/rewind_handoff.dart';
import 'package:neo_brutalism_locket/features/safety/safety_repository.dart';
import 'package:neo_brutalism_locket/features/safety/safety_widgets.dart';
import 'package:neo_brutalism_locket/features/settings/settings_screen.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/core/responsive.dart';
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
import 'package:neo_brutalism_locket/features/posts/post_tags.dart';
import 'package:neo_brutalism_locket/features/posts/posts_repository.dart';
import 'package:neo_brutalism_locket/features/posts/posts_store.dart';
import 'package:neo_brutalism_locket/features/auth/account_session.dart';
import 'package:neo_brutalism_locket/features/friends/friends_repository.dart';
import 'package:neo_brutalism_locket/features/friends/friends_store.dart';
import 'package:neo_brutalism_locket/features/friends/friends_widgets.dart';
import 'package:neo_brutalism_locket/core/haptics.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';
import 'package:neo_brutalism_locket/features/camera/camera_experience.dart';
import 'package:neo_brutalism_locket/core/app_log.dart';
import 'package:neo_brutalism_locket/features/search/embedding_backfill.dart';
import 'package:neo_brutalism_locket/features/search/photo_search.dart';
import 'package:neo_brutalism_locket/features/search/search_backend.dart';
import 'package:neo_brutalism_locket/features/search/search_v2_client.dart';
import 'package:neo_brutalism_locket/features/search/photo_embedding.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_engine_factory.dart';
import 'package:neo_brutalism_locket/features/photos/archive_screen.dart';
import 'package:neo_brutalism_locket/features/pov/pov_actions.dart';
import 'package:neo_brutalism_locket/features/pov/pov_qr_sheet.dart';
import 'package:neo_brutalism_locket/features/pov/pov_scan.dart';
import 'package:neo_brutalism_locket/features/pov/pov_repository.dart';
import 'package:neo_brutalism_locket/features/pov/pov_store.dart';
import 'package:neo_brutalism_locket/features/photos/photo_repository.dart';
import 'package:neo_brutalism_locket/features/profile/profile_screen.dart';
import 'package:neo_brutalism_locket/features/progress/player_store.dart';
import 'package:neo_brutalism_locket/features/quest/on_device/on_device_quest_verifier.dart';
import 'package:neo_brutalism_locket/features/quest/quest_card.dart';
import 'package:neo_brutalism_locket/features/quest/quest_catalog.dart';
import 'package:neo_brutalism_locket/features/quest/quest_post_screen.dart';
import 'package:neo_brutalism_locket/features/quest/quest_verifier.dart';
import 'package:neo_brutalism_locket/features/shop/shop_screen.dart';
import 'package:neo_brutalism_locket/features/profile/player_avatar.dart';
import 'package:neo_brutalism_locket/features/social/feed_filter.dart';
import 'package:neo_brutalism_locket/features/social/feed_view.dart';
import 'package:neo_brutalism_locket/features/social/local_friend_text.dart';
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
    this.povRepository,
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
    this.albumsRepository,
    this.contestRepository,
  });

  /// The weekly contest and the Gallery (same rule as [groupsRepository]).
  final ContestRepository? contestRepository;

  /// Groups on the server (built from [session] when not given and a backend
  /// is configured).
  final GroupsRepository? groupsRepository;

  /// The shared canvas on the server (same rule as [groupsRepository]).
  final CanvasRepository? canvasRepository;
  final AlbumsRepository? albumsRepository;

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

  /// Omni POV (a friend watches my camera). Null: the real one with an account.
  final PovRepository? povRepository;

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
  FeedFilter _feedFilter = const FeedFilter.everyone();
  List<PocketMessage> _messages = [];
  List<FriendPost> _posts = [];
  PocketFriend? _activeFriend;
  int _tabIndex = _cameraTab;
  int _previousTabIndex = _cameraTab;
  bool _cameraOffstage = false;
  bool _showFeed = false;
  FriendsStore? _friendsStore;
  GroupsStore? _groupsStore;
  AlbumsStore? _albumsStore;
  CanvasRepository? _canvasRepository;
  ContestStore? _contestStore;
  ContestArtCache? _artCache;

  /// Which list the FRIENDS tab shows: friends (false) or groups (true).
  bool _showGroups = false;
  PostsStore? _postsStore;
  ChatStore? _chat;
  PovStore? _pov;
  InteractionsStore? _interactions;
  PostTagsStore? _tags;
  SafetyRepository? _safety;
  WidgetUpdater? _widget;
  Future<void> Function()? _beforeSignOut;
  StreamSubscription<PushTap>? _pushSubscription;
  PostOutbox? _outbox;
  MediaUrls? _mediaUrls;
  Timer? _outboxTimer;

  /// Gives my older posts their search vectors, once, a while after start.
  Timer? _backfillTimer;

  /// Photo search in the history tab (signed in, real backend only).
  PhotoSearch? _photoSearch;
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
    if (Platform.isAndroid) {
      // Pictures the lock screen left that nobody came for.
      unawaited(sweepRewindHandoff().catchError((Object _) {}));
    }
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
      final albumsRepository =
          widget.albumsRepository ??
          (Backend.isReady
              ? SupabaseAlbumsRepository(myId: session.user.id)
              : null);
      if (albumsRepository != null) {
        _albumsStore = AlbumsStore(albumsRepository)..refresh();
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
      _tags = PostTagsStore(SupabasePostTagsSource(), myId: session.user.id)
        ..addListener(_onPostsChanged);
      _chat =
          ChatStore(
              widget.chatRepository ??
                  SupabaseChatRepository(myId: session.user.id),
              myId: session.user.id,
            )
            ..addListener(_onChatChanged)
            ..refresh();
      final povRepository =
          widget.povRepository ??
          (Backend.isReady
              ? SupabasePovRepository(myId: session.user.id)
              : null);
      if (povRepository != null) {
        _pov = PovStore(povRepository, myId: session.user.id)..start();
      }
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
            onNotice: _showPushBanner,
          );
      _pushSubscription = push.taps.listen(_onPushTap);
      // Before signing out: stop pushes to this phone (still signed in then)
      // and take the account's photo off the home screen.
      _beforeSignOut = () async {
        await _pov?.end();
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
          PostOutbox(
            repository: posts.repository,
            userId: session.user.id,
            embedPhoto: embedPhotoForSearch,
          );
      _mediaUrls = widget.mediaUrls ?? SupabaseMediaUrls();
      if (widget.postsRepository == null && Backend.isReady) {
        final backfill = EmbeddingBackfill(
          SupabaseBackfillSource(myId: session.user.id),
          embed: embedPhotoForSearch,
        );
        _backfillTimer = Timer(const Duration(seconds: 30), backfill.run);
        _photoSearch = PhotoSearch(
          myId: session.user.id,
          backend: SupabaseSearchBackend(myId: session.user.id),
          v2: HttpSearchV2(
            accessToken: () => Backend.client.auth.currentSession?.accessToken,
          ),
        );
        // The Vietnamese pack (ML Kit, ~30 MB) cannot ship in the app: fetch
        // it quietly on Wi-Fi so it is there by the first search.
        unawaited(
          _photoSearch!
              .prepareLanguagePack(wifiOnly: true)
              .catchError((Object e) => AppLog.warn('photo_search', e)),
        );
      }
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
    _flight?.remove();
    _pushSubscription?.cancel();
    if (widget.session?.beforeSignOut == _beforeSignOut) {
      widget.session?.beforeSignOut = null;
    }
    _outboxTimer?.cancel();
    _backfillTimer?.cancel();
    _photoSearch?.close();
    _postsStore
      ?..removeListener(_onPostsChanged)
      ..removeListener(_onPostsLoaded)
      ..dispose();
    _tags
      ?..removeListener(_onPostsChanged)
      ..dispose();
    _outbox?.dispose();
    _pov?.dispose();
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
    _albumsStore?.dispose();
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
          original: _originalToCompare(photo, mine.imagePath),
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
      if (!mounted) return;
      _notify(AppLocalizations.of(context).photoMissingRetake);
      return;
    }
    await _openQuestPost(quest, photo, _player.today);
  }

  Future<void> _openFriendProfile(PocketFriend friend) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) {
            final page = FriendProfileScreen(
              friend: friend,
              posts: _posts
                  .where((post) => post.friendId == friend.id)
                  .toList(),
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
      // A widget may have been placed or set to someone while away.
      _refreshWidget();
    }
  }

  void _onGroupsChanged() {
    if (mounted) setState(() {});
    // The widgets that follow a group need to know who is in it.
    if (_groupsStore?.isLoaded ?? false) _refreshWidget();
  }

  /// The groups banner leads to the same contest tab as the menu bar.
  void _openContest() => _selectTab(_contestTab);

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
          albums: _albumsStore,
          mediaUrls: _mediaUrls,
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
    _tags?.load(posts);
    _refreshWidget();
    _warmFeedPictures(posts);
  }

  /// Starts fetching the newest pictures now, so the feed opens on pictures
  /// that are already on the phone: the small previews of every loaded post
  /// first (the history grid shows them all, and signing their URLs one at a
  /// time was slow), then the full ones, then the originals people may drag to
  /// compare.
  void _warmFeedPictures(List<RemotePost> posts) {
    final newest = posts.take(12).toList();
    warmMedia(_mediaUrls, [
      for (final post in posts) ?post.thumbPath,
      for (final post in newest) post.mediaPath,
      for (final post in newest)
        if (!post.isVideo) ?post.originalPath,
    ]);
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
          groups: [
            for (final summary
                in _groupsStore?.groups ?? const <GroupSummary>[])
              WidgetGroup(
                id: summary.group.id,
                name: summary.group.name,
                memberIds: {
                  for (final member in summary.members) member.person.id,
                },
              ),
          ],
        )
        .catchError((Object _) {});
  }

  void _onChatChanged() {
    final open = _activeFriend;
    // A message arrives in the conversation that is on screen: it is read.
    if (open != null && _tabIndex == _chatPage) _chat?.markRead(open.id);
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
    File? original,
    List<String> albumIds = const [],
    List<String> taggedIds = const [],
  }) => _queueAndSend(
    (outbox) => outbox.enqueue(
      source: file,
      caption: caption,
      style: style,
      questId: questId,
      overlay: overlay,
      recipients: recipients,
      original: original,
      albumIds: albumIds,
      taggedIds: taggedIds,
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
      // The albums count the new post once it is on the server.
      if (!stillWaiting) unawaited(_albumsStore?.refresh());
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
        builder: (context) => PostComposerScreen(
          imagePath: path,
          friends: store.friends,
          albums: _albumsStore?.open ?? const [],
        ),
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
      original: _originalToCompare(photo, processed),
      albumIds: result.albumIds,
      taggedIds: result.taggedIds,
    );
  }

  /// The shot just taken, with the caption, labels and recipients chosen in the
  /// popup over the camera: queue it.
  Future<bool> _postDraft(NeoPhoto photo, ComposerResult result) async {
    final store = _friendsStore;
    if (store == null) return false;
    final processed = photo.status == ProcessingStatus.done
        ? photo.processedPath
        : null;
    final path = processed ?? photo.originalPath;
    return _queuePost(
      file: File(path),
      caption: result.caption,
      style: processed == null ? StyleType.none : photo.styleType,
      overlay: result.overlay,
      recipients: result.recipients,
      friendCount: result.recipients?.length ?? store.friends.length,
      original: _originalToCompare(photo, processed),
      albumIds: result.albumIds,
      taggedIds: result.taggedIds,
    );
  }

  /// The shot before its style, to send beside the styled one so people can
  /// compare; null when it was not styled.
  File? _originalToCompare(NeoPhoto photo, String? processed) {
    if (processed == null ||
        processed == photo.originalPath ||
        photo.styleType == null ||
        photo.styleType == StyleType.none) {
      return null;
    }
    return File(photo.originalPath);
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
          albums: _albumsStore?.open ?? const [],
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
        albumIds: result.albumIds,
        taggedIds: result.taggedIds,
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
    _selectTab(_cameraTab);
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

  /// The lock-screen rewind screen picked a frame (neolocket://rewind?file=):
  /// print it on the camera tab like a shot just taken. The file is deleted
  /// whatever happens. On a cold start the camera tab may not exist yet.
  Future<void> _importRewind(String file) async {
    final bytes = await takeRewindHandoff(file);
    if (bytes == null) return;
    for (var wait = 0; wait < 20 && mounted; wait++) {
      _selectTab(_cameraTab);
      final camera = _camera;
      if (camera != null) {
        await camera.importShot(bytes);
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  }

  /// Someone opened an invite link (neolocket://add/NAME): offer to add them.
  void _onInviteLink(Uri uri) {
    final rewindFile = rewindFileFromLink(uri);
    if (rewindFile != null) {
      _importRewind(rewindFile);
      return;
    }
    // An Omni POV code opened from another camera app: the same as scanning it here.
    final povCode = povCodeFromLink(uri);
    if (povCode != null) {
      final pov = _pov;
      if (pov != null && mounted) {
        _selectTab(_cameraTab);
        joinPovWithCode(context, store: pov, code: povCode, friends: _friends);
      }
      return;
    }
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
    _selectTab(_friendsTab);
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
      if (!mounted) return;
      _notify(
        (error is LocalFriendException
                ? localFriendText(AppLocalizations.of(context), error)
                : AppLocalizations.of(context).peUnknown)
            .toUpperCase(),
      );
    }
  }

  Future<void> _openFriend(PocketFriend friend) async {
    final chat = _chat;
    if (chat != null) {
      setState(() {
        _activeFriend = friend;
        _tabIndex = _chatPage;
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
      _tabIndex = _chatPage;
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
      if (!mounted) return;
      _notify(
        (error is LocalFriendException
                ? localFriendText(AppLocalizations.of(context), error)
                : AppLocalizations.of(context).peUnknown)
            .toUpperCase(),
      );
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

  /// A push arrived while the app is open: Android shows nothing then, so show
  /// it as a banner here, with a way into what it is about. Not when the person
  /// is already looking at that very chat.
  void _showPushBanner(PushNotice notice) {
    if (!mounted) return;
    final tap = notice.tap;
    if (tap != null &&
        tap.type == 'message' &&
        _tabIndex == _chatPage &&
        _activeFriend != null &&
        _activeFriend!.id == tap.fromId) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          backgroundColor: NeoColors.ink,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (notice.title.isNotEmpty)
                Text(
                  notice.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: NeoColors.surface,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              if (notice.body.isNotEmpty)
                Text(
                  notice.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: NeoColors.surface,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          action: tap == null
              ? null
              : SnackBarAction(
                  label: l10n.pushOpen,
                  textColor: NeoColors.accent,
                  onPressed: () => _onPushTap(tap),
                ),
        ),
      );
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
          // The friend list is not loaded yet: their chat is listed there.
          _selectTab(_friendsTab);
        }
      case 'friend_request' || 'friend_accepted':
        _selectTab(_friendsTab);
      default:
        _selectTab(_cameraTab);
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
            accountExport: Backend.isReady
                ? AccountExport(
                    source: SupabaseMyPostsSource(myId: session.user.id),
                    exporter: MediaExporter(_mediaUrls),
                    username: session.profile.username ?? '',
                  )
                : null,
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
            if (post.originalPath != null && !post.isVideo) ...[
              const SizedBox(height: 12),
              NeoButton(
                expand: true,
                label: l10n.postMenuSaveOriginal,
                icon: Icons.photo_outlined,
                variant: NeoButtonVariant.outline,
                onPressed: () => Navigator.pop(context, 'saveOriginal'),
              ),
            ],
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
      case 'saveOriginal':
        final ok = await actions.save(post.originalPath!);
        if (mounted) {
          _notify(ok ? l10n.postOriginalSaved : l10n.postSaveFailed);
        }
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
            onPressed: Haptics.tap(() => Navigator.pop(context, false)),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: Haptics.tap(() => Navigator.pop(context, true)),
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
      // A reaction shows as emojis floating up the feed, not as a notice.
      if (reaction != null) return;
      final name = _friends
          .where((friend) => friend.id == post.friendId)
          .map((friend) => friend.name.split(' ').first)
          .firstOrNull;
      final l10n = AppLocalizations.of(context);
      final what = l10n.replyWord;
      _notify(
        name == null
            ? l10n.sentNotice(what)
            : l10n.sentNoticeTo(what, name.toUpperCase()),
      );
    } on FormatException catch (error) {
      if (!mounted) return;
      _notify(
        (error is LocalFriendException
                ? localFriendText(AppLocalizations.of(context), error)
                : AppLocalizations.of(context).peUnknown)
            .toUpperCase(),
      );
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

  /// "with you" on a post: the tagged person takes their name off it.
  Future<void> _removeMyTag(RemotePost post) async {
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
            l10n.tagRemoveTitle,
            style: const TextStyle(
              color: NeoColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            l10n.tagRemoveBody,
            style: const TextStyle(color: NeoColors.ink),
          ),
          actions: [
            TextButton(
              onPressed: Haptics.tap(() => Navigator.pop(context, false)),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: Haptics.tap(() => Navigator.pop(context, true)),
              child: Text(l10n.tagRemoveConfirm),
            ),
          ],
        );
      },
    );
    if (remove != true || !mounted) return;
    final l10n = AppLocalizations.of(context);
    try {
      await _tags?.removeMine(post.id);
      if (mounted) _notify(l10n.tagRemoved);
    } catch (_) {
      if (mounted) _notify(l10n.errUnknown);
    }
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
              onPressed: Haptics.tap(() => Navigator.pop(context, false)),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: Haptics.tap(() => Navigator.pop(context, true)),
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
      _tabIndex = _friendsTab;
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
            onPressed: Haptics.tap(() => Navigator.pop(context, false)),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: Haptics.tap(() => Navigator.pop(context, true)),
            child: Text(l10n.removeFriendConfirm),
          ),
        ],
      ),
    );
    if (remove != true || !mounted) return;
    try {
      await store.removeFriend(person);
      if (mounted) setState(() => _tabIndex = _friendsTab);
    } on FriendsFailure catch (failure) {
      if (mounted) _notify(friendsFailureText(l10n, failure));
    }
  }

  /// The three menu tabs, in the bar's order with the camera in the middle.
  /// The archive hides behind the camera's button: it shows in the bar while
  /// that button is up as the shutter. It, a chat (opened from a friend) and
  /// the profile (behind the avatar on the camera) are pages, not menu tabs:
  /// they sit after them.
  static const _menuTabCount = 3;
  static const _friendsTab = 0;
  static const _cameraTab = 1;
  static const _contestTab = 2;
  static const _archiveTab = 3;
  static const _chatPage = 4;
  static const _profilePage = 5;

  /// The Friends tab's scan button: the camera comes up and looks for a friend's code.
  void _scanPovCode() {
    _selectTab(_cameraTab);
    unawaited(_camera?.startPovScan());
  }

  void _selectTab(int index) {
    Haptics.select();
    if (index != _cameraTab) unawaited(_camera?.stopPovScan());
    final wasShooting = _shooting;
    // Measured now: once the camera is off screen the shutter has no place.
    final shutter = _rectOf(_shutterKey);
    if (index != _tabIndex) {
      _previousTabIndex = _tabIndex;
      _tabHistory.remove(index);
      _tabHistory.add(_tabIndex);
      if (_tabHistory.length > 8) _tabHistory.removeAt(0);
    }
    setState(() {
      _tabIndex = index;
      _activeFriend = null;
      if (index == _cameraTab) {
        _showFeed = false;
        _cameraOffstage = false;
      }
    });
    if (index != _cameraTab) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _tabIndex != _cameraTab) {
          setState(() => _cameraOffstage = true);
        }
      });
    }
    if (index == _cameraTab) _camera?.closePrint();
    if (index != _cameraTab) _camera?.leaveQuestMode();
    if (index == _friendsTab) _loadSocial();
    if (index == _archiveTab) _loadArchive();
    if (!wasShooting && _shooting) {
      _flyShutter(up: true);
    } else if (wasShooting && !_shooting && shutter != null) {
      _flyShutter(up: false, from: shutter);
    }
  }

  /// The tabs visited before this one, most recent last: the phone's back
  /// button walks them instead of leaving the app.
  final _tabHistory = <int>[];

  /// Nothing left to go back to: the camera is the home page.
  bool get _atHome =>
      !_showFeed && _tabHistory.isEmpty && _tabIndex == _cameraTab;

  void _goBack() {
    if (_showFeed && _tabIndex == _cameraTab) {
      setState(() => _showFeed = false);
      return;
    }
    if (_tabIndex == _chatPage) {
      setState(() {
        _activeFriend = null;
        _tabIndex = _friendsTab;
      });
      return;
    }
    final previous = _tabHistory.isNotEmpty ? _tabHistory.removeLast() : null;
    // Back to a tab through the history must not push it again.
    final saved = List<int>.of(_tabHistory);
    _selectTab(previous ?? _cameraTab);
    _tabHistory
      ..clear()
      ..addAll(saved);
  }

  /// The live camera is on screen, so the menu's SHOOT button is its shutter.
  bool get _shooting => _tabIndex == _cameraTab && !_showFeed;

  final _shutterKey = GlobalKey();
  final _navShootKey = GlobalKey();

  /// The SHOOT button is between the menu bar and the shutter: neither end
  /// shows it until it lands.
  bool _flying = false;
  OverlayEntry? _flight;

  Rect? _rectOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// Flies the SHOOT button up into the shutter ([up]) or the shutter back
  /// down into the menu bar, from [from] (the shutter's place before it left).
  void _flyShutter({required bool up, Rect? from}) {
    if (MediaQuery.disableAnimationsOf(context)) return;
    _flight?.remove();
    _flight = null;
    setState(() => _flying = true);
    // Where the far end is is only known once the new tab is laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final rawStart = up ? _rectOf(_navShootKey) : from;
      final rawEnd = _rectOf(up ? _shutterKey : _navShootKey);
      if (rawStart == null || rawEnd == null) {
        _land(null);
        return;
      }
      // Both the bottom nav shoot button and the shutter are strictly centered
      // horizontally. Forcing the flight path to the screen's centerline prevents
      // the button from drifting or squashing to the left or right during tab transitions.
      final screenCenterX = MediaQuery.of(context).size.width / 2;
      final start = Rect.fromCenter(
        center: Offset(screenCenterX, rawStart.center.dy),
        width: rawStart.width,
        height: rawStart.height,
      );
      final end = Rect.fromCenter(
        center: Offset(screenCenterX, rawEnd.center.dy),
        width: rawEnd.width,
        height: rawEnd.height,
      );
      late final OverlayEntry entry;
      entry = OverlayEntry(
        builder: (_) => ShutterFlight(
          from: start,
          to: end,
          up: up,
          onDone: () => _land(entry),
        ),
      );
      _flight = entry;
      Overlay.of(context).insert(entry);
    });
  }

  /// The flight [entry] is over (null: it never took off).
  void _land(OverlayEntry? entry) {
    // A newer flight took over: it lands by itself.
    if (entry != null && entry != _flight) return;
    _flight?.remove();
    _flight = null;
    if (mounted) setState(() => _flying = false);
  }

  /// Swiping moves between the menu tabs; the pages after them are left with
  /// their back button.
  void _swipeTab(int index) {
    if (_tabIndex >= _menuTabCount) return;
    _selectTab(index);
  }

  void _openPhoto(NeoPhoto photo) {
    _showCamera();
    _camera?.openPhoto(photo);
  }

  /// Switches to the SHOOT tab's camera page.
  void _showCamera() {
    setState(() {
      _previousTabIndex = _tabIndex;
      _tabIndex = _cameraTab;
      _cameraOffstage = false;
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
    final l10n = AppLocalizations.of(context);
    final cameraVisible = _tabIndex == _cameraTab && !_showFeed;
    final page = switch (_tabIndex) {
      _cameraTab when _showFeed => _feedScreen(
        key: const ValueKey('feed'),
        entries: _filteredFeed(),
        filterPill: _filterPill(),
        onClose: () => setState(() => _showFeed = false),
      ),
      _cameraTab => const SizedBox.shrink(key: ValueKey('camera')),
      _friendsTab => _buildFriends(),
      _chatPage when _activeFriend != null => ConversationScreen(
        key: ValueKey('thread-${_activeFriend!.id}'),
        friend: _activeFriend!,
        messages: _allMessages
            .where((message) => message.friendId == _activeFriend!.id)
            .toList(),
        onBack: () => setState(() {
          _activeFriend = null;
          _tabIndex = _friendsTab;
        }),
        onSend: _sendSocialMessage,
        onSendLatestPhoto: _sendLatestPrint,
        onRemoveFriend: _removeActiveFriend,
        posts: _posts,
        photoOfPost: (postId) {
          final post = _postsStore?.posts
              .where((p) => p.id == postId)
              .firstOrNull;
          return post == null ? null : post.thumbPath ?? post.mediaPath;
        },
        onOpenProfile: () => _openFriendProfile(_activeFriend!),
        allowPhoto: !_online,
      ),
      // The chat's friend went away (e.g. removed): back on the friends list.
      _chatPage => _buildFriends(),
      _contestTab => _buildContestTab(),
      _archiveTab => _buildArchivePage(),
      _ => _buildProfilePage(),
    };
    final cameraSlideOffset = switch (_tabIndex) {
      _friendsTab => const Offset(1.0, 0.0),
      _contestTab => const Offset(-1.0, 0.0),
      _cameraTab => Offset.zero,
      _ => Offset.zero,
    };
    final isContestTab = _tabIndex == _contestTab;
    final scaffold = Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: _tabIndex != _cameraTab,
      body: SafeArea(
        child: Column(
          children: [
            // The camera page carries its own streak; no Sunbit while shooting.
            if (!cameraVisible) _buildStatusStrip(),
            Expanded(
              child: TabSwipeDetector(
                tabCount: _menuTabCount,
                currentIndex: _tabIndex,
                onSwipe: _swipeTab,
                child: Stack(
                  // Fill the area even while the camera is off-stage (size 0).
                  fit: StackFit.expand,
                  clipBehavior: Clip.hardEdge,
                  children: [
                    // Always mounted, so the camera does not restart per tab.
                    AnimatedSlide(
                      offset: cameraSlideOffset,
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      onEnd: () {
                        if (mounted && _tabIndex != _cameraTab) {
                          setState(() => _cameraOffstage = true);
                        }
                      },
                      child: Offstage(
                        // The feed covers the camera: keep the shutter row from
                        // showing through it.
                        offstage: _cameraOffstage || _showFeed,
                        child: IgnorePointer(
                          ignoring: !cameraVisible,
                          child: TickerMode(
                            enabled: cameraVisible,
                            child: CameraTab(
                              key: _cameraKey,
                              player: _player,
                              photos: _photos,
                              repository: _repository,
                              styleEngineFactory: _styleEngineFactory,
                              questVerifier: _questVerifier,
                              embedPhoto: _online ? null : embedPhotoForSearch,
                              onPhotoChanged: _onPhotoChanged,
                              onOpenFeed: _openFeed,
                              onOpenQuestSheet: _openQuestSheet,
                              onQuestPassed: _openQuestPost,
                              onSendPrint: _online ? _sendPrint : null,
                              onPostDraft: _online ? _postDraft : null,
                              friends: _friendsStore?.friends ?? const [],
                              pov: _pov,
                              povRepository: _pov?.repository,
                              povFriends: _friends,
                              albums: _albumsStore?.open ?? const [],
                              onPhotoRemoved: _onPhotoRemoved,
                              onVideoRecorded: _online ? _sendVideo : null,
                              header: _homeHeader(),
                              shutterKey: _shutterKey,
                              hideShutter: _flying,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Kept mounted over the camera (its page is empty then), so
                    // the switcher has a page to fade from when leaving it.
                    Positioned.fill(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        layoutBuilder: (currentChild, previousChildren) => Stack(
                          fit: StackFit.expand,
                          children: [
                            ...previousChildren,
                            ?currentChild,
                          ],
                        ),
                        transitionBuilder: (child, animation) {
                          // Opening / closing the feed from the camera is a
                          // vertical move (swipe down); tabs stay horizontal.
                          if (_tabIndex == _cameraTab &&
                              (child.key == const ValueKey('feed') ||
                                  child.key == const ValueKey('camera'))) {
                            final isFeed = child.key == const ValueKey('feed');
                            return SlideTransition(
                              position: Tween<Offset>(
                                begin: isFeed
                                    ? const Offset(0.0, 1.0)
                                    : Offset.zero,
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            );
                          }
                          final inFromRight = _tabIndex >= _previousTabIndex;
                          final beginOffset = inFromRight
                              ? const Offset(1.0, 0.0)
                              : const Offset(-1.0, 0.0);
                          final endOffset = inFromRight
                              ? const Offset(-1.0, 0.0)
                              : const Offset(1.0, 0.0);
                          final isIncoming = child.key == page.key;
                          final offsetTween = Tween<Offset>(
                            begin: isIncoming ? beginOffset : endOffset,
                            end: Offset.zero,
                          );
                          return SlideTransition(
                            position: offsetTween.animate(animation),
                            child: child,
                          );
                        },
                        child: page,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: TabSwipeDetector(
        tabCount: _menuTabCount,
        currentIndex: _tabIndex,
        onSwipe: _swipeTab,
        child: NeoBottomNav(
          // A chat belongs to the friends tab.
          selectedIndex: _tabIndex == _chatPage ? _friendsTab : _tabIndex,
          // With the camera's button up as the shutter, its place in the bar
          // is the archive's.
          onSelected: (index) => _selectTab(
            index == _cameraTab && (_shooting || _flying) ? _archiveTab : index,
          ),
          prominentKey: _navShootKey,
          prominentDocked: _shooting || _flying,
          // In the order of the tab constants above.
          tabs: [
            NeoBottomNavTab(
              label: l10n.tabFriends,
              outlineIcon: Icons.people_alt_outlined,
              filledIcon: Icons.people_alt,
              activeColor: NeoColors.accent,
            ),
            // Shooting is what the app is for: a big raised button, with the
            // archive behind it.
            NeoBottomNavTab(
              label: l10n.tabShoot,
              outlineIcon: Icons.photo_camera_outlined,
              filledIcon: Icons.photo_camera,
              activeColor: NeoColors.accent,
              prominent: true,
              behind: NeoBottomNavTab(
                label: _online ? l10n.historyTab : l10n.tabPrints,
                outlineIcon: Icons.grid_view_outlined,
                filledIcon: Icons.grid_view_rounded,
                activeColor: NeoColors.accent,
              ),
            ),
            NeoBottomNavTab(
              label: l10n.tabContest,
              outlineIcon: Icons.emoji_events_outlined,
              filledIcon: Icons.emoji_events,
              activeColor: NeoColors.accent,
            ),
          ],
        ),
      ),
    );
    final body = Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: isContestTab
                ? _contestBackground()
                // An empty ColoredBox shrinks to nothing inside the switcher's
                // loose Stack, which left the window's black showing through.
                : const ColoredBox(
                    key: ValueKey('paper-bg'),
                    color: NeoColors.paper,
                    child: SizedBox.expand(),
                  ),
          ),
        ),
        scaffold,
      ],
    );
    return _withScopes(
      PopScope(
        canPop: _atHome,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _goBack();
        },
        child: body,
      ),
    );
  }

  /// The contest tab's background: this week's theme, painted.
  Widget _contestBackground() {
    final store = _contestStore;
    if (store == null) {
      return const ContestBackdrop(
        key: ValueKey('contest-bg'),
        child: SizedBox.expand(),
      );
    }
    return ListenableBuilder(
      key: const ValueKey('contest-bg'),
      listenable: store,
      builder: (context, _) => ContestBackdrop(
        key: ValueKey('contest-bg-${store.theme?.titleEn}'),
        themeTitle: store.theme?.titleEn,
        child: const SizedBox.expand(),
      ),
    );
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
      pov: _pov == null
          ? null
          : PovActions(
              onShowCode: () => showPovQrSheet(context, store: _pov!),
              onScan: _scanPovCode,
            ),
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

  /// The feed entries that pass the whose-posts filter.
  List<FeedEntry> _filteredFeed() {
    final myId = widget.session?.user.id;
    final entries = _online
        ? buildRemoteFeed(
            _postsStore?.posts ?? const [],
            myId: myId!,
            friendIds: {for (final f in _friends) f.id},
          )
        : buildFeed(
            _posts,
            _photos,
            questPosts: _player.state?.questPosts ?? const [],
          );
    if (_feedFilter.isEveryone) return entries;
    return [
      for (final entry in entries)
        if (_feedFilter.allows(entry.authorId, myId)) entry,
    ];
  }

  Widget _filterPill() => FeedFilterPill(
    filter: _feedFilter,
    friends: _friends,
    onChanged: (filter) => setState(() => _feedFilter = filter),
  );

  /// The feed UI, for the feed itself and for the history viewer.
  FeedScreen _feedScreen({
    Key? key,
    required List<FeedEntry> entries,
    required VoidCallback onClose,
    int initialPage = 0,
    Widget? filterPill,
  }) => FeedScreen(
    key: key,
    filterPill: filterPill,
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
    onOpenSelf: () => _selectTab(_profilePage),
    musicMuted: _player.state?.musicMuted ?? false,
    onMuteChanged: _player.setMusicMuted,
    onReplyRemote: _online ? _replyToRemote : null,
    onReactRemote: _online ? _reactToRemote : null,
    onViewed: _online ? _onFeedViewed : null,
    onPostMenu: _online ? _showPostMenu : null,
    activity: _interactions?.activity ?? const {},
    tags: _tags?.tags ?? const {},
    onRemoveMyTag: _online ? _removeMyTag : null,
  );

  /// The weekly contest as a menu tab (signed-in only: it lives on the server).
  Widget _buildContestTab() {
    final contest = _contestStore;
    final canvas = _canvasRepository;
    if (contest == null || canvas == null) {
      return Center(
        key: const ValueKey('contest-offline'),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            AppLocalizations.of(context).contestNeedsAccount,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: NeoColors.ink,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }
    return ContestScreen(
      key: const ValueKey('contest'),
      store: contest,
      canvases: canvas,
      safety: _safety,
      showBack: false,
    );
  }

  /// Your profile, opened from the avatar on the camera page; the back button
  /// returns to the camera.
  Widget _buildProfilePage() {
    final l10n = AppLocalizations.of(context);
    return Column(
      key: const ValueKey('profile'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 22, 0),
          child: Row(
            children: [
              NeoIconButton(
                icon: Icons.arrow_back,
                tooltip: l10n.backTooltip,
                onPressed: () => _selectTab(_cameraTab),
              ),
            ],
          ),
        ),
        Expanded(
          child: ProfileScreen(
            store: _player,
            session: widget.session,
            onOpenSettings: _online && widget.settings != null
                ? _openSettings
                : null,
            remoteQuestPosts: _online
                ? [
                    for (final post
                        in _postsStore?.posts ?? const <RemotePost>[])
                      if (post.authorId == widget.session!.user.id &&
                          post.questId != null)
                        post,
                  ]
                : null,
            onOpenRemote: _openHistoryPost,
          ),
        ),
      ],
    );
  }

  /// The camera page's header: the whose-posts pill in the middle and your
  /// profile avatar on the right.
  Widget _homeHeader() => Row(
    children: [
      Expanded(
        child: Align(
          alignment: Alignment.centerLeft,
          child: StreakChip(
            streak: _player.streak,
            onTap: _openQuestSheet,
            round: true,
          ),
        ),
      ),
      _filterPill(),
      Expanded(
        child: Align(
          alignment: Alignment.centerRight,
          child: Tooltip(
            message: AppLocalizations.of(context).tabMe,
            child: GestureDetector(
              onTap: Haptics.tap(() => _selectTab(_profilePage)),
              child: PlayerAvatar(
                state: _player.state,
                size: context.s(44),
                remotePath: widget.session?.profile.avatarPath,
              ),
            ),
          ),
        ),
      ),
    ],
  );

  /// The archive (posts and prints on this phone), a menu tab.
  Widget _buildArchivePage() {
    final l10n = AppLocalizations.of(context);
    // Online, the history is the whole archive: your posts and your friends'.
    if (_online) return _buildHistoryTab();
    return Column(
      key: const ValueKey('archive'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 22, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _online ? l10n.historyTab : l10n.tabPrints,
                  style: const TextStyle(
                    fontFamily: NeoFont.display,
                    color: NeoColors.ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _online
              ? _buildHistoryTab()
              : ArchiveScreen(
                  photos: _photos,
                  onOpenPhoto: _openPhoto,
                  onOpenCamera: () => _selectTab(_cameraTab),
                ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    final posts = _postsStore;
    return HistoryScreen(
      key: const ValueKey('history'),
      posts: posts?.posts ?? const [],
      friends: _friends,
      myId: widget.session!.user.id,
      onOpen: _openHistoryPost,
      hasMore: posts?.hasMore ?? false,
      loadingMore: posts?.isLoadingMore ?? false,
      failed: posts?.failed ?? false,
      onLoadMore: posts?.loadMore,
      onRefresh: _syncPosts,
      search: _photoSearch,
      myNames: [
        ?widget.session!.profile.displayName,
        ?widget.session!.profile.username,
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
}
