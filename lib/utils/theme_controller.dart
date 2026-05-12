import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'liquid_colors.dart';

/// Owns the app-wide theme mode (System / Light / Dark) and keeps
/// [LiquidColors] in sync with the resolved brightness so colors are correct
/// even outside a build (e.g. `CustomPainter`s reading `LiquidColors.x`).
class ThemeController extends ChangeNotifier with WidgetsBindingObserver {
  ThemeController._() {
    // Observe — don't overwrite — so Flutter's own brightness tracking
    // (needed for ThemeMode.system + MediaQuery) keeps working.
    WidgetsBinding.instance.addObserver(this);
  }
  static final ThemeController instance = ThemeController._();

  static const _kPrefKey = 'themeMode';

  ThemeMode _mode = ThemeMode.dark;
  ThemeMode get mode => _mode;

  /// The brightness actually in effect right now (resolves `system`).
  Brightness get effectiveBrightness {
    switch (_mode) {
      case ThemeMode.light:
        return Brightness.light;
      case ThemeMode.dark:
        return Brightness.dark;
      case ThemeMode.system:
        return PlatformDispatcher.instance.platformBrightness;
    }
  }

  /// Loads the persisted preference. Defaults to dark (the app's original look)
  /// when nothing is stored.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _mode = _decode(prefs.getString(_kPrefKey)) ?? ThemeMode.dark;
    } catch (_) {
      _mode = ThemeMode.dark;
    }
    LiquidColors.applyBrightness(effectiveBrightness);
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    LiquidColors.applyBrightness(effectiveBrightness);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefKey, _encode(mode));
    } catch (_) {}
  }

  @override
  void didChangePlatformBrightness() {
    if (_mode != ThemeMode.system) return;
    LiquidColors.applyBrightness(effectiveBrightness);
    notifyListeners();
  }

  static ThemeMode? _decode(String? raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return null;
    }
  }

  static String _encode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  static String label(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }
}
