import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/friends/friends_repository.dart';
import 'package:neo_brutalism_locket/features/safety/safety_repository.dart';
import 'package:neo_brutalism_locket/features/social/social_views.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';
import 'package:neo_brutalism_locket/core/haptics.dart';

String reasonLabel(AppLocalizations l10n, ReportReason reason) =>
    switch (reason) {
      ReportReason.spam => l10n.reportSpam,
      ReportReason.inappropriate => l10n.reportInappropriate,
      ReportReason.harassment => l10n.reportHarassment,
      ReportReason.other => l10n.reportOther,
    };

String safetyFailureText(AppLocalizations l10n, SafetyFailure failure) =>
    switch (failure.kind) {
      SafetyFailureKind.tooMany => l10n.reportTooMany,
      SafetyFailureKind.network => l10n.errNetwork,
      _ => l10n.safetyFailed,
    };

/// What the person chose in the report sheet.
class ReportDraft {
  const ReportDraft({required this.reason, this.details});

  final ReportReason reason;
  final String? details;
}

/// Pick a reason (and optionally add details). Null when they back out.
Future<ReportDraft?> showReportSheet(BuildContext context) =>
    showModalBottomSheet<ReportDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _ReportSheet(),
    );

class _ReportSheet extends StatefulWidget {
  const _ReportSheet();

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  ReportReason? _reason;
  final _details = TextEditingController();

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.all(18),
        decoration: NeoTheme.panel(color: NeoColors.surface, radius: 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.reportTitle,
                style: const TextStyle(
                  fontFamily: NeoFont.display,
                  color: NeoColors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.reportWhy,
                style: const TextStyle(
                  color: NeoColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              for (final reason in ReportReason.values)
                _reasonRow(reason, reasonLabel(l10n, reason)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: NeoTheme.panel(color: NeoColors.paper),
                child: TextField(
                  controller: _details,
                  maxLength: 500,
                  maxLines: 3,
                  minLines: 1,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: l10n.reportDetailsHint,
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(height: 14),
              NeoButton(
                expand: true,
                label: l10n.reportSend,
                icon: Icons.flag_outlined,
                variant: NeoButtonVariant.primary,
                onPressed: _reason == null
                    ? null
                    : () => Navigator.of(context).pop(
                        ReportDraft(
                          reason: _reason!,
                          details: _details.text.trim().isEmpty
                              ? null
                              : _details.text.trim(),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reasonRow(ReportReason reason, String label) {
    final selected = _reason == reason;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: Haptics.tap(() => setState(() => _reason = reason)),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: NeoColors.ink,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: NeoColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Block X?" — true when they confirm.
Future<bool> confirmBlock(BuildContext context, String name) async {
  final l10n = AppLocalizations.of(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: NeoColors.surface,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: NeoColors.ink, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      title: Text(
        l10n.blockTitle(name),
        style: const TextStyle(
          color: NeoColors.ink,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: Text(
        l10n.blockBody,
        style: const TextStyle(color: NeoColors.ink),
      ),
      actions: [
        TextButton(
          onPressed: Haptics.tap(() => Navigator.pop(context, false)),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: Haptics.tap(() => Navigator.pop(context, true)),
          child: Text(l10n.blockPerson),
        ),
      ],
    ),
  );
  return result == true;
}

/// The people I blocked, each with an unblock button.
class BlockedScreen extends StatefulWidget {
  const BlockedScreen({super.key, required this.safety, this.onChanged});

  final SafetyRepository safety;

  /// Called after someone was unblocked (the app refreshes friends).
  final VoidCallback? onChanged;

  @override
  State<BlockedScreen> createState() => _BlockedScreenState();
}

class _BlockedScreenState extends State<BlockedScreen> {
  List<Person>? _people;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final people = await widget.safety.loadBlocked();
      if (mounted) {
        setState(() {
          _people = people;
          _failed = false;
        });
      }
    } on SafetyFailure {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _unblock(Person person) async {
    final l10n = AppLocalizations.of(context);
    try {
      await widget.safety.unblock(person.id);
      if (!mounted) return;
      setState(
        () => _people = [
          for (final p in _people ?? const <Person>[])
            if (p.id != person.id) p,
        ],
      );
      widget.onChanged?.call();
      showNeoSnack(context, l10n.unblockedDone(person.displayName));
    } on SafetyFailure catch (failure) {
      if (mounted) showNeoSnack(context, safetyFailureText(l10n, failure));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final people = _people;
    return Scaffold(
      backgroundColor: NeoColors.paper,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  NeoIconButton(
                    icon: Icons.arrow_back,
                    tooltip: l10n.cancel,
                    fill: NeoColors.yellow,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    l10n.blockedTitle,
                    style: const TextStyle(
                      color: NeoColors.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: people == null
                    ? Center(
                        child: _failed
                            ? NeoButton(
                                label: l10n.retry,
                                icon: Icons.refresh,
                                variant: NeoButtonVariant.accent,
                                onPressed: _load,
                              )
                            : const CircularProgressIndicator(
                                color: NeoColors.ink,
                              ),
                      )
                    : people.isEmpty
                    ? Center(
                        child: Text(
                          l10n.blockedEmpty,
                          style: const TextStyle(
                            color: NeoColors.muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : ListView(
                        children: [
                          for (final person in people)
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: NeoTheme.panel(),
                              child: Row(
                                children: [
                                  FriendAvatar(
                                    friend: person.toPocketFriend(),
                                    size: 40,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          person.displayName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: NeoColors.ink,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        Text(
                                          person.handle,
                                          style: const TextStyle(
                                            color: NeoColors.muted,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  NeoButton(
                                    label: l10n.unblock,
                                    variant: NeoButtonVariant.outline,
                                    onPressed: () => _unblock(person),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
