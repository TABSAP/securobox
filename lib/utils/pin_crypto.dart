import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
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
  // Iteration count for NEW/updated PINs. A numeric PIN has very low inherent
  // entropy (10k–1M combinations), so the marginal brute-force resistance of a
  // very high count is small while the unlock latency it adds is real. 50k
  // keeps a solid work factor while letting the unlock complete well under a
  // second. Legacy PINs hashed at the old count still verify (see verifyPin)
  // and are transparently re-hashed to this count on the next unlock.
  static const _kIterations = 50000;
  static const _kLegacyIterations = 100000;
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
    return Uint8List.fromList(List<int>.generate(length, (_) => r.nextInt(256)));
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

    // PINs created before iteration counts were stored used the old, higher
    // count; honour whatever count this hash was actually derived with.
    final iterStr = await _secure.read(key: _kIterKey);
    final iterations = int.tryParse(iterStr ?? '') ?? _kLegacyIterations;

    final salt = base64Decode(saltStr);
    final stored = base64Decode(hashStr);
    final candidate = await pbkdf2(
      Uint8List.fromList(utf8.encode(pin)),
      salt,
      iterations,
      _kHashLengthBytes,
    );

    final ok = _constantTimeEqual(stored, candidate);
    // Transparently upgrade an old-count hash to the current (faster) count so
    // subsequent unlocks are quicker. Runs after the result is known and is not
    // awaited, so it never delays the unlock.
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
    await _secure.delete(key: _kHashKey);
    await _secure.delete(key: _kSaltKey);
    await _secure.delete(key: _kIterKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('appPin');
    await prefs.remove('secure_pin');
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
