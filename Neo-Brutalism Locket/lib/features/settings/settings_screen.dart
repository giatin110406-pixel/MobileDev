import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/app_settings.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/auth/account_session.dart';
import 'package:neo_brutalism_locket/features/auth/auth_repository.dart';
import 'package:neo_brutalism_locket/features/auth/auth_widgets.dart';
import 'package:neo_brutalism_locket/features/auth/profile_repository.dart';
import 'package:neo_brutalism_locket/features/auth/reset_password_screen.dart';
import 'package:neo_brutalism_locket/features/image_engine/remote/server_settings_sheet.dart';
import 'package:neo_brutalism_locket/features/notifications/push_service.dart';
import 'package:neo_brutalism_locket/features/safety/safety_repository.dart';
import 'package:neo_brutalism_locket/features/safety/safety_widgets.dart';
import 'package:neo_brutalism_locket/features/settings/haptics_check.dart';
import 'package:neo_brutalism_locket/features/settings/legal_text.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';
import 'package:neo_brutalism_locket/core/haptics.dart';

/// Account, privacy, language and about. Opened from the profile tab.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.session,
    required this.settings,
    required this.auth,
    required this.safety,
    required this.onBlocksChanged,
    this.notifications,
    this.openServerSettings = showServerSettingsSheet,
  });

  /// Saved notification choices (the notification section is hidden when null).
  final NotificationPrefsRepository? notifications;

  final AccountSession session;
  final AppSettings settings;
  final AuthRepository auth;
  final SafetyRepository safety;

  /// Someone was unblocked: refresh the friends and the feed.
  final VoidCallback onBlocksChanged;

  /// Opens the laptop connection sheet (replaceable in tests).
  final Future<void> Function(BuildContext context) openServerSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: NeoColors.paper,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([session, settings]),
          builder: (context, _) {
            final profile = session.profile;
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
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
                      l10n.settingsTitle,
                      style: const TextStyle(
                        fontFamily: NeoFont.display,
                        color: NeoColors.ink,
                        fontSize: 26,
                        height: 1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                _heading(l10n.settingsAccount),
                _card([
                  if (session.user.email != null)
                    _info(l10n.settingsEmail(session.user.email!)),
                  _row(
                    icon: Icons.person_outline,
                    label: l10n.settingsEditProfile,
                    detail:
                        '${profile.displayName ?? ''} · @${profile.username ?? ''}',
                    onTap: () => _editProfile(context),
                  ),
                  _row(
                    icon: Icons.lock_outline,
                    label: l10n.settingsChangePassword,
                    onTap: () => _changePassword(context),
                  ),
                ]),
                _heading(l10n.settingsPrivacy),
                _card([
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                    activeThumbColor: NeoColors.ink,
                    activeTrackColor: NeoColors.teal,
                    title: Text(l10n.settingsAllowRequests, style: _labelStyle),
                    subtitle: Text(
                      l10n.settingsAllowRequestsHint,
                      style: _hintStyle,
                    ),
                    value: profile.allowRequests,
                    onChanged: Haptics.tapWith(
                      (value) => _setAllowRequests(context, value),
                    ),
                  ),
                  _row(
                    icon: Icons.block,
                    label: l10n.settingsBlocked,
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => BlockedScreen(
                          safety: safety,
                          onChanged: onBlocksChanged,
                        ),
                      ),
                    ),
                  ),
                ]),
                if (notifications != null) ...[
                  _heading(l10n.settingsNotifications),
                  _card([_NotificationSwitches(repository: notifications!)]),
                ],
                _heading(l10n.settingsFeedback),
                _card([
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    child: NeoSwitch(
                      value: settings.hapticsEnabled,
                      label: l10n.settingsHaptics,
                      onChanged: settings.setHaptics,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        NeoSwitch(
                          value: settings.hapticsDirect,
                          label: AppLocalizations.of(
                            context,
                          ).settingsHapticsDirect,
                          onChanged: settings.setHapticsDirect,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppLocalizations.of(
                            context,
                          ).settingsHapticsDirectHint,
                          style: _hintStyle,
                        ),
                      ],
                    ),
                  ),
                  _row(
                    icon: Icons.vibration,
                    label: AppLocalizations.of(context).settingsHapticsTest,
                    onTap: () => showHapticsCheck(context),
                  ),
                ]),
                _heading(l10n.settingsLanguage),
                _card([
                  _languageRow(context, l10n.settingsLanguageSystem, null),
                  _languageRow(
                    context,
                    l10n.settingsLanguageVi,
                    const Locale('vi'),
                  ),
                  _languageRow(
                    context,
                    l10n.settingsLanguageEn,
                    const Locale('en'),
                  ),
                ]),
                _heading(l10n.settingsAbout),
                _card([
                  _row(
                    icon: Icons.dns_outlined,
                    label: l10n.settingsLaptop,
                    onTap: () => openServerSettings(context),
                  ),
                  _row(
                    icon: Icons.privacy_tip_outlined,
                    label: l10n.settingsPrivacyPolicy,
                    onTap: () => _openLegal(
                      context,
                      l10n.settingsPrivacyPolicy,
                      privacyPolicy,
                    ),
                  ),
                  _row(
                    icon: Icons.description_outlined,
                    label: l10n.settingsTerms,
                    onTap: () =>
                        _openLegal(context, l10n.settingsTerms, termsOfUse),
                  ),
                ]),
                const SizedBox(height: 22),
                NeoButton(
                  expand: true,
                  label: l10n.signOut,
                  icon: Icons.logout,
                  variant: NeoButtonVariant.outline,
                  onPressed: () => _signOut(context),
                ),
                const SizedBox(height: 14),
                NeoButton(
                  expand: true,
                  label: l10n.settingsDeleteAccount,
                  icon: Icons.delete_forever_outlined,
                  variant: NeoButtonVariant.primary,
                  onPressed: () => _deleteAccount(context),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static const _labelStyle = TextStyle(
    color: NeoColors.ink,
    fontSize: 14,
    fontWeight: FontWeight.w800,
  );
  static const _hintStyle = TextStyle(
    color: NeoColors.muted,
    fontSize: 11,
    fontWeight: FontWeight.w600,
  );

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 22, 2, 8),
    child: Text(
      text,
      style: const TextStyle(
        color: NeoColors.muted,
        fontSize: 10,
        fontWeight: FontWeight.w900,
      ),
    ),
  );

  Widget _card(List<Widget> children) => Container(
    decoration: NeoTheme.panel(),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (final (i, child) in children.indexed) ...[
          if (i > 0)
            const Divider(height: 1, thickness: 1.5, color: NeoColors.ink),
          child,
        ],
      ],
    ),
  );

  Widget _info(String text) => Padding(
    padding: const EdgeInsets.all(14),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(text, style: _hintStyle.copyWith(fontSize: 12)),
    ),
  );

  Widget _row({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    String? detail,
  }) => InkWell(
    onTap: Haptics.tap(onTap),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: NeoColors.ink),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: _labelStyle),
                if (detail != null)
                  Text(detail, style: _hintStyle, maxLines: 1),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: NeoColors.muted),
        ],
      ),
    ),
  );

  Widget _languageRow(BuildContext context, String label, Locale? locale) {
    final selected = settings.locale?.languageCode == locale?.languageCode;
    return InkWell(
      onTap: Haptics.tap(() {
        settings.setLocale(locale);
        if (locale != null) session.rememberLocale(locale.languageCode);
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 20,
              color: NeoColors.ink,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: _labelStyle)),
          ],
        ),
      ),
    );
  }

  Future<void> _setAllowRequests(BuildContext context, bool value) async {
    final l10n = AppLocalizations.of(context);
    try {
      await session.setAllowRequests(value);
    } catch (_) {
      if (context.mounted) showNeoSnack(context, l10n.safetyFailed);
    }
  }

  void _changePassword(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (routeContext) => ResetPasswordScreen(
          auth: auth,
          onDone: () => Navigator.of(routeContext).pop(),
          onCancel: () => Navigator.of(routeContext).pop(),
        ),
      ),
    );
  }

  Future<void> _editProfile(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EditProfileSheet(session: session),
  );

  void _openLegal(
    BuildContext context,
    String title,
    List<LegalSection> Function(String languageCode) sections,
  ) {
    final code = Localizations.localeOf(context).languageCode;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => LegalScreen(title: title, sections: sections(code)),
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: NeoColors.surface,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: NeoColors.ink, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        title: Text(l10n.signOutConfirmTitle),
        content: Text(l10n.signOutConfirmBody),
        actions: [
          TextButton(
            onPressed: Haptics.tap(() => Navigator.pop(context, false)),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: Haptics.tap(() => Navigator.pop(context, true)),
            child: Text(l10n.signOut),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (context.mounted) Navigator.of(context).pop();
    await session.signOut();
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final username = session.profile.username ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteAccountDialog(username: username),
    );
    if (confirmed != true) return;
    try {
      await session.deleteAccount();
      if (context.mounted) Navigator.of(context).pop();
    } catch (_) {
      if (context.mounted) showNeoSnack(context, l10n.deleteAccountFailed);
    }
  }
}

