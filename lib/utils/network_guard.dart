import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:video_player_app/utils/session_manager.dart';
import 'package:video_player_app/utils/vault_crypto.dart';

class NetworkGuard {
  NetworkGuard._();
  static final NetworkGuard instance = NetworkGuard._();

  static const _kEnabled = 'offlineIntegrityLock';

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;

  bool _enabled = false;

  bool get enabled => _enabled;

  final ValueNotifier<bool> online = ValueNotifier<bool>(false);

  bool get blockUnlock => _enabled && online.value;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_kEnabled) ?? false;

    final current = await _connectivity.checkConnectivity();
    online.value = _isOnline(current);

    _sub = _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);

    if (_enabled && online.value) _seal();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, value);
    if (value && online.value) _seal();
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    online.value = _isOnline(results);
    if (_enabled && online.value) _seal();
  }

  static bool _isOnline(List<ConnectivityResult> results) => results.any(
        (r) =>
            r == ConnectivityResult.wifi ||
            r == ConnectivityResult.mobile ||
            r == ConnectivityResult.ethernet ||
            r == ConnectivityResult.vpn,
      );

  void _seal() {
    unawaited(VaultCrypto.instance.revokeSession());
    SessionManager.instance.requestLock();
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
