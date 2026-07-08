import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LiquidColors {
  LiquidColors._();

  static bool _dark = true;
  static bool get isDark => _dark;

  /// Transparent, edge-to-edge system bar style with the correct icon
  /// brightness for the current theme. Contrast scrims are disabled so the app
  /// content extends cleanly under the status/navigation bars (no grey band).
  static SystemUiOverlayStyle get systemOverlayStyle => SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: _dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: _dark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness:
            _dark ? Brightness.light : Brightness.dark,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarContrastEnforced: false,
      );

  static void applyBrightness(Brightness brightness) {
    _dark = brightness == Brightness.dark;
  }

  static Color _pick(Color dark, Color light) => _dark ? dark : light;

  // ── Brand: a single indigo, expressed as light→deep shades so gradients keep
  // depth without introducing extra hues. Everything interactive uses indigo;
  // green (success) and red (error) remain purely as functional signals.
  static const Color indigo = Color(0xFF6366F1); // indigo-500
  static const Color indigoDeep = Color(0xFF4F46E5); // indigo-600
  static const Color indigoDeeper = Color(0xFF4338CA); // indigo-700
  static const Color indigoSoft = Color(0xFF818CF8); // indigo-400

  static const Color primaryStart = indigoSoft;
  static const Color primaryMid = indigoDeep;
  static const Color primaryEnd = indigoDeeper;

  static const Color secondaryStart = indigo;
  static const Color secondaryEnd = indigoDeep;

  // Backgrounds are primarily black & white: pure white in Light mode, a clean
  // near-black in Dark mode. The brand indigo is used only as a sparing accent.
  static Color get backgroundDeep =>
      _pick(const Color(0xFF0B0B0F), const Color(0xFFFFFFFF));

  static Color get backgroundMid =>
      _pick(const Color(0xFF121216), const Color(0xFFFFFFFF));

  static Color get backgroundLight =>
      _pick(const Color(0xFF1A1A20), const Color(0xFFF3F4F6));

  static Color get surface =>
      _pick(const Color(0xFF141418), const Color(0xFFFFFFFF));

  static Color get surfaceMuted =>
      _pick(const Color(0x14FFFFFF), const Color(0xFFF1F2F4));

  static Color get cardBorder =>
      _pick(const Color(0x1AFFFFFF), const Color(0xFFE6E8EC));

  static Color get divider =>
      _pick(const Color(0x14FFFFFF), const Color(0xFFEDEEF1));

  static Color get shadow =>
      _pick(const Color(0x66000000), const Color(0x0F000000));

  static Color get scrim =>
      _pick(const Color(0xB3000000), const Color(0x66000000));

  static Color get textPrimary =>
      _pick(const Color(0xFFFFFFFF), const Color(0xFF0A0A0C));
  static Color get textSecondary =>
      _pick(const Color(0xFFA0A4AB), const Color(0xFF5B5F66));
  static Color get textTertiary =>
      _pick(const Color(0xFF6B7078), const Color(0xFF9AA0A8));

  // All former accents now resolve to the one indigo brand color (with a
  // slightly deeper shade for two-stop gradients so they keep subtle depth).
  static Color get accentBlue => _pick(indigo, indigoDeep);
  static Color get accentPurple => _pick(indigoDeep, indigoDeeper);
  static Color get accentPink => _pick(indigo, indigoDeep);
  static Color get accentOrange => _pick(indigo, indigoDeep);

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
        colors: [indigoSoft, indigoDeep, indigoDeeper],
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

  // Media types are no longer colour-coded — a single indigo keeps the UI
  // calm and consistent; the media icon alone distinguishes the type.
  static Color getMediaColor(String type) => _pick(indigo, indigoDeep);

  static Gradient getMediaGradient(String type) => LinearGradient(
        colors: [_pick(indigo, indigoDeep), _pick(indigoDeep, indigoDeeper)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}
