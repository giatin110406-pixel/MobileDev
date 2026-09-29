import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/camera/camera_experience.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NeoLocketApp());
}

class NeoLocketApp extends StatelessWidget {
  const NeoLocketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pocket Portrait',
      debugShowCheckedModeBanner: false,
      theme: NeoTheme.data,
      home: const CameraExperienceScreen(),
    );
  }
}
