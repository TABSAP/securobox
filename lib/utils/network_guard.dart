import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:video_player_app/utils/session_manager.dart';
import 'package:video_player_app/utils/vault_crypto.dart';

/// Offline Integrity Lock.
///
/// An opt-in mode that continuously watches the device's network interfaces.
/// While it is enabled, the vault is only allowed to be open when the device
/// is fully offline. The instant a Wi-Fi / mobile / ethernet / VPN path comes
/// up, the live encryption session is revoked and the lock screen is forced.
///
/// The point is anti-remote-exfiltration: if decrypted content is never
/// resident in memory or in the temp cache while a network path exists, there
/// is no online window in which malware or a remote attacker could read it.
///
/// Everything here is local — there is no server, no probe request, no
/// reachability check beyond the OS-reported interface state.
class NetworkGuard {
  NetworkGuard._();
  static final NetworkGuard instance = NetworkGuard._();

  static const _kEnabled = 'offlineIntegrityLock';

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;

  bool _enabled = false;

  /// Whether the Offline Integrity Lock is switched on.
  bool get enabled => _enabled;

  /// Live network state — true when the OS reports any internet-capable
  /// interface (Wi-Fi, mobile data, ethernet or VPN). The lock screen and the
  /// settings card both listen here.
  final ValueNotifier<bool> online = ValueNotifier<bool>(false);

  /// True when the vault must stay sealed right now: the feature is on AND a
  /// network path is up. The lock screen consults this before granting entry.
  bool get blockUnlock => _enabled && online.value;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_kEnabled) ?? false;

    final current = await _connectivity.checkConnectivity();
    online.value = _isOnline(current);

    _sub = _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);

    // If the app is launching while already exposed, seal up front.
    if (_enabled && online.value) _seal();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, value);
    // Turning the feature on while online seals immediately, exactly as a
    // later network change would.
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

  /// Network exposure detected: revoke the in-memory encryption session and
  /// force the lock screen. Re-authentication (only possible once offline
  /// again) re-derives a fresh session from the at-rest key.
  void _seal() {
    unawaited(VaultCrypto.instance.revokeSession());
    SessionManager.instance.requestLock();
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
