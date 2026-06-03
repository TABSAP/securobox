import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:video_player_app/utils/pbkdf2.dart';

class RecoveryService {
  RecoveryService._();
  static final RecoveryService instance = RecoveryService._();

  // The recovery code is hashed with salted PBKDF2-HMAC-SHA256 (100k), matching
  // the PIN's strength (v1 used an unsalted single SHA-256). Bumped to v2 keys so
  // a fresh salted hash is written; recovery must be re-set up after upgrade.
  static const _kHashKey = 'recovery_hash_v2';
  static const _kSaltKey = 'recovery_salt_v2';
  static const _kEmailKey = 'recovery_email_v1';
  static const _kIterations = 100000;
  static const _kKeyLengthBytes = 32;
  static const _kSaltLengthBytes = 16;

  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  String generateCode() {
    final r = Random.secure();
    final raw = String.fromCharCodes(
      List.generate(16, (_) => _alphabet.codeUnitAt(r.nextInt(_alphabet.length))),
    );
    return '${raw.substring(0, 4)}-${raw.substring(4, 8)}-'
        '${raw.substring(8, 12)}-${raw.substring(12, 16)}';
  }

  String _normalize(String code) =>
      code.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();

  Uint8List _randomBytes(int length) {
    final r = Random.secure();
    return Uint8List.fromList(List<int>.generate(length, (_) => r.nextInt(256)));
  }

  Future<String> _hash(String code, Uint8List salt) async {
    final dk = await pbkdf2(
      Uint8List.fromList(utf8.encode(_normalize(code))),
      salt,
      _kIterations,
      _kKeyLengthBytes,
    );
    return base64Encode(dk);
  }

  Future<void> save({required String code, required String email}) async {
    final salt = _randomBytes(_kSaltLengthBytes);
    await _secure.write(key: _kSaltKey, value: base64Encode(salt));
    await _secure.write(key: _kHashKey, value: await _hash(code, salt));
    await _secure.write(key: _kEmailKey, value: email.trim());
  }

  Future<bool> isEnabled() async {
    return (await _secure.read(key: _kHashKey)) != null;
  }

  Future<String?> getEmail() async => _secure.read(key: _kEmailKey);

  Future<bool> verify(String code) async {
    final stored = await _secure.read(key: _kHashKey);
    final saltB64 = await _secure.read(key: _kSaltKey);
    if (stored == null || saltB64 == null) return false;
    return _constantTimeEqual(await _hash(code, base64Decode(saltB64)), stored);
  }

  Future<bool> verifyEmailAndCode({
    required String email,
    required String code,
  }) async {
    final storedHash = await _secure.read(key: _kHashKey);
    final storedEmail = await _secure.read(key: _kEmailKey);
    final saltB64 = await _secure.read(key: _kSaltKey);
    if (storedHash == null || storedEmail == null || saltB64 == null) {
      return false;
    }
    final emailMatches =
        email.trim().toLowerCase() == storedEmail.trim().toLowerCase();
    final codeMatches = _constantTimeEqual(
      await _hash(code, base64Decode(saltB64)),
      storedHash,
    );
    return emailMatches && codeMatches;
  }

  Future<void> clear() async {
    await _secure.delete(key: _kHashKey);
    await _secure.delete(key: _kSaltKey);
    await _secure.delete(key: _kEmailKey);
  }

  static const String hiddenLabel = '••••••••@••••••.•••';

  static String mask(String email) {
    return email.trim().isEmpty ? '' : hiddenLabel;
  }

  bool _constantTimeEqual(String a, String b) {
    if (a.length != b.length) return false;
    int diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
