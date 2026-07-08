import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:video_player_app/utils/pbkdf2.dart';

class RecoveryService {
  RecoveryService._();
  static final RecoveryService instance = RecoveryService._();

  static const _kHashKey = 'recovery_hash_v2';
  static const _kSaltKey = 'recovery_salt_v2';
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

  Future<void> save({required String code}) async {
    final salt = _randomBytes(_kSaltLengthBytes);
    await _secure.write(key: _kSaltKey, value: base64Encode(salt));
    await _secure.write(key: _kHashKey, value: await _hash(code, salt));
  }

  Future<bool> isEnabled() async {
    return (await _secure.read(key: _kHashKey)) != null;
  }

  Future<bool> verify(String code) async {
    final stored = await _secure.read(key: _kHashKey);
    final saltB64 = await _secure.read(key: _kSaltKey);
    if (stored == null || saltB64 == null) return false;
    return _constantTimeEqual(await _hash(code, base64Decode(saltB64)), stored);
  }

  Future<void> clear() async {
    await _secure.delete(key: _kHashKey);
    await _secure.delete(key: _kSaltKey);
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
