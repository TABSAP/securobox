import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:video_thumbnail/video_thumbnail.dart';

import 'package:video_player_app/models/app_models.dart';
import 'package:video_player_app/utils/vault_crypto.dart';

/// Session cache of ready-to-render preview files, keyed by vault item id.
///
/// Previews are decrypted/extracted plaintext, so — like [VaultCrypto]'s temp
/// cache — everything lives under the vault temp dir and is wiped on lock. The
/// importer *primes* this cache the moment a file is imported (while the source
/// is still in hand), so [VaultThumbnail] can show the real preview instantly
/// on first build instead of flashing a placeholder icon.
class ThumbnailCache {
  ThumbnailCache._();
  static final ThumbnailCache instance = ThumbnailCache._();

  final Map<String, File> _cache = {};
  final Map<String, Future<File?>> _inflight = {};

  /// Synchronous cache hit — used in `initState` so a warm preview renders on
  /// the very first frame (no placeholder flash). Returns null on a miss.
  File? peek(String id) {
    final f = _cache[id];
    if (f == null) return null;
    if (f.existsSync()) return f;
    _cache.remove(id); // stale (temp wiped) — drop it.
    return null;
  }

  void put(String id, File file) => _cache[id] = file;

  void remove(String id) {
    _cache.remove(id);
    _inflight.remove(id);
  }

  void clear() {
    _cache.clear();
    _inflight.clear();
  }

  /// Ensures a preview exists for [item], generating it from the encrypted file
  /// on a cache miss. Concurrent callers for the same id share one future.
  Future<File?> ensure(VideoItem item) {
    final hit = peek(item.id);
    if (hit != null) return Future.value(hit);
    final existing = _inflight[item.id];
    if (existing != null) return existing;
    final future = _generate(item).then((file) {
      _inflight.remove(item.id);
      if (file != null) _cache[item.id] = file;
      return file;
    });
    _inflight[item.id] = future;
    return future;
  }

  Future<File?> _generate(VideoItem item) async {
    if (item.isLocked) return null;
    try {
      if (item.type == 'image') {
        final path = item.encrypted
            ? await VaultCrypto.instance.decryptToTemp(item.path)
            : item.path;
        final f = File(path);
        return await f.exists() ? f : null;
      }
      if (item.type == 'video') {
        final videoPath = item.encrypted
            ? await VaultCrypto.instance.decryptToTemp(item.path)
            : item.path;
        final dir = await VaultCrypto.instance.previewTempDir();
        final thumbPath = await VideoThumbnail.thumbnailFile(
          video: videoPath,
          thumbnailPath: dir.path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 256,
          quality: 55,
        );
        if (thumbPath == null) return null;
        final t = File(thumbPath);
        return await t.exists() ? t : null;
      }
    } catch (_) {
      // Fall back to the type icon on any decrypt/extract failure.
    }
    return null;
  }

  /// Primes the cache straight from the plaintext [source] at import time, so
  /// the preview is ready before the item ever appears on screen. Images are
  /// copied synchronously (fast, and avoids a race with original-deletion);
  /// videos have a first frame extracted in the background from the encrypted
  /// file via [ensure]. No-ops for types without previews (audio/documents).
  Future<void> primeFromSource({
    required VideoItem item,
    required File source,
    required Directory previewDir,
  }) async {
    try {
      if (item.type == 'image') {
        final ext = p.extension(source.path);
        final dest = File(p.join(previewDir.path, 'thumb_${item.id}$ext'));
        source.copySync(dest.path);
        _cache[item.id] = dest;
      } else if (item.type == 'video') {
        unawaited(ensure(item));
      }
    } catch (_) {
      // A failed prime just means the thumbnail loads lazily later.
    }
  }
}
