import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'liquid_colors.dart';

class ThemeController extends ChangeNotifier with WidgetsBindingObserver {
  ThemeController._() {
    WidgetsBinding.instance.addObserver(this);
  }
  static final ThemeController instance = ThemeController._();

  static const _kPrefKey = 'themeMode';
  static const _kGlassIntensityPrefKey = 'glassIntensity';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  final ValueNotifier<double> glassIntensityListenable = ValueNotifier(1.0);
  Timer? _glassIntensitySaveTimer;
  double get glassIntensity => glassIntensityListenable.value;

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

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _mode = _decode(prefs.getString(_kPrefKey)) ?? ThemeMode.system;
      glassIntensityListenable.value =
          (prefs.getDouble(_kGlassIntensityPrefKey) ?? 1.0).clamp(0.0, 1.0);
    } catch (_) {
      _mode = ThemeMode.system;
      glassIntensityListenable.value = 1.0;
    }
    LiquidColors.applyBrightness(effectiveBrightness);
  }

  void setGlassIntensity(double value) {
    final normalized = value.clamp(0.0, 1.0).toDouble();
    if ((normalized - glassIntensity).abs() < 0.001) return;
    glassIntensityListenable.value = normalized;

    _glassIntensitySaveTimer?.cancel();
    _glassIntensitySaveTimer = Timer(
      const Duration(milliseconds: 250),
      () async {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setDouble(_kGlassIntensityPrefKey, glassIntensity);
        } catch (_) {}
      },
    );
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
