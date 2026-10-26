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
      await tester.pumpWidget(
        const MaterialApp(
          home: MainScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Should be on HomeDashboard (Library) initially
      expect(find.byType(HomeDashboard), findsOneWidget);

      final libraryNavBtn = find.descendant(
        of: find.byType(LiquidBottomNav),
        matching: find.text('Library'),
      );
      final settingsNavBtn = find.descendant(
        of: find.byType(LiquidBottomNav),
        matching: find.text('Settings'),
      );

      // Push a dummy subpage inside Library navigator
      final libraryNav = tester.state<NavigatorState>(
        find.descendant(
          of: find.byType(MainScreen),
          matching: find.byType(Navigator),
        ).first,
      );
      libraryNav.push(
        MaterialPageRoute(
          builder: (_) => const Scaffold(body: Center(child: Text('Library Subpage'))),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Library Subpage'), findsOneWidget);

      // Now tap Library on bottom nav: it should pop the subpage and return directly to HomeDashboard!
      await tester.tap(libraryNavBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Library Subpage'), findsNothing);
      expect(find.byType(HomeDashboard), findsOneWidget);

      // Tap on Settings tab
      await tester.tap(settingsNavBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(SettingsScreen), findsOneWidget);

      // Push a dummy subpage inside Settings navigator
      final settingsNav = tester.state<NavigatorState>(
        find.descendant(
          of: find.byType(MainScreen),
          matching: find.byType(Navigator),
        ).last,
      );
      settingsNav.push(
        MaterialPageRoute(
          builder: (_) => const Scaffold(body: Center(child: Text('Settings Subpage'))),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Settings Subpage'), findsOneWidget);

      // While on Settings Subpage, tap Library on bottom nav:
      // It should pop Settings subpage and land directly on Library root!
      await tester.tap(libraryNavBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Settings Subpage'), findsNothing);
      expect(find.byType(HomeDashboard), findsOneWidget);

      // Switch back to Settings: it should be at root SettingsScreen, NOT the subpage!
      await tester.tap(settingsNavBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Settings Subpage'), findsNothing);
      expect(find.byType(SettingsScreen), findsOneWidget);
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

      // Renders Library and Settings
      expect(find.text('Library'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);

      // Verify active library icon is video_library_rounded and inactive is settings_outlined
      expect(find.byIcon(Icons.video_library_rounded), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

      // Verify it does NOT render the floating ClipRRect with borderRadius 27 or BackdropFilter
      expect(find.byType(BackdropFilter), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
