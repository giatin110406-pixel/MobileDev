import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ProcessingStatus { pending, done, failed }

class NeoPhoto {
  const NeoPhoto({
    required this.id,
    required this.originalPath,
    required this.createdAt,
    required this.status,
    this.processedPath,
  });

  final String id;
  final String originalPath;
  final String? processedPath;
  final DateTime createdAt;
  final ProcessingStatus status;

  NeoPhoto copyWith({String? processedPath, ProcessingStatus? status}) =>
      NeoPhoto(
        id: id,
        originalPath: originalPath,
        processedPath: processedPath ?? this.processedPath,
        createdAt: createdAt,
        status: status ?? this.status,
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'originalPath': originalPath,
    'processedPath': processedPath,
    'createdAt': createdAt.toIso8601String(),
    'status': status.name,
  };

  factory NeoPhoto.fromJson(Map<String, dynamic> json) => NeoPhoto(
    id: json['id'] as String,
    originalPath: json['originalPath'] as String,
    processedPath: json['processedPath'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
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

  Future<NeoPhoto> saveOriginal(Uint8List bytes) async {
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
    );
    await upsert(photo);
    return photo;
  }

  Future<String> saveProcessed(String id, Uint8List bytes) async {
    final directory = await _photoDirectory();
    final path = '${directory.path}${Platform.pathSeparator}${id}_neo.png';
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
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
}
