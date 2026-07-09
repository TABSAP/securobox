import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:video_player_app/utils/decoy_service.dart';
import 'package:video_player_app/utils/media_importer.dart';
import 'package:video_player_app/utils/disguise_service.dart';
import 'package:video_player_app/utils/network_guard.dart';
import 'package:video_player_app/utils/notification_service.dart';
import 'package:video_player_app/utils/pbkdf2.dart';
import 'package:video_player_app/utils/screen_security.dart';
import 'package:video_player_app/utils/session_manager.dart';
import 'package:video_player_app/utils/theme_controller.dart';
import 'package:video_player_app/utils/vault_crypto.dart';
import 'package:video_player_app/share_import/share_intake.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Draw edge-to-edge: content extends cleanly behind the status/navigation
  // bars for a seamless top (no grey status-bar band).
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  await ScreenSecurity.init();

  await ThemeController.instance.init();

  await SessionManager.instance.init();

  await NetworkGuard.instance.init();

  unawaited(NotificationService.instance.init());

  // Clean up any fake decoy content seeded by earlier builds (runs once).
  unawaited(DecoyService.instance.purgeSeededDecoyData());

  // Fold any legacy Archives/Code/eBooks/Fonts items into Documents.
  unawaited(MediaImporter.instance.migrateLegacyDocumentTypes());

  unawaited(DisguiseService.instance.load());

  prewarmPbkdf2();

  unawaited(() async {
    try {
      final auth = LocalAuthentication();
      await auth.isDeviceSupported();
      await auth.canCheckBiometrics;
      await auth.getAvailableBiometrics();
    } catch (_) {}
  }());

  VaultCrypto.lastSelfTestResult = await VaultCrypto.instance.selfTest();

  unawaited(VaultCrypto.instance.wipeAllTempCache());

  // Start listening for files shared into the app (Android Sharesheet / iOS
  // Share Extension). Presentation is gated on the vault being unlocked.
  unawaited(ShareIntake.instance.init());

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const MyApp());
}