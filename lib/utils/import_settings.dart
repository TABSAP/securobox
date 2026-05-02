import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeletionResult {
  final int requested;
  final int deleted;
  final bool needsManualOnIos;
  DeletionResult({
    required this.requested,
    required this.deleted,
    required this.needsManualOnIos,
  });
}

class ImportSettings {
  ImportSettings._();
  static final ImportSettings instance = ImportSettings._();

  static const _kDeleteOriginalsKey = 'delete_originals_v1';

  Future<bool> deleteOriginalsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kDeleteOriginalsKey) ?? false;
  }

  Future<void> setDeleteOriginalsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDeleteOriginalsKey, value);
  }

  /// Best-effort: try to remove the source file at its OS path AND, when
  /// the file looks like it came from the system Photos library, ask
  /// PhotoManager to delete the matching asset (which on iOS triggers the
  /// native delete-photos confirmation).
  ///
  /// Returns whether the source path was successfully removed (or was
  /// already gone).
  Future<bool> deleteOriginal(File source) async {
    final origPath = source.path;
    final origName = p.basename(origPath);
    int origSize = 0;
    try {
      origSize = await source.length();
    } catch (_) {}

    bool fileGone = false;
    try {
      if (await source.exists()) {
        await source.delete();
      }
      fileGone = true;
    } catch (_) {}

    if (!Platform.isIOS) return fileGone;

    // iOS: file_picker returns a temp copy, so the line above only deletes
    // the copy. Try to find the matching PHAsset and request deletion.
    try {
      final permission = await Permission.photos.status;
      if (!permission.isGranted) return fileGone;

      final paths = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        hasAll: true,
      );
      if (paths.isEmpty) return fileGone;

      final all = paths.first;
      final total = await all.assetCountAsync;
      final scanLimit = total > 200 ? 200 : total;
      final assets = await all.getAssetListRange(start: 0, end: scanLimit);

      String? matchId;
      for (final asset in assets) {
        final title = await asset.titleAsync;
        if (title.toLowerCase() != origName.toLowerCase()) continue;
        if (origSize > 0) {
          final assetFile = await asset.file;
          if (assetFile != null) {
            final assetSize = await assetFile.length();
            if (assetSize != origSize) continue;
          }
        }
        matchId = asset.id;
        break;
      }

      if (matchId != null) {
        await PhotoManager.editor.deleteWithIds([matchId]);
      }
    } catch (_) {}

    return fileGone;
  }
}
