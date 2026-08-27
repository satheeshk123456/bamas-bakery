import 'package:flutter/material.dart';
import '../widgets/app_image.dart';

/// Full-screen photo viewer -- black background, pinch/double-tap to
/// zoom, tap the close button or back to dismiss. Used from the offers
/// carousel so tapping a banner shows the whole photo properly instead
/// of just the cropped carousel thumbnail.
class FullImageScreen extends StatelessWidget {
  final String source;
  const FullImageScreen({super.key, required this.source});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: AppImage(source: source, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
