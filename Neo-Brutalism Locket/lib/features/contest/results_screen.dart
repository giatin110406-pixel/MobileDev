import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/contest/contest_repository.dart';
import 'package:neo_brutalism_locket/features/contest/contest_widgets.dart';
import 'package:neo_brutalism_locket/features/contest/gallery/pixel_art.dart';
import 'package:neo_brutalism_locket/features/quest/confetti.dart';

/// The winners of one contest: first, second and third, on a podium.
class ResultsScreen extends StatefulWidget {
  const ResultsScreen({
    required this.repository,
    required this.contestId,
    super.key,
  });

  final ContestRepository repository;
  final String contestId;

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  ContestResults? _results;
  ContestFailure? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final results = await widget.repository.results(widget.contestId);
      if (mounted) setState(() => _results = results);
    } on ContestFailure catch (failure) {
      if (mounted) setState(() => _error = failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    final vi = isVietnamese(context);
    return Scaffold(
      backgroundColor: NeoColors.paper,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                children: [
                  NeoIconButton(
                    icon: Icons.arrow_back,
                    tooltip: 'Quay lại',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      results == null
                          ? 'Kết quả'
                          : 'Kết quả: ${vi ? results.titleVi : results.titleEn}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: NeoColors.ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _body(context, results)),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, ContestResults? results) {
    if (results == null) {
      return Center(
        child: _error == null
            ? const CircularProgressIndicator(color: NeoColors.ink)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(contestFailureText(_error!)),
                  const SizedBox(height: 10),
                  NeoButton(label: 'THỬ LẠI', onPressed: _load),
                ],
              ),
      );
    }
    if (results.phase != ContestPhase.finalized) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Kết quả sẽ có lúc 23:59 Chủ nhật (giờ Việt Nam).',
            textAlign: TextAlign.center,
            style: TextStyle(color: NeoColors.ink, fontWeight: FontWeight.w700),
          ),
        ),
      );
    }
    if (results.winners.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            results.entryCount == 0
                ? 'Tuần này chưa có bài dự thi nào.'
                : 'Chưa có bài nào đủ số phiếu hợp lệ để xếp hạng '
                      '(cần ít nhất 3 phiếu).',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: NeoColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            Text(
              '${results.entryCount} bài dự thi · ${results.weekKey}',
              style: const TextStyle(
                color: NeoColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            for (final winner in results.winners) _winner(winner),
          ],
        ),
        const IgnorePointer(child: Confetti(autoFire: true)),
      ],
    );
  }

  Widget _winner(GalleryEntry entry) {
    const names = {1: 'HẠNG NHẤT', 2: 'HẠNG NHÌ', 3: 'HẠNG BA'};
    const colors = {
      1: NeoColors.yellow,
      2: NeoColors.teal,
      3: NeoColors.orange,
    };
    final rank = entry.rank ?? 3;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: NeoTheme.panel(color: colors[rank] ?? NeoColors.surface),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events, size: rank == 1 ? 34 : 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  names[rank] ?? 'TOP 3',
                  style: TextStyle(
                    color: NeoColors.ink,
                    fontSize: rank == 1 ? 20 : 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              NeoLabel(
                '${entry.score?.toStringAsFixed(2) ?? '?'} · ${entry.voteCount ?? 0} phiếu',
                color: NeoColors.surface,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: rank == 1 ? 300 : 220),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F2E9),
                  border: Border.all(color: const Color(0xFF17110E), width: 6),
                ),
                child: PixelArt(
                  width: entry.width,
                  height: entry.height,
                  palette: entry.palette,
                  pixels: entry.pixels,
                  semanticLabel: '${names[rank]}: ${entry.groupName}',
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            entry.groupName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: NeoColors.ink,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
