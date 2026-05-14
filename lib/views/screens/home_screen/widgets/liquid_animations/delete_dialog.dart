import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:flutter/material.dart';

class DeleteDialog extends StatelessWidget {
  final String title;
  final VoidCallback onConfirm;

  const DeleteDialog({super.key, required this.title, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: LiquidColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: LiquidColors.textPrimary.withValues(alpha: .1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.red.withValues(alpha: .3),
                  width: 1,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red,
                  size: 30,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Move to Trash?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: LiquidColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '"$title" will be moved to recycle bin.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: LiquidColors.textSecondary),
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(
                        color: LiquidColors.textTertiary,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: LiquidColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onConfirm();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Move to Trash',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
