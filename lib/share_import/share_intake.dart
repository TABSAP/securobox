import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'package:video_player_app/utils/flush_bar_helper.dart';
import 'package:video_player_app/utils/media_importer.dart';
import 'package:video_player_app/utils/notification_service.dart';
import 'package:video_player_app/utils/session_manager.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class ShareIntake {
  ShareIntake._();
  static final ShareIntake instance = ShareIntake._();

  final List<String> _pending = [];
  StreamSubscription<List<SharedMediaFile>>? _sub;
  bool _initialised = false;
  bool _unlocked = false;
  bool _importing = false;

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

  void markUnlocked() {
    _unlocked = true;
    _maybeImport();
  }

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
    if (!_unlocked || SessionManager.instance.shouldLock.value) return;

    final batch = List<String>.from(_pending);
    _pending.clear();
    _importing = true;

    WidgetsBinding.instance.addPostFrameCallback((_) => _importBatch(batch));
  }

  Future<void> _importBatch(List<String> batch) async {
    if (!_unlocked || SessionManager.instance.shouldLock.value) {
      _pending.insertAll(0, batch);
      _importing = false;
      return;
    }

    var added = 0;
    var failed = 0;
    var skipped = 0;
    try {
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
        final result = await MediaImporter.instance.importFiles(
          items: items,
          category: null,
        );
        added = result.added;
        failed += result.failed;
      }
    } catch (_) {
      final unaccounted = batch.length - added - skipped - failed;
      if (unaccounted > 0) failed += unaccounted;
    } finally {
      _importing = false;
    }

    _reportResult(added: added, failed: failed, skipped: skipped);

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
      unawaited(
        NotificationService.instance.addEvent(
          title: 'Files added to your vault',
          body:
              '$added file${added == 1 ? '' : 's'} imported'
              '${detail.isEmpty ? '' : ' · $detail'}.',
          kind: 'info',
        ),
      );
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
