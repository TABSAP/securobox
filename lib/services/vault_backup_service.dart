import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/export.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:video_player_app/models/app_models.dart';
import 'package:video_player_app/services/media_service.dart';
import 'package:video_player_app/utils/pbkdf2.dart';
import 'package:video_player_app/utils/vault_context.dart';
import 'package:video_player_app/utils/vault_crypto.dart';

class VaultBackupService {
  VaultBackupService._();
  static final instance = VaultBackupService._();

  static const _magic = [0x53, 0x42, 0x58, 0x42, 0x41, 0x4b, 0x31, 0x00];
  static const _saltLength = 16;
  static const _ivLength = 16;
  static const _tagLength = 32;
  static const _iterations = 180000;
  static const _maxBackupBytes = 128 * 1024 * 1024;

  Future<int> get itemCount async {
    final p = await SharedPreferences.getInstance();
    return (p.getStringList(VaultContext.instance.libraryKey) ?? const [])
        .length;
  }

  Future<Uint8List> createBackup(String passphrase) async {
    _checkPassphrase(passphrase);
    final prefs = await SharedPreferences.getInstance();
    final rows = prefs.getStringList(VaultContext.instance.libraryKey) ?? [];
    final zip = Archive();
    final records = <Map<String, String>>[];
    var totalBytes = 0;
    for (var i = 0; i < rows.length; i++) {
      final item = VideoItem.fromStorageString(rows[i]);
      final stored = File(item.path);
      if (!await stored.exists()) {
        throw StateError('A vault file is missing: ${item.title}');
      }
      final plainPath = item.encrypted
          ? await VaultCrypto.instance.decryptToTemp(
              item.path,
              formatVersion: item.encryptionVersion,
            )
          : item.path;
      final plainFile = File(plainPath);
      totalBytes += await plainFile.length();
      if (totalBytes > _maxBackupBytes) {
        throw StateError('Backup is larger than the 128 MB supported limit.');
      }
      final bytes = await plainFile.readAsBytes();
      final payloadName = 'payload/$i.bin';
      zip.addFile(ArchiveFile(payloadName, bytes.length, bytes));
      records.add({'record': rows[i], 'payload': payloadName});
    }
    final manifest = utf8.encode(
      jsonEncode({
        'format': 1,
        'created': DateTime.now().toUtc().toIso8601String(),
        'decoy': VaultContext.instance.isDecoy,
        'customCategories':
            prefs.getStringList(VaultContext.instance.customCategoriesKey) ??
            [],
        'categoriesConfig': prefs.getString(
          VaultContext.instance.categoriesConfigKey,
        ),
        'lockedCategories':
            prefs.getStringList(
              VaultContext.instance.isDecoy
                  ? 'lockedCategories_decoy'
                  : 'lockedCategories',
            ) ??
            [],
        'records': records,
      }),
    );
    zip.addFile(ArchiveFile('manifest.json', manifest.length, manifest));
    final zipBytes = ZipEncoder().encode(zip);
    return sealAsync(Uint8List.fromList(zipBytes), passphrase);
  }

  Future<int> restoreBackup(Uint8List container, String passphrase) async {
    _checkPassphrase(passphrase);
    return restoreBackupWithPassword(container, passphrase);
  }

  Future<Uint8List> sealAsync(Uint8List plaintext, String passphrase) async {
    final random = Random.secure();
    final salt = Uint8List.fromList(
      List.generate(_saltLength, (_) => random.nextInt(256)),
    );
    final iv = Uint8List.fromList(
      List.generate(_ivLength, (_) => random.nextInt(256)),
    );
    final derived = await pbkdf2(
      Uint8List.fromList(utf8.encode(passphrase)),
      salt,
      _iterations,
      64,
    );
    final cipher = CTRStreamCipher(AESEngine())
      ..init(
        true,
        ParametersWithIV<KeyParameter>(
          KeyParameter(Uint8List.sublistView(derived, 0, 32)),
          iv,
        ),
      );
    final ciphertext = cipher.process(plaintext);
    final header = Uint8List.fromList([..._magic, ...salt, ...iv]);
    final authenticated = Uint8List.fromList([...header, ...ciphertext]);
    final mac = HMac(SHA256Digest(), 64)
      ..init(KeyParameter(Uint8List.sublistView(derived, 32, 64)));
    final tag = mac.process(authenticated);
    return Uint8List.fromList([...authenticated, ...tag]);
  }

