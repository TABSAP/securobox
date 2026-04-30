import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  SessionManager._();
  static final SessionManager instance = SessionManager._();

  static const _kAutoLockSeconds = 'autoLockSeconds';
  static const _kSessionLastActive = 'sessionLastActive';
  static const _kFailedAttempts = 'failedPinAttempts';
  static const _kCooldownUntil = 'cooldownUntil';

  static const Map<int, String> autoLockOptions = {
    0: 'Immediately',
    30: 'After 30 seconds',
    60: 'After 1 minute',
    300: 'After 5 minutes',
    900: 'After 15 minutes',
    -1: 'Never',
  };

  int _autoLockSeconds = 60;
  int get autoLockSeconds => _autoLockSeconds;

  final ValueNotifier<bool> shouldLock = ValueNotifier<bool>(false);
  final ValueNotifier<bool> showPrivacyShield = ValueNotifier<bool>(false);

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
    await resetFailedAttempts();
    await markActive();
  }

  Future<int> recordFailedAttempt() async {
    final prefs = await SharedPreferences.getInstance();
    final n = (prefs.getInt(_kFailedAttempts) ?? 0) + 1;
    await prefs.setInt(_kFailedAttempts, n);

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
      await prefs.setInt(_kCooldownUntil, until);
    }
    return n;
  }

  Future<void> resetFailedAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kFailedAttempts);
    await prefs.remove(_kCooldownUntil);
  }

  Future<int> getFailedAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kFailedAttempts) ?? 0;
  }

  Future<Duration?> getCooldownRemaining() async {
    final prefs = await SharedPreferences.getInstance();
    final until = prefs.getInt(_kCooldownUntil);
    if (until == null) return null;
    final remainingMs = until - DateTime.now().millisecondsSinceEpoch;
    if (remainingMs <= 0) {
      await prefs.remove(_kCooldownUntil);
      return null;
    }
    return Duration(milliseconds: remainingMs);
  }
}
