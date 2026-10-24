import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:http/http.dart' as http;
import 'package:neo_brutalism_locket/core/app_log.dart';
import 'package:neo_brutalism_locket/core/backend/backend.dart';
import 'package:neo_brutalism_locket/core/backend/media_urls.dart';
import 'package:neo_brutalism_locket/features/posts/post_models.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// One file to put in a zip: where it is in the `media` bucket and what it is
/// called inside the zip.
class ExportFile {
  const ExportFile({required this.path, required this.name});

  final String path;
  final String name;
}

/// What [MediaExporter.buildZip] made.
class ExportResult {
  const ExportResult({required this.file, required this.added, this.missed});

  final File file;

  /// Files in the zip (besides the list that describes them).
  final int added;

  /// Files that could not be downloaded and are not in the zip.
  final int? missed;
}

/// Downloads pictures from the private bucket and zips them, so a group's album
/// or a whole account can be kept outside the app. Files go to disk one at a
/// time: a thousand photos never sit in memory together.
class MediaExporter {
  MediaExporter(
    this._urls, {
    http.Client? client,
    Future<Directory> Function()? tempDir,
  }) : _client = client ?? http.Client(),
       _tempDir = tempDir ?? getTemporaryDirectory;

  final MediaUrls? _urls;
  final http.Client _client;
  final Future<Directory> Function() _tempDir;

  /// Zips [files] (and [extras], small text files such as a list of posts) into
  /// `<temp>/<zipName>.zip`. [onProgress] hears (done, total) after each file.
  /// Null when there is nothing to zip or nothing could be downloaded at all.
  Future<ExportResult?> buildZip({
    required String zipName,
    required List<ExportFile> files,
    Map<String, String> extras = const {},
    void Function(int done, int total)? onProgress,
  }) async {
    final urls = _urls;
    if (urls == null || files.isEmpty) return null;
    final work = await Directory.systemTemp.createTemp('export_');
    final base = await _tempDir();
    final zip = File('${base.path}${Platform.pathSeparator}$zipName.zip');
    final encoder = ZipFileEncoder();
    var added = 0;
    var missed = 0;
    try {
      if (zip.existsSync()) zip.deleteSync();
      encoder.create(zip.path);
      for (final (index, file) in files.indexed) {
        final local = File(
          '${work.path}${Platform.pathSeparator}${index.toString()}',
        );
        if (await _download(urls, file.path, local)) {
          await encoder.addFile(local, file.name);
          added++;
        } else {
          missed++;
        }
        try {
          if (local.existsSync()) await local.delete();
        } catch (e, st) {
          AppLog.warn('media_export', e, st);
        }
        onProgress?.call(index + 1, files.length);
      }
      for (final entry in extras.entries) {
        encoder.addArchiveFile(ArchiveFile.string(entry.key, entry.value));
      }
      await encoder.close();
    } catch (e, st) {
      AppLog.warn('media_export', e, st);
      try {
        await encoder.close();
      } catch (_) {}
      if (zip.existsSync()) zip.deleteSync();
      return null;
    } finally {
      try {
        await work.delete(recursive: true);
      } catch (e, st) {
        AppLog.warn('media_export', e, st);
      }
    }
    if (added == 0) {
      if (zip.existsSync()) zip.deleteSync();
      return null;
    }
    return ExportResult(file: zip, added: added, missed: missed);
  }

  Future<bool> _download(MediaUrls urls, String path, File into) async {
    final url = await urls.resolve('media', path);
    if (url == null) return false;
    try {
      final response = await _client
          .send(http.Request('GET', Uri.parse(url)))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        await response.stream.drain<void>();
        return false;
      }
      final sink = into.openWrite();
      try {
        await response.stream.pipe(sink);
      } catch (_) {
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Opens the share sheet with the zip (save to Files / Drive, send...).
  /// True when the sheet opened.
  Future<bool> share(File zip, {String? text}) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          files: [XFile(zip.path, mimeType: 'application/zip')],
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// A date for a file name: `2026-10-23`.
String dateStamp(DateTime time) =>
    '${time.year.toString().padLeft(4, '0')}-'
    '${time.month.toString().padLeft(2, '0')}-'
    '${time.day.toString().padLeft(2, '0')}';

/// Where a post's files go in a zip, and its entry in the list of posts.
/// Names start with the date so the folder sorts by time; the first eight
/// characters of the id keep two shots of one second apart.
class PostExport {
  PostExport(this.post);

  final RemotePost post;

  String get _stem => '${dateStamp(post.createdAt)}_${post.id.substring(0, 8)}';

  String get mediaName =>
      '${post.isVideo ? 'videos' : 'photos'}/$_stem.${_extension(post.mediaPath)}';

  String? get originalName =>
      post.originalPath == null ? null : 'originals/$_stem.jpg';

  List<ExportFile> get files => [
    ExportFile(path: post.mediaPath, name: mediaName),
    if (post.originalPath != null)
      ExportFile(path: post.originalPath!, name: originalName!),
  ];

  Map<String, Object?> toJson() => {
    'id': post.id,
    'created_at': post.createdAt.toIso8601String(),
    'caption': post.caption,
    'style': post.style?.name,
    'overlay': post.overlay,
    'file': mediaName,
    'original': originalName,
  };

  static String _extension(String path) {
    final dot = path.lastIndexOf('.');
    return dot < 0 ? 'jpg' : path.substring(dot + 1).toLowerCase();
  }
}

/// All of my posts, oldest page last, for "export my data".
abstract interface class MyPostsSource {
  /// My posts older than [before], newest first. Empty at the end.
  Future<List<RemotePost>> page({DateTime? before, int limit = 100});
}

class SupabaseMyPostsSource implements MyPostsSource {
  SupabaseMyPostsSource({required this.myId});

  final String myId;

  @override
  Future<List<RemotePost>> page({DateTime? before, int limit = 100}) async {
    var query = Backend.client
        .from('posts')
        .select(RemotePost.columns)
        .eq('author_id', myId)
        .filter('deleted_at', 'is', null);
    if (before != null) {
      query = query.lt('created_at', before.toUtc().toIso8601String());
    }
    final rows = await query.order('created_at', ascending: false).limit(limit);
    return [for (final row in rows) RemotePost.fromRow(row)];
  }
}

/// Everything I posted (the pictures as shared and, where there is one, the shot
/// before its style) plus `posts.json`, in one zip.
class AccountExport {
  AccountExport({
    required this.source,
    required this.exporter,
    required this.username,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final MyPostsSource source;
  final MediaExporter exporter;
  final String username;
  final DateTime Function() _clock;

  /// Null when there is nothing to export or nothing could be downloaded.
  Future<ExportResult?> run({
    void Function(int done, int total)? onProgress,
  }) async {
    final posts = <RemotePost>[];
    DateTime? cursor;
    while (true) {
      final page = await source.page(before: cursor);
      if (page.isEmpty) break;
      posts.addAll(page);
      cursor = page.last.createdAt;
      if (page.length < 100) break;
    }
    if (posts.isEmpty) return null;
    final exports = [for (final post in posts) PostExport(post)];
    final listing = const JsonEncoder.withIndent('  ').convert({
      'exported_at': _clock().toIso8601String(),
      'username': username,
      'posts': [for (final export in exports) export.toJson()],
    });
    return exporter.buildZip(
      zipName: 'pocket_portrait_${dateStamp(_clock())}',
      files: [for (final export in exports) ...export.files],
      extras: {'posts.json': listing},
      onProgress: onProgress,
    );
  }
}
