import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:video_player_app/models/app_models.dart';
import 'package:video_player_app/services/media_service.dart';
import 'package:video_player_app/utils/file_type_registry.dart';
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

  /// Document file extensions (no leading dots, lowercase), exposed so the
  /// file picker can restrict a Documents import to real document types.
  static List<String> get docExtensions =>
      FileTypeRegistry.extensionsFor('document').toList();

  String detectTypeFromPath(String path) => FileTypeRegistry.kindForPath(path);

  String defaultCategoryForType(String type) =>
      FileTypeRegistry.categoryForKind(type);

  Future<ImportResult> importFiles({
    required List<PickedMedia> items,
    String? category,
    bool encrypt = true,
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
        final storedPath = encrypt
            ? await VaultCrypto.instance.importEncrypted(f)
            : await VaultCrypto.instance.importPlain(f);
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
          path: storedPath,
          type: fileType,
          isLocked: false,
          category: cat,
          encrypted: encrypt,
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

  /// Lowercased titles of everything currently in the vault, so an import
  /// preview can flag incoming files whose name already exists.
  Future<Set<String>> existingTitlesLower() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(VaultContext.instance.libraryKey) ?? [];
    final set = <String>{};
    for (final s in list) {
      try {
        set.add(VideoItem.fromStorageString(s).title.toLowerCase());
      } catch (_) {}
    }
    return set;
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
