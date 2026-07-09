import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:local_auth/local_auth.dart';
import 'package:share_plus/share_plus.dart';

import '../models/app_models.dart';
import '../utils/session_manager.dart';
import '../utils/thumbnail_cache.dart';
import '../utils/vault_context.dart';

List<VideoItem> _parseActiveMedia(List<String> raw) {
  final list = <VideoItem>[];
  for (final data in raw) {
    final item = VideoItem.fromStorageString(data);
    if (!item.isDeleted) list.add(item);
  }
  list.sort((a, b) => b.id.compareTo(a.id));
  return list;
}

class MediaService {
  String get _storageKey => VaultContext.instance.libraryKey;
  String get _downloadHistoryKey => VaultContext.instance.downloadHistoryKey;

  static final ValueNotifier<int> revision = ValueNotifier<int>(0);
  static void notifyChanged() => revision.value++;

  static const String galleryAlbum = 'SecuroBox';

  final LocalAuthentication _localAuth = LocalAuthentication();
  List<VideoItem> _mediaList = [];

  List<VideoItem> get mediaList => _mediaList;

  /// Step-by-step trace of the restore pipeline.
  ///
  /// Uses [debugPrint] (not `developer.log`, which only reaches the VM service)
  /// so every step is visible in `adb logcat` and `flutter logs`.
  static void _log(String message) => debugPrint('[SecuroBox.Restore] $message');

  /// Reads the raw library as a **mutable** list.
  ///
  /// `SharedPreferences.getStringList` may hand back an unmodifiable view, and
  /// mutating it throws `Unsupported operation: Cannot remove from an
  /// unmodifiable list`. Every writer must go through this.
  Future<List<String>> _readRawLibrary(SharedPreferences prefs) async =>
      List<String>.from(prefs.getStringList(_storageKey) ?? const <String>[]);

