import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ImportSettings {
  ImportSettings._();
  static final ImportSettings instance = ImportSettings._();

  static const _kDeleteOriginalsKey = 'delete_originals_v1';
  static const _galleryScanCap = 2000;
  static const _galleryPageSize = 200;

  Future<bool> deleteOriginalsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    // Off by default: an import never triggers Android's "Allow … to delete?"
    // system prompt unless the user explicitly opts in from Settings.
    return prefs.getBool(_kDeleteOriginalsKey) ?? false;
  }

  Future<void> setDeleteOriginalsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDeleteOriginalsKey, value);
  }

  /// Deletes the picker's cached/temp copy of [source]. file_picker hands us a
  /// path to a copy in the app cache — removing it doesn't touch the original
  /// gallery / file-manager entry. Use [findGalleryAssetId] +
  /// [deleteGalleryAssets] to remove the underlying MediaStore / PHAsset entry.
  Future<bool> deleteOriginal(File source) async {
    try {
      if (await source.exists()) {
        await source.delete();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Pulls the numeric MediaStore id out of a picker [identifier]. file_picker
  /// hands back the source `content://` URI on Android, and every flavour of
  /// that URI — direct MediaStore, the modern Photo Picker, or a SAF document
  /// URI — embeds the media `_id`. Returns null for non-media URIs (e.g. the
  /// downloads provider) so they fall through to the name/size scan.
  String? _galleryIdFromIdentifier(String? identifier) {
    if (identifier == null || identifier.isEmpty) return null;
    final decoded = Uri.decodeFull(identifier);
    // SAF document URI: .../document/image:1234 (or video:/audio:).
    final doc = RegExp(
      r'document/(?:image|video|audio):(\d+)',
      caseSensitive: false,
    ).firstMatch(decoded);
    if (doc != null) return doc.group(1);
    // Direct MediaStore or Photo Picker URI: content://media/.../media/1234.
    final media = RegExp(r'/media/(\d+)(?:[/?#]|$)').firstMatch(decoded);
    if (media != null) return media.group(1);
    return null;
  }

  /// Locates the MediaStore / PHAsset entry that [source] was copied from.
  ///
  /// Fast path: when the picker supplied an [identifier] (the source content
  /// URI), the exact MediaStore id is read straight out of it and confirmed
  /// against the library. Otherwise falls back to matching display-name and
  /// (when possible) byte size. Returns null when the file isn't a known
  /// gallery asset (typical for documents picked via SAF).
  Future<String?> findGalleryAssetId(File source, {String? identifier}) async {
    if (!await _ensureGalleryPermission()) return null;

    // Fast path — exact id straight from the picker, no scanning or guessing.
    final hintedId = _galleryIdFromIdentifier(identifier);
    if (hintedId != null) {
      try {
        final asset = await AssetEntity.fromId(hintedId);
        if (asset != null) return asset.id;
      } catch (_) {}
    }

    final origName = p.basename(source.path);
    if (origName.isEmpty) return null;
    int origSize = 0;
    try {
      origSize = await source.length();
    } catch (_) {}

    try {
      // RequestType.all (not .common) so audio assets are scanned too.
      final paths = await PhotoManager.getAssetPathList(
        type: RequestType.all,
        hasAll: true,
      );
      if (paths.isEmpty) return null;
      // The first path is not always the "All / Recent" album — picking the
      // wrong one means a freshly-picked file is never found.
      final all = paths.firstWhere(
        (e) => e.isAll,
        orElse: () => paths.first,
      );
      final total = await all.assetCountAsync;
      if (total == 0) return null;

      final scanLimit = total > _galleryScanCap ? _galleryScanCap : total;
      int scanned = 0;
      int page = 0;
      // First asset whose name matches but whose byte size couldn't be
      // confirmed — used as a fallback when no exact size match is found.
      String? nameOnlyMatch;

      while (scanned < scanLimit) {
        final remaining = scanLimit - scanned;
        final size = remaining < _galleryPageSize ? remaining : _galleryPageSize;
        final assets = await all.getAssetListPaged(page: page, size: size);
        if (assets.isEmpty) break;

        for (final asset in assets) {
          final title = await asset.titleAsync;
          if (title.toLowerCase() != origName.toLowerCase()) continue;
          if (origSize <= 0) return asset.id;
          try {
            final f = await asset.file;
            if (f != null && await f.length() == origSize) return asset.id;
          } catch (_) {}
          // Name matched but the size check was inconclusive — remember it
          // rather than discarding a probable hit.
          nameOnlyMatch ??= asset.id;
        }

        scanned += assets.length;
        page++;
      }
      return nameOnlyMatch;
    } catch (_) {}
    return null;
  }

  /// Removes the supplied gallery assets. On Android 11+ this triggers the
  /// system "delete these items?" sheet (one prompt per batch); on iOS the
  /// native Photos confirmation. Returns the ids that were actually removed.
  Future<List<String>> deleteGalleryAssets(List<String> ids) async {
    if (ids.isEmpty) return const [];
    try {
      return await PhotoManager.editor.deleteWithIds(ids);
    } catch (_) {
      return const [];
    }
  }

  Future<bool> _ensureGalleryPermission() async {
    try {
      final state = await PhotoManager.requestPermissionExtend();
      return state.hasAccess;
    } catch (_) {
      return false;
    }
  }
}
