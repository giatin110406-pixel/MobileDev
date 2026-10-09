import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';

/// Labels drawn over a post: the time it was taken and the place. Stored as
/// data (not burned into the picture), so they stay sharp and can be hidden.
class PostOverlay {
  const PostOverlay({this.time, this.place});

  /// "14:05" — the poster's local time when they shot it.
  final String? time;

  /// A town or district name, e.g. "Huế".
  final String? place;

  bool get isEmpty => (time ?? '').isEmpty && (place ?? '').isEmpty;

  /// Null when there is nothing to show (no overlay is stored).
  Map<String, dynamic>? toJson() => isEmpty
      ? null
      : {
          if ((time ?? '').isNotEmpty) 'time': time,
          if ((place ?? '').isNotEmpty) 'place': place,
        };

  /// Reads what the server returned, ignoring anything unexpected.
  static PostOverlay fromJson(Map<String, dynamic>? json) {
    String? text(Object? value) {
      if (value is! String) return null;
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return trimmed.length > 40 ? trimmed.substring(0, 40) : trimmed;
    }

    return PostOverlay(time: text(json?['time']), place: text(json?['place']));
  }
}

/// "09:05", "14:30".
String formatOverlayTime(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

/// The labels in the top-right corner of a post.
class OverlayLabels extends StatelessWidget {
  const OverlayLabels({super.key, required this.overlay});

  final PostOverlay overlay;

  @override
  Widget build(BuildContext context) {
    if (overlay.isEmpty) return const SizedBox.shrink();
    Widget label(IconData icon, String text) => Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: NeoColors.ink.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: NeoColors.surface),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: NeoColors.surface,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (overlay.time != null) label(Icons.schedule, overlay.time!),
        if (overlay.place != null) label(Icons.place_outlined, overlay.place!),
      ],
    );
  }
}

enum PlaceProblem { servicesOff, denied, failed }

class PlaceUnavailable implements Exception {
  const PlaceUnavailable(this.problem);

  final PlaceProblem problem;
}

/// Where the phone is, as a place name.
abstract interface class PlaceLookup {
  /// Throws [PlaceUnavailable].
  Future<String> currentPlace();
}

/// Coarse location (no GPS needed) turned into a town name by the phone's
/// own geocoder. Only the name is stored, never the coordinates.
class DevicePlaceLookup implements PlaceLookup {
  const DevicePlaceLookup();

  @override
  Future<String> currentPlace() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const PlaceUnavailable(PlaceProblem.servicesOff);
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const PlaceUnavailable(PlaceProblem.denied);
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 12),
        ),
      );
      final marks = await geo.Geocoding().placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      for (final mark in marks) {
        for (final name in [
          mark.locality,
          mark.subAdministrativeArea,
          mark.administrativeArea,
        ]) {
          if (name != null && name.trim().isNotEmpty) return name.trim();
        }
      }
    } catch (_) {
      // Falls through to "failed".
    }
    throw const PlaceUnavailable(PlaceProblem.failed);
  }
}
