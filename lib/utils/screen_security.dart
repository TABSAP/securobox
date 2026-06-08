import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_screenshot_blocker/flutter_screenshot_blocker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScreenSecurity {
  ScreenSecurity._();

  static const _kKey = 'screenshotBlock';
  static final ValueNotifier<bool> enabled = ValueNotifier<bool>(true);

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    enabled.value = prefs.getBool(_kKey) ?? true;
    await _apply(enabled.value);
  }

  static Future<void> setEnabled(bool value) async {
    enabled.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kKey, value);
    await _apply(value);
  }

  static Future<void> _apply(bool value) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      if (value) {
        await FlutterScreenshotBlocker.enableScreenshotBlocking();
      } else {
        await FlutterScreenshotBlocker.disableScreenshotBlocking();
      }
    } catch (_) {
    }
  }
}
