import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/friends/friends_repository.dart';
import 'package:neo_brutalism_locket/features/groups/group_chat_store.dart';
import 'package:neo_brutalism_locket/features/groups/groups_repository.dart';
import 'package:neo_brutalism_locket/features/groups/groups_widgets.dart';

/// The group's chat: messages with the newest at the bottom.
class GroupChatView extends StatefulWidget {
  const GroupChatView({
    required this.store,
    required this.members,
    required this.myId,
    required this.onOpenPerson,
    super.key,
  });

  final GroupChatStore store;

  /// Who is in the group now, by id (people who left show as "Một người").
  final Map<String, Person> members;
  final String myId;
  final ValueChanged<Person> onOpenPerson;

  @override
  State<GroupChatView> createState() => _GroupChatViewState();
}

class _GroupChatViewState extends State<GroupChatView> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    try {
      await widget.store.send(text);
    } on GroupFailure catch (failure) {
      // Put the text back so nothing typed is lost.
      if (mounted) {
        _input.text = text;
        showNeoSnack(context, groupFailureText(failure));
      }
    }
  }

  String _nameOf(String? id) {
    if (id == null) return 'Một người';
    if (id == widget.myId) return 'Bạn';
    return widget.members[id]?.displayName ?? 'Một người';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListenableBuilder(
            listenable: widget.store,
            builder: (context, _) {
              final store = widget.store;
              if (!store.isLoaded) {
                return Center(
                  child: store.failed
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Không tải được tin nhắn.',
                              style: TextStyle(
                                color: NeoColors.ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            NeoButton(label: 'THỬ LẠI', onPressed: store.load),
                          ],
                        )
                      : const CircularProgressIndicator(color: NeoColors.ink),
                );
              }
              if (store.messages.isEmpty) {
                return const Center(
                  child: Text(
                    'Hãy chào cả nhóm 👋',
                    style: TextStyle(
                      color: NeoColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }
              final messages = store.messages.reversed.toList();
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  if (message.kind == GroupMessageKind.system) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                        child: Text(
                          systemMessageText(message, _nameOf(message.senderId)),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: NeoColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  }
                  final mine = message.senderId == widget.myId;
                  final sender = message.senderId == null
                      ? null
                      : widget.members[message.senderId];
                  return _Bubble(
                    text: message.body,
                    mine: mine,
                    name: mine ? null : _nameOf(message.senderId),
                    onTapName: sender == null
                        ? null
                        : () => widget.onOpenPerson(sender),
                  );
                },
              );
            },
          ),
        ),
        _composer(),
      ],
    );
  }

  Widget _composer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      color: NeoColors.surface,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              maxLength: 500,
              minLines: 1,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _send(),
              decoration: const InputDecoration(
                counterText: '',
                hintText: 'Nhắn cho cả nhóm…',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ListenableBuilder(
            listenable: widget.store,
            builder: (context, _) => NeoIconButton(
              icon: Icons.send,
              tooltip: 'Gửi',
              fill: NeoColors.yellow,
              onPressed: widget.store.sending ? null : _send,
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.text,
    required this.mine,
    this.name,
    this.onTapName,
  });

  final String text;
  final bool mine;
  final String? name;
  final VoidCallback? onTapName;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.75,
          ),
          child: Column(
            crossAxisAlignment: mine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (name != null)
                GestureDetector(
                  onTap: onTapName,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 3, left: 2),
                    child: Text(
                      name!,
                      style: const TextStyle(
                        color: NeoColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: mine ? NeoColors.yellow : NeoColors.surface,
                  border: Border.all(color: NeoColors.ink, width: 2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  text,
                  style: const TextStyle(
                    color: NeoColors.ink,
                    fontSize: 14,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
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
