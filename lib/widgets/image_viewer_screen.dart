import 'dart:io';

import 'package:flutter/material.dart';

import 'package:video_player_app/utils/liquid_colors.dart';

/// Full-screen, pinch-to-zoom viewer for a decrypted image file.
class ImageViewerScreen extends StatelessWidget {
  final String path;
  final String title;

  const ImageViewerScreen({super.key, required this.path, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LiquidColors.backgroundDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: LiquidColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(title, style: TextStyle(color: LiquidColors.textPrimary)),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.file(
            File(path),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, color: LiquidColors.error, size: 60),
                  const SizedBox(height: 16),
                  Text(
                    'Unable to load image',
                    style: TextStyle(color: LiquidColors.textPrimary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
