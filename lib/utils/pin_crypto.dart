import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PinCrypto {
  PinCrypto._();
  static final PinCrypto instance = PinCrypto._();

  static const _kHashKey = 'pin_hash_v1';
  static const _kSaltKey = 'pin_salt_v1';
  static const _kIterations = 100000;
  static const _kHashLengthBytes = 32;
  static const _kSaltLengthBytes = 16;

  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  Uint8List _randomBytes(int length) {
    final r = Random.secure();
    return Uint8List.fromList(List<int>.generate(length, (_) => r.nextInt(256)));
  }

  Uint8List _pbkdf2(Uint8List password, Uint8List salt, int iterations, int dkLen) {
    final hmac = Hmac(sha256, password);
    final blockSize = 32;
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

  Future<void> setPin(String pin) async {
    final salt = _randomBytes(_kSaltLengthBytes);
    final hash = _pbkdf2(
      Uint8List.fromList(utf8.encode(pin)),
      salt,
      _kIterations,
      _kHashLengthBytes,
    );
    await _secure.write(key: _kSaltKey, value: base64Encode(salt));
    await _secure.write(key: _kHashKey, value: base64Encode(hash));
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('appPin');
    await prefs.remove('secure_pin');
  }

  Future<bool> verifyPin(String pin) async {
    final saltStr = await _secure.read(key: _kSaltKey);
    final hashStr = await _secure.read(key: _kHashKey);

    if (saltStr == null || hashStr == null) {
      return await _migrateLegacyAndVerify(pin);
    }

    final salt = base64Decode(saltStr);
    final stored = base64Decode(hashStr);
    final candidate = _pbkdf2(
      Uint8List.fromList(utf8.encode(pin)),
      salt,
      _kIterations,
      _kHashLengthBytes,
    );

    return _constantTimeEqual(stored, candidate);
  }

  Future<bool> hasPin() async {
    final hash = await _secure.read(key: _kHashKey);
    if (hash != null) return true;
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getStringList('appPin');
    return legacy != null && legacy.length == 4;
  }

  Future<bool> _migrateLegacyAndVerify(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getStringList('appPin');
    if (legacy == null || legacy.length != 4) return false;
    final legacyPin = legacy.join();
    if (!_constantTimeStringEqual(legacyPin, pin)) return false;

    await setPin(pin);
    return true;
  }

  Future<void> clearPin() async {
    await _secure.delete(key: _kHashKey);
    await _secure.delete(key: _kSaltKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('appPin');
    await prefs.remove('secure_pin');
  }

  bool _constantTimeEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    int diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  bool _constantTimeStringEqual(String a, String b) {
    if (a.length != b.length) return false;
    int diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
