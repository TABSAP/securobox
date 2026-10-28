import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_app/models/app_models.dart';
import 'package:video_player_app/utils/file_type_registry.dart';
import 'package:video_player_app/utils/pbkdf2.dart';
import 'package:video_player_app/utils/title_helper.dart';
import 'package:video_player_app/utils/thumbnail_cache.dart';
import 'package:video_player_app/utils/vault_context.dart';
import 'package:video_player_app/utils/vault_crypto.dart';

class LockerImportResult {
  const LockerImportResult({required this.added, required this.failed});
  final int added;
  final int failed;
}

class LockerLoadResult {
  const LockerLoadResult({
    required this.items,
    required this.invalidRecords,
    required this.missingFiles,
  });

  final List<VideoItem> items;
  final int invalidRecords;
  final int missingFiles;
}

class PrivateLockerService {
  PrivateLockerService._();
  static final instance = PrivateLockerService._();

  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  static const _iterations = 100000;

  @visibleForTesting
  static bool isValidPinFormat(String pin) => RegExp(r'^\d{6}$').hasMatch(pin);

  @visibleForTesting
  static bool isSupportedMediaType(String type) =>
      type == 'image' || type == 'video';

  @visibleForTesting
  static bool isPathInsideLocker(String path, String lockerRoot) {
    final normalizedRoot = p.normalize(p.absolute(lockerRoot));
    final normalizedPath = p.normalize(p.absolute(path));
    return p.isWithin(normalizedRoot, normalizedPath);
  }

  String get _suffix => VaultContext.instance.isDecoy ? '_decoy' : '';
  String get _enabledKey => 'privateLockerEnabled$_suffix';
  String get _itemsKey => 'privateLockerItems$_suffix';
  String get _hashKey => 'private_locker_pin_hash_v1$_suffix';
  String get _saltKey => 'private_locker_pin_salt_v1$_suffix';
  String get _iterationsKey => 'private_locker_pin_iterations_v1$_suffix';
  String get _failedAttemptsKey => 'privateLockerFailedAttempts$_suffix';
  String get _lockoutUntilKey => 'privateLockerLockoutUntil$_suffix';

