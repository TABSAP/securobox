import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_app/onboarding_screen/onboarding_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'hasOnboarded': false});
  });

  testWidgets(
    'Welcome screen renders cleanly and transitions to length picker without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Welcome to SecuroBox'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text('AES-256 encryption for every file'), findsOneWidget);

      final buttonCenter = tester.getCenter(find.text('Get Started'));
      expect(buttonCenter.dy, greaterThan(700));

      await tester.tap(find.text('Get Started'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Set a Strong PIN'), findsOneWidget);
      expect(
        find.text('Choose your PIN length. Longer PINs are stronger.'),
        findsOneWidget,
      );
    },
  );
}
