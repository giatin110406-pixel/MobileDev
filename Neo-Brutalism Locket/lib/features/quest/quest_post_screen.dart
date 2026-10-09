import 'dart:io';

import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_engine_factory.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_type.dart';
import 'package:neo_brutalism_locket/features/photos/photo_repository.dart';
import 'package:neo_brutalism_locket/features/progress/player_repository.dart';
import 'package:neo_brutalism_locket/features/progress/player_state.dart';
import 'package:neo_brutalism_locket/features/progress/player_store.dart';
import 'package:neo_brutalism_locket/features/quest/confetti.dart';
import 'package:neo_brutalism_locket/features/quest/quest_card.dart';
import 'package:neo_brutalism_locket/features/quest/quest_catalog.dart';
import 'package:neo_brutalism_locket/features/shop/cosmetics.dart';
import 'package:neo_brutalism_locket/features/wallet/sunbit_badge.dart';

/// After a quest photo passes the check: turn it into the quest's style,
/// celebrate, let the user edit the caption and post it. Pops `true` once
/// posted. Leaving early keeps the passed photo for later today.
class QuestPostScreen extends StatefulWidget {
  const QuestPostScreen({
    super.key,
    required this.store,
    required this.quest,
    required this.photo,
    required this.questDay,
    this.photoRepository,
    this.styleEngineFactory = const StyleEngineFactory(),
  });

  final PlayerStore store;
  final Quest quest;

  /// The passed photo (original saved; processed here if not done yet).
  final NeoPhoto photo;

  /// The Vietnam day the photo passed on; posting after 00:00 is refused.
  final int questDay;
  final PhotoRepository? photoRepository;
  final StyleEngineFactory styleEngineFactory;

  @override
  State<QuestPostScreen> createState() => _QuestPostScreenState();
}

class _QuestPostScreenState extends State<QuestPostScreen> {
  final _confetti = GlobalKey<ConfettiState>();
  late final PhotoRepository _photos =
      widget.photoRepository ?? PhotoRepository();
  late final TextEditingController _caption = TextEditingController(
    text: widget.quest.caption,
  );
  late NeoPhoto _photo = widget.photo;
  String _stage = '';
  double _progress = 0;
  bool _posting = false;

  bool get _ready =>
      _photo.status == ProcessingStatus.done &&
      _photo.processedPath != null &&
      _photo.styleType == widget.quest.style;

