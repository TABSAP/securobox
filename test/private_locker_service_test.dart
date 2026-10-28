import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_app/security_settings/private_locker_screen.dart';
import 'package:video_player_app/services/private_locker_service.dart';
import 'package:video_player_app/utils/vault_context.dart';

void main() {
  setUp(() {
    VaultContext.instance.exitDecoy();
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('PIN format accepts exactly six digits', () {
    expect(PrivateLockerService.isValidPinFormat('123456'), isTrue);
    expect(PrivateLockerService.isValidPinFormat('12345'), isFalse);
    expect(PrivateLockerService.isValidPinFormat('1234567'), isFalse);
    expect(PrivateLockerService.isValidPinFormat('12a456'), isFalse);
  });

  test('media type and path validation reject unsafe locker records', () {
    expect(PrivateLockerService.isSupportedMediaType('image'), isTrue);
    expect(PrivateLockerService.isSupportedMediaType('video'), isTrue);
    expect(PrivateLockerService.isSupportedMediaType('document'), isFalse);

    final root = '${Directory.systemTemp.path}/vault/private_locker';
    expect(
      PrivateLockerService.isPathInsideLocker('$root/a.jpg.enc', root),
      isTrue,
    );
    expect(
      PrivateLockerService.isPathInsideLocker('$root/../outside.jpg.enc', root),
      isFalse,
    );
    expect(
      PrivateLockerService.isPathInsideLocker('${root}_evil/a.jpg.enc', root),
      isFalse,
    );
  });

  test(
    'PIN setup verifies correctly and throttles repeated failures',
    () async {
      final service = PrivateLockerService.instance;
      await service.configure('482619');

      expect(await service.isEnabled(), isTrue);
      expect(await service.isConfigured(), isTrue);
      expect(await service.verifyPin('482619'), isTrue);
      for (var attempt = 0; attempt < 5; attempt++) {
        expect(await service.verifyPin('000000'), isFalse);
      }
      expect(await service.verifyPin('482619'), isFalse);
    },
  );

  test('real and decoy lockers use separate PIN namespaces', () async {
    final service = PrivateLockerService.instance;
    await service.configure('135790');

    VaultContext.instance.enterDecoy();
    expect(await service.isEnabled(), isFalse);
    expect(await service.isConfigured(), isFalse);
    await service.configure('246801');
    expect(await service.verifyPin('246801'), isTrue);
    expect(await service.verifyPin('135790'), isFalse);

    VaultContext.instance.exitDecoy();
    expect(await service.verifyPin('135790'), isTrue);
    expect(await service.verifyPin('246801'), isFalse);
  });

  test('unsupported import is skipped without touching main library', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('videoLibrary', const ['existing-main-entry']);
    final temp = await Directory.systemTemp.createTemp('locker_test_');
    addTearDown(() => temp.delete(recursive: true));
    final source = File('${temp.path}/not_media.pdf')..writeAsStringSync('pdf');

    final result = await PrivateLockerService.instance.importFiles([source]);

    expect(result.added, 0);
    expect(result.failed, 1);
    expect(prefs.getStringList('privateLockerItems'), isNull);
    expect(prefs.getStringList('videoLibrary'), ['existing-main-entry']);
    expect(await source.exists(), isTrue);
  });

  testWidgets('first use explains private locker recovery limits', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PrivateLockerScreen()));
    await tester.pumpAndSettle();

    expect(find.text('A private space for selected media'), findsOneWidget);
    expect(find.text('Set up Private Locker'), findsOneWidget);
    expect(find.textContaining('PIN cannot be recovered'), findsOneWidget);
    expect(
      find.textContaining('not included in regular vault backups'),
      findsOneWidget,
    );
  });
}
