import 'package:flutter/material.dart';

class LiquidColors {
  LiquidColors._();

  static bool _dark = true;
  static bool get isDark => _dark;

  static void applyBrightness(Brightness brightness) {
    _dark = brightness == Brightness.dark;
  }

  static Color _pick(Color dark, Color light) => _dark ? dark : light;

  static const Color primaryStart = Color(0xFF4158D0);
  static const Color primaryMid = Color(0xFFC850C0);
  static const Color primaryEnd = Color(0xFFFFCC70);

  static const Color secondaryStart = Color(0xFF0093E9);
  static const Color secondaryEnd = Color(0xFF80D0C7);

  static Color get backgroundDeep =>
      _pick(const Color(0xFF0A0F1E), const Color(0xFFF4F6FB));

  static Color get backgroundMid =>
      _pick(const Color(0xFF141B2B), const Color(0xFFFFFFFF));

  static Color get backgroundLight =>
      _pick(const Color(0xFF1E2738), const Color(0xFFF1F4FA));

  static Color get surface =>
      _pick(const Color(0xFF1A1F2E), const Color(0xFFFFFFFF));

  static Color get surfaceMuted =>
      _pick(const Color(0x14FFFFFF), const Color(0xFFEDF0F7));

  static Color get cardBorder =>
      _pick(const Color(0x12FFFFFF), const Color(0xFFE1E6EF));

  static Color get divider =>
      _pick(const Color(0x0FFFFFFF), const Color(0xFFE6EAF1));

  static Color get shadow =>
      _pick(const Color(0x4D000000), const Color(0x14000000));

  static Color get scrim =>
      _pick(const Color(0x99000000), const Color(0x66000000));

  static Color get textPrimary =>
      _pick(const Color(0xFFFFFFFF), const Color(0xFF1A1F2E));
  static Color get textSecondary =>
      _pick(const Color(0xFF9CA3AF), const Color(0xFF5B6472));
  static Color get textTertiary =>
      _pick(const Color(0xFF6B7280), const Color(0xFF8A93A3));

  static Color get accentBlue =>
      _pick(const Color(0xFF3B82F6), const Color(0xFF2563EB));
  static Color get accentPurple =>
      _pick(const Color(0xFF8B5CF6), const Color(0xFF7C3AED));
  static Color get accentPink =>
      _pick(const Color(0xFFEC4899), const Color(0xFFDB2777));
  static Color get accentOrange =>
      _pick(const Color(0xFFF59E0B), const Color(0xFFD97706));

  static Color get success =>
      _pick(const Color(0xFF10B981), const Color(0xFF059669));
  static Color get warning =>
      _pick(const Color(0xFFF59E0B), const Color(0xFFD97706));
  static Color get error =>
      _pick(const Color(0xFFEF4444), const Color(0xFFDC2626));
  static Color get info => accentBlue;

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

  static Gradient get backgroundGradient => LinearGradient(
        colors: [backgroundDeep, backgroundMid, backgroundLight],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0.0, 0.5, 1.0],
      );

  static Gradient get liquidFlowGradient => const RadialGradient(
        colors: [primaryStart, primaryMid, primaryEnd],
        center: Alignment(-0.3, -0.3),
        radius: 1.5,
        stops: [0.0, 0.5, 1.0],
      );

  static Gradient get cardGradient => _dark
      ? LinearGradient(
          colors: [
            backgroundLight.withValues(alpha: 0.9),
            backgroundMid.withValues(alpha: 0.95),
            backgroundDeep.withValues(alpha: 0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
      : const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFF6F8FC), Color(0xFFEEF2F9)],
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
        return LinearGradient(
          colors: [accentBlue, accentPurple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'image':
        return LinearGradient(
          colors: [
            success,
            _pick(const Color(0xFF34D399), const Color(0xFF10B981)),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'audio':
        return LinearGradient(
          colors: [accentPurple, accentPink],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'document':
        return LinearGradient(
          colors: [
            accentOrange,
            _pick(const Color(0xFFF97316), const Color(0xFFEA580C)),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      default:
        return LinearGradient(
          colors: [
            accentPink,
            _pick(const Color(0xFFF43F5E), const Color(0xFFE11D48)),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }
}
