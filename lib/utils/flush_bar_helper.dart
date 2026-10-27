import 'package:flutter/material.dart';
import 'package:video_player_app/widgets/liquid_glass_surface.dart';

class FlushBarHelper {
  static void _show(
    BuildContext context, {
    required String message,
    required Color statusColor,
    required IconData icon,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (message.trim().isEmpty) return;

    final theme = Theme.of(context);
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          padding: EdgeInsets.zero,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          behavior: SnackBarBehavior.floating,
          duration: duration,
          dismissDirection: DismissDirection.down,
          content: LiquidGlassSurface(
            borderRadius: 18,
            blur: 22,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                LiquidGlassSurface(
                  borderRadius: 13,
                  blur: 12,
                  tintColor: statusColor,
                  tintOpacity: 0.12,
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(icon, color: statusColor, size: 21),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }

  static void flushBarErrorMessage(String message, BuildContext context) {
    _show(
      context,
      message: message,
      statusColor: Theme.of(context).colorScheme.error,
      icon: Icons.error_outline_rounded,
    );
  }

  static void flushBarSuccessMessage(String message, BuildContext context) {
    _show(
      context,
      message: message,
      statusColor: const Color(0xFF2E9D73),
      icon: Icons.check_circle_outline_rounded,
      duration: const Duration(seconds: 2),
    );
  }

  static void flushBarInfoMessage(String message, BuildContext context) {
    _show(
      context,
      message: message,
      statusColor: Theme.of(
        context,
      ).colorScheme.onSurface.withValues(alpha: 0.72),
      icon: Icons.info_outline_rounded,
    );
  }

  static void flushBarWarningMessage(String message, BuildContext context) {
    _show(
      context,
      message: message,
      statusColor: const Color(0xFFC58A36),
      icon: Icons.warning_amber_rounded,
    );
  }
}
