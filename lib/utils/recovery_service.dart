import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class RecoveryService {
  RecoveryService._();
  static final RecoveryService instance = RecoveryService._();

  static const _kHashKey = 'recovery_hash_v1';
  static const _kEmailKey = 'recovery_email_v1';

  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(),
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

  String _hash(String code) {
    final bytes = utf8.encode(_normalize(code));
    return base64Encode(sha256.convert(bytes).bytes);
  }

  Future<void> save({required String code, required String email}) async {
    await _secure.write(key: _kHashKey, value: _hash(code));
    await _secure.write(key: _kEmailKey, value: email.trim());
  }

  Future<bool> isEnabled() async {
    return (await _secure.read(key: _kHashKey)) != null;
  }

  Future<String?> getEmail() async => _secure.read(key: _kEmailKey);

  Future<bool> verify(String code) async {
    final stored = await _secure.read(key: _kHashKey);
    if (stored == null) return false;
    return _constantTimeEqual(_hash(code), stored);
  }

  Future<bool> verifyEmailAndCode({
    required String email,
    required String code,
  }) async {
    final storedHash = await _secure.read(key: _kHashKey);
    final storedEmail = await _secure.read(key: _kEmailKey);
    if (storedHash == null || storedEmail == null) return false;
    final emailMatches =
        email.trim().toLowerCase() == storedEmail.trim().toLowerCase();
    final codeMatches = _constantTimeEqual(_hash(code), storedHash);
    return emailMatches && codeMatches;
  }

  Future<void> clear() async {
    await _secure.delete(key: _kHashKey);
    await _secure.delete(key: _kEmailKey);
  }

  static String mask(String email) {
    final trimmed = email.trim();
    final at = trimmed.indexOf('@');
    if (at <= 0) return trimmed;
    final local = trimmed.substring(0, at);
    final domain = trimmed.substring(at);

    if (local.length == 1) return '$local•••••$domain';
    if (local.length == 2) return '${local[0]}•••••${local[1]}$domain';

    final maskCount = (local.length - 2).clamp(3, 6);
    return '${local[0]}${'•' * maskCount}${local[local.length - 1]}$domain';
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
