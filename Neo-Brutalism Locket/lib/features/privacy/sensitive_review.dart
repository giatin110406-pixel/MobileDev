import 'dart:io';

import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/app_log.dart';
import 'package:neo_brutalism_locket/core/haptics.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/privacy/sensitive_check.dart';
import 'package:neo_brutalism_locket/features/privacy/sensitive_rules.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

/// What to send after the check.
class SensitiveDecision {
  const SensitiveDecision(this.photo, {required this.covered});

  /// The file to post: [photo] itself, or a covered copy.
  final File photo;

  /// Something was covered: copies of the photo that were not covered (the
  /// "before style" original) must not be sent beside it.
  final bool covered;
}

/// Checks [photo] before it is posted. Nothing found: the photo goes as it
/// is. Something found: the person sees where and chooses. Null means they
/// went back to the photo instead of posting.
///
/// When the check itself fails the photo is still posted (the check must
/// never stop someone posting), and the person is told it was not checked.
Future<SensitiveDecision?> reviewSensitive(
  BuildContext context,
  File photo, {
  required SensitiveScanner scanner,
  void Function(String message)? notify,
}) async {
  final SensitiveScan scan;
  try {
    scan = await scanner.scan(photo);
  } catch (error, stack) {
    AppLog.warn('sensitive_check', error, stack);
    if (context.mounted) {
      notify?.call(AppLocalizations.of(context).sensitiveCheckFailed);
    }
    return SensitiveDecision(photo, covered: false);
  }
  if (scan.findings.isEmpty) return SensitiveDecision(photo, covered: false);
  if (!context.mounted) return null;
  return Navigator.of(context).push<SensitiveDecision>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) =>
          SensitiveReviewScreen(photo: photo, scan: scan, scanner: scanner),
    ),
  );
}

String sensitiveKindLabel(AppLocalizations l, SensitiveKind kind) =>
    switch (kind) {
      SensitiveKind.idNumber => l.sensitiveKindIdNumber,
      SensitiveKind.phone => l.sensitiveKindPhone,
      SensitiveKind.plate => l.sensitiveKindPlate,
      SensitiveKind.card => l.sensitiveKindCard,
      SensitiveKind.address => l.sensitiveKindAddress,
      SensitiveKind.idDocument => l.sensitiveKindIdDocument,
      SensitiveKind.screenText => l.sensitiveKindScreenText,
    };

/// The photo with each finding boxed; every box starts covered.
class SensitiveReviewScreen extends StatefulWidget {
  const SensitiveReviewScreen({
    super.key,
    required this.photo,
    required this.scan,
    required this.scanner,
  });

  final File photo;
  final SensitiveScan scan;
  final SensitiveScanner scanner;

  @override
  State<SensitiveReviewScreen> createState() => _SensitiveReviewScreenState();
}

class _SensitiveReviewScreenState extends State<SensitiveReviewScreen> {
  late final _covered = List.filled(widget.scan.findings.length, true);
  bool _working = false;

  Future<void> _post({required bool cover}) async {
    if (_working) return;
    final boxes = [
      for (var i = 0; i < _covered.length; i++)
        if (cover && _covered[i]) widget.scan.findings[i].box,
    ];
    if (boxes.isEmpty) {
      Navigator.of(
        context,
      ).pop(SensitiveDecision(widget.photo, covered: false));
      return;
    }
    setState(() => _working = true);
    try {
      final file = await widget.scanner.cover(widget.photo, boxes);
      if (mounted) {
        Navigator.of(context).pop(SensitiveDecision(file, covered: true));
      }
    } catch (error, stack) {
      AppLog.warn('sensitive_cover', error, stack);
      if (mounted) {
        setState(() => _working = false);
        showNeoSnack(context, AppLocalizations.of(context).photoNotSaved);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final findings = widget.scan.findings;
    final size = widget.scan.size;
    final anyCovered = _covered.contains(true);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l.sensitiveTitle,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Text(
                l.sensitiveIntro(findings.length),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Center(
                  child: DecoratedBox(
                    decoration: NeoTheme.panel(),
                    child: ClipRect(
                      child: FittedBox(
                        child: SizedBox(
                          width: size.width,
                          height: size.height,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Image.file(
                                  widget.photo,
                                  fit: BoxFit.fill,
                                ),
                              ),
                              for (var i = 0; i < findings.length; i++)
                                _box(context, l, i, size),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Text(
                l.sensitiveMayMiss,
                style: const TextStyle(fontSize: 12, color: NeoColors.muted),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: _working
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        NeoButton(
                          key: const ValueKey('sensitive-cover'),
                          label: l.sensitiveCoverAndPost,
                          icon: Icons.blur_on,
                          expand: true,
                          onPressed: anyCovered
                              ? () => _post(cover: true)
                              : null,
                        ),
                        const SizedBox(height: 10),
                        NeoButton(
                          key: const ValueKey('sensitive-as-is'),
                          label: l.sensitivePostAsIs,
                          variant: NeoButtonVariant.outline,
                          expand: true,
                          onPressed: () => _post(cover: false),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _box(BuildContext context, AppLocalizations l, int i, Size size) {
    final finding = widget.scan.findings[i];
    final covered = _covered[i];
    // Lines and labels are drawn in photo pixels, then scaled with the photo:
    // keep them a readable size whatever the resolution.
    final unit = size.longestSide / 400;
    final box = finding.box.intersect(Offset.zero & size);
    return Positioned.fromRect(
      rect: box.inflate(unit * 2),
      child: GestureDetector(
        key: ValueKey('sensitive-box-$i'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Haptics.select();
          setState(() => _covered[i] = !covered);
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: covered
                      ? NeoColors.ink.withValues(alpha: .55)
                      : Colors.transparent,
                  border: Border.all(
                    color: covered ? NeoColors.coral : NeoColors.lime,
                    width: unit * 1.5,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              bottom: -unit * 13,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: unit * 3,
                  vertical: unit,
                ),
                color: covered ? NeoColors.coral : NeoColors.lime,
                child: Text(
                  '${sensitiveKindLabel(l, finding.kind)} · '
                  '${covered ? l.sensitiveCovered : l.sensitiveShown}',
                  style: TextStyle(
                    color: NeoColors.ink,
                    fontSize: unit * 7,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
