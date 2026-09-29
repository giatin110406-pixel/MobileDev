import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:neo_brutalism_locket/features/image_engine/segmentation_mask.dart';
import 'package:path_provider/path_provider.dart';

class AndroidSelfieSegmentation {
  static const _channel = MethodChannel(
    'com.neobrutalism.neo_brutalism_locket/image_segmentation',
  );

  Future<PersonMask?> segment(Uint8List imageBytes) async {
    if (!Platform.isAndroid) return null;

    File? workingFile;
    try {
      final temporaryDirectory = await getTemporaryDirectory();
      final id = DateTime.now().microsecondsSinceEpoch;
      workingFile = File(
        '${temporaryDirectory.path}${Platform.pathSeparator}segmentation_$id.png',
      );
      await workingFile.writeAsBytes(imageBytes, flush: true);
      final result = await _channel.invokeMapMethod<String, Object?>(
        'segmentPerson',
        {'path': workingFile.path},
      );
      if (result == null) return null;

      final width = result['width'];
      final height = result['height'];
      final maskBytes = result['maskBytes'];
      if (width is! int || height is! int || maskBytes is! Uint8List) {
        return null;
      }
      final count = width * height;
      if (width <= 0 || height <= 0 || maskBytes.lengthInBytes != count * 4) {
        return null;
      }

      final data = ByteData.sublistView(maskBytes);
      final confidences = Float32List(count);
      for (var index = 0; index < count; index++) {
        confidences[index] = data.getFloat32(index * 4, Endian.little);
      }
      return PersonMask(width: width, height: height, confidences: confidences);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    } catch (_) {
      return null;
    } finally {
      if (workingFile != null) {
        try {
          if (await workingFile.exists()) await workingFile.delete();
        } catch (_) {}
      }
    }
  }
}