  @override
  void initState() {
    super.initState();
    if (_ready) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _confetti.currentState?.fire(),
      );
    } else {
      _process();
    }
  }

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _process() async {
    final pending = _photo.copyWith(
      status: ProcessingStatus.pending,
      styleType: widget.quest.style,
      clearFailureReason: true,
    );
    setState(() {
      _photo = pending;
      _stage = 'starting';
      _progress = 0;
    });
    try {
      final engine = widget.styleEngineFactory.create(widget.quest.style);
      final output = await engine.process(
        File(pending.originalPath),
        widget.quest.style,
        onProgress: (stage, fraction) {
          if (!mounted) return;
          setState(() {
            _stage = stage;
            _progress = fraction;
          });
        },
      );
      final done = pending.copyWith(
        processedPath: output.file.path,
        styleSource: output.source,
        status: ProcessingStatus.done,
      );
      await _photos.upsert(done);
      if (!mounted) return;
      setState(() => _photo = done);
      _confetti.currentState?.fire();
    } catch (error) {
      final failed = pending.copyWith(
        status: ProcessingStatus.failed,
        failureReason: error.toString(),
      );
      await _photos.upsert(failed);
      if (mounted) setState(() => _photo = failed);
    }
  }

  Future<void> _post() async {
    if (!_ready || _posting) return;
    setState(() => _posting = true);
    try {
      final reward = await widget.store.completeQuest(
        quest: widget.quest,
        questDay: widget.questDay,
        photoId: _photo.id,
        imagePath: _photo.processedPath!,
        caption: _caption.text,
      );
      if (!mounted) return;
      await _showReward(reward);
      if (mounted) Navigator.of(context).pop(true);
    } on PlayerException catch (error) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => _NeoDialog(
          title: 'KHÔNG ĐĂNG ĐƯỢC',
          body: Text(error.message, style: _bodyStyle),
          action: 'ĐÓNG',
        ),
      );
      if (mounted) Navigator.of(context).pop(false);
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _showReward(QuestReward reward) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _NeoDialog(
      title: 'ĐĂNG THÀNH CÔNG!',
      action: 'TUYỆT!',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _rewardRow('Hoàn thành nhiệm vụ', reward.base),
          if (reward.bonus > 0)
            _rewardRow('Thưởng streak ${reward.streak} ngày', reward.bonus),
          if (reward.ink > 0)
            _rewardRow('Mực để vẽ canvas nhóm', reward.ink, ink: true),
          const SizedBox(height: 14),
          StreakChip(streak: reward.streak),
          const SizedBox(height: 8),
          Text(
            reward.streak == 1
                ? 'Bắt đầu streak mới. Quay lại vào ngày mai nhé!'
                : 'Bạn đã hoàn thành ${reward.streak} ngày liên tiếp!',
            textAlign: TextAlign.center,
            style: _bodyStyle,
          ),
        ],
      ),
    ),
  );

  Widget _rewardRow(String label, int amount, {bool ink = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(label, style: _bodyStyle)),
        if (ink)
          const Icon(Icons.water_drop, size: 18, color: NeoColors.blue)
        else
          const SunbitCoin(size: 18),
        const SizedBox(width: 6),
        Text(
          '+$amount',
          style: const TextStyle(
            color: NeoColors.ink,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );

  static const _bodyStyle = TextStyle(
    color: NeoColors.ink,
    fontSize: 13,
    height: 1.35,
    fontWeight: FontWeight.w600,
  );

  @override
  Widget build(BuildContext context) {
    final quest = widget.quest;
    final failed = _photo.status == ProcessingStatus.failed;
    final imagePath = _ready ? _photo.processedPath! : _photo.originalPath;
    return Scaffold(
      backgroundColor: NeoColors.paper,
      body: Stack(
        children: [
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              children: [
                Row(
                  children: [
                    NeoIconButton(
                      icon: Icons.arrow_back,
                      tooltip: 'Để sau (ảnh vẫn được giữ đến hết hôm nay)',
                      fill: NeoColors.yellow,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _ready
                                ? 'CHUẨN RỒI! ${quest.emoji}'
                                : 'ẢNH ĐẠT YÊU CẦU',
                            style: const TextStyle(
                              color: NeoColors.ink,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            quest.storyTitle.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: NeoColors.muted,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SunbitBadge(balance: widget.store.balance),
                  ],
                ),
                const SizedBox(height: 16),
                AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: NeoTheme.panel(
                      color: NeoColors.surface,
                      radius: 40,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(
                          File(imagePath),
                          key: ValueKey(imagePath),
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          top: 16,
                          left: 16,
                          child: NeoLabel(
                            '♪ ${quest.style.label}',
                            color: questStyleColor(quest.style),
                          ),
                        ),
                        if (!_ready && !failed)
                          ColoredBox(
                            color: NeoColors.ink.withValues(alpha: 0.35),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: NeoColors.surface,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (!_ready && !failed) ...[
                  Text(
                    'ĐANG BIẾN THÀNH ${quest.style.label} · ${_stage.toUpperCase()}',
                    style: const TextStyle(
                      color: NeoColors.ink,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: _progress <= 0 ? null : _progress,
                    color: NeoColors.teal,
                    backgroundColor: NeoColors.surface,
                    minHeight: 6,
                  ),
                ],
                if (failed) ...[
                  const Text(
                    'Chưa biến đổi được ảnh. Ảnh gốc vẫn an toàn.',
                    style: _bodyStyle,
                  ),
                  const SizedBox(height: 10),
                  NeoButton(
                    expand: true,
                    label: 'THỬ LẠI',
                    icon: Icons.refresh,
                    variant: NeoButtonVariant.accent,
                    onPressed: _process,
                  ),
                ],
                const SizedBox(height: 14),
                const Text(
                  'CHÚ THÍCH',
                  style: TextStyle(
                    color: NeoColors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: NeoTheme.panel(color: NeoColors.surface),
                  child: TextField(
                    controller: _caption,
                    maxLength: QuestRules.maxCaptionLength,
                    maxLines: 2,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(
                      color: NeoColors.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Viết một dòng ngắn...',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                NeoButton(
                  expand: true,
                  label: _posting ? 'ĐANG ĐĂNG...' : 'ĐĂNG LÊN TRANG CÁ NHÂN',
                  icon: Icons.send_rounded,
                  variant: NeoButtonVariant.primary,
                  onPressed: _ready && !_posting ? _post : null,
                ),
                const SizedBox(height: 8),
                Text(
                  'Post nhiệm vụ có nhạc ${quest.style == StyleType.vanGogh ? 'giao hưởng' : 'chiptune'} riêng khi bạn bè lướt đến.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: NeoColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Positioned.fill(child: Confetti(key: _confetti)),
        ],
      ),
    );
  }
}

class _NeoDialog extends StatelessWidget {
  const _NeoDialog({
    required this.title,
    required this.body,
    required this.action,
  });

  final String title;
  final Widget body;
  final String action;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: NeoTheme.panel(color: NeoColors.surface, radius: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: NeoColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          body,
          const SizedBox(height: 18),
          NeoButton(
            expand: true,
            label: action,
            variant: NeoButtonVariant.accent,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    ),
  );
}
