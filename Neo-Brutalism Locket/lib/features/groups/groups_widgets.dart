import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/canvas/canvas_repository.dart';
import 'package:neo_brutalism_locket/features/friends/friends_repository.dart';
import 'package:neo_brutalism_locket/features/friends/friends_store.dart';
import 'package:neo_brutalism_locket/features/friends/friends_widgets.dart';
import 'package:neo_brutalism_locket/features/groups/groups_repository.dart';
import 'package:neo_brutalism_locket/features/safety/safety_repository.dart';
import 'package:neo_brutalism_locket/features/safety/safety_widgets.dart';

/// What went wrong with a group action, in words.
String groupFailureText(GroupFailure failure) => switch (failure.kind) {
  GroupFailureKind.notFound => 'Không tìm thấy nhóm hoặc người này.',
  GroupFailureKind.notOwner => 'Chỉ trưởng nhóm mới làm được việc này.',
  GroupFailureKind.notMember => 'Bạn không còn ở trong nhóm này.',
  GroupFailureKind.self => 'Không thể làm việc này với chính mình.',
  GroupFailureKind.empty => 'Hãy nhập nội dung.',
  GroupFailureKind.tooLong => 'Nội dung quá dài.',
  GroupFailureKind.blockedWord =>
    'Có từ không phù hợp. Hãy dùng ngôn từ lịch sự để mọi người cùng vui nhé.',
  GroupFailureKind.badName => 'Tên nhóm cần từ 1 đến 40 ký tự.',
  GroupFailureKind.badSize =>
    'Số thành viên tối đa phải từ 2 đến 12 và không nhỏ hơn số người hiện có.',
  GroupFailureKind.groupLimit =>
    'Bạn chỉ được ở tối đa 5 nhóm và làm trưởng tối đa 3 nhóm.',
  GroupFailureKind.memberLimit => 'Nhóm đã đủ người (kể cả lời mời đang chờ).',
  GroupFailureKind.theirGroupLimit => 'Bạn đang ở quá nhiều nhóm (tối đa 5).',
  GroupFailureKind.alreadyMember => 'Người này đã ở trong nhóm.',
  GroupFailureKind.alreadyInvited => 'Đã mời người này rồi.',
  GroupFailureKind.expired => 'Lời mời đã hết hạn.',
  GroupFailureKind.ownerMustTransfer =>
    'Hãy chuyển quyền trưởng nhóm cho người khác trước khi rời.',
  GroupFailureKind.network => 'Không kết nối được. Thử lại nhé.',
  GroupFailureKind.unknown => 'Có lỗi xảy ra. Thử lại nhé.',
};

String canvasFailureText(CanvasFailureKind kind) => switch (kind) {
  CanvasFailureKind.insufficientInk =>
    'Hết mực. Hoàn thành nhiệm vụ hằng ngày để nhận thêm 10 mực.',
  CanvasFailureKind.rateLimited => 'Vẽ chậm lại một chút (tối đa 30 ô/phút).',
  CanvasFailureKind.canvasLocked => 'Canvas này đã được lưu trữ.',
  CanvasFailureKind.notFound => 'Không tìm thấy canvas.',
  CanvasFailureKind.notOwner => 'Chỉ trưởng nhóm mới làm được việc này.',
  CanvasFailureKind.badPixel ||
  CanvasFailureKind.tooManyPixels => 'Ô vẽ không hợp lệ.',
  CanvasFailureKind.badSize => 'Kích thước hoặc bảng màu không hợp lệ.',
  CanvasFailureKind.network => 'Mất kết nối. Canvas chuyển sang chế độ chỉ xem.',
  CanvasFailureKind.unknown => 'Có lỗi xảy ra. Thử lại nhé.',
};

/// A system line in the chat ("Nam joined").
String systemMessageText(GroupMessage message, String name) =>
    switch (message.body) {
      'joined' => '$name đã tham gia nhóm',
      'left' => '$name đã rời nhóm',
      'kicked' => '$name đã bị mời ra khỏi nhóm',
      'owner_changed' => '$name là trưởng nhóm mới',
      'entry_submitted' => 'Nhóm đã nộp bài dự thi tuần này',
      _ => name,
    };

const _badgeColors = [
  NeoColors.pink,
  NeoColors.purple,
  NeoColors.teal,
  NeoColors.yellow,
  NeoColors.blue,
  NeoColors.orange,
];