  Future<Uint8List> unsealAsync(Uint8List data, String passphrase) async {
    final headerLength = _magic.length + _saltLength + _ivLength;
    if (data.length < headerLength + _tagLength || !_startsWith(data, _magic)) {
      throw const FormatException('This is not a SecuroBox backup.');
    }
    final salt = Uint8List.sublistView(
      data,
      _magic.length,
      _magic.length + _saltLength,
    );
    final ivStart = _magic.length + _saltLength;
    final iv = Uint8List.sublistView(data, ivStart, ivStart + _ivLength);
    final bodyEnd = data.length - _tagLength;
    final derived = await pbkdf2(
      Uint8List.fromList(utf8.encode(passphrase)),
      salt,
      _iterations,
      64,
    );
    final mac = HMac(SHA256Digest(), 64)
      ..init(KeyParameter(Uint8List.sublistView(derived, 32, 64)));
    final expected = mac.process(Uint8List.sublistView(data, 0, bodyEnd));
    if (!_constantTimeEqual(expected, Uint8List.sublistView(data, bodyEnd))) {
      throw const FormatException('Wrong passphrase or damaged backup.');
    }
    final cipher = CTRStreamCipher(AESEngine())
      ..init(
        true,
        ParametersWithIV<KeyParameter>(
          KeyParameter(Uint8List.sublistView(derived, 0, 32)),
          iv,
        ),
      );
    return cipher.process(Uint8List.sublistView(data, headerLength, bodyEnd));
  }

  Future<int> restoreBackupWithPassword(
    Uint8List bytes,
    String passphrase,
  ) async => _restoreDecrypted(await unsealAsync(bytes, passphrase));

  Future<int> _restoreDecrypted(Uint8List zipBytes) async {
    final archive = ZipDecoder().decodeBytes(zipBytes, verify: true);
    final manifestFile = archive.findFile('manifest.json');
    if (manifestFile == null) throw const FormatException('Missing manifest.');
    final manifest = jsonDecode(utf8.decode(manifestFile.content as List<int>));
    if (manifest is! Map ||
        manifest['format'] != 1 ||
        manifest['records'] is! List) {
      throw const FormatException('Unsupported backup format.');
    }
    if (manifest['decoy'] != VaultContext.instance.isDecoy) {
      throw const FormatException('This backup belongs to a different vault.');
    }
    final staged = <(VideoItem, Uint8List)>[];
    for (final entry in manifest['records'] as List) {
      if (entry is! Map ||
          entry['record'] is! String ||
          entry['payload'] is! String) {
        throw const FormatException('Invalid backup record.');
      }
      final payload = archive.findFile(entry['payload'] as String);
      if (payload == null) {
        throw const FormatException('Missing media payload.');
      }
      staged.add((
        VideoItem.fromStorageString(entry['record'] as String),
        Uint8List.fromList(payload.content as List<int>),
      ));
    }
    final prefs = await SharedPreferences.getInstance();
    final key = VaultContext.instance.libraryKey;
    final rows = List<String>.from(prefs.getStringList(key) ?? const []);
    final ids = rows.map((r) => VideoItem.fromStorageString(r).id).toSet();
    final created = <String>[];
    final tmpDir = await getTemporaryDirectory();
    try {
      for (var i = 0; i < staged.length; i++) {
        final (item, bytes) = staged[i];
        final tmp = File(
          p.join(
            tmpDir.path,
            'sb_restore_${DateTime.now().microsecondsSinceEpoch}_$i${p.extension(item.title)}',
          ),
        );
        await tmp.writeAsBytes(bytes, flush: true);
        try {
          final stored = await VaultCrypto.instance.importEncrypted(tmp);
          created.add(stored);
          var restored = item.copyWith(
            path: stored,
            encrypted: true,
            encryptionVersion: 1,
            inGallery: false,
            galleryId: '',
          );
          if (ids.contains(restored.id)) {
            restored = restored.copyWith(id: '${restored.id}_restored_$i');
          }
          ids.add(restored.id);
          rows.add(restored.toStorageString());
        } finally {
          if (await tmp.exists()) await tmp.delete();
        }
      }
      final customCategories = manifest['customCategories'];
      if (customCategories is List &&
          customCategories.every((e) => e is String)) {
        await prefs.setStringList(
          VaultContext.instance.customCategoriesKey,
          customCategories.cast<String>(),
        );
      }
      if (manifest['categoriesConfig'] is String) {
        await prefs.setString(
          VaultContext.instance.categoriesConfigKey,
          manifest['categoriesConfig'] as String,
        );
      }
      final lockedCategories = manifest['lockedCategories'];
      if (lockedCategories is List &&
          lockedCategories.every((e) => e is String)) {
        await prefs.setStringList(
          VaultContext.instance.isDecoy
              ? 'lockedCategories_decoy'
              : 'lockedCategories',
          lockedCategories.cast<String>(),
        );
      }
      await prefs.setStringList(key, rows);
      MediaService.notifyChanged();
      return staged.length;
    } catch (_) {
      for (final path in created) {
        try {
          final f = File(path);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  static bool _startsWith(Uint8List data, List<int> prefix) {
    if (data.length < prefix.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (data[i] != prefix[i]) return false;
    }
    return true;
  }

  static bool _constantTimeEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  static void _checkPassphrase(String passphrase) {
    if (passphrase.trim().length < 10) {
      throw ArgumentError('Use a passphrase with at least 10 characters.');
    }
  }
}
