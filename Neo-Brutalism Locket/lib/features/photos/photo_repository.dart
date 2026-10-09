import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_result.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_type.dart';

enum ProcessingStatus { pending, done, failed }

class NeoPhoto {
  const NeoPhoto({
    required this.id,
    required this.originalPath,
    required this.createdAt,
    required this.status,
    this.styleType,
    this.styleSource,
    this.failureReason,
    this.processedPath,
  });

  final String id;
  final String originalPath;
  final String? processedPath;
  final DateTime createdAt;
  final ProcessingStatus status;
  final StyleType? styleType;

  /// Which path produced the processed image (null for legacy photos).
  final StyleSource? styleSource;
  final String? failureReason;

  NeoPhoto copyWith({
    String? processedPath,
    ProcessingStatus? status,
    StyleType? styleType,
    StyleSource? styleSource,
    String? failureReason,
    bool clearFailureReason = false,
  }) => NeoPhoto(
    id: id,
    originalPath: originalPath,
    processedPath: processedPath ?? this.processedPath,
    createdAt: createdAt,
    status: status ?? this.status,
    styleType: styleType ?? this.styleType,
    styleSource: styleSource ?? this.styleSource,
    failureReason: clearFailureReason
        ? null
        : failureReason ?? this.failureReason,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'originalPath': originalPath,
    'processedPath': processedPath,
    'createdAt': createdAt.toIso8601String(),
    'status': status.name,
    'styleType': styleType?.name,
    'styleSource': styleSource?.name,
    'failureReason': failureReason,
  };

  factory NeoPhoto.fromJson(Map<String, dynamic> json) => NeoPhoto(
    id: json['id'] as String,
    originalPath: json['originalPath'] as String,
    processedPath: json['processedPath'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    styleType: StyleType.values.cast<StyleType?>().firstWhere(
      (value) => value?.name == json['styleType'],
      orElse: () => null,
    ),
    styleSource: StyleSource.values.cast<StyleSource?>().firstWhere(
      (value) => value?.name == json['styleSource'],
      orElse: () => null,
    ),
    failureReason: json['failureReason'] as String?,
    status: ProcessingStatus.values.firstWhere(
      (value) => value.name == json['status'],
      orElse: () => ProcessingStatus.failed,
    ),
  );
}

class PhotoRepository {
  static const _metadataKey = 'neo_photos_v1';

  Future<Directory> _photoDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(
      '${documents.path}${Platform.pathSeparator}photos',
    );
    await directory.create(recursive: true);
    return directory;
  }

  Future<List<NeoPhoto>> loadPhotos() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_metadataKey);
    if (stored == null) return [];

    final decoded = jsonDecode(stored) as List<dynamic>;
    final photos =
        decoded
            .map((item) => NeoPhoto.fromJson(item as Map<String, dynamic>))
            .where((photo) => File(photo.originalPath).existsSync())
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return photos;
  }

  Future<NeoPhoto> saveOriginal(
    Uint8List bytes, {
    required StyleType styleType,
  }) async {
    final now = DateTime.now();
    final id = now.microsecondsSinceEpoch.toString();
    final directory = await _photoDirectory();
    final path = '${directory.path}${Platform.pathSeparator}${id}_original.jpg';
    await File(path).writeAsBytes(bytes, flush: true);
    final photo = NeoPhoto(
      id: id,
      originalPath: path,
      createdAt: now,
      status: ProcessingStatus.pending,
      styleType: styleType,
    );
    await upsert(photo);
    return photo;
  }

  Future<void> upsert(NeoPhoto photo) async {
    final photos = await loadPhotos();
    final index = photos.indexWhere((item) => item.id == photo.id);
    if (index == -1) {
      photos.insert(0, photo);
    } else {
      photos[index] = photo;
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _metadataKey,
      jsonEncode(photos.map((item) => item.toJson()).toList()),
    );
  }

  /// Forgets [photo] and deletes its files (a shot that was posted or
  /// thrown away).
  Future<void> delete(NeoPhoto photo) async {
    final photos = await loadPhotos()
      ..removeWhere((item) => item.id == photo.id);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _metadataKey,
      jsonEncode(photos.map((item) => item.toJson()).toList()),
    );
    for (final path in [photo.originalPath, photo.processedPath]) {
      if (path == null) continue;
      try {
        await File(path).delete();
      } catch (_) {
        // Already gone.
      }
    }
  }
}
