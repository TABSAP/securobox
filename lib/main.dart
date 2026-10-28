import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:video_player_app/ads/ad_service.dart';
import 'package:video_player_app/utils/decoy_service.dart';
import 'package:video_player_app/utils/media_importer.dart';
import 'package:video_player_app/utils/disguise_service.dart';
import 'package:video_player_app/utils/network_guard.dart';
import 'package:video_player_app/utils/notification_service.dart';
import 'package:video_player_app/utils/pin_crypto.dart';
import 'package:video_player_app/utils/pbkdf2.dart';
import 'package:video_player_app/utils/screen_security.dart';
import 'package:video_player_app/utils/session_manager.dart';
import 'package:video_player_app/utils/theme_controller.dart';
import 'package:video_player_app/utils/vault_crypto.dart';
import 'package:video_player_app/share_import/share_intake.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  await ScreenSecurity.init();

  await ThemeController.instance.init();

  await SessionManager.instance.init();

  await PinCrypto.instance.migrateLegacyPinOnStartup();

  await NetworkGuard.instance.init();

  unawaited(AdService.instance.initialize());

  unawaited(NotificationService.instance.init());

  unawaited(DecoyService.instance.purgeSeededDecoyData());

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

  unawaited(ShareIntake.instance.init());

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const MyApp());
}
