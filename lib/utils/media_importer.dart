import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:video_player_app/models/app_models.dart';
import 'package:video_player_app/services/media_service.dart';
import 'package:video_player_app/utils/import_settings.dart';
import 'package:video_player_app/utils/thumbnail_cache.dart';
import 'package:video_player_app/utils/title_helper.dart';
import 'package:video_player_app/utils/vault_context.dart';
import 'package:video_player_app/utils/vault_crypto.dart';

class ImportResult {
  final int added;
  final int failed;
  final int deletedOriginals;
  final bool deleteOriginalsRequested;
  ImportResult({
    required this.added,
    required this.failed,
    required this.deletedOriginals,
    required this.deleteOriginalsRequested,
  });
}

class PickedMedia {
  final File file;
  final String? identifier;
  final String? galleryAssetId;
  final String? originalName;
  // Where this file came from: 'gallery' | 'camera' | 'file'. And the device
  // album relative path to restore it to on unlock (e.g. 'DCIM/Camera').
  final String? origin;
  final String? originAlbum;
  const PickedMedia(
    this.file, {
    this.identifier,
    this.galleryAssetId,
    this.originalName,
    this.origin,
    this.originAlbum,
  });
}

class MediaImporter {
  MediaImporter._();
  static final MediaImporter instance = MediaImporter._();

  static const _videoExts = {
    'mp4', 'mov', 'avi', 'mkv', 'wmv', 'flv', 'm4v', 'webm', '3gp', 'mpg',
    'mpeg', 'ts', 'mts', 'm2ts',
  };
  static const _imageExts = {
    'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'heic', 'heif', 'tiff', 'tif',
    'svg', 'ico',
  };
  static const _audioExts = {
    'mp3', 'wav', 'aac', 'flac', 'ogg', 'oga', 'm4a', 'm4b', 'm4p', 'wma',
    'aiff', 'aif', 'alac', 'opus', 'amr', 'mka', 'mid', 'midi', 'ape', 'ac3',
    'dts', 'ra', 'rm', '3ga', 'caf',
  };
  static const _docExts = {
    'pdf', 'doc', 'docx', 'txt', 'ppt', 'pptx', 'xls', 'xlsx', 'rtf', 'csv',
    'odt', 'ods', 'odp', 'xml', 'html', 'htm', 'epub', 'mobi', 'tex', 'md',
  };

  /// Document file extensions (no leading dots, lowercase), exposed so the
  /// file picker can restrict a Documents import to real document types.
  static List<String> get docExtensions => _docExts.toList();

  String detectTypeFromPath(String path) {
    final ext = p.extension(path).toLowerCase().replaceFirst('.', '');
    if (_videoExts.contains(ext)) return 'video';
    if (_imageExts.contains(ext)) return 'image';
    if (_audioExts.contains(ext)) return 'audio';
    if (_docExts.contains(ext)) return 'document';
    return 'other';
  }

  String defaultCategoryForType(String type) {
    switch (type) {
      case 'video':
        return 'Videos';
      case 'image':
        return 'Photos';
      case 'audio':
        return 'Audio';
      case 'document':
        return 'Documents';
      default:
        return 'Others';
    }
  }

  Future<ImportResult> importFiles({
    required List<PickedMedia> items,
    String? category,
    void Function(int done, int total)? onProgress,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final libKey = VaultContext.instance.libraryKey;
    final list = prefs.getStringList(libKey) ?? [];
    final deleteOriginals = await ImportSettings.instance
        .deleteOriginalsEnabled();
    const galleryTypes = {'image', 'audio', 'video'};
    // Resolved once so previews can be primed synchronously inside the loop.
    final previewDir = await VaultCrypto.instance.previewTempDir();

    int added = 0;
    int failed = 0;
    int deletedOriginals = 0;
    final pendingGalleryIds = <String>[];

    for (int i = 0; i < items.length; i++) {
      final f = items[i].file;
      try {
        final encrypted = await VaultCrypto.instance.importEncrypted(f);
        final fileType = detectTypeFromPath(f.path);
        final cat = category ?? defaultCategoryForType(fileType);
        final original = items[i].originalName;
        final title = (original != null && original.trim().isNotEmpty)
            ? TitleHelper.originalName(original, type: fileType)
            : TitleHelper.smartName(f.path, type: fileType);
        final ts = DateTime.now().millisecondsSinceEpoch + i;
        final item = VideoItem(
          id: '$ts',
          title: title,
          path: encrypted,
          type: fileType,
          isLocked: false,
          category: cat,
          encrypted: true,
          origin: items[i].origin ?? '',
          originAlbum: items[i].originAlbum ?? '',
        );
        list.add(item.toStorageString());
        added++;

        // Prime the preview now (source still in hand) so the thumbnail shows
        // instantly when the item appears — no refresh or lazy load needed.
        await ThumbnailCache.instance.primeFromSource(
          item: item,
          source: f,
          previewDir: previewDir,
        );

        if (deleteOriginals && galleryTypes.contains(fileType)) {
          final directId = items[i].galleryAssetId;
          if (directId != null && directId.isNotEmpty) {
            if (!pendingGalleryIds.contains(directId)) {
              pendingGalleryIds.add(directId);
            }
          } else {
            final id = await ImportSettings.instance.findGalleryAssetId(
              f,
              identifier: items[i].identifier,
            );
            if (id != null && !pendingGalleryIds.contains(id)) {
              pendingGalleryIds.add(id);
            }
          }
        }
        await ImportSettings.instance.deleteOriginal(f);
      } catch (_) {
        failed++;
      }
      onProgress?.call(i + 1, items.length);
    }

    await prefs.setStringList(libKey, list);
    if (added > 0) MediaService.notifyChanged();

    if (deleteOriginals && pendingGalleryIds.isNotEmpty) {
      final removed = await ImportSettings.instance.deleteGalleryAssets(
        pendingGalleryIds,
      );
      deletedOriginals = removed.length;
    }

    return ImportResult(
      added: added,
      failed: failed,
      deletedOriginals: deletedOriginals,
      deleteOriginalsRequested: deleteOriginals,
    );
  }

  Future<int> moveCategoryItems(String from, String to) async {
    if (from == to) return 0;
    final prefs = await SharedPreferences.getInstance();
    final libKey = VaultContext.instance.libraryKey;
    final list = prefs.getStringList(libKey) ?? [];
    int changed = 0;
    for (int i = 0; i < list.length; i++) {
      final parts = list[i].split('|');
      if (parts.length > 5 && parts[5] == from) {
        parts[5] = to;
        list[i] = parts.join('|');
        changed++;
      }
    }
    if (changed > 0) await prefs.setStringList(libKey, list);
    return changed;
  }
}
