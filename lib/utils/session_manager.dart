import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  SessionManager._();
  static final SessionManager instance = SessionManager._();

  static const _kAutoLockSeconds = 'autoLockSeconds';
  static const _kSessionLastActive = 'sessionLastActive';
  static const _kFailedAttempts = 'failedPinAttempts';
  static const _kCooldownUntil = 'cooldownUntil';
  static const _kFailedBio = 'failedBioAttempts';
  static const _kBioCooldownUntil = 'bioCooldownUntil';
  static const bioCooldownThreshold = 3;
  static const _bioCooldownSeconds = 60;

  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  Future<int> _secureInt(String key) async {
    final v = await _secure.read(key: key);
    return v == null ? 0 : (int.tryParse(v) ?? 0);
  }

  static const Map<int, String> autoLockOptions = {
    0: 'Immediately',
    30: 'After 30 seconds',
    60: 'After 1 minute',
    300: 'After 5 minutes',
    900: 'After 15 minutes',

  };

  int _autoLockSeconds = 60;
  int get autoLockSeconds => _autoLockSeconds;

  final ValueNotifier<bool> shouldLock = ValueNotifier<bool>(false);
  final ValueNotifier<bool> showPrivacyShield = ValueNotifier<bool>(false);

  int _trustedDepth = 0;
  bool get inTrustedInteraction => _trustedDepth > 0;
  void beginTrustedInteraction() => _trustedDepth++;
  void endTrustedInteraction() {
    if (_trustedDepth > 0) _trustedDepth--;
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _autoLockSeconds = prefs.getInt(_kAutoLockSeconds) ?? 60;
  }

  Future<void> setAutoLockSeconds(int seconds) async {
    _autoLockSeconds = seconds;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kAutoLockSeconds, seconds);
  }

  Future<void> markActive() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kSessionLastActive, DateTime.now().millisecondsSinceEpoch);
  }

  Future<bool> hasInactivityElapsed() async {
    if (_autoLockSeconds < 0) return false;
    if (_autoLockSeconds == 0) return true;
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_kSessionLastActive) ?? 0;
    if (last == 0) return false;
    final elapsedMs = DateTime.now().millisecondsSinceEpoch - last;
    return elapsedMs >= _autoLockSeconds * 1000;
  }

  void requestLock() {
    shouldLock.value = true;
  }

  Future<void> unlock() async {
    shouldLock.value = false;
    await markActive();
    unawaited(resetFailedAttempts());
    unawaited(resetFailedBiometricAttempts());
  }

  Future<int> recordFailedAttempt() async {
    final n = (await _secureInt(_kFailedAttempts)) + 1;
    await _secure.write(key: _kFailedAttempts, value: '$n');

    int cooldownSeconds = 0;
    if (n >= 12) {
      cooldownSeconds = 900;
    } else if (n >= 9) {
      cooldownSeconds = 300;
    } else if (n >= 6) {
      cooldownSeconds = 60;
    } else if (n >= 3) {
      cooldownSeconds = 30;
    }

    if (cooldownSeconds > 0) {
      final until = DateTime.now()
          .add(Duration(seconds: cooldownSeconds))
          .millisecondsSinceEpoch;
      await _secure.write(key: _kCooldownUntil, value: '$until');
    }
    return n;
  }

  Future<void> resetFailedAttempts() async {
    await _secure.delete(key: _kFailedAttempts);
    await _secure.delete(key: _kCooldownUntil);
  }

  Future<int> getFailedAttempts() async => _secureInt(_kFailedAttempts);

  Future<Duration?> getCooldownRemaining() async {
    final v = await _secure.read(key: _kCooldownUntil);
    if (v == null) return null;
    final until = int.tryParse(v);
    if (until == null) return null;
    final remainingMs = until - DateTime.now().millisecondsSinceEpoch;
    if (remainingMs <= 0) {
      await _secure.delete(key: _kCooldownUntil);
      return null;
    }
    return Duration(milliseconds: remainingMs);
  }

  Future<int> recordFailedBiometricAttempt() async {
    final n = (await _secureInt(_kFailedBio)) + 1;
    await _secure.write(key: _kFailedBio, value: '$n');
    if (n >= bioCooldownThreshold) {
      final until = DateTime.now()
          .add(const Duration(seconds: _bioCooldownSeconds))
          .millisecondsSinceEpoch;
      await _secure.write(key: _kBioCooldownUntil, value: '$until');
    }
    return n;
  }

  Future<int> getFailedBiometricAttempts() async => _secureInt(_kFailedBio);

  Future<void> resetFailedBiometricAttempts() async {
    await _secure.delete(key: _kFailedBio);
    await _secure.delete(key: _kBioCooldownUntil);
  }

  Future<Duration?> getBiometricCooldownRemaining() async {
    final v = await _secure.read(key: _kBioCooldownUntil);
    if (v == null) return null;
    final until = int.tryParse(v);
    if (until == null) return null;
    final remainingMs = until - DateTime.now().millisecondsSinceEpoch;
    if (remainingMs <= 0) {
      await _secure.delete(key: _kBioCooldownUntil);
      await _secure.delete(key: _kFailedBio);
      return null;
    }
    return Duration(milliseconds: remainingMs);
  }
}
