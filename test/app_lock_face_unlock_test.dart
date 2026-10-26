import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_app/app_lock_screen/app_lock_screen.dart';
import 'package:video_player_app/app_lock_screen/widgets/liquid_action_button.dart';
import 'package:video_player_app/security_settings/face_scan_screen.dart';
import 'package:video_player_app/utils/face_recognition_service.dart';

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
    SharedPreferences.setMockInitialValues({'biometric': false});
    await enrollMockFace();
  });

  tearDown(() async {
    await FaceRecognitionService.instance.clearEnrollment();
  });

  testWidgets('FaceScanScreen is opened on launch when face is enrolled and falls back to PIN on cancel', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AppLockScreen()),
    );
    await tester.pump(); // frame 1
    await tester.pump(const Duration(milliseconds: 100)); // post frame
    await tester.pump(const Duration(milliseconds: 500)); // route transition

    // FaceScanScreen was opened
    expect(find.byType(FaceScanScreen), findsOneWidget);

    // Cancel / dismiss face scan screen
    final navState = tester.state<NavigatorState>(
      find.descendant(
        of: find.byType(MaterialApp),
        matching: find.byType(Navigator),
      ).first,
    );
    navState.pop(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Should fall back to PIN stage
    expect(find.text('Type your PIN to unlock the vault'), findsOneWidget);

    // "Unlock with Face" pill button was removed to keep PIN pad clean
    expect(find.text('Unlock with Face'), findsNothing);

    // Button 9 on keypad displays Face Scan icon
    expect(
      find.descendant(
        of: find.byType(LiquidActionButton),
        matching: find.byIcon(Icons.face_retouching_natural),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Keypad button 9 triggers FaceScanScreen when tapped', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AppLockScreen()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));

    // Pop the initial auto-prompt
    final navState = tester.state<NavigatorState>(
      find.descendant(
        of: find.byType(MaterialApp),
        matching: find.byType(Navigator),
      ).first,
    );
    navState.pop(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Scroll to and tap button 9 on keypad
    final btn9 = find.descendant(
      of: find.byType(LiquidActionButton),
      matching: find.byIcon(Icons.face_retouching_natural),
    );
    expect(btn9, findsOneWidget);
    await tester.ensureVisible(btn9);
    await tester.tap(btn9);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(FaceScanScreen), findsOneWidget);
  });

  testWidgets('Successful Face Scan unlocks the app', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AppLockScreen(isOverlay: true)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(FaceScanScreen), findsOneWidget);

    // Simulate successful face scan
    final navState = tester.state<NavigatorState>(
      find.descendant(
        of: find.byType(MaterialApp),
        matching: find.byType(Navigator),
      ).first,
    );
    navState.pop(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // AppLockScreen overlay is popped upon successful unlock
    expect(find.byType(AppLockScreen), findsNothing);
  });
}
