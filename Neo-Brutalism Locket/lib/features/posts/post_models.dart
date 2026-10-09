import 'dart:math';

import 'package:neo_brutalism_locket/features/image_engine/style_type.dart';

/// A random version-4 UUID. The client makes the id before uploading, so a
/// retry after a dropped connection can never create a second post.
String newUuid([Random? random]) {
  final r = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => r.nextInt(256));
  bytes[6] = (bytes[6] & 0x0F) | 0x40;
  bytes[8] = (bytes[8] & 0x3F) | 0x80;
  String hex(int from, int to) => bytes
      .sublist(from, to)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}

StyleType? _styleFromName(String? name) {
  for (final style in StyleType.values) {
    if (style.name == name) return style;
  }
  return null;
}

/// A post as stored on the server.
class RemotePost {
  const RemotePost({
    required this.id,
    required this.authorId,
    required this.mediaPath,
    required this.createdAt,
    this.kind = 'photo',
    this.thumbPath,
    this.caption = '',
    this.style,
    this.questId,
    this.overlay,
  });

  final String id;
  final String authorId;
  final String kind;

  /// Paths in the `media` bucket.
  final String mediaPath;
  final String? thumbPath;
  final String caption;
  final StyleType? style;
  final String? questId;
  final Map<String, dynamic>? overlay;
  final DateTime createdAt;

  bool get isVideo => kind == 'video';

  static const columns =
      'id, author_id, kind, media_path, thumb_path, caption, style, quest_id, '
      'overlay, created_at';

  factory RemotePost.fromRow(Map<String, dynamic> row) => RemotePost(
    id: row['id'] as String,
    authorId: row['author_id'] as String,
    kind: (row['kind'] as String?) ?? 'photo',
    mediaPath: row['media_path'] as String,
    thumbPath: row['thumb_path'] as String?,
    caption: (row['caption'] as String?) ?? '',
    style: _styleFromName(row['style'] as String?),
    questId: row['quest_id'] as String?,
    overlay: (row['overlay'] as Map?)?.cast<String, dynamic>(),
    createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
  );
}

/// A post waiting to be uploaded. The picture is already encoded and saved in
/// the app's own folder, so it survives the app being closed.
class PendingPost {
  const PendingPost({
    required this.id,
    required this.mediaFile,
    required this.thumbFile,
    required this.extension,
    required this.createdAt,
    this.kind = 'photo',
    this.caption = '',
    this.style,
    this.questId,
    this.overlay,
    this.recipients,
    this.attempts = 0,
  });

  final String id;
  final String mediaFile;

  /// Null when no thumbnail could be made (a video on a picky phone).
  final String? thumbFile;

  /// `photo` or `video`.
  final String kind;

  /// `jpg`, `png` or `mp4`.
  final String extension;
  final String caption;
  final StyleType? style;
  final String? questId;
  final Map<String, dynamic>? overlay;

  /// Friend ids, or null for all friends.
  final List<String>? recipients;
  final DateTime createdAt;

  /// Failed tries that were not just a missing connection.
  final int attempts;

  String get contentType => switch (extension) {
    'png' => 'image/png',
    'mp4' => 'video/mp4',
    _ => 'image/jpeg',
  };

  PendingPost failedOnce() => PendingPost(
    id: id,
    mediaFile: mediaFile,
    thumbFile: thumbFile,
    extension: extension,
    createdAt: createdAt,
    kind: kind,
    caption: caption,
    style: style,
    questId: questId,
    overlay: overlay,
    recipients: recipients,
    attempts: attempts + 1,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'mediaFile': mediaFile,
    'thumbFile': thumbFile,
    'kind': kind,
    'extension': extension,
    'caption': caption,
    'style': style?.name,
    'questId': questId,
    'overlay': overlay,
    'recipients': recipients,
    'createdAt': createdAt.toIso8601String(),
    'attempts': attempts,
  };

  factory PendingPost.fromJson(Map<String, dynamic> json) => PendingPost(
    id: json['id'] as String,
    mediaFile: json['mediaFile'] as String,
    thumbFile: json['thumbFile'] as String?,
    kind: json['kind'] as String? ?? 'photo',
    extension: json['extension'] as String? ?? 'jpg',
    caption: json['caption'] as String? ?? '',
    style: _styleFromName(json['style'] as String?),
    questId: json['questId'] as String?,
    overlay: (json['overlay'] as Map?)?.cast<String, dynamic>(),
    recipients: (json['recipients'] as List?)?.cast<String>(),
    createdAt: DateTime.parse(json['createdAt'] as String),
    attempts: json['attempts'] as int? ?? 0,
  );
}
