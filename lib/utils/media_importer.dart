import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:video_player_app/utils/import_settings.dart';
import 'package:video_player_app/utils/title_helper.dart';
import 'package:video_player_app/utils/vault_context.dart';
import 'package:video_player_app/utils/vault_crypto.dart';

class ImportResult {
  final int added;
  final int deletedOriginals;
  final bool deleteOriginalsRequested;
  ImportResult({
    required this.added,
    required this.deletedOriginals,
    required this.deleteOriginalsRequested,
  });
}

/// A file chosen via the system picker, paired with the picker's platform
/// identifier (on Android, the source content URI) when one is available.
/// The identifier embeds the exact MediaStore id, so the importer can delete
/// the precise gallery asset instead of guessing it back by name + size.
class PickedMedia {
  final File file;
  final String? identifier;
  const PickedMedia(this.file, {this.identifier});
}

/// Bridges the file picker output to the encrypted vault library. Each file is
/// AES-encrypted via [VaultCrypto], appended to the routed library list, and
/// (when import settings allow) the source file is wiped so the import is
/// invisible to the system gallery / file manager.
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

  /// Imports [items] into the vault. When [category] is null the category is
  /// derived from each file's extension. Calls [onProgress] after every file
  /// so callers can drive a progress UI.
  ///
  /// When delete-originals is enabled, the picker's temp copy is always
  /// removed and the matching gallery asset id (image / audio) is collected,
  /// then deleted as a single batch at the end — that keeps the Android 11+
  /// system delete sheet to a single prompt for the whole import. Videos are
  /// deliberately excluded, so a video-only import raises no delete sheet.
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
    // Videos are intentionally left in the gallery — removing them would
    // raise the system "Delete these items?" sheet, which is suppressed for
    // video imports. Only images and audio are routed to MediaStore deletion.
    const galleryTypes = {'image', 'audio'};

    int added = 0;
    int deletedOriginals = 0;
    final pendingGalleryIds = <String>[];

    for (int i = 0; i < items.length; i++) {
      final f = items[i].file;
      try {
        final encrypted = await VaultCrypto.instance.importEncrypted(f);
        final fileType = detectTypeFromPath(f.path);
        final cat = category ?? defaultCategoryForType(fileType);
        final title = TitleHelper.smartName(f.path, type: fileType);
        final ts = DateTime.now().millisecondsSinceEpoch + i;
        list.add(
          '$ts|$title|$encrypted|$fileType|false|$cat|false||true|false',
        );
        added++;

        if (deleteOriginals) {
          if (galleryTypes.contains(fileType)) {
            final id = await ImportSettings.instance.findGalleryAssetId(
              f,
              identifier: items[i].identifier,
            );
            if (id != null && !pendingGalleryIds.contains(id)) {
              pendingGalleryIds.add(id);
            }
          }
          await ImportSettings.instance.deleteOriginal(f);
        }
      } catch (_) {}
      onProgress?.call(i + 1, items.length);
    }

    await prefs.setStringList(libKey, list);

    if (deleteOriginals && pendingGalleryIds.isNotEmpty) {
      final removed = await ImportSettings.instance.deleteGalleryAssets(
        pendingGalleryIds,
      );
      deletedOriginals = removed.length;
    }

    return ImportResult(
      added: added,
      deletedOriginals: deletedOriginals,
      deleteOriginalsRequested: deleteOriginals,
    );
  }

  /// Re-labels every library item currently filed under category [from] to
  /// [to]. Used when a custom category is renamed (from → new name) or
  /// deleted (from → 'Others'). Returns how many items were changed.
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
