import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_app/utils/vault_context.dart';

/// Manages the decoy ("fake") PIN and the decoy vault's auto-seeded content.
///
/// The fake PIN is hashed with the same PBKDF2-HMAC-SHA256 / 100k-iteration
/// scheme as the real PIN, so an attacker who somehow reads secure storage
/// can't tell which hash is the "real" one by the algorithm. It is stored
/// under separate keys, and the decoy vault uses a separate master key and a
/// separate on-disk directory — the two vaults are cryptographically isolated.
class DecoyService {
  DecoyService._();
  static final DecoyService instance = DecoyService._();

  static const _kFakeHash = 'decoy_pin_hash_v1';
  static const _kFakeSalt = 'decoy_pin_salt_v1';
  static const _kFakeLen = 'decoy_pin_len_v1';
  static const _kDuressLog = 'decoy_audit_v1';
  static const _kDecoyMasterKey = 'vault_master_key_decoy_v1';

  static const _iterations = 100000;
  static const _hashLengthBytes = 32;
  static const _saltLengthBytes = 16;

  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  Uint8List _randomBytes(int length) {
    final r = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => r.nextInt(256)),
    );
  }

  Uint8List _pbkdf2(
      Uint8List password, Uint8List salt, int iterations, int dkLen) {
    final hmac = Hmac(sha256, password);
    const blockSize = 32;
    final blocks = (dkLen / blockSize).ceil();
    final result = Uint8List(dkLen);
    int offset = 0;
    for (int i = 1; i <= blocks; i++) {
      final block = Uint8List(salt.length + 4)
        ..setRange(0, salt.length, salt)
        ..[salt.length] = (i >> 24) & 0xff
        ..[salt.length + 1] = (i >> 16) & 0xff
        ..[salt.length + 2] = (i >> 8) & 0xff
        ..[salt.length + 3] = i & 0xff;
      var u = Uint8List.fromList(hmac.convert(block).bytes);
      final t = Uint8List.fromList(u);
      for (int j = 1; j < iterations; j++) {
        u = Uint8List.fromList(hmac.convert(u).bytes);
        for (int k = 0; k < blockSize; k++) {
          t[k] ^= u[k];
        }
      }
      final remaining = dkLen - offset;
      final copy = remaining < blockSize ? remaining : blockSize;
      result.setRange(offset, offset + copy, t);
      offset += copy;
    }
    return result;
  }

  bool _constantTimeEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    int diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  Future<bool> hasFakePin() async =>
      (await _secure.read(key: _kFakeHash)) != null;

  Future<int> fakePinLength() async {
    final v = await _secure.read(key: _kFakeLen);
    return int.tryParse(v ?? '') ?? 4;
  }

  Future<void> setupFakePin(String pin) async {
    final salt = _randomBytes(_saltLengthBytes);
    final hash = _pbkdf2(
      Uint8List.fromList(utf8.encode(pin)),
      salt,
      _iterations,
      _hashLengthBytes,
    );
    await _secure.write(key: _kFakeSalt, value: base64Encode(salt));
    await _secure.write(key: _kFakeHash, value: base64Encode(hash));
    await _secure.write(key: _kFakeLen, value: pin.length.toString());
    await _seedDecoyVaultIfEmpty();
  }

  Future<bool> verifyFakePin(String pin) async {
    final saltStr = await _secure.read(key: _kFakeSalt);
    final hashStr = await _secure.read(key: _kFakeHash);
    if (saltStr == null || hashStr == null) return false;
    final candidate = _pbkdf2(
      Uint8List.fromList(utf8.encode(pin)),
      base64Decode(saltStr),
      _iterations,
      _hashLengthBytes,
    );
    return _constantTimeEqual(candidate, base64Decode(hashStr));
  }

  Future<void> clearFakePin({bool wipeDecoyVault = false}) async {
    await _secure.delete(key: _kFakeHash);
    await _secure.delete(key: _kFakeSalt);
    await _secure.delete(key: _kFakeLen);
    if (wipeDecoyVault) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(VaultContext.decoyLibraryKey);
      await prefs.remove(VaultContext.decoyCustomCategoriesKey);
      await prefs.remove(VaultContext.decoyDownloadHistoryKey);
      await _secure.delete(key: _kDecoyMasterKey);
    }
  }

  /// Hidden audit trail: each time the decoy vault is opened under the fake
  /// PIN, bump a counter and append a timestamp (last 10 kept). Stored in
  /// secure storage, not visible anywhere in the decoy UI.
  Future<void> recordDuressEntry() async {
    try {
      final raw = await _secure.read(key: _kDuressLog) ?? '0|';
      final parts = raw.split('|');
      final count = (int.tryParse(parts[0]) ?? 0) + 1;
      final stamps = (parts.length > 1 && parts[1].isNotEmpty)
          ? parts[1].split(',')
          : <String>[];
      stamps.add(DateTime.now().toIso8601String());
      while (stamps.length > 10) {
        stamps.removeAt(0);
      }
      await _secure.write(key: _kDuressLog, value: '$count|${stamps.join(',')}');
    } catch (_) {}
  }

  Future<int> duressEntryCount() async {
    try {
      final raw = await _secure.read(key: _kDuressLog);
      if (raw == null) return 0;
      return int.tryParse(raw.split('|').first) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  // ---- seed believable-but-harmless decoy library metadata ----
  Future<void> _seedDecoyVaultIfEmpty() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(VaultContext.decoyLibraryKey);
    if (existing != null && existing.isNotEmpty) return;

    final base = DateTime.now().millisecondsSinceEpoch -
        const Duration(days: 90).inMilliseconds;

    String entry(String title, String type, String category, int daysOffset) {
      final id = (base + daysOffset * 86400000).toString();
      // id|title|path|type|isLocked|category|isDeleted|deletedDate|encrypted|isHidden
      return '$id|$title||$type|false|$category|false||false|false';
    }

    await prefs.setStringList(VaultContext.decoyLibraryKey, [
      entry('Beach Trip 2024.mp4', 'video', 'Videos', 2),
      entry('Family Dinner.mp4', 'video', 'Videos', 9),
      entry('Concert Clip.mov', 'video', 'Videos', 21),
      entry('Sunset.jpg', 'image', 'Photos', 4),
      entry('Group Photo.png', 'image', 'Photos', 12),
      entry('Birthday Cake.jpg', 'image', 'Photos', 33),
      entry('Hiking Trail.heic', 'image', 'Photos', 47),
      entry('Workout Playlist.mp3', 'audio', 'Audio', 6),
      entry('Voice Note.m4a', 'audio', 'Audio', 18),
      entry('Lecture Notes.pdf', 'document', 'Documents', 7),
      entry('Receipts March.pdf', 'document', 'Documents', 25),
      entry('Travel Itinerary.pdf', 'document', 'Documents', 41),
    ]);
    await prefs.setStringList(
        VaultContext.decoyCustomCategoriesKey, ['Travel', 'Work']);

    final dlBase = DateTime.now().millisecondsSinceEpoch -
        const Duration(days: 14).inMilliseconds;
    String dl(String name, String size, int daysOffset) {
      final id = (dlBase + daysOffset * 86400000).toString();
      final date =
          DateTime.fromMillisecondsSinceEpoch(int.parse(id)).toIso8601String();
      // id|fileName|fileSize|status|date|path||url::progress
      return '$id|$name|$size|completed|$date|||::1.0';
    }

    await prefs.setStringList(VaultContext.decoyDownloadHistoryKey, [
      dl('Sunset.jpg', '2.4 MB', 12),
      dl('Beach Trip 2024.mp4', '184.2 MB', 9),
      dl('Lecture Notes.pdf', '880.0 KB', 4),
    ]);
  }
}
