import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_app/utils/pbkdf2.dart';

class PinCrypto {
  PinCrypto._();
  static final PinCrypto instance = PinCrypto._();

  static const _kHashKey = 'pin_hash_v1';
  static const _kSaltKey = 'pin_salt_v1';
  static const _kIterKey = 'pin_iters_v1';
  static const _kPinLengthKey = 'pin_length_v1';
  static const _kIterations = 600000;
  static const _kLegacyIterations = 100000;
  static const _kMaxIterations = 1000000;
  static const _kHashLengthBytes = 32;
  static const _kSaltLengthBytes = 16;
  static const defaultPinLength = 4;
  static const supportedPinLengths = [4, 6];

  int _cachedPinLength = defaultPinLength;
  int get cachedPinLength => _cachedPinLength;

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

  Future<void> setPin(String pin) async {
    final salt = _randomBytes(_kSaltLengthBytes);
    final hash = await pbkdf2(
      Uint8List.fromList(utf8.encode(pin)),
      salt,
      _kIterations,
      _kHashLengthBytes,
    );
    await _secure.write(key: _kSaltKey, value: base64Encode(salt));
    await _secure.write(key: _kHashKey, value: base64Encode(hash));
    await _secure.write(key: _kIterKey, value: '$_kIterations');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPinLengthKey, pin.length);
    _cachedPinLength = pin.length;
    await prefs.remove('appPin');
    await prefs.remove('secure_pin');
  }

  Future<void> migrateLegacyPinOnStartup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedHash = await _secure.read(key: _kHashKey);
      final storedSalt = await _secure.read(key: _kSaltKey);
      final storedIterations = await _secure.read(key: _kIterKey);
      final decodedHash = storedHash == null ? null : base64Decode(storedHash);
      final decodedSalt = storedSalt == null ? null : base64Decode(storedSalt);
      final iterations = int.tryParse(storedIterations ?? '');
      final hasValidVerifier =
          decodedHash?.length == _kHashLengthBytes &&
          decodedSalt?.length == _kSaltLengthBytes &&
          iterations != null &&
          iterations > 0 &&
          iterations <= _kMaxIterations;
      if (hasValidVerifier) {
        await prefs.remove('appPin');
        await prefs.remove('secure_pin');
        return;
      }
      final legacy =
          prefs.getStringList('appPin') ?? prefs.getStringList('secure_pin');
      if (legacy == null ||
          (legacy.length != 4 && legacy.length != 6) ||
          legacy.any(
            (digit) => digit.length != 1 || int.tryParse(digit) == null,
          )) {
        return;
      }
      await setPin(legacy.join());
    } catch (error) {
      if (kDebugMode) debugPrint('Legacy PIN migration failed: $error');
    }
  }

  Future<int> getPinLength() async {
    final prefs = await SharedPreferences.getInstance();
    final len = prefs.getInt(_kPinLengthKey) ?? defaultPinLength;
    _cachedPinLength = len;
    return len;
  }

  Future<void> setPreferredPinLength(int length) async {
    if (!supportedPinLengths.contains(length)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPinLengthKey, length);
    _cachedPinLength = length;
  }

  Future<bool> verifyPin(String pin) async {
    final saltStr = await _secure.read(key: _kSaltKey);
    final hashStr = await _secure.read(key: _kHashKey);

    if (saltStr == null || hashStr == null) {
      return await _migrateLegacyAndVerify(pin);
    }

    final iterStr = await _secure.read(key: _kIterKey);
    final iterations = int.tryParse(iterStr ?? '') ?? _kLegacyIterations;
    if (iterations <= 0 || iterations > _kMaxIterations) return false;

    late final Uint8List salt;
    late final Uint8List stored;
    try {
      salt = base64Decode(saltStr);
      stored = base64Decode(hashStr);
    } on FormatException {
      return false;
    }
    if (salt.length != _kSaltLengthBytes ||
        stored.length != _kHashLengthBytes) {
      return false;
    }
    final candidate = await pbkdf2(
      Uint8List.fromList(utf8.encode(pin)),
      salt,
      iterations,
      _kHashLengthBytes,
    );

    final ok = _constantTimeEqual(stored, candidate);
    if (ok && iterations != _kIterations) {
      unawaited(setPin(pin));
    }
    return ok;
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
    final prefs = await SharedPreferences.getInstance();
    final oldValues = <String, String?>{
      _kHashKey: await _secure.read(key: _kHashKey),
      _kSaltKey: await _secure.read(key: _kSaltKey),
      _kIterKey: await _secure.read(key: _kIterKey),
    };
    final oldAppPin = prefs.getStringList('appPin');
    final oldSecurePin = prefs.getStringList('secure_pin');
    try {
      await _secure.delete(key: _kHashKey);
      await _secure.delete(key: _kSaltKey);
      await _secure.delete(key: _kIterKey);
      await prefs.remove('appPin');
      await prefs.remove('secure_pin');
    } catch (_) {
      for (final entry in oldValues.entries) {
        try {
          final value = entry.value;
          if (value == null) {
            await _secure.delete(key: entry.key);
          } else {
            await _secure.write(key: entry.key, value: value);
          }
        } catch (_) {}
      }
      try {
        if (oldAppPin != null) await prefs.setStringList('appPin', oldAppPin);
        if (oldSecurePin != null) {
          await prefs.setStringList('secure_pin', oldSecurePin);
        }
      } catch (_) {}
      rethrow;
    }
    _cachedPinLength = defaultPinLength;
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
