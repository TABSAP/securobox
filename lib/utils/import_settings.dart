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
    return prefs.getBool(_kDeleteOriginalsKey) ?? true;
  }

  Future<void> setDeleteOriginalsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDeleteOriginalsKey, value);
  }

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

  String? _galleryIdFromIdentifier(String? identifier) {
    if (identifier == null || identifier.isEmpty) return null;
    final decoded = Uri.decodeFull(identifier);
    final doc = RegExp(
      r'document/(?:image|video|audio):(\d+)',
      caseSensitive: false,
    ).firstMatch(decoded);
    if (doc != null) return doc.group(1);
    final media = RegExp(r'/media/(\d+)(?:[/?#]|$)').firstMatch(decoded);
    if (media != null) return media.group(1);
    return null;
  }

  Future<String?> findGalleryAssetId(File source, {String? identifier}) async {
    if (!await _ensureGalleryPermission()) return null;

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
      final paths = await PhotoManager.getAssetPathList(
        type: RequestType.all,
        hasAll: true,
      );
      if (paths.isEmpty) return null;
      final all = paths.firstWhere(
        (e) => e.isAll,
        orElse: () => paths.first,
      );
      final total = await all.assetCountAsync;
      if (total == 0) return null;

      final scanLimit = total > _galleryScanCap ? _galleryScanCap : total;
      int scanned = 0;
      int page = 0;
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
          nameOnlyMatch ??= asset.id;
        }

        scanned += assets.length;
        page++;
      }
      return nameOnlyMatch;
    } catch (_) {}
    return null;
  }

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