/// One switch per kind of notification. Each change is saved at once; if the
/// save fails the switch goes back.
class _NotificationSwitches extends StatefulWidget {
  const _NotificationSwitches({required this.repository});

  final NotificationPrefsRepository repository;

  @override
  State<_NotificationSwitches> createState() => _NotificationSwitchesState();
}

class _NotificationSwitchesState extends State<_NotificationSwitches> {
  NotificationPrefs? _prefs;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await widget.repository.load();
      if (mounted) setState(() => _prefs = prefs);
    } catch (_) {
      // Shown as on until it can be read; changing a switch tries to save.
      if (mounted) setState(() => _prefs = const NotificationPrefs());
    }
  }

  Future<void> _change(NotificationPrefs next) async {
    final before = _prefs ?? const NotificationPrefs();
    setState(() => _prefs = next);
    try {
      await widget.repository.save(next);
    } catch (_) {
      if (!mounted) return;
      setState(() => _prefs = before);
      showNeoSnack(context, AppLocalizations.of(context).safetyFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final prefs = _prefs;
    Widget tile(
      String label,
      bool value,
      NotificationPrefs Function(bool) next,
    ) => SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      activeThumbColor: NeoColors.ink,
      activeTrackColor: NeoColors.teal,
      title: Text(label, style: SettingsScreen._labelStyle),
      value: value,
      onChanged: Haptics.tapWith(
        prefs == null ? null : (v) => _change(next(v)),
      ),
    );
    final current = prefs ?? const NotificationPrefs();
    return Column(
      children: [
        tile(
          l10n.notifyNewPost,
          current.newPost,
          (v) => current.copyWith(newPost: v),
        ),
        tile(
          l10n.notifyMessages,
          current.messages,
          (v) => current.copyWith(messages: v),
        ),
        tile(
          l10n.notifyReactions,
          current.reactions,
          (v) => current.copyWith(reactions: v),
        ),
        tile(
          l10n.notifyFriendRequests,
          current.friendRequests,
          (v) => current.copyWith(friendRequests: v),
        ),
      ],
    );
  }
}

