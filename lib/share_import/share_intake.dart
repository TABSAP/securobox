import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'package:video_player_app/utils/flush_bar_helper.dart';
import 'package:video_player_app/utils/media_importer.dart';
import 'package:video_player_app/utils/notification_service.dart';
import 'package:video_player_app/utils/session_manager.dart';

/// Global navigator key, used to surface a result toast from outside the widget
/// tree (from the intake service below).
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Receives files shared into SecuroBox from the OS share sheet — the Android
/// Sharesheet (ACTION_SEND / ACTION_SEND_MULTIPLE) and the iOS Share Extension.
///
/// Shared files are imported **automatically**: the type of each file is
/// detected and it is filed into the matching category (Photos / Videos / Audio
/// / Documents) and encrypted into the vault. There is no preview screen and no
/// destination prompt — the user never has to make a choice.
///
/// Security: nothing is imported while the vault is locked. A share can arrive
/// before the user has authenticated (it can even launch the app), so the paths
/// are queued and only imported once the vault is unlocked. The queue is also
/// flushed the moment the app returns from a mid-session lock — which is what
/// keeps decoy-mode and real-vault imports from ever being confused.
class ShareIntake {
  ShareIntake._();
  static final ShareIntake instance = ShareIntake._();

  final List<String> _pending = [];
  StreamSubscription<List<SharedMediaFile>>? _sub;
  bool _initialised = false;
  bool _unlocked = false;
  bool _importing = false;

  /// Call once at startup. Captures the launch share payload and subscribes to
  /// shares delivered while the app is running.
  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    SessionManager.instance.shouldLock.addListener(_maybeImport);

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
    _maybeImport();
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
    _maybeImport();
  }

  void _maybeImport() {
    if (_pending.isEmpty || _importing) return;
    // Gate: only when unlocked and not mid-lock, so we always import into the
    // vault the user actually authenticated into.
    if (!_unlocked || SessionManager.instance.shouldLock.value) return;

    // Claim the batch synchronously so a second call can't double-import.
    final batch = List<String>.from(_pending);
    _pending.clear();
    _importing = true;

    // `markUnlocked()` is called from MainScreen.initState, so defer off the
    // build phase: the result toast pushes a route, which must never happen
    // while the framework is building.
    WidgetsBinding.instance.addPostFrameCallback((_) => _importBatch(batch));
  }

  /// Encrypts and files every shared path into its auto-detected category.
  Future<void> _importBatch(List<String> batch) async {
    // The vault can lock between scheduling this and the frame running it.
    // Re-check, and requeue rather than importing into the wrong vault.
    if (!_unlocked || SessionManager.instance.shouldLock.value) {
      _pending.insertAll(0, batch);
      _importing = false;
      return;
    }

    var added = 0;
    var failed = 0;
    var skipped = 0;
    try {
      // Skip files whose name already exists in the vault, so re-sharing the
      // same photo doesn't silently create a duplicate.
      final existing = await MediaImporter.instance.existingTitlesLower();

      final items = <PickedMedia>[];
      for (final path in batch) {
        final file = File(path);
        if (!await file.exists()) {
          failed++;
          continue;
        }
        final name = p.basename(path);
        final nameNoExt = p.basenameWithoutExtension(path);
        if (existing.contains(name.toLowerCase()) ||
            existing.contains(nameNoExt.toLowerCase())) {
          skipped++;
          continue;
        }
        items.add(PickedMedia(file, originalName: name, origin: 'file'));
      }

      if (items.isNotEmpty) {
        // category: null → each file is auto-categorised by its detected type.
        final result = await MediaImporter.instance.importFiles(
          items: items,
          category: null,
          encrypt: true,
        );
        added = result.added;
        failed += result.failed;
      }
    } catch (_) {
      // Attribute only the files we never accounted for, so the missing-file
      // failures counted above aren't double-counted.
      final unaccounted = batch.length - added - skipped - failed;
      if (unaccounted > 0) failed += unaccounted;
    } finally {
      _importing = false;
    }

    _reportResult(added: added, failed: failed, skipped: skipped);

    // Anything that arrived while this batch was importing.
    _maybeImport();
  }

  void _reportResult({
    required int added,
    required int failed,
    required int skipped,
  }) {
    if (added == 0 && failed == 0 && skipped == 0) return;

    if (added > 0) {
      final detail = <String>[
        if (skipped > 0) '$skipped already in vault',
        if (failed > 0) '$failed failed',
      ].join(' · ');
      unawaited(NotificationService.instance.addEvent(
        title: 'Files added to your vault',
        body: '$added file${added == 1 ? '' : 's'} imported'
            '${detail.isEmpty ? '' : ' · $detail'}.',
        kind: 'info',
      ));
    }

    final context = appNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;

    if (added > 0) {
      FlushBarHelper.flushBarSuccessMessage(
        '$added file${added == 1 ? '' : 's'} imported to your vault',
        context,
      );
    } else if (skipped > 0 && failed == 0) {
      FlushBarHelper.flushBarInfoMessage(
        skipped == 1
            ? 'That file is already in your vault'
            : 'Those $skipped files are already in your vault',
        context,
      );
    } else {
      FlushBarHelper.flushBarErrorMessage(
        'Couldn\'t import the shared file${failed == 1 ? '' : 's'}',
        context,
      );
    }
  }

  void dispose() {
    _sub?.cancel();
    SessionManager.instance.shouldLock.removeListener(_maybeImport);
  }
}
