import 'dart:io';

import 'package:flutter/foundation.dart';
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

  static List<String> get docExtensions =>
      FileTypeRegistry.documentExtensions.toList()..sort();

  String detectTypeFromPath(String path) =>
      FileTypeRegistry.storageTypeForPath(path);

  String defaultCategoryForType(String type) =>
      FileTypeRegistry.categoryForKind(type);

  Future<ImportResult> importFiles({
    required List<PickedMedia> items,
    String? category,
    bool? deleteOriginalsOverride,
    void Function(int done, int total)? onProgress,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final libKey = VaultContext.instance.libraryKey;
    final list = prefs.getStringList(libKey) ?? [];
    final deleteOriginals =
        deleteOriginalsOverride ??
        await ImportSettings.instance.deleteOriginalsEnabled();
    const galleryTypes = {'image', 'audio', 'video'};
    final previewDir = await VaultCrypto.instance.previewTempDir();

    int added = 0;
    int failed = 0;
    int deletedOriginals = 0;
    final pendingGalleryIds = <String>[];
    final pendingOriginalDeletes = <File>[];
    final importedPaths = <String>[];

    for (int i = 0; i < items.length; i++) {
      final f = items[i].file;
      String? storedPath;
      try {
        final originalName = items[i].originalName;
        final typeSource = originalName?.trim().isNotEmpty == true
            ? originalName!
            : f.path;
        final fileType = detectTypeFromPath(typeSource);
        storedPath = await VaultCrypto.instance.importEncrypted(
          f,
          fileName: originalName,
        );
        final cat = category ?? defaultCategoryForType(fileType);
        final original = originalName;
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
          encrypted: true,
          encryptionVersion: 1,
          origin: items[i].origin ?? '',
          originAlbum: items[i].originAlbum ?? '',
        );
        try {
          await ThumbnailCache.instance.primeFromSource(
            item: item,
            source: f,
            previewDir: previewDir,
          );
        } catch (error) {
          if (kDebugMode) debugPrint('Thumbnail generation failed: $error');
        }

        if (deleteOriginals && galleryTypes.contains(fileType)) {
          final directId = items[i].galleryAssetId;
          if (directId != null && directId.isNotEmpty) {
            if (!pendingGalleryIds.contains(directId)) {
              pendingGalleryIds.add(directId);
            }
          } else {
            try {
              final id = await ImportSettings.instance.findGalleryAssetId(
                f,
                identifier: items[i].identifier,
              );
              if (id != null && !pendingGalleryIds.contains(id)) {
                pendingGalleryIds.add(id);
              }
            } catch (error) {
              if (kDebugMode) debugPrint('Gallery lookup failed: $error');
            }
          }
        }
        list.add(item.toStorageString());
        importedPaths.add(storedPath);
        added++;
        if (deleteOriginals) pendingOriginalDeletes.add(f);
      } catch (_) {
        failed++;
        if (storedPath != null) {
          await VaultCrypto.instance.deleteEncryptedFile(storedPath);
        }
      }
      onProgress?.call(i + 1, items.length);
    }

    try {
      await prefs.setStringList(libKey, list);
    } catch (_) {
      for (final path in importedPaths) {
        await VaultCrypto.instance.deleteEncryptedFile(path);
      }
      rethrow;
    }
    if (added > 0) MediaService.notifyChanged();

    if (deleteOriginals) {
      for (final original in pendingOriginalDeletes) {
        await ImportSettings.instance.deleteOriginal(original);
      }
    }

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

  Future<void> migrateLegacyDocumentTypes() async {
    final prefs = await SharedPreferences.getInstance();
    final libKey = VaultContext.instance.libraryKey;
    final list = prefs.getStringList(libKey) ?? [];
    const legacyTypes = {'archive', 'code', 'ebook', 'font'};
    const legacyCategories = {'archives', 'code', 'ebooks', 'fonts'};

    var changed = false;
    for (int i = 0; i < list.length; i++) {
      final parts = list[i].split('|');
      if (parts.length < 6) continue;
      var itemChanged = false;
      if (legacyTypes.contains(parts[3])) {
        parts[3] = 'document';
        itemChanged = true;
      }
      if (legacyCategories.contains(parts[5].toLowerCase())) {
        parts[5] = 'Documents';
        itemChanged = true;
      }
      if (itemChanged) {
        list[i] = parts.join('|');
        changed = true;
      }
    }
    if (changed) {
      await prefs.setStringList(libKey, list);
      MediaService.notifyChanged();
    }
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
