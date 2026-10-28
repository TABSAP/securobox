import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:video_thumbnail/video_thumbnail.dart';

import 'package:video_player_app/models/app_models.dart';
import 'package:video_player_app/utils/vault_crypto.dart';

class ThumbnailCache {
  ThumbnailCache._();
  static final ThumbnailCache instance = ThumbnailCache._();

  final Map<String, File> _cache = {};
  final Map<String, Future<File?>> _inflight = {};

  File? peek(String id) {
    final f = _cache[id];
    if (f == null) return null;
    if (f.existsSync()) return f;
    _cache.remove(id);
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
            ? await VaultCrypto.instance.decryptToTemp(
                item.path,
                formatVersion: item.encryptionVersion,
              )
            : item.path;
        final f = File(path);
        return await f.exists() ? f : null;
      }
      if (item.type == 'video') {
        final videoPath = item.encrypted
            ? await VaultCrypto.instance.decryptToTemp(
                item.path,
                formatVersion: item.encryptionVersion,
              )
            : item.path;
        final dir = await VaultCrypto.instance.previewTempDir();
        for (final timeMs in const [1000, 0]) {
          final thumbPath = await VideoThumbnail.thumbnailFile(
            video: videoPath,
            thumbnailPath: dir.path,
            imageFormat: ImageFormat.JPEG,
            maxWidth: 256,
            quality: 65,
            timeMs: timeMs,
          );
          if (thumbPath == null) continue;
          final thumbnail = File(thumbPath);
          if (await thumbnail.exists() && await thumbnail.length() > 0) {
            return thumbnail;
          }
        }
      }
    } catch (_) {}
    return null;
  }

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
    } catch (_) {}
  }
}