  Future<List<VideoItem>> loadMedia() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_storageKey) ?? [];

      final loadedList = raw.length > 250
          ? await compute(_parseActiveMedia, raw)
          : _parseActiveMedia(raw);

      _mediaList = loadedList;
      return loadedList;
    } catch (e) {
      return [];
    }
  }

  Future<bool> saveMedia(List<VideoItem> mediaList) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mediaStrings = mediaList.map((v) => v.toStorageString()).toList();
      await prefs.setStringList(_storageKey, mediaStrings);
      _mediaList = mediaList;
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateMediaCategory(VideoItem media, String newCategory) async {
    try {
      final updatedMedia = media.copyWith(category: newCategory);
      final prefs = await SharedPreferences.getInstance();
      final mediaList = await _readRawLibrary(prefs);

      final index = mediaList.indexWhere((item) => item.startsWith(media.id));
      if (index != -1) {
        mediaList[index] = updatedMedia.toStorageString();
        await prefs.setStringList(_storageKey, mediaList);

        final localIndex = _mediaList.indexWhere((item) => item.id == media.id);
        if (localIndex != -1) {
          _mediaList[localIndex] = updatedMedia;
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<VideoItem?> setFavorite(VideoItem media, bool value) async {
    try {
      final updatedMedia = media.copyWith(isFavorite: value);
      final prefs = await SharedPreferences.getInstance();
      final mediaList = await _readRawLibrary(prefs);

      final index = mediaList.indexWhere((item) => item.startsWith(media.id));
      if (index == -1) return null;
      mediaList[index] = updatedMedia.toStorageString();
      await prefs.setStringList(_storageKey, mediaList);

      final localIndex = _mediaList.indexWhere((item) => item.id == media.id);
      if (localIndex != -1) _mediaList[localIndex] = updatedMedia;
      // Let listeners (e.g. the dashboard Favorites count) update in real time.
      notifyChanged();
      return updatedMedia;
    } catch (e) {
      return null;
    }
  }

  Future<bool> toggleMediaLock(VideoItem media) async {
    try {
      final updatedMedia = media.copyWith(isLocked: !media.isLocked);
      final prefs = await SharedPreferences.getInstance();
      final mediaList = await _readRawLibrary(prefs);

      final index = mediaList.indexWhere((item) => item.startsWith(media.id));
      if (index != -1) {
        mediaList[index] = updatedMedia.toStorageString();
        await prefs.setStringList(_storageKey, mediaList);

        final localIndex = _mediaList.indexWhere((item) => item.id == media.id);
        if (localIndex != -1) {
          _mediaList[localIndex] = updatedMedia;
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> softDeleteMedia(VideoItem media) async {
    try {
      final deletedMedia = media.copyWith(
        isDeleted: true,
        deletedDate: DateTime.now(),
      );

      final prefs = await SharedPreferences.getInstance();
      final mediaList = await _readRawLibrary(prefs);

      final index = mediaList.indexWhere((item) => item.startsWith(media.id));
      if (index != -1) {
        mediaList[index] = deletedMedia.toStorageString();
        await prefs.setStringList(_storageKey, mediaList);

        _mediaList.removeWhere((item) => item.id == media.id);
        // Let listeners update in real time — the dashboard drops the item and
        // the Recycle Bin badge counts it.
        notifyChanged();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> restoreMedia(String mediaId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mediaList = await _readRawLibrary(prefs);

      final index = mediaList.indexWhere((item) => item.startsWith(mediaId));
      if (index != -1) {
        final media = VideoItem.fromStorageString(mediaList[index]);
        final restoredMedia = media.copyWith(
          isDeleted: false,
          deletedDate: null,
        );
        mediaList[index] = restoredMedia.toStorageString();
        await prefs.setStringList(_storageKey, mediaList);

        _mediaList.add(restoredMedia);
        _mediaList.sort((a, b) => b.id.compareTo(a.id));
        // Restoring shrinks the bin — refresh listeners (badge, library).
        notifyChanged();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Permanently removes an item from the vault.
  ///
  /// The library entry is dropped FIRST — that entry is what makes the item
  /// appear in the app, so it must never survive because of a failure while
  /// deleting the encrypted blob. A leftover blob is a harmless disk orphan;
  /// a leftover entry is a ghost the user can see.
  Future<bool> permanentlyDeleteMedia(String mediaId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mediaList = await _readRawLibrary(prefs);

      // Exact id match — `startsWith` would also match an id that merely shares
      // a prefix with this one.
      String? vaultPath;
      final kept = <String>[];
      for (final raw in mediaList) {
        try {
          final item = VideoItem.fromStorageString(raw);
          if (item.id == mediaId) {
            vaultPath = item.path;
            continue; // drop it
          }
        } catch (_) {
          // Unparseable row — keep it rather than silently losing data.
        }
        kept.add(raw);
      }

      if (kept.length == mediaList.length) {
        // Nothing matched: already gone. Treat as success and let the caller
        // refresh, rather than reporting a failure for an absent item.
        _mediaList.removeWhere((item) => item.id == mediaId);
        return true;
      }

      await prefs.setStringList(_storageKey, kept);
      _mediaList.removeWhere((item) => item.id == mediaId);

      // Best effort, and deliberately after the entry is gone.
      if (vaultPath != null && vaultPath.isNotEmpty) {
        try {
          final file = File(vaultPath);
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<VideoItem>> getDeletedMedia() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mediaList = await _readRawLibrary(prefs);

      return mediaList
          .map((data) => VideoItem.fromStorageString(data))
          .where((item) => item.isDeleted)
          .toList()
        ..sort((a, b) {
          if (a.deletedDate == null) return 1;
          if (b.deletedDate == null) return -1;
          return b.deletedDate!.compareTo(a.deletedDate!);
        });
    } catch (e) {
      return [];
    }
  }

  Future<bool> authenticateUser({String reason = 'Authenticate to access locked media'}) async {
    SessionManager.instance.beginTrustedInteraction();
    try {
      final bool canCheck = await _localAuth.canCheckBiometrics;
      final bool supported = await _localAuth.isDeviceSupported();
      if (!canCheck && !supported) return false;
      return await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        sensitiveTransaction: true,
        persistAcrossBackgrounding: true,
      );
    } catch (e) {
      return false;
    } finally {
      SessionManager.instance.endTrustedInteraction();
    }
  }

  Future<bool> renameMedia(VideoItem media, String newName) async {
    try {
      if (newName.trim().isEmpty) {
        return false;
      }

      final safeFileName = newName.trim().replaceAll(RegExp(r'[<>:"/\\|?*]'), '');
      if (safeFileName.isEmpty) {
        return false;
      }

      final file = File(media.path);
      if (!await file.exists()) {

        final foundPath = await findActualFilePath(media.title);
        if (foundPath.isEmpty) {
          return false;
        }

        final updatedMedia = media.copyWith(path: foundPath);
        await updateMediaPath(media.id, foundPath);
        return await renameMedia(updatedMedia, newName);
      }

      final directory = file.parent;
      final extension = media.path.split('.').last;

      final newPath = '${directory.path}/$safeFileName.$extension';

      if (await File(newPath).exists()) {
        return false;
      }

      await file.rename(newPath);

      final prefs = await SharedPreferences.getInstance();
      final mediaList = await _readRawLibrary(prefs);

      final index = mediaList.indexWhere((item) => item.startsWith(media.id));
      if (index != -1) {

        final oldMedia = VideoItem.fromStorageString(mediaList[index]);
        final updatedMedia = oldMedia.copyWith(
          title: safeFileName,
          path: newPath,
        );

        mediaList[index] = updatedMedia.toStorageString();
        await prefs.setStringList(_storageKey, mediaList);

        final localIndex = _mediaList.indexWhere((item) => item.id == media.id);
        if (localIndex != -1) {
          _mediaList[localIndex] = updatedMedia;
        }

        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateMediaPath(String mediaId, String newPath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mediaList = await _readRawLibrary(prefs);

      final index = mediaList.indexWhere((item) => item.startsWith(mediaId));
      if (index != -1) {
        final media = VideoItem.fromStorageString(mediaList[index]);
        final updatedMedia = media.copyWith(path: newPath);
        mediaList[index] = updatedMedia.toStorageString();
        await prefs.setStringList(_storageKey, mediaList);

        final localIndex = _mediaList.indexWhere((item) => item.id == mediaId);
        if (localIndex != -1) {
          _mediaList[localIndex] = updatedMedia;
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<String> findActualFilePath(String fileName) async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final appDocPath = appDocDir.path;

      final possibleDirs = [
        appDocPath,
        '$appDocPath/secure_player',
        '$appDocPath/secure_player/videos',
        '$appDocPath/videos',
        '/storage/emulated/0/Movies/$galleryAlbum',
        '/storage/emulated/0/Pictures/$galleryAlbum',
        '/storage/emulated/0/Music/$galleryAlbum',
        '/storage/emulated/0/Download/$galleryAlbum',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Download/SecureVideo',
        '/storage/emulated/0/Movies',
        '/storage/emulated/0/Movies/SecureVideo',
        '/storage/emulated/0/Pictures',
        '/storage/emulated/0/Pictures/SecureImages',
        '/storage/emulated/0/DCIM/Camera',
        '/storage/emulated/0/Music',
        '/storage/emulated/0/Music/SecureVideo',
      ];

      for (final dirPath in possibleDirs) {
        try {
          final dir = Directory(dirPath);
          if (await dir.exists()) {

            final files = dir.listSync().whereType<File>().toList();

            final baseName = fileName.split('.').first;
            for (final file in files) {
              if (file.path.contains(baseName) || file.path.contains(fileName)) {
                return file.path;
              }
            }
          }
        } catch (e) {
          continue;
        }
      }

      await _searchDirectoryRecursively(appDocDir, fileName).then((path) {
        if (path.isNotEmpty) {
          return path;
        }
      });

      return '';
    } catch (e) {
      return '';
    }
  }

  Future<String> _searchDirectoryRecursively(Directory dir, String fileName) async {
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          if (entity.path.contains(fileName) ||
              entity.path.contains(fileName.split('.').first)) {
            return entity.path;
          }
        }
      }
    } catch (_) {}
    return '';
  }

  Future<bool> downloadFile({
    required String filePath,
    required String fileName,
  }) async {
    try {
      final permission = await PhotoManager.requestPermissionExtend();
      if (!permission.isAuth) {
        return false;
      }

      final file = File(filePath);
      if (!await file.exists()) {
        return false;
      }

      final ext = fileName.contains('.')
          ? fileName.split('.').last.toLowerCase()
          : '';

      final fileSize = await file.length();
      final fileSizeStr = _formatBytes(fileSize);

      bool saved = false;

      if (['mp4', 'mkv', 'avi', 'mov', 'webm', '3gp', 'm4v', 'mpg', 'mpeg']
          .contains(ext)) {
        await PhotoManager.editor.saveVideo(
          file,
          title: fileName,
          relativePath: 'Movies/$galleryAlbum',
        );
        saved = true;
      } else if (['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'heic', 'heif']
          .contains(ext)) {
        await PhotoManager.editor.saveImage(
          await file.readAsBytes(),
          title: fileName,
          relativePath: 'Pictures/$galleryAlbum',
          filename: fileName,
        );
        saved = true;
      } else if (Platform.isAndroid) {
        final folder =
            ['mp3', 'wav', 'aac', 'ogg', 'm4a', 'flac', 'opus'].contains(ext)
                ? 'Music/$galleryAlbum'
                : 'Download/$galleryAlbum';
        final dir = Directory('/storage/emulated/0/$folder');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        final newFile = File('${dir.path}/$fileName');
        await file.copy(newFile.path);
        saved = await newFile.exists();
      } else {
        await SharePlus.instance.share(
          ShareParams(files: [XFile(filePath)], subject: fileName),
        );
        saved = true;
      }

      if (saved) {
        await _addToDownloadHistory(
          fileName: fileName,
          filePath: filePath,
          fileSize: fileSizeStr,
        );
      }

      return saved;
    } catch (_) {
      return false;
    }
  }

  /// Saves a (decrypted) file to the device gallery (making it visible again)
  /// and marks the item as unlocked/in-gallery. For photos and videos this
  /// records the created asset id so the item can be hidden again later; other
  /// file types are exported via [downloadFile]. Returns the updated item.
  /// MediaStore only accepts a relative path whose first segment is one of the
  /// standard public directories. Anything else throws
  /// `IllegalArgumentException: Primary directory ... not allowed`.
  static const _allowedPrimaryDirs = {
    'DCIM', 'Pictures', 'Movies', 'Music', 'Download', 'Documents',
    'Alarms', 'Audiobooks', 'Notifications', 'Podcasts', 'Ringtones',
  };

  /// Normalises a stored `originAlbum` into a MediaStore-safe relative path, or
  /// null when it can't be used (absolute path from a different volume, an
  /// unsupported primary directory, empty, …).
  String? _sanitizeAlbum(String raw) {
    var path = raw.trim().replaceAll('\\', '/');
    if (path.isEmpty) return null;
    // `AssetEntity.relativePath` is sometimes an absolute filesystem path.
    path = path.replaceFirst(RegExp(r'^/?storage/emulated/\d+/'), '');
    path = path.replaceFirst(RegExp(r'^/?sdcard/'), '');
    path = path.replaceAll(RegExp(r'^/+|/+$'), '');
    if (path.isEmpty) return null;
    final primary = path.split('/').first;
    if (!_allowedPrimaryDirs.contains(primary)) return null;
    return path;
  }

  /// Albums to try, best first. The original location leads; the platform
  /// default (the Camera album) is always the last resort so a restore never
  /// fails just because the original album is unusable.
  List<String> _albumCandidates(VideoItem media) {
    final candidates = <String>[];
    void add(String? value) {
      if (value != null && value.isNotEmpty && !candidates.contains(value)) {
        candidates.add(value);
      }
    }

    add(_sanitizeAlbum(media.originAlbum));
    if (media.origin == 'camera') add('DCIM/Camera');
    add('DCIM/Camera'); // default for photos and videos
    return candidates;
  }

  /// Writes the decrypted file back onto the device: photos/videos into the
  /// gallery album they came from (falling back to the Camera album), and
  /// everything else into Downloads.
  ///
  /// Returns true only when the file is verifiably on the device. Each album is
  /// attempted independently — a rejection by MediaStore falls through to the
  /// next candidate rather than aborting the whole restore.
  Future<bool> _exportToDevice(
    VideoItem media,
    File file,
    String fileName,
  ) async {
    final ext =
        fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';

    const videoExts = {
      'mp4', 'mkv', 'avi', 'mov', 'webm', '3gp', 'm4v', 'mpg', 'mpeg',
    };
    const imageExts = {
      'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'heic', 'heif',
    };

    final isVideo = videoExts.contains(ext);
    final isImage = imageExts.contains(ext);
    final sourceSize = await file.length();
    _log('export: name=$fileName ext=$ext isVideo=$isVideo isImage=$isImage '
        'src=${file.path} size=$sourceSize origin=${media.origin} '
        'originAlbum="${media.originAlbum}"');

    if (isVideo || isImage) {
      final permission = await PhotoManager.requestPermissionExtend();
      _log('export: permission isAuth=${permission.isAuth} value=$permission');
      if (!permission.isAuth) return false;

      final bytes = isImage ? await file.readAsBytes() : null;
      final candidates = _albumCandidates(media);
      _log('export: album candidates=$candidates');

      for (final album in candidates) {
        try {
          _log('export: trying album="$album"');
          final asset = isVideo
              ? await PhotoManager.editor
                  .saveVideo(file, title: fileName, relativePath: album)
              : await PhotoManager.editor.saveImage(
                  bytes!,
                  title: fileName,
                  relativePath: album,
                  filename: fileName,
                );
          _log('export: saved assetId=${asset.id} relativePath=${asset.relativePath}');
          if (asset.id.isEmpty) continue;

          // Verify the asset is really on disk and readable before we let the
          // caller delete the vault copy.
          final written = await asset.file;
          final exists = written != null && await written.exists();
          final size = exists ? await written.length() : -1;
          _log('export: verify path=${written?.path} exists=$exists size=$size '
              'expected=$sourceSize');
          if (exists && size > 0) return true;

          _log('export: verification FAILED for album="$album", trying next');
        } catch (e) {
          _log('export: album="$album" rejected: $e');
          // Bad primary dir, missing volume, … — fall through to the next one.
        }
      }
      _log('export: all album candidates failed');
      return false;
    }

    // Audio / documents / archives / anything else → Downloads.
    return _exportToDownloads(file, fileName, sourceSize);
  }

  static const MethodChannel _mediaStoreChannel =
      MethodChannel('secure_player/media_store');

  static const Map<String, String> _mimeTypes = {
    'pdf': 'application/pdf',
    'txt': 'text/plain',
    'csv': 'text/csv',
    'rtf': 'application/rtf',
    'doc': 'application/msword',
    'docx':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx':
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'zip': 'application/zip',
    'rar': 'application/vnd.rar',
    '7z': 'application/x-7z-compressed',
    'epub': 'application/epub+zip',
    'json': 'application/json',
    'xml': 'application/xml',
    'mp3': 'audio/mpeg',
    'wav': 'audio/wav',
    'm4a': 'audio/mp4',
    'flac': 'audio/flac',
    'ogg': 'audio/ogg',
  };

  String _mimeTypeFor(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0) return 'application/octet-stream';
    final ext = fileName.substring(dot + 1).toLowerCase();
    return _mimeTypes[ext] ?? 'application/octet-stream';
  }

  /// Copies [file] into the public Downloads folder.
  ///
  /// On Android 10+ scoped storage forbids writing to shared storage with the
  /// File API — the old `Directory('/storage/emulated/0/Download/SecuroBox')
  /// .create()` always threw EACCES. We insert through MediaStore natively
  /// instead, and only fall back to a raw copy on older releases.
  Future<bool> _exportToDownloads(
    File file,
    String fileName,
    int sourceSize,
  ) async {
    if (Platform.isAndroid) {
      final mime = _mimeTypeFor(fileName);
      try {
        _log('downloads: invoking MediaStore saveToDownloads mime=$mime');
        final result = await _mediaStoreChannel
            .invokeMapMethod<String, dynamic>('saveToDownloads', {
          'path': file.path,
          'fileName': fileName,
          'mimeType': mime,
        });
        if (result != null) {
          final uri = result['uri'];
          final bytes = (result['bytes'] as num?)?.toInt() ?? -1;
          _log('downloads: MediaStore uri=$uri bytes=$bytes expected=$sourceSize');
          if (bytes == sourceSize) return true;
          _log('downloads: byte-count mismatch — treating as failure');
        } else {
          _log('downloads: MediaStore returned null (see SecuroBoxRestore tag)');
        }
      } on MissingPluginException catch (e) {
        _log('downloads: native handler MISSING ($e)');
      } on PlatformException catch (e) {
        _log('downloads: PlatformException $e');
      } catch (e) {
        _log('downloads: unexpected $e');
      }

      // Deliberately NO raw-copy fallback: on API 29+ a File-API write to
      // shared storage is either rejected or produces a file that MediaStore
      // never indexes — invisible in Gallery/Files, yet it would look like a
      // success and let us delete the vault copy. The native side already
      // handles pre-Q with a direct copy. Failing here keeps the file safe.
      _log('downloads: FAILED — vault copy will be kept');
      return false;
    }

    // iOS/other: hand off to the share sheet. We cannot verify a write, so we
    // deliberately report failure and keep the vault copy.
    try {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], subject: fileName),
      );
    } catch (_) {}
    _log('downloads: non-Android share sheet — not treated as a verified write');
    return false;
  }

  /// Unlock = restore + remove. Puts [media] back where it came from on the
  /// device, then deletes SecuroBox's encrypted copy so it no longer appears in
  /// the app.
  ///
  /// The vault copy is only ever deleted **after** the export is confirmed, so a
  /// failed or denied restore never loses the file. Returns true on success.
  Future<bool> restoreToDeviceAndRemove(
    VideoItem media,
    String decryptedPath,
    String fileName,
  ) async {
    final file = File(decryptedPath);
    int size = 0;
    _log('=== restore START id=${media.id} title="${media.title}" '
        'type=${media.type} encrypted=${media.encrypted} vaultPath=${media.path}');
    try {
      if (!await file.exists()) {
        _log('restore ABORT: decrypted source missing at $decryptedPath');
        return false;
      }
      size = await file.length();
      _log('restore: decrypted source=$decryptedPath size=$size');
      // Step 1 — restore. If this fails or throws, nothing is removed and the
      // file stays safely encrypted in the vault.
      if (!await _exportToDevice(media, file, fileName)) {
        _log('restore ABORT: export failed — vault copy KEPT');
        return false;
      }
      _log('restore: export VERIFIED on device');
    } catch (e) {
      _log('restore ABORT: exception during export ($e) — vault copy KEPT');
      return false;
    }

    // Step 2 — the file is now verifiably on the device, so the vault copy MUST
    // go. Nothing non-essential below is allowed to abort the removal.
    try {
      await _addToDownloadHistory(
        fileName: fileName,
        filePath: decryptedPath,
        fileSize: _formatBytes(size),
      );
    } catch (_) {
      // Download history is cosmetic — never let it strand a restored file.
    }

    var removed = false;
    try {
      removed = await permanentlyDeleteMedia(media.id);
    } catch (e) {
      _log('restore: permanentlyDeleteMedia threw $e');
      removed = false;
    }

    // Read back: the entry is what makes the item visible, so confirm it is
    // actually gone rather than trusting the return value.
    if (!removed || await _libraryContains(media.id)) {
      _log('restore: entry survived first delete — retrying');
      try {
        removed = await permanentlyDeleteMedia(media.id);
      } catch (e) {
        _log('restore: retry threw $e');
      }
      removed = !await _libraryContains(media.id);
    }

    ThumbnailCache.instance.remove(media.id);
    // Always notify: the library changed on disk either way, and the UI must
    // reflect reality in real time without a manual refresh.
    notifyChanged();
    _log('=== restore END removed=$removed id=${media.id}');
    return removed;
  }

  /// True if [mediaId] still has a library entry on disk.
  Future<bool> _libraryContains(String mediaId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_storageKey) ?? const <String>[];
      for (final row in raw) {
        try {
          if (VideoItem.fromStorageString(row).id == mediaId) return true;
        } catch (_) {}
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Deletes SecuroBox's copy of an item that is already present on the device
  /// (a legacy "unlocked to gallery" item), without exporting it again.
  Future<bool> removeVaultCopy(VideoItem media) async {
    try {
      await permanentlyDeleteMedia(media.id);
      final removed = !await _libraryContains(media.id);
      ThumbnailCache.instance.remove(media.id);
      notifyChanged();
      return removed;
    } catch (_) {
      return false;
    }
  }

  Future<void> _addToDownloadHistory({
    required String fileName,
    required String filePath,
    required String fileSize,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final downloadList = prefs.getStringList(_downloadHistoryKey) ?? [];

      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final date = DateTime.now().toIso8601String();
      final downloadData = '$id|$fileName|$fileSize|completed|$date|$filePath||::1.0';

      downloadList.add(downloadData);
      await prefs.setStringList(_downloadHistoryKey, downloadList);
    } catch (_) {}
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
    int i = 0;
    double bytesDouble = bytes.toDouble();

    while (bytesDouble >= 1024 && i < suffixes.length - 1) {
      bytesDouble /= 1024;
      i++;
    }
    return '${bytesDouble.toStringAsFixed(1)} ${suffixes[i]}';
  }

  Future<List<Map<String, dynamic>>> getDownloadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final downloadList = prefs.getStringList(_downloadHistoryKey) ?? [];

      return downloadList.map((item) {
        final parts = item.split('|');
        return {
          'id': parts[0],
          'fileName': parts[1],
          'fileSize': parts[2],
          'status': parts[3],
          'date': parts[4],
          'filePath': parts[5],
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }
}
