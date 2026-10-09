import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/canvas/canvas_painter.dart';
import 'package:neo_brutalism_locket/features/canvas/canvas_repository.dart';
import 'package:neo_brutalism_locket/features/canvas/canvas_store.dart';
import 'package:neo_brutalism_locket/features/groups/groups_widgets.dart';
import 'package:neo_brutalism_locket/features/wallet/ink_badge.dart';

/// The group's canvas: tap a cell to paint it with the chosen colour, pinch
/// to zoom, drag to move, hold a cell to see who painted it.
class CanvasView extends StatefulWidget {
  const CanvasView({required this.store, required this.nameOf, super.key});

  final CanvasStore store;

  /// A person's name from their id (null when they are gone or unknown).
  final String? Function(String userId) nameOf;

  @override
  State<CanvasView> createState() => _CanvasViewState();
}

class _CanvasViewState extends State<CanvasView> {
  int _selected = 1;
  CanvasFailureKind? _told;

  CanvasStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    store.addListener(_onChanged);
  }

  @override
  void dispose() {
    store.removeListener(_onChanged);
    super.dispose();
  }

  /// Tells the user once per refusal why a pixel did not stay.
  void _onChanged() {
    final failure = store.lastFailure;
    if (failure == null) {
      _told = null;
    } else if (failure != _told && store.status == CanvasStatus.ready) {
      _told = failure;
      if (mounted) showNeoSnack(context, canvasFailureText(failure));
    }
  }

  void _paintAt(Offset local, double side) {
    final cell = side / store.width;
    final x = (local.dx / cell).floor();
    final y = (local.dy / cell).floor();
    store.paint(x, y, _selected);
  }

  void _whoAt(Offset local, double side) {
    final cell = side / store.width;
    final x = (local.dx / cell).floor();
    final y = (local.dy / cell).floor();
    if (x < 0 || y < 0 || x >= store.width || y >= store.height) return;
    final userId = store.painterAt(x, y);
    final name = userId == null ? null : widget.nameOf(userId);
    showNeoSnack(
      context,
      userId == null
          ? 'Ô (${x + 1}, ${y + 1}): chưa ai vẽ'
          : 'Ô (${x + 1}, ${y + 1}): ${name ?? 'một người đã rời nhóm'} vẽ',
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        switch (store.status) {
          case CanvasStatus.loading:
            return const Center(
              child: CircularProgressIndicator(color: NeoColors.ink),
            );
          case CanvasStatus.error:
            return _Message(
              text: 'Không tải được canvas.',
              actionLabel: 'THỬ LẠI',
              onAction: store.reload,
            );
          case CanvasStatus.empty:
            return const _Message(text: 'Nhóm này chưa có canvas.');
          case CanvasStatus.ready:
            return _ready(context);
        }
      },
    );
  }

  Widget _ready(BuildContext context) {
    final locked = !(store.data?.active ?? true);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              InkBadge(amount: store.ink),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  store.ink == 0
                      ? 'Hết mực: hoàn thành nhiệm vụ để nhận 10 mực.'
                      : 'Mỗi ô vẽ tốn 1 mực. Giữ một ô để xem ai vẽ.',
                  style: const TextStyle(
                    color: NeoColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (store.offline)
          _Banner(
            text: 'Mất kết nối: canvas chỉ để xem.',
            actionLabel: 'THỬ LẠI',
            onAction: store.reload,
          ),
        if (locked)
          const _Banner(text: 'Canvas này đã được lưu trữ (chỉ xem).'),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              final side = box.biggest.shortestSide - 24;
              return InteractiveViewer(
                minScale: 1,
                maxScale: 10,
                child: Center(
                  child: Container(
                    width: side,
                    height: side,
                    decoration: BoxDecoration(
                      border: Border.all(color: NeoColors.ink, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: NeoColors.ink,
                          offset: Offset(4, 4),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: GestureDetector(
                      onTapUp: (d) => _paintAt(d.localPosition, side - 4),
                      onLongPressStart: (d) =>
                          _whoAt(d.localPosition, side - 4),
                      child: Semantics(
                        label:
                            'Canvas ${store.width} nhân ${store.height} ô. '
                            'Chạm một ô để vẽ.',
                        child: CustomPaint(
                          size: Size.square(side - 4),
                          painter: CanvasPainter(store),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        _palette(),
      ],
    );
  }

  Widget _palette() {
    final colors = store.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      color: NeoColors.surface,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < colors.length; i++)
            Semantics(
              button: true,
              selected: i == _selected,
              label: 'Màu ${i + 1}',
              child: GestureDetector(
                onTap: () => setState(() => _selected = i),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Color(colors[i]),
                    border: Border.all(
                      color: NeoColors.ink,
                      width: i == _selected ? 4 : 1.5,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.actionLabel, this.onAction});

  final String text;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: const TextStyle(
              color: NeoColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 12),
            NeoButton(label: actionLabel!, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, this.actionLabel, this.onAction});

  final String text;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(10),
      decoration: NeoTheme.panel(color: NeoColors.orange, borderWidth: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: NeoColors.ink,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (actionLabel != null)
            NeoButton(label: actionLabel!, onPressed: onAction),
        ],
      ),
    );
  }
}
