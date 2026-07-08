import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_app/utils/pbkdf2.dart';
import 'package:video_player_app/utils/vault_context.dart';

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
    aOptions: AndroidOptions(resetOnError: false),
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
    final hash = await pbkdf2(
      Uint8List.fromList(utf8.encode(pin)),
      salt,
      _iterations,
      _hashLengthBytes,
    );
    await _secure.write(key: _kFakeSalt, value: base64Encode(salt));
    await _secure.write(key: _kFakeHash, value: base64Encode(hash));
    await _secure.write(key: _kFakeLen, value: pin.length.toString());
    // The decoy vault starts empty. The user adds their own decoy content.
  }

  Future<bool> verifyFakePin(String pin) async {
    final saltStr = await _secure.read(key: _kFakeSalt);
    final hashStr = await _secure.read(key: _kFakeHash);
    if (saltStr == null || hashStr == null) return false;
    final candidate = await pbkdf2(
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

  /// One-time cleanup for installs that were seeded with fake decoy content by
  /// an earlier build. Runs once (guarded by a flag) and only removes the
  /// clearly-fake seeds — real, user-added content is never touched:
  ///   - decoy media whose file path is empty (seeded fakes never had a real
  ///     file; imported items always have a path),
  ///   - the seeded empty 'Travel'/'Work' custom categories (only if no real
  ///     decoy item uses them),
  ///   - the seeded decoy download history.
  Future<void> purgeSeededDecoyData() async {
    const purgedFlag = 'decoy_seed_purged_v1';
    const decoyConfigKey = 'categoriesConfig_decoy';
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(purgedFlag) == true) return;

      // 1) Drop fake media (empty path in field index 2).
      final lib = prefs.getStringList(VaultContext.decoyLibraryKey);
      if (lib != null && lib.isNotEmpty) {
        final kept = lib.where((row) {
          final parts = row.split('|');
          return parts.length > 2 && parts[2].trim().isNotEmpty;
        }).toList();
        if (kept.length != lib.length) {
          await prefs.setStringList(VaultContext.decoyLibraryKey, kept);
        }

        // 2) Remove the seeded 'Travel'/'Work' categories if now unused.
        final usedCats = kept
            .map((r) {
              final p = r.split('|');
              return p.length > 5 ? p[5].toLowerCase() : '';
            })
            .toSet();
        final customs =
            prefs.getStringList(VaultContext.decoyCustomCategoriesKey);
        if (customs != null && customs.isNotEmpty) {
          final keptCats = customs.where((c) {
            final lc = c.toLowerCase();
            final seeded = lc == 'travel' || lc == 'work';
            return !(seeded && !usedCats.contains(lc));
          }).toList();
          if (keptCats.length != customs.length) {
            await prefs.setStringList(
                VaultContext.decoyCustomCategoriesKey, keptCats);
            // Rebuild the decoy category config from the cleaned list.
            await prefs.remove(decoyConfigKey);
          }
        }
      }

      // 3) Remove the seeded fake download history.
      await prefs.remove(VaultContext.decoyDownloadHistoryKey);

      await prefs.setBool(purgedFlag, true);
    } catch (_) {}
  }
}
