import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/features/rewind/rewind_channel.dart';

/// The live camera as a centred square (cover fit), so the person sees just
/// the part that will be kept.
///
/// The turn follows the camera plugin's own preview code
/// (camera_android_camerax: surface_texture_rotated_preview.dart and
/// image_reader_rotated_preview.dart) for a screen locked upright: the display
/// rotation and the turn the plugin's CameraPreview pre-applies are both zero.
class RewindPreview extends StatelessWidget {
  const RewindPreview({super.key, required this.start});

  final RewindStart start;

  @override
  Widget build(BuildContext context) {
    Widget texture = Texture(textureId: start.textureId);
    if (!start.handlesCropAndRotation) {
      // Front camera: mirrored first, like the plugin does, then turned by
      // the sensor's own orientation.
      if (start.front) texture = Transform.scale(scaleY: -1, child: texture);
      texture = RotatedBox(
        quarterTurns: start.sensorOrientation ~/ 90,
        child: texture,
      );
    }
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            // The buffer is landscape; the screen is upright.
            width: start.previewHeight.toDouble(),
            height: start.previewWidth.toDouble(),
            child: texture,
          ),
        ),
      ),
    );
  }
}
