import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_screenshot_blocker/flutter_screenshot_blocker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controls whether screenshots / screen recording are blocked in the app.
///
/// Blocked by default (the vault shows private content); the user can allow
/// screenshots from Settings. The preference persists; [init] applies it at
/// launch and [setEnabled] applies + saves a change at runtime.
class ScreenshotGuard {
  ScreenshotGuard._();

  static const _kKey = 'block_screenshots';

  static Future<bool> isBlocking() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kKey) ?? true; // blocked by default
  }

  static Future<void> setBlocking(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kKey, value);
    await _apply(value);
  }

  static Future<void> init() async {
    await _apply(await isBlocking());
  }

  static Future<void> _apply(bool blocking) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      if (blocking) {
        await FlutterScreenshotBlocker.enableScreenshotBlocking();
      } else {
        await FlutterScreenshotBlocker.disableScreenshotBlocking();
      }
    } on Object catch (_) {
      // Ignored — blocking is best-effort.
    }
  }
}
