import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_app/security_settings/security_setting.dart';
import 'package:video_player_app/utils/face_recognition_service.dart';
import 'package:video_player_app/utils/pin_crypto.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> enrollMockFace() async {
    const len = 166;
    final baseVector = List<double>.generate(len, (i) => (i % 10) * 0.1);
    final samples = List.generate(
      FaceRecognitionService.enrollSamples,
      (sIdx) => List<double>.generate(len, (i) => baseVector[i] + (sIdx * 0.005)),
    );
    await FaceRecognitionService.instance.enroll(samples);
  }

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({
      'hasOnboarded': true,
      'appLock': true,
      'biometric': false,
      'biometric_face': true,
    });
    await PinCrypto.instance.setPin('1234');
    await enrollMockFace();
  });

  tearDown(() async {
    await FaceRecognitionService.instance.clearEnrollment();
  });

  Finder findFaceRecognitionSwitch() {
    return find.descendant(
      of: find.ancestor(
        of: find.text('In-app face unlock is enrolled'),
        matching: find.byType(Row),
      ),
      matching: find.byType(Switch),
    );
  }

  testWidgets(
    'Turn off Face Recognition dialog: Cancel button dismisses dialog cleanly without crashing',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SecuritySettingsScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final faceSwitch = findFaceRecognitionSwitch();
      expect(faceSwitch, findsOneWidget);
      await tester.ensureVisible(faceSwitch);

      // Toggle switch OFF
      await tester.tap(faceSwitch);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Confirmation dialog should be visible
      expect(find.text('Turn off Face Recognition?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Verify & turn off'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Dialog should be dismissed, and SecuritySettingsScreen is still mounted and intact
      expect(find.text('Turn off Face Recognition?'), findsNothing);
      expect(find.byType(SecuritySettingsScreen), findsOneWidget);
      expect(await FaceRecognitionService.instance.isEnrolled(), isTrue);
    },
  );

  testWidgets(
    'Turn off Face Recognition dialog: Verify & turn off opens PIN dialog and turns off on PIN entry',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SecuritySettingsScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final faceSwitch = findFaceRecognitionSwitch();
      expect(faceSwitch, findsOneWidget);
      await tester.ensureVisible(faceSwitch);

      // Toggle switch OFF
      await tester.tap(faceSwitch);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Turn off Face Recognition?'), findsOneWidget);

      // Tap "Verify & turn off"
      await tester.tap(find.text('Verify & turn off'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Should prompt for PIN via PinUnlockDialog
      expect(find.text('Verify your PIN to turn off Face Recognition'), findsOneWidget);

      // Enter correct PIN: '1', '2', '3', '4' inside PinUnlockDialog
      for (final digit in ['1', '2', '3', '4']) {
        final keyBtn = find.widgetWithText(InkWell, digit);
        expect(keyBtn, findsOneWidget);
        await tester.tap(keyBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Wait for real async isolate PBKDF2 calculation
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 1500));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Enrollment should now be cleared
      expect(await FaceRecognitionService.instance.isEnrolled(), isFalse);
    },
  );
}
