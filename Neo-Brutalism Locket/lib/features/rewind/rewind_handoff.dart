import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// The lock-screen rewind screen cannot post anything itself. It saves the
/// picked picture in the app's files and opens the main app on
/// `neolocket://rewind?file=<digits>.jpg`; these helpers read that link and
/// the file behind it.
final _fileName = RegExp(r'^\d+\.jpg$');

/// The file name in a rewind link, or null when [uri] is not a well-formed
/// one (another host, no `file`, a path or a name that is not `<digits>.jpg`).
String? rewindFileFromLink(Uri uri) {
  if (uri.scheme != 'neolocket' || uri.host != 'rewind') return null;
  final name = uri.queryParameters['file'];
  if (name == null || !_fileName.hasMatch(name)) return null;
  return name;
}

/// Where the lock-screen activity leaves pictures (the app's files folder,
/// which is what Android's `filesDir` is).
Future<Directory> rewindHandoffDir() async => Directory(
  '${(await getApplicationSupportDirectory()).path}/rewind_handoff',
);

/// Reads the picture [name] left by the lock screen and deletes it. Null when
/// it is gone or [name] is not a name the lock screen writes.
Future<Uint8List?> takeRewindHandoff(String name, {Directory? dir}) async {
  if (!_fileName.hasMatch(name)) return null;
  final file = File('${(dir ?? await rewindHandoffDir()).path}/$name');
  try {
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    return bytes.isEmpty ? null : bytes;
  } finally {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Left for the sweep.
    }
  }
}

/// Deletes handed-over pictures older than [maxAge] (nobody came for them).
Future<void> sweepRewindHandoff({
  Duration maxAge = const Duration(hours: 1),
  Directory? dir,
  DateTime? now,
}) async {
  final folder = dir ?? await rewindHandoffDir();
  if (!await folder.exists()) return;
  final cutoff = (now ?? DateTime.now()).subtract(maxAge);
  await for (final entity in folder.list()) {
    if (entity is! File) continue;
    try {
      if ((await entity.lastModified()).isBefore(cutoff)) await entity.delete();
    } catch (_) {
      // Next start tries again.
    }
  }
}
