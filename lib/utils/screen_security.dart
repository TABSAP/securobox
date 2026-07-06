import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenshot_blocker/flutter_screenshot_blocker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScreenSecurity {
  ScreenSecurity._();

  static const _kKey = 'screenshotBlock';
  static const MethodChannel _channel = MethodChannel(
    'secure_player/screen_security',
  );

  static final ValueNotifier<bool> enabled = ValueNotifier<bool>(true);
  static bool _handlerReady = false;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    enabled.value = prefs.getBool(_kKey) ?? true;
    _ensureHandler();
    await _apply(enabled.value);
  }

  static void _ensureHandler() {
    if (kIsWeb || !Platform.isIOS || _handlerReady) return;
    _handlerReady = true;
    _channel.setMethodCallHandler((call) async => null);
  }

  static Future<void> setEnabled(bool value) async {
    enabled.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kKey, value);
    await _apply(value);
  }

  static Future<void> _apply(bool value) async {
    if (kIsWeb) return;
    try {
      if (Platform.isAndroid) {
        if (value) {
          await FlutterScreenshotBlocker.enableScreenshotBlocking();
        } else {
          await FlutterScreenshotBlocker.disableScreenshotBlocking();
        }
      } else if (Platform.isIOS) {
        await _channel.invokeMethod<void>('setSecure', value);
      }
    } catch (_) {}
  }
}