/// Asks the person to type their username before an account is deleted.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.username});

  final String username;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _typed = TextEditingController();

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  bool get _matches =>
      widget.username.isNotEmpty &&
      normalizeUsername(_typed.text) == widget.username;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      backgroundColor: NeoColors.surface,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: NeoColors.ink, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      title: Text(
        l10n.deleteAccountTitle,
        style: const TextStyle(
          color: NeoColors.ink,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.deleteAccountBody),
          const SizedBox(height: 14),
          Text(
            l10n.deleteAccountType(widget.username),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          ),
          TextField(
            controller: _typed,
            autocorrect: false,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: Haptics.tap(() => Navigator.pop(context, false)),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: Haptics.tap(
            _matches ? () => Navigator.pop(context, true) : null,
          ),
          child: Text(l10n.deleteAccountConfirm),
        ),
      ],
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({required this.session});

  final AccountSession session;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final _name = TextEditingController(
    text: widget.session.profile.displayName ?? '',
  );
  late final _username = TextEditingController(
    text: widget.session.profile.username ?? '',
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final username = normalizeUsername(_username.text);
    final problem = checkUsername(username);
    if (_name.text.trim().isEmpty) {
      setState(() => _error = l10n.displayNameRequired);
      return;
    }
    if (problem != null) {
      setState(() => _error = usernameProblemText(l10n, problem));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.session.updateIdentity(
        displayName: _name.text.trim(),
        username: username,
      );
      if (mounted) Navigator.of(context).pop();
    } on UsernameTaken {
      if (mounted) setState(() => _error = l10n.usernameTaken);
    } catch (_) {
      if (mounted) setState(() => _error = l10n.errUnknown);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
                l10n.editProfileTitle,
                style: const TextStyle(
                  fontFamily: NeoFont.display,
                  color: NeoColors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              NeoField(
                label: l10n.displayNameLabel,
                controller: _name,
                maxLength: 40,
                enabled: !_saving,
              ),
              const SizedBox(height: 14),
              NeoField(
                label: l10n.usernameLabel,
                controller: _username,
                prefix: '@',
                maxLength: 21,
                autocorrect: false,
                enabled: !_saving,
              ),
              if (_error != null) FieldMessage(_error!),
              const SizedBox(height: 16),
              NeoButton(
                expand: true,
                label: l10n.saveButton,
                icon: _saving ? Icons.hourglass_top : Icons.check,
                variant: NeoButtonVariant.primary,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A policy or terms page: titled paragraphs.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.title, required this.sections});

  final String title;
  final List<LegalSection> sections;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: NeoColors.paper,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
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
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontFamily: NeoFont.display,
                      color: NeoColors.ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: NeoTheme.panel(color: NeoColors.yellow),
              child: Text(
                l10n.legalDraftNote,
                style: const TextStyle(
                  color: NeoColors.ink,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            for (final section in sections) ...[
              const SizedBox(height: 18),
              Text(
                section.heading,
                style: const TextStyle(
                  color: NeoColors.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                section.body,
                style: const TextStyle(
                  color: NeoColors.ink,
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
