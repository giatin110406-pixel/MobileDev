import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/haptics.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/camera/shot_camera.dart';
import 'package:neo_brutalism_locket/features/rewind/rewind_channel.dart';
import 'package:neo_brutalism_locket/features/rewind/rewind_timeline.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

/// What the person picked: a square JPEG ready to print, and which frame it is
/// (null for the picture the camera took at the press).
@immutable
class RewindChoice {
  const RewindChoice({required this.bytes, required this.framePath});

  final Uint8List bytes;
  final String? framePath;
}

/// The frames the camera kept around a shot, to pick another one when the
/// shutter was pressed a moment too early or too late. The picture taken at
/// the press is the first on the strip and the one chosen at first.
///
/// Pops a [RewindChoice] to print, or null when nothing changes.
class RewindPicker extends StatefulWidget {
  const RewindPicker({
    super.key,
    required this.burst,
    required this.stillPath,
    required this.currentFramePath,
    required this.readStill,
    this.backend,
  });

  final ShotBurst burst;

  /// The picture the camera took at the press (EXIF says how to turn it).
  final String stillPath;

  /// The frame printed now, or null when the picture from the press is.
  final String? currentFramePath;

  /// The still as a square, upright JPEG.
  final Future<Uint8List> Function(String path) readStill;
  final RewindBackend? backend;

  @override
  State<RewindPicker> createState() => _RewindPickerState();
}

class _RewindPickerState extends State<RewindPicker> {
  static const _thumb = 72.0;

  late final RewindBackend _backend =
      widget.backend ?? MethodChannelRewindBackend();
  late final List<RewindFrame> _frames = [...widget.burst.frames]
    ..sort((a, b) => a.offsetMs.compareTo(b.offsetMs));

  /// 0 is the picture from the press, then the frames in time order.
  late int _selected = _indexOfCurrent();
  bool _busy = false;

  int _indexOfCurrent() {
    final current = widget.currentFramePath;
    if (current == null) return 0;
    final at = _frames.indexWhere((f) => f.path == current);
    return at < 0 ? 0 : at + 1;
  }

  Future<void> _use() async {
    if (_busy) return;
    if (_selected == _indexOfCurrent()) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _busy = true);
    try {
      final RewindChoice choice;
      if (_selected == 0) {
        choice = RewindChoice(
          bytes: await widget.readStill(widget.stillPath),
          framePath: null,
        );
      } else {
        final frame = _frames[_selected - 1];
        choice = RewindChoice(
          bytes: await _backend.finalizeFrame(frame.path, frame.rotation),
          framePath: frame.path,
        );
      }
      if (mounted) Navigator.of(context).pop(choice);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      showNeoSnack(context, AppLocalizations.of(context).photoNotSaved);
    }
  }

  void _select(int index) {
    if (index == _selected || index < 0 || index > _frames.length) return;
    Haptics.select();
    setState(() => _selected = index);
  }

  double _drag = 0;

  void _onDrag(DragUpdateDetails details, double width) {
    _drag += details.delta.dx;
    // About a quarter of the picture's width moves one frame.
    final step = width / 4;
    while (_drag <= -step) {
      _drag += step;
      _select(_selected + 1);
    }
    while (_drag >= step) {
      _drag -= step;
      _select(_selected - 1);
    }
  }

  Widget _picture(int index, {int? cacheWidth}) {
    if (index == 0) {
      return Image.file(
        File(widget.stillPath),
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        gaplessPlayback: true,
      );
    }
    final frame = _frames[index - 1];
    return RotatedBox(
      quarterTurns: frame.rotation ~/ 90,
      child: Image.file(
        File(frame.path),
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        gaplessPlayback: true,
      ),
    );
  }

  String _label(int index, String language, AppLocalizations l10n) => index == 0
      ? l10n.rewindPickOriginal
      : rewindOffsetLabel(_frames[index - 1].offsetMs, languageCode: language);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    return Scaffold(
      backgroundColor: NeoColors.paper,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  NeoIconButton(
                    icon: Icons.close,
                    tooltip: l10n.rewindClose,
                    onPressed: () => Navigator.of(context).pop(),
                    fill: NeoColors.coral,
                    size: 44,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.rewindPickTitle,
                      style: const TextStyle(
                        color: NeoColors.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, box) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (_) => _drag = 0,
                  onHorizontalDragUpdate: (d) => _onDrag(d, box.maxWidth),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: NeoTheme.panel(
                        color: NeoColors.surface,
                        radius: 40,
                      ),
                      foregroundDecoration: neoPanelOutline(radius: 40),
                      child: NeoPanelClip(
                        radius: 40,
                        child: Semantics(
                          label: l10n.rewindFrameSemantics(
                            _label(_selected, language, l10n),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              _picture(_selected, cacheWidth: 1080),
                              Positioned(
                                left: 14,
                                top: 14,
                                child: NeoLabel(
                                  _label(_selected, language, l10n),
                                  color: NeoColors.accent,
                                ),
                              ),
                              if (_selected != 0)
                                Positioned(
                                  right: 14,
                                  top: 14,
                                  child: NeoLabel(l10n.rewindExtraFrame),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: _thumb + 30,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _frames.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final chosen = index == _selected;
                    return GestureDetector(
                      onTap: () => _select(index),
                      child: Column(
                        children: [
                          Container(
                            width: _thumb,
                            height: _thumb,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: NeoColors.ink,
                                width: chosen ? 4 : 1.5,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: _picture(index, cacheWidth: 200),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _label(index, language, l10n),
                            style: TextStyle(
                              color: NeoColors.ink,
                              fontSize: 10,
                              fontWeight: chosen
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const Spacer(),
              NeoButton(
                label: l10n.rewindPickUse,
                icon: Icons.check,
                expand: true,
                onPressed: _busy ? null : _use,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
