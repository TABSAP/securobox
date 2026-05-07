import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';

class FlushBarHelper {
  static void _show(
    BuildContext context, {
    required String message,
    required Color background,
    required IconData icon,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (message.trim().isEmpty) return;
    Flushbar(
      forwardAnimationCurve: Curves.decelerate,
      reverseAnimationCurve: Curves.easeInOut,
      message: message,
      duration: duration,
      messageColor: Colors.white,
      backgroundColor: background,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(15),
      flushbarPosition: FlushbarPosition.TOP,
      positionOffset: 20,
      icon: Icon(icon, color: Colors.white),
      borderRadius: BorderRadius.circular(8),
      boxShadows: [
        BoxShadow(
          color: background.withValues(alpha: 0.3),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ).show(context);
  }

  static void flushBarErrorMessage(String message, BuildContext context) {
    _show(
      context,
      message: message,
      background: Colors.red.shade600,
      icon: Icons.error_outline,
    );
  }

  static void flushBarSuccessMessage(String message, BuildContext context) {
    _show(
      context,
      message: message,
      background: Colors.green.shade600,
      icon: Icons.check_circle_outline,
      duration: const Duration(seconds: 2),
    );
  }

  static void flushBarInfoMessage(String message, BuildContext context) {
    _show(
      context,
      message: message,
      background: Colors.blue.shade600,
      icon: Icons.info_outline,
    );
  }

  static void flushBarWarningMessage(String message, BuildContext context) {
    _show(
      context,
      message: message,
      background: Colors.orange.shade700,
      icon: Icons.warning_amber_outlined,
    );
  }
}