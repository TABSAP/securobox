import 'package:flutter/material.dart';

class LiquidColors {

  static const Color primaryStart = Color(0xFF4158D0);
  static const Color primaryMid = Color(0xFFC850C0);
  static const Color primaryEnd = Color(0xFFFFCC70);

  static const Color secondaryStart = Color(0xFF0093E9);
  static const Color secondaryEnd = Color(0xFF80D0C7);

  static const Color backgroundDeep = Color(0xFF0A0F1E);
  static const Color backgroundMid = Color(0xFF141B2B);
  static const Color backgroundLight = Color(0xFF1E2738);

  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color accentPink = Color(0xFFEC4899);
  static const Color accentOrange = Color(0xFFF59E0B);

  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  static Gradient get primaryGradient => const LinearGradient(
    colors: [primaryStart, primaryMid, primaryEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static Gradient get secondaryGradient => const LinearGradient(
    colors: [secondaryStart, secondaryEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static Gradient get backgroundGradient => const LinearGradient(
    colors: [backgroundDeep, backgroundMid, backgroundLight],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.5, 1.0],
  );

  static Gradient get liquidFlowGradient => const RadialGradient(
    colors: [primaryStart, primaryMid, primaryEnd],
    center: Alignment(-0.3, -0.3),
    radius: 1.5,
    stops: [0.0, 0.5, 1.0],
  );

  static Gradient get cardGradient => LinearGradient(
    colors: [
      backgroundLight.withOpacity(0.9),
      backgroundMid.withOpacity(0.95),
      backgroundDeep.withOpacity(0.9),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static Color getMediaColor(String type) {
    switch (type) {
      case 'video':
        return accentBlue;
      case 'image':
        return success;
      case 'audio':
        return accentPurple;
      case 'document':
        return accentOrange;
      default:
        return accentPink;
    }
  }

  static Gradient getMediaGradient(String type) {
    switch (type) {
      case 'video':
        return const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'image':
        return const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF34D399)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'audio':
        return const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'document':
        return const LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFFF97316)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      default:
        return const LinearGradient(
          colors: [Color(0xFFEC4899), Color(0xFFF43F5E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }
}