  Future<bool> isEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_enabledKey) ?? false;

  Future<bool> isConfigured() async =>
      (await _secure.read(key: _hashKey)) != null;

  Future<void> configure(String pin) async {
    if (!isValidPinFormat(pin)) {
      throw ArgumentError('Private Locker PIN must contain six digits.');
    }
    final random = Random.secure();
    final salt = Uint8List.fromList(
      List<int>.generate(16, (_) => random.nextInt(256)),
    );
    final hash = await pbkdf2(
      Uint8List.fromList(utf8.encode(pin)),
      salt,
      _iterations,
      32,
    );
    final prefs = await SharedPreferences.getInstance();
    final keys = (_saltKey, _hashKey, _iterationsKey);
    final oldSalt = await _secure.read(key: keys.$1);
    final oldHash = await _secure.read(key: keys.$2);
    final oldIterations = await _secure.read(key: keys.$3);
    final wasEnabled = prefs.getBool(_enabledKey) ?? false;
    try {
      await _secure.write(key: keys.$1, value: base64Encode(salt));
      await _secure.write(key: keys.$2, value: base64Encode(hash));
      await _secure.write(key: keys.$3, value: '$_iterations');
      await _secure.delete(key: _failedAttemptsKey);
      await _secure.delete(key: _lockoutUntilKey);
      if (!await prefs.setBool(_enabledKey, true)) {
        throw StateError('Could not enable Private Locker.');
      }
    } catch (_) {
      await _restoreSecureValue(keys.$1, oldSalt);
      await _restoreSecureValue(keys.$2, oldHash);
      await _restoreSecureValue(keys.$3, oldIterations);
      try {
        await prefs.setBool(_enabledKey, wasEnabled);
      } catch (_) {}
      rethrow;
    }
  }

  Future<bool> verifyPin(String pin) async {
    final keys = (_saltKey, _hashKey, _iterationsKey);
    final lockoutValue = await _secure.read(key: _lockoutUntilKey);
    final lockoutUntil = int.tryParse(lockoutValue ?? '') ?? 0;
    if (DateTime.now().millisecondsSinceEpoch < lockoutUntil) return false;
    if (!isValidPinFormat(pin)) return _recordFailedAttempt();
    final saltValue = await _secure.read(key: keys.$1);
    final hashValue = await _secure.read(key: keys.$2);
    if (saltValue == null || hashValue == null) {
      throw const FormatException('Locker credentials are incomplete.');
    }
    final Uint8List salt;
    final Uint8List expected;
    try {
      salt = base64Decode(saltValue);
      expected = base64Decode(hashValue);
    } on FormatException {
      throw const FormatException('Locker credentials are damaged.');
    }
    if (salt.length != 16 || expected.length != 32) {
      throw const FormatException('Locker credentials are damaged.');
    }
    final iterationsValue = await _secure.read(key: keys.$3);
    final iterations = int.tryParse(iterationsValue ?? '') ?? _iterations;
    if (iterations < _iterations || iterations > 1000000) {
      throw const FormatException('Locker credentials are invalid.');
    }
    final candidate = await pbkdf2(
      Uint8List.fromList(utf8.encode(pin)),
      salt,
      iterations,
      expected.length,
    );
    if (candidate.length != expected.length) return false;
    var difference = 0;
    for (var i = 0; i < expected.length; i++) {
      difference |= expected[i] ^ candidate[i];
    }
    if (difference == 0) {
      await _secure.delete(key: _failedAttemptsKey);
      await _secure.delete(key: _lockoutUntilKey);
      return true;
    }
    return _recordFailedAttempt();
  }

  Future<bool> _recordFailedAttempt() async {
    final attemptValue = await _secure.read(key: _failedAttemptsKey);
    final attempts = (int.tryParse(attemptValue ?? '') ?? 0) + 1;
    if (attempts >= 5) {
      await _secure.write(key: _failedAttemptsKey, value: '0');
      await _secure.write(
        key: _lockoutUntilKey,
        value: DateTime.now()
            .add(const Duration(seconds: 30))
            .millisecondsSinceEpoch
            .toString(),
      );
    } else {
      await _secure.write(key: _failedAttemptsKey, value: attempts.toString());
    }
    return false;
  }

  Future<void> _restoreSecureValue(String key, String? value) async {
    try {
      if (value == null) {
        await _secure.delete(key: key);
      } else {
        await _secure.write(key: key, value: value);
      }
    } catch (_) {}
  }

  Future<LockerLoadResult> loadItems() async {
    final prefs = await SharedPreferences.getInstance();
    final rows = prefs.getStringList(_itemsKey) ?? const <String>[];
    final documents = await getApplicationDocumentsDirectory();
    final lockerRoot = p.normalize(
      p.join(
        documents.path,
        VaultContext.instance.vaultDirName,
        'private_locker',
      ),
    );
    final items = <VideoItem>[];
    var invalidRecords = 0;
    var missingFiles = 0;
    for (final row in rows) {
      try {
        final item = VideoItem.fromStorageString(row);
        if (item.isDeleted) continue;
        final normalizedPath = p.normalize(item.path);
        final insideLocker = isPathInsideLocker(normalizedPath, lockerRoot);
        if (!insideLocker ||
            !item.encrypted ||
            !isSupportedMediaType(item.type)) {
          invalidRecords++;
          continue;
        }
        final entityType = await FileSystemEntity.type(
          normalizedPath,
          followLinks: false,
        );
        if (entityType == FileSystemEntityType.link) {
          invalidRecords++;
          continue;
        }
        if (entityType != FileSystemEntityType.file) {
          missingFiles++;
          continue;
        }
        items.add(item);
      } catch (_) {
        invalidRecords++;
      }
    }
    items.sort((a, b) => b.id.compareTo(a.id));
    return LockerLoadResult(
      items: items,
      invalidRecords: invalidRecords,
      missingFiles: missingFiles,
    );
  }

  Future<void> clearSessionPreviews(List<VideoItem> items) async {
    for (final item in items) {
      final preview = ThumbnailCache.instance.peek(item.id);
      ThumbnailCache.instance.remove(item.id);
      if (preview != null) {
        try {
          if (await preview.exists()) await preview.delete();
        } catch (_) {}
      }
      if (item.encrypted) {
        await VaultCrypto.instance.forgetCachedPlaintext(item.path);
      }
    }
  }

  Future<LockerImportResult> importFiles(List<File> sources) async {
    final prefs = await SharedPreferences.getInstance();
    final oldRows = List<String>.from(
      prefs.getStringList(_itemsKey) ?? const [],
    );
    final rows = List<String>.from(oldRows);
    final createdPaths = <String>[];
    var failed = 0;

    for (var index = 0; index < sources.length; index++) {
      final source = sources[index];
      String? createdPath;
      try {
        if (!await source.exists()) {
          throw const FileSystemException('Missing source');
        }
        final type = FileTypeRegistry.storageTypeForPath(source.path);
        if (!isSupportedMediaType(type)) {
          failed++;
          continue;
        }
        final encryptedPath = await VaultCrypto.instance.importEncrypted(
          source,
          subdir: 'private_locker',
        );
        createdPath = encryptedPath;
        createdPaths.add(encryptedPath);
        final id = '${DateTime.now().microsecondsSinceEpoch}_$index';
        final title = TitleHelper.originalName(
          source.uri.pathSegments.isEmpty
              ? source.path
              : source.uri.pathSegments.last,
          type: type,
        );
        rows.add(
          VideoItem(
            id: id,
            title: title,
            path: encryptedPath,
            type: type,
            category: type == 'image' ? 'Photos' : 'Videos',
            encrypted: true,
            encryptionVersion: 1,
            origin: 'private_locker',
          ).toStorageString(),
        );
      } catch (_) {
        if (createdPath != null) {
          createdPaths.remove(createdPath);
          await VaultCrypto.instance.deleteEncryptedFile(createdPath);
        }
        failed++;
      }
    }

    try {
      if (createdPaths.isNotEmpty &&
          !await prefs.setStringList(_itemsKey, rows)) {
        throw StateError('Could not save Private Locker records.');
      }
    } catch (_) {
      for (final path in createdPaths) {
        await VaultCrypto.instance.deleteEncryptedFile(path);
      }
      rethrow;
    }

    return LockerImportResult(
      added: rows.length - oldRows.length,
      failed: failed,
    );
  }
}
