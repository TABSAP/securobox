import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:video_player_app/utils/disguise_service.dart';
import 'package:video_player_app/utils/network_guard.dart';
import 'package:video_player_app/utils/pbkdf2.dart';
import 'package:video_player_app/utils/screenshot_guard.dart';
import 'package:video_player_app/utils/session_manager.dart';
import 'package:video_player_app/utils/theme_controller.dart';
import 'package:video_player_app/utils/vault_crypto.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Apply screenshot / screen-recording protection (default blocked, user can allow from settings)
  await ScreenshotGuard.init();

  await ThemeController.instance.init();

  await SessionManager.instance.init();

  // Offline Integrity Lock — starts watching network interfaces immediately
  await NetworkGuard.instance.init();

  unawaited(DisguiseService.instance.load());

  // Prewarm PBKDF2 isolate for fast crypto operations
  prewarmPbkdf2();

  // Warm local_auth for faster first biometric prompt
  unawaited(() async {
    try {
      final auth = LocalAuthentication();
      await auth.isDeviceSupported();
      await auth.canCheckBiometrics;
      await auth.getAvailableBiometrics();
    } catch (_) {}
  }());

  // Self test vault crypto
  VaultCrypto.lastSelfTestResult = await VaultCrypto.instance.selfTest();

  // Lock orientation
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const MyApp());
}