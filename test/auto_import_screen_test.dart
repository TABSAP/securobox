import 'dart:async';
import 'package:photo_manager/photo_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_app/security_settings/auto_import_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.fluttercandies/photo_manager');
  final media = {
    'data': [
      {'id': 'photo', 'type': 1, 'width': 100, 'height': 100, 'title': 'Photo'},
    ],
  };
  Future<Object?> Function(MethodCall)? scan;
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'autoImportRules': ['album'],
    });
    scan = (_) async => media;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'requestPermissionExtend':
              return PermissionState.authorized.index;
            case 'getAssetPathList':
              return {
                'data': [
                  {
                    'id': 'album',
                    'name': 'Camera',
                    'isAll': false,
                    'assetCount': 1,
                  },
                ],
              };
            case 'getAssetCountFromPath':
              return 1;
            case 'getAssetListPaged':
              return scan!(call);
            default:
              return null;
          }
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: AutoImportScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'disabling last album clears import selection and toggle stays usable',
    (tester) async {
      await open(tester);
      expect(find.text('Import 1 selected'), findsOneWidget);
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(find.text('0 selected'), findsOneWidget);
      expect(find.text('Import 1 selected'), findsNothing);
      expect(
        tester.widget<Switch>(find.byType(Switch).first).onChanged,
        isNotNull,
      );
      expect(
        (await SharedPreferences.getInstance()).getStringList(
          'autoImportRules',
        ),
        isEmpty,
      );
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(find.text('Import 1 selected'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'scan finishing after disabling album cannot restore stale items',
    (tester) async {
      final pending = Completer<Object?>();
      scan = (_) => pending.future;
      await open(tester);
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      pending.complete(media);
      await tester.pumpAndSettle();
      expect(find.text('0 selected'), findsOneWidget);
      expect(find.text('Import 1 selected'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('periodic scan respects manual deselection', (tester) async {
    await open(tester);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(find.text('Import 1 selected'), findsNothing);
    await tester.pump(const Duration(seconds: 46));
    await tester.pumpAndSettle();
    expect(find.text('Import 1 selected'), findsNothing);
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isFalse,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
