import 'dart:async';

import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'package:video_player_app/share_import/share_import_screen.dart';
import 'package:video_player_app/utils/session_manager.dart';

/// Global navigator key so files shared into the app can be presented from
/// outside the widget tree (from the intake service below).
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Receives files shared into SecuroBox from the OS share sheet — the Android
/// Sharesheet (ACTION_SEND / ACTION_SEND_MULTIPLE) and the iOS Share Extension
/// — and opens the Import Preview screen for them.
///
/// Security: shared files are NEVER shown while the vault is locked. A share can
/// arrive before the user has authenticated (it can even launch the app), so the
/// paths are queued and only presented once the vault is unlocked. The queue is
/// also flushed the moment the app returns from a mid-session lock.
class ShareIntake {
  ShareIntake._();
  static final ShareIntake instance = ShareIntake._();

  final List<String> _pending = [];
  StreamSubscription<List<SharedMediaFile>>? _sub;
  bool _initialised = false;
  bool _unlocked = false;
  bool _presenting = false;

  /// Call once at startup. Captures the launch share payload and subscribes to
  /// shares delivered while the app is running.
  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    SessionManager.instance.shouldLock.addListener(_maybePresent);

    _sub = ReceiveSharingIntent.instance.getMediaStream().listen(
      _enqueue,
      onError: (_) {},
    );

    try {
      final initial = await ReceiveSharingIntent.instance.getInitialMedia();
      if (initial.isNotEmpty) {
        _enqueue(initial);
        await ReceiveSharingIntent.instance.reset();
      }
    } catch (_) {}
  }

  /// Called by the main (unlocked) screen when the vault becomes accessible.
  void markUnlocked() {
    _unlocked = true;
    _maybePresent();
  }

  /// Called when the unlocked screen is torn down (app locked / signed out).
  void markLocked() => _unlocked = false;

  void _enqueue(List<SharedMediaFile> files) {
    final paths = files
        .map((f) => f.path)
        .where((path) => path.trim().isNotEmpty)
        .toList();
    if (paths.isEmpty) return;
    _pending.addAll(paths);
    _maybePresent();
  }

  void _maybePresent() {
    if (_pending.isEmpty || _presenting) return;
    // Gate: only when unlocked, not mid-lock, and a navigator is mounted.
    if (!_unlocked || SessionManager.instance.shouldLock.value) return;
    final nav = appNavigatorKey.currentState;
    if (nav == null) return;

    final batch = List<String>.from(_pending);
    _pending.clear();
    _presenting = true;
    nav
        .push(
          MaterialPageRoute(
            builder: (_) => ShareImportScreen(
              paths: batch,
              onDone: () => nav.maybePop(),
            ),
          ),
        )
        .whenComplete(() {
          _presenting = false;
          // Present anything that queued up while this batch was open.
          _maybePresent();
        });
  }

  void dispose() {
    _sub?.cancel();
    SessionManager.instance.shouldLock.removeListener(_maybePresent);
  }
}
