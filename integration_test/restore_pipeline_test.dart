import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:video_player_app/models/app_models.dart';
import 'package:video_player_app/services/media_service.dart';
import 'package:video_player_app/utils/vault_context.dart';

/// A real 1x1 JPEG. MediaStore must be able to index it.
const _jpeg1x1 =
    '/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRof'
    'Hh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAALCAABAAEBAREA/8QAFAAB'
    'AAAAAAAAAAAAAAAAAAAACf/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AVN//2Q==';

const _minimalPdf = '%PDF-1.4\n1 0 obj<</Type/Catalog>>endobj\ntrailer<</Root 1 0 R>>\n%%EOF\n';

/// Seeds a library entry so the removal half of the pipeline has something real
/// to delete, then returns the item.
Future<VideoItem> _seed(VideoItem item) async {
  final prefs = await SharedPreferences.getInstance();
  final key = VaultContext.instance.libraryKey;
  final list = List<String>.from(prefs.getStringList(key) ?? const <String>[]);
  list.add(item.toStorageString());
  await prefs.setStringList(key, list);
  return item;
}

Future<bool> _libraryHas(String id) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final rows = prefs.getStringList(VaultContext.instance.libraryKey) ?? const [];
  for (final row in rows) {
    try {
      if (VideoItem.fromStorageString(row).id == id) return true;
    } catch (_) {}
  }
  return false;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('photo restores to DCIM/Camera and is removed from the vault',
      (tester) async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final name = 'securobox_e2e_photo_$stamp.jpg';
    final tmp = await getTemporaryDirectory();
    final src = File('${tmp.path}/$name')
      ..writeAsBytesSync(base64Decode(_jpeg1x1));
    expect(src.existsSync(), isTrue);

    final item = await _seed(VideoItem(
      id: '$stamp',
      title: 'securobox_e2e_photo_$stamp',
      path: src.path,
      type: 'image',
      category: 'Photos',
      encrypted: false, // already plaintext; skip decryption
      origin: 'gallery',
      originAlbum: 'DCIM/Camera',
    ));
    expect(await _libraryHas(item.id), isTrue, reason: 'seed failed');

    final ok = await MediaService().restoreToDeviceAndRemove(
      item,
      src.path,
      name,
    );

    expect(ok, isTrue, reason: 'restoreToDeviceAndRemove returned false');
    expect(await _libraryHas(item.id), isFalse,
        reason: 'vault entry survived a successful restore');
    // Print for the adb-side verification step.
    // ignore: avoid_print
    print('E2E_PHOTO_NAME=$name');
  });

  testWidgets('document restores to Downloads and is removed from the vault',
      (tester) async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final name = 'securobox_e2e_doc_$stamp.pdf';
    final tmp = await getTemporaryDirectory();
    final src = File('${tmp.path}/$name')..writeAsStringSync(_minimalPdf);
    expect(src.existsSync(), isTrue);

    final item = await _seed(VideoItem(
      id: '$stamp',
      title: 'securobox_e2e_doc_$stamp',
      path: src.path,
      type: 'document',
      category: 'Documents',
      encrypted: false,
      origin: 'file',
    ));
    expect(await _libraryHas(item.id), isTrue, reason: 'seed failed');

    final ok = await MediaService().restoreToDeviceAndRemove(
      item,
      src.path,
      name,
    );

    expect(ok, isTrue, reason: 'document restore returned false');
    expect(await _libraryHas(item.id), isFalse,
        reason: 'vault entry survived a successful restore');
    // ignore: avoid_print
    print('E2E_DOC_NAME=$name');
  });

  testWidgets('failed restore keeps the vault copy (atomicity)', (tester) async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final item = await _seed(VideoItem(
      id: '$stamp',
      title: 'securobox_e2e_missing_$stamp',
      path: '/does/not/exist/file.jpg',
      type: 'image',
      category: 'Photos',
      encrypted: false,
    ));

    final ok = await MediaService().restoreToDeviceAndRemove(
      item,
      '/does/not/exist/file.jpg',
      'file.jpg',
    );

    expect(ok, isFalse, reason: 'a missing source must not report success');
    expect(await _libraryHas(item.id), isTrue,
        reason: 'a FAILED restore must never delete the vault copy');
  });
}
