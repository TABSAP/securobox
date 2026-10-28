import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:video_player_app/app_lock_screen/app_lock_screen.dart';
import 'package:video_player_app/main_screen.dart';
import 'package:video_player_app/onboarding_screen/onboarding_screen.dart';

class StartupRouter {
  StartupRouter._();

  static const _kSplashSeen = 'splash_seen_v1';

  static Future<bool> shouldShowSplash() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return !(prefs.getBool(_kSplashSeen) ?? false);
    } catch (_) {
      return false;
    }
  }

  static Future<void> markSplashSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kSplashSeen, true);
    } catch (_) {}
  }

  static Future<Widget> resolveStartScreen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasOnboarded = prefs.getBool('hasOnboarded') ?? false;
      final lockEnabled =
          (prefs.getBool('appLock') ?? false) ||
          (prefs.getBool('biometric') ?? false) ||
          (prefs.getBool('biometric_face') ?? false);
      if (!hasOnboarded) return const OnboardingScreen();
      return lockEnabled ? const AppLockScreen() : const MainScreen();
    } catch (_) {
      return const MainScreen();
    }
  }
}
