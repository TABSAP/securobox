import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_app/main_screen.dart';
import 'package:video_player_app/views/screens/home_screen/home_dashboard.dart';
import 'package:video_player_app/settings/settings_screen.dart';
import 'package:video_player_app/widgets/liquid_bottom_nav.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'hasOnboarded': true});
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'Tapping Library or Settings bottom nav item navigates directly to root screen from anywhere, popping subpages',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await tester.pumpWidget(const MaterialApp(home: MainScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(HomeDashboard), findsOneWidget);

      final libraryNavBtn = find.descendant(
        of: find.byType(LiquidBottomNav),
        matching: find.text('Library'),
      );
      final settingsNavBtn = find.descendant(
        of: find.byType(LiquidBottomNav),
        matching: find.text('Settings'),
      );

      final libraryNav = tester.state<NavigatorState>(
        find
            .descendant(
              of: find.byType(MainScreen),
              matching: find.byType(Navigator),
            )
            .first,
      );
      libraryNav.push(
        MaterialPageRoute(
          builder: (_) =>
              const Scaffold(body: Center(child: Text('Library Subpage'))),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Library Subpage'), findsOneWidget);

      await tester.tap(libraryNavBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Library Subpage'), findsNothing);
      expect(find.byType(HomeDashboard), findsOneWidget);

      await tester.tap(settingsNavBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(SettingsScreen), findsOneWidget);

      final settingsNav = tester.state<NavigatorState>(
        find
            .descendant(
              of: find.byType(MainScreen),
              matching: find.byType(Navigator),
            )
            .last,
      );
      settingsNav.push(
        MaterialPageRoute(
          builder: (_) =>
              const Scaffold(body: Center(child: Text('Settings Subpage'))),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Settings Subpage'), findsOneWidget);

      await tester.tap(libraryNavBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Settings Subpage'), findsNothing);
      expect(find.byType(HomeDashboard), findsOneWidget);

      await tester.tap(settingsNavBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Settings Subpage'), findsNothing);
      expect(find.byType(SettingsScreen), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'Android side renders simple, docked professional bottom navigation bar without floating card margins',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            bottomNavigationBar: LiquidBottomNav(selectedIndex: 0),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Library'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);

      expect(find.byIcon(Icons.video_library_rounded), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

      expect(find.byType(BackdropFilter), findsNothing);
      expect(
        tester.getRect(find.byType(LiquidBottomNav)).bottom,
        tester.view.physicalSize.height / tester.view.devicePixelRatio,
      );
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