/// A coloured square with the first letter: the group's picture.
class GroupBadge extends StatelessWidget {
  const GroupBadge({required this.name, this.size = 46, super.key});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    var hash = 0;
    for (final unit in name.codeUnits) {
      hash = (hash * 31 + unit) & 0x7FFFFFFF;
    }
    final letter = name.trim().isEmpty
        ? '?'
        : String.fromCharCode(name.trim().runes.first).toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _badgeColors[hash % _badgeColors.length],
        border: Border.all(color: NeoColors.ink, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        letter,
        style: TextStyle(
          color: NeoColors.ink,
          fontSize: size * 0.45,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

/// A person's square picture: their colour and first letter.
class PersonBadge extends StatelessWidget {
  const PersonBadge({required this.person, this.size = 40, super.key});

  final Person person;
  final double size;

  @override
  Widget build(BuildContext context) {
    final friend = person.toPocketFriend();
    final name = person.displayName.trim();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Color(friend.avatarColor),
        border: Border.all(color: NeoColors.ink, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        name.isEmpty ? '?' : String.fromCharCode(name.runes.first).toUpperCase(),
        style: TextStyle(
          color: NeoColors.ink,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

/// Two big buttons that flip between the friends list and the groups.
class FriendsGroupsSwitch extends StatelessWidget {
  const FriendsGroupsSwitch({
    required this.showGroups,
    required this.onChanged,
    this.groupUnread = 0,
    super.key,
  });

  final bool showGroups;
  final ValueChanged<bool> onChanged;
  final int groupUnread;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Segment(
            label: 'BẠN BÈ',
            icon: Icons.people_alt_outlined,
            selected: !showGroups,
            onTap: () => onChanged(false),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Segment(
            label: 'NHÓM',
            icon: Icons.groups_2_outlined,
            selected: showGroups,
            badge: groupUnread,
            onTap: () => onChanged(true),
          ),
        ),
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: selected ? NeoColors.yellow : NeoColors.surface,
            border: Border.all(color: NeoColors.ink, width: 2),
            borderRadius: BorderRadius.circular(8),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: NeoColors.ink,
                      offset: Offset(3, 3),
                      blurRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: NeoColors.ink),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: NeoColors.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (badge > 0) ...[
                const SizedBox(width: 8),
                NeoLabel('$badge', color: NeoColors.pink),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// What a stranger in a group sees: only the public card. Their photos stay
/// private until you are friends (the database enforces that, not this screen).
Future<void> showPersonCard(
  BuildContext context, {
  required Person person,
  required FriendsStore friends,
  SafetyRepository? safety,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (context) =>
      _PersonCard(person: person, friends: friends, safety: safety),
);

class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.person,
    required this.friends,
    required this.safety,
  });

  final Person person;
  final FriendsStore friends;
  final SafetyRepository? safety;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: friends,
      builder: (context, _) {
        final isFriend = friends.friendById(person.id) != null;
        final asked = friends.outgoing.any((r) => r.person.id == person.id);
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.all(18),
          decoration: NeoTheme.panel(radius: 16),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    PersonBadge(person: person, size: 56),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            person.displayName,
                            style: const TextStyle(
                              color: NeoColors.ink,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            person.handle,
                            style: const TextStyle(
                              color: NeoColors.muted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  isFriend
                      ? 'Hai bạn là bạn bè: ảnh mới của nhau hiện trong feed.'
                      : 'Ở chung nhóm chưa phải là bạn bè. Chỉ khi kết bạn, '
                            'hai người mới xem được ảnh của nhau.',
                  style: const TextStyle(
                    color: NeoColors.ink,
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                NeoButton(
                  label: isFriend
                      ? 'ĐÃ LÀ BẠN BÈ'
                      : asked
                      ? 'ĐÃ GỬI LỜI MỜI'
                      : 'KẾT BẠN',
                  icon: isFriend ? Icons.check : Icons.person_add_alt_1,
                  expand: true,
                  onPressed: isFriend || asked
                      ? null
                      : () => sendFriendRequestWithFeedback(
                          context,
                          friends,
                          person,
                        ),
                ),
                if (safety != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: NeoButton(
                          label: 'BÁO CÁO',
                          icon: Icons.flag_outlined,
                          variant: NeoButtonVariant.outline,
                          expand: true,
                          onPressed: () => _report(context),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: NeoButton(
                          label: 'CHẶN',
                          icon: Icons.block,
                          variant: NeoButtonVariant.outline,
                          expand: true,
                          onPressed: () => _block(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _report(BuildContext context) async {
    final draft = await showReportSheet(context);
    if (draft == null || !context.mounted) return;
    try {
      await safety!.report(
        userId: person.id,
        reason: draft.reason,
        details: draft.details,
      );
      if (context.mounted) showNeoSnack(context, 'Đã gửi báo cáo. Cảm ơn bạn.');
    } on SafetyFailure {
      if (context.mounted) {
        showNeoSnack(context, 'Không gửi được báo cáo. Thử lại nhé.');
      }
    }
  }

  Future<void> _block(BuildContext context) async {
    if (!await confirmBlock(context, person.displayName) || !context.mounted) {
      return;
    }
    try {
      await safety!.block(person.id);
      await friends.refresh();
      if (context.mounted) {
        Navigator.of(context).pop();
        showNeoSnack(context, 'Đã chặn ${person.displayName}.');
      }
    } on SafetyFailure {
      if (context.mounted) {
        showNeoSnack(context, 'Không chặn được. Thử lại nhé.');
      }
    }
  }
}
