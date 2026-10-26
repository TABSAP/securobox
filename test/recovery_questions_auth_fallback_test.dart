import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_app/app_lock_screen/app_lock_screen.dart';
import 'package:video_player_app/security_settings/security_setting.dart';
import 'package:video_player_app/utils/face_recognition_service.dart';
import 'package:video_player_app/utils/pin_crypto.dart';
import 'package:video_player_app/widgets/pin_unlock_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({
      'biometric': false,
      'biometric_face': false,
      'appLock': true,
      'recovery_setup_complete': true,
    });
    await PinCrypto.instance.setPin('1234');
  });

  tearDown(() async {
    await FaceRecognitionService.instance.clearEnrollment();
  });

  testWidgets('When fingerprint is disabled, tapping Recovery questions prompts for PIN directly', (tester) async {
    SharedPreferences.setMockInitialValues({
      'biometric': false,
      'biometric_face': false,
      'appLock': true,
      'recovery_setup_complete': true,
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: SecuritySettingsScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Scroll until "Recovery questions" is visible
    final recoveryTile = find.text('Recovery questions');
    await tester.scrollUntilVisible(
      recoveryTile,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(recoveryTile, findsOneWidget);

    // Tap Recovery questions
    await tester.tap(recoveryTile);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // PinUnlockDialog should be displayed directly (asking for PIN, NOT fingerprint)
    expect(find.byType(PinUnlockDialog), findsOneWidget);
    expect(find.text('Confirm with PIN'), findsOneWidget);
    expect(find.text('Enter your app PIN to change recovery questions'), findsOneWidget);
  });

  testWidgets('When both biometric and face unlock are disabled, AppLockScreen opens directly with PIN pad', (tester) async {
    SharedPreferences.setMockInitialValues({
      'biometric': false,
      'biometric_face': false,
      'appLock': true,
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: AppLockScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));

    // Directly shows PIN entry UI
    expect(find.text('Type your PIN to unlock the vault'), findsOneWidget);
  });
}
