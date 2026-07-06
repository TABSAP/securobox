import 'package:flutter/material.dart';

import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/widgets/app_confirm_dialog.dart';
import '../../../../../utils/media_helper.dart';

class DownloadDialog extends StatelessWidget {
  final String title;
  final String path;
  final VoidCallback onConfirm;

  const DownloadDialog({
    super.key,
    required this.title,
    required this.path,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final type = MediaHelper.getFileTypeLabel(path).toLowerCase();
    return AppConfirmDialog(
      icon: Icons.download_rounded,
      accent: LiquidColors.accentBlue,
      title: 'Save to device?',
      message:
          '"$title" will be decrypted and saved to your device as a $type. '
          'Anyone with access to your gallery can then see it.',
      confirmLabel: 'Save',
      onConfirm: onConfirm,
    );
  }
}
