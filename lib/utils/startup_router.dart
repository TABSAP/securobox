import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:video_player_app/app_lock_screen/app_lock_screen.dart';
import 'package:video_player_app/main_screen.dart';
import 'package:video_player_app/onboarding_screen/onboarding_screen.dart';

/// Decides what the app opens on, and whether the branded Splash Screen is
/// shown at all.
///
/// The splash is a *first-launch only* experience: once it has been seen, every
/// subsequent launch goes straight to the appropriate screen (onboarding, the
/// lock screen, or the vault) with no branded interstitial.
class StartupRouter {
  StartupRouter._();

  static const _kSplashSeen = 'splash_seen_v1';

  /// True only until the splash has been shown once on this device.
  static Future<bool> shouldShowSplash() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return !(prefs.getBool(_kSplashSeen) ?? false);
    } catch (_) {
      // If prefs are unavailable, don't block startup on the splash.
      return false;
    }
  }

  /// Records that the splash has been shown, so it never appears again.
  static Future<void> markSplashSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kSplashSeen, true);
    } catch (_) {}
  }

  /// The screen the app should actually open on, independent of the splash.
  static Future<Widget> resolveStartScreen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasOnboarded = prefs.getBool('hasOnboarded') ?? false;
      final lockEnabled = (prefs.getBool('appLock') ?? false) ||
          (prefs.getBool('biometric') ?? false) ||
          (prefs.getBool('biometric_face') ?? false);
      if (!hasOnboarded) return const OnboardingScreen();
      return lockEnabled ? const AppLockScreen() : const MainScreen();
    } catch (_) {
      return const MainScreen();
    }
  }
}
