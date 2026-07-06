import 'package:flutter/material.dart';

import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/widgets/app_confirm_dialog.dart';

class DeleteDialog extends StatelessWidget {
  final String title;
  final VoidCallback onConfirm;

  const DeleteDialog({super.key, required this.title, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return AppConfirmDialog(
      icon: Icons.delete_outline_rounded,
      accent: LiquidColors.error,
      title: 'Move to Trash?',
      message:
          '"$title" moves to the Recycle Bin — you can restore it within 30 days.',
      confirmLabel: 'Move to Trash',
      onConfirm: onConfirm,
    );
  }
}
