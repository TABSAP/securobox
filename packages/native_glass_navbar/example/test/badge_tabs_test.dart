import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_glass_navbar/native_glass_navbar.dart';
import 'package:native_glass_navbar_example/badge_tabs.dart';

void main() {
  testWidgets('badge demo updates and clears per-tab values', (tester) async {
    // This widget-level test exercises the demo through its Flutter fallback,
    // without requiring a native iOS platform view.
    await tester.pumpWidget(const MaterialApp(home: BadgeTabsApp()));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);

    List<String?> badges() => tester
        .widget<NativeGlassNavBar>(find.byType(NativeGlassNavBar))
        .tabs
        .map((tab) => tab.badgeValue)
        .toList();

    expect(badges(), [null, '3', '!']);

    await tester.tap(find.text('Add message'));
    await tester.pumpAndSettle();
    expect(badges(), [null, '4', '!']);

    await tester.tap(find.text('Mark all read'));
    await tester.pumpAndSettle();
    expect(badges(), [null, null, '!']);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(badges(), [null, null, null]);
  });
}
