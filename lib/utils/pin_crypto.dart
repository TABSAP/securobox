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
  static const _kPinLengthKey = 'pin_length_v1';
  static const _kIterations = 100000;
  static const _kHashLengthBytes = 32;
  static const _kSaltLengthBytes = 16;
  static const defaultPinLength = 4;
  static const supportedPinLengths = [4, 6];

  /// Session cache of the configured PIN length.
  ///
  /// Held on the singleton so it survives widget / activity recreation — e.g.
  /// when the user switches the disguise (app icon / name), Android may rebuild
  /// the Flutter view, but the Dart process (and this singleton) live on. UI can
  /// read [cachedPinLength] synchronously to render the correct number of PIN
  /// fields on the very first frame, so the PIN-length UI stays consistent for
  /// the whole session instead of briefly flashing the 4-digit default while an
  /// async [getPinLength] read completes.
  int _cachedPinLength = defaultPinLength;
  int get cachedPinLength => _cachedPinLength;

  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(),
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

    final salt = base64Decode(saltStr);
    final stored = base64Decode(hashStr);
    final candidate = await pbkdf2(
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
