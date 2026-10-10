import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

/// Quick reactions shown in the bar, like Locket.
const quickReactions = ['💛', '🔥', '😍'];

/// More emojis in the picker sheet.
const moreReactions = [
  '😂', '🥹', '😭', '🤩', '😮', '🥰', '😎', '🤯', //
  '👏', '🙌', '💯', '✨', '🎉', '💀', '👀', '🫶',
  '❤️', '💜', '💙', '💚', '🌈', '☀️', '🌙', '📸',
];

/// "Send a message..." bar under a friend's post: type a reply, tap a quick
/// emoji, or open the picker for more. With text typed the emojis give way to
/// a send button.
class ReplyBar extends StatefulWidget {
  const ReplyBar({
    super.key,
    required this.onSendText,
    required this.onReact,
    this.hint,
  });

  final Future<void> Function(String text) onSendText;
  final Future<void> Function(String emoji) onReact;

  /// Null: the standard "Send a message..." in the app's language.
  final String? hint;

  @override
  State<ReplyBar> createState() => _ReplyBarState();
}

class _ReplyBarState extends State<ReplyBar> {
  final _controller = TextEditingController();
  bool _busy = false;

  bool get _hasText => _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() => _run(() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    await widget.onSendText(text);
    _controller.clear();
    if (mounted) FocusScope.of(context).unfocus();
  });

  Future<void> _react(String emoji) => _run(() => widget.onReact(emoji));

  Future<void> _openPicker() async {
    final emoji = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: NeoColors.surface,
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: NeoColors.ink, width: 2),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context).reactWith,
                style: const TextStyle(
                  color: NeoColors.ink,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: GridView.extent(
                  maxCrossAxisExtent: 52,
                  shrinkWrap: true,
                  children: [
                    for (final emoji in [...quickReactions, ...moreReactions])
                      InkResponse(
                        onTap: () => Navigator.of(context).pop(emoji),
                        child: Center(
                          child: Text(
                            emoji,
                            style: const TextStyle(
                              fontFamily: NeoFont.display,
                              fontSize: 26,
                            ),
                          ),
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
    if (emoji != null) await _react(emoji);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.only(left: 16, right: 6),
      decoration: BoxDecoration(
        color: NeoColors.surface,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: NeoColors.ink, width: 2),
        boxShadow: const [
          BoxShadow(color: NeoColors.ink, offset: Offset(3, 3), blurRadius: 0),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: !_busy,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              style: const TextStyle(
                color: NeoColors.ink,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText:
                    widget.hint ?? AppLocalizations.of(context).sendMessageHint,
                hintStyle: const TextStyle(
                  color: NeoColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (_hasText)
            IconButton(
              tooltip: AppLocalizations.of(context).sendReplyTooltip,
              onPressed: _busy ? null : _send,
              icon: const Icon(Icons.send_rounded, color: NeoColors.ink),
            )
          else ...[
            for (final emoji in quickReactions)
              Semantics(
                button: true,
                label: AppLocalizations.of(context).reactSemantics(emoji),
                child: InkResponse(
                  onTap: _busy ? null : () => _react(emoji),
                  radius: 20,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      emoji,
                      style: const TextStyle(
                        fontFamily: NeoFont.display,
                        fontSize: 22,
                      ),
                    ),
                  ),
                ),
              ),
            IconButton(
              tooltip: AppLocalizations.of(context).moreEmojiTooltip,
              onPressed: _busy ? null : _openPicker,
              icon: const Icon(
                Icons.add_reaction_outlined,
                color: NeoColors.ink,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
