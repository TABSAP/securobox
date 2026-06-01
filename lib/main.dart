import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenshot_blocker/flutter_screenshot_blocker.dart';
import 'package:video_player_app/utils/disguise_service.dart';
import 'package:video_player_app/utils/network_guard.dart';
import 'package:video_player_app/utils/pbkdf2.dart';
import 'package:video_player_app/utils/session_manager.dart';
import 'package:video_player_app/utils/theme_controller.dart';
import 'package:video_player_app/utils/vault_crypto.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && Platform.isAndroid) {
    try {
      FlutterScreenshotBlocker.enableScreenshotBlocking();
    } on Object catch (_) { /* ignored */ }
  }

  await ThemeController.instance.init();

  await SessionManager.instance.init();

  // Offline Integrity Lock — starts watching network interfaces immediately
  // so the vault seals the moment the device is exposed to a network.
  await NetworkGuard.instance.init();

  unawaited(DisguiseService.instance.load());

  // Spawn the PBKDF2 worker isolate up front so the very first PIN create /
  // confirm / unlock hashes instantly instead of paying isolate-spawn latency.
  prewarmPbkdf2();

  VaultCrypto.lastSelfTestResult = await VaultCrypto.instance.selfTest();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const MyApp());
}
