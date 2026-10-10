import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/auth/auth_widgets.dart';
import 'package:neo_brutalism_locket/features/auth/profile_repository.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_engine_utils.dart';
import 'package:neo_brutalism_locket/features/progress/player_repository.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

/// First sign-in: pick a display name, a unique username and (optionally) a
/// profile photo. Calls [onDone] with the saved profile.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.userId,
    required this.profiles,
    required this.onDone,
    this.initialName,
    this.pickPhoto,
  });

  final String userId;
  final ProfileRepository profiles;
  final ValueChanged<Profile> onDone;
  final String? initialName;

  /// Test hook: returns the chosen photo's bytes instead of opening the gallery.
  final Future<Uint8List?> Function()? pickPhoto;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _NameCheck { idle, checking, available, taken }

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final _name = TextEditingController(text: widget.initialName ?? '');
  final _username = TextEditingController();
  Timer? _debounce;
  _NameCheck _check = _NameCheck.idle;
  UsernameProblem? _problem;
  String? _error;
  Uint8List? _photo;
  bool _saving = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _name.dispose();
    _username.dispose();
    super.dispose();
  }

  void _onUsernameChanged(String raw) {
    _debounce?.cancel();
    final username = normalizeUsername(raw);
    if (username.isEmpty) {
      setState(() {
        _problem = null;
        _check = _NameCheck.idle;
      });
      return;
    }
    final problem = checkUsername(username);
    setState(() {
      _problem = problem;
      _check = problem == null ? _NameCheck.checking : _NameCheck.idle;
    });
    if (problem != null) return;
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final free = await widget.profiles.isUsernameAvailable(username);
        if (!mounted || normalizeUsername(_username.text) != username) return;
        setState(() => _check = free ? _NameCheck.available : _NameCheck.taken);
      } catch (_) {
        // Leave it unchecked; saving will report a clash anyway.
        if (mounted) setState(() => _check = _NameCheck.idle);
      }
    });
  }

  Future<void> _pickPhoto() async {
    try {
      final custom = widget.pickPhoto;
      final Uint8List? bytes;
      if (custom != null) {
        bytes = await custom();
      } else {
        final picked = await ImagePicker().pickImage(
          source: ImageSource.gallery,
        );
        if (picked == null) return;
        bytes = await compute(
          cropToSquareJpegCapped,
          await picked.readAsBytes(),
        );
      }
      if (bytes != null && mounted) setState(() => _photo = bytes);
    } catch (_) {
      // Picking is optional: ignore a failed pick.
    }
  }

  bool get _canSave =>
      !_saving &&
      _name.text.trim().isNotEmpty &&
      _problem == null &&
      normalizeUsername(_username.text).isNotEmpty &&
      _check != _NameCheck.taken;

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
      var profile = await widget.profiles.saveIdentity(
        userId: widget.userId,
        username: username,
        displayName: _name.text,
      );
      final photo = _photo;
      if (photo != null) {
        // Keep the local copy so the profile tab shows it at once.
        try {
          await PlayerRepository().setAvatar(photo);
        } catch (_) {
          // Only the offline copy; the server copy below still counts.
        }
        try {
          profile = await widget.profiles.uploadAvatar(widget.userId, photo);
        } catch (_) {
          // The account is fine without it; the avatar can be set again later.
        }
      }
      if (mounted) widget.onDone(profile);
    } on UsernameTaken {
      if (mounted) {
        setState(() {
          _check = _NameCheck.taken;
          _error = l10n.usernameTaken;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = l10n.errUnknown);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final problem = _problem;
    return Scaffold(
      backgroundColor: NeoColors.paper,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.onboardingTitle,
                    style: const TextStyle(
                      fontFamily: NeoFont.display,
                      color: NeoColors.ink,
                      fontSize: 30,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.onboardingSubtitle,
                    style: const TextStyle(
                      color: NeoColors.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _saving ? null : _pickPhoto,
                        child: Container(
                          key: const ValueKey('avatar-picker'),
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: NeoColors.pink,
                            shape: BoxShape.circle,
                            border: Border.all(color: NeoColors.ink, width: 2),
                            boxShadow: const [
                              BoxShadow(
                                color: NeoColors.ink,
                                offset: Offset(3, 3),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _photo == null
                              ? const Icon(
                                  Icons.add_a_photo_outlined,
                                  color: NeoColors.ink,
                                  size: 30,
                                )
                              : Image.memory(
                                  _photo!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stack) =>
                                      const Icon(Icons.broken_image_outlined),
                                ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.avatarOptional,
                              style: const TextStyle(
                                color: NeoColors.muted,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            NeoButton(
                              label: l10n.avatarPick,
                              icon: Icons.photo_library_outlined,
                              variant: NeoButtonVariant.outline,
                              onPressed: _saving ? null : _pickPhoto,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  NeoField(
                    label: l10n.displayNameLabel,
                    controller: _name,
                    maxLength: 40,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {}),
                    enabled: !_saving,
                  ),
                  const SizedBox(height: 16),
                  NeoField(
                    label: l10n.usernameLabel,
                    controller: _username,
                    prefix: '@',
                    maxLength: 21,
                    autocorrect: false,
                    textInputAction: TextInputAction.done,
                    onChanged: _onUsernameChanged,
                    onSubmitted: (_) => _canSave ? _save() : null,
                    enabled: !_saving,
                  ),
                  if (problem != null)
                    FieldMessage(usernameProblemText(l10n, problem))
                  else if (_check == _NameCheck.checking)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        l10n.usernameChecking,
                        style: const TextStyle(
                          color: NeoColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else if (_check == _NameCheck.available)
                    FieldMessage(l10n.usernameAvailable, good: true)
                  else if (_check == _NameCheck.taken)
                    FieldMessage(l10n.usernameTaken)
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        l10n.usernameHelp,
                        style: const TextStyle(
                          color: NeoColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  if (_error != null && problem == null) FieldMessage(_error!),
                  const SizedBox(height: 22),
                  NeoButton(
                    expand: true,
                    label: l10n.continueButton,
                    icon: _saving ? Icons.hourglass_top : Icons.arrow_forward,
                    variant: NeoButtonVariant.primary,
                    onPressed: _canSave ? _save : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
