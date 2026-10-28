import 'package:video_player_app/utils/biometric_policy.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:local_auth/local_auth.dart';
import 'package:share_plus/share_plus.dart';

import '../models/app_models.dart';
import '../utils/session_manager.dart';
import '../utils/thumbnail_cache.dart';
import '../utils/vault_context.dart';
import '../utils/vault_crypto.dart';

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

  static void _log(String message) {
    if (kDebugMode) debugPrint('[SecuroBox.Restore] $message');
  }

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

      final index = mediaList.indexWhere(
        (item) => item.split('|').first == media.id,
      );
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

      final index = mediaList.indexWhere(
        (item) => item.split('|').first == media.id,
      );
      if (index == -1) return null;
      mediaList[index] = updatedMedia.toStorageString();
      await prefs.setStringList(_storageKey, mediaList);

      final localIndex = _mediaList.indexWhere((item) => item.id == media.id);
      if (localIndex != -1) _mediaList[localIndex] = updatedMedia;
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
        notifyChanged();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> permanentlyDeleteMedia(String mediaId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mediaList = await _readRawLibrary(prefs);

      String? vaultPath;
      final kept = <String>[];
      for (final raw in mediaList) {
        try {
          final item = VideoItem.fromStorageString(raw);
          if (item.id == mediaId) {
            vaultPath = item.path;
            continue;
          }
        } catch (_) {}
        kept.add(raw);
      }

      if (kept.length == mediaList.length) {
        _mediaList.removeWhere((item) => item.id == mediaId);
        return true;
      }

      await prefs.setStringList(_storageKey, kept);
      _mediaList.removeWhere((item) => item.id == mediaId);

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

  Future<bool> authenticateUser({
    String reason = 'Authenticate to access locked media',
  }) async {
    SessionManager.instance.beginTrustedInteraction();
    try {
      final bool canCheck = await _localAuth.canCheckBiometrics;
      final bool supported = await _localAuth.isDeviceSupported();
      if (!canCheck && !supported) return false;
      return await BiometricPolicy.authenticate(
        _localAuth,
        reason: reason,
        sensitiveTransaction: true,
      );
    } catch (e) {
      return false;
    } finally {
      SessionManager.instance.endTrustedInteraction();
    }
  }

  Future<bool> renameMedia(VideoItem media, String newName) async {
    String? renamedPath;
    String? originalPath;
    try {
      var safeFileName = newName.trim().replaceAll(
        RegExp(r'[<>:"/\\|?*\u0000-\u001F]'),
        '',
      );
      if (safeFileName.isEmpty) {
        return false;
      }

      var oldPath = media.path;
      var file = File(oldPath);
      if (!await file.exists() && media.encrypted) {
        final recovered = await VaultCrypto.instance.resolveStoredFilePath(
          oldPath,
        );
        if (recovered != null) {
          oldPath = recovered;
          file = File(oldPath);
        }
      }
      if (!await file.exists()) return false;

      final encryptedSuffix = media.encrypted && oldPath.endsWith('.enc');
      final unwrappedPath = encryptedSuffix
          ? oldPath.substring(0, oldPath.length - '.enc'.length)
          : oldPath;
      final extension = p.extension(unwrappedPath);
      if (extension.isNotEmpty &&
          safeFileName.toLowerCase().endsWith(extension.toLowerCase())) {
        safeFileName = safeFileName.substring(
          0,
          safeFileName.length - extension.length,
        );
      }
      if (safeFileName.trim().isEmpty) return false;

      final newPath = p.join(
        file.parent.path,
        '$safeFileName$extension${encryptedSuffix ? '.enc' : ''}',
      );
      if (newPath == oldPath) {
        if (oldPath != media.path) await updateMediaPath(media.id, oldPath);
        return true;
      }

      if (await File(newPath).exists()) return false;
      originalPath = oldPath;
      final renamed = await file.rename(newPath);
      renamedPath = renamed.path;

      final prefs = await SharedPreferences.getInstance();
      final mediaList = await _readRawLibrary(prefs);

      final index = mediaList.indexWhere(
        (raw) => raw.startsWith('${media.id}|'),
      );
      if (index < 0) {
        await File(renamedPath).rename(originalPath);
        return false;
      }

      final updatedMedia = VideoItem.fromStorageString(
        mediaList[index],
      ).copyWith(title: safeFileName, path: renamedPath);
      mediaList[index] = updatedMedia.toStorageString();
      final saved = await prefs.setStringList(_storageKey, mediaList);
      if (!saved) {
        await File(renamedPath).rename(originalPath);
        return false;
      }

      final localIndex = _mediaList.indexWhere((item) => item.id == media.id);
      if (localIndex >= 0) _mediaList[localIndex] = updatedMedia;
      return true;
    } catch (_) {
      if (renamedPath != null &&
          originalPath != null &&
          await File(renamedPath).exists() &&
          !await File(originalPath).exists()) {
        try {
          await File(renamedPath).rename(originalPath);
        } catch (_) {}
      }
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
              if (file.path.contains(baseName) ||
                  file.path.contains(fileName)) {
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

  Future<String> _searchDirectoryRecursively(
    Directory dir,
    String fileName,
  ) async {
    try {
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
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

      if ([
        'mp4',
        'mkv',
        'avi',
        'mov',
        'webm',
        '3gp',
        'm4v',
        'mpg',
        'mpeg',
      ].contains(ext)) {
        await PhotoManager.editor.saveVideo(
          file,
          title: fileName,
          relativePath: 'Movies/$galleryAlbum',
        );
        saved = true;
      } else if ([
        'jpg',
        'jpeg',
        'png',
        'webp',
        'gif',
        'bmp',
        'heic',
        'heif',
      ].contains(ext)) {
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

  static const _allowedPrimaryDirs = {
    'DCIM',
    'Pictures',
    'Movies',
    'Music',
    'Download',
    'Documents',
    'Alarms',
    'Audiobooks',
    'Notifications',
    'Podcasts',
    'Ringtones',
  };

  String? _sanitizeAlbum(String raw) {
    var path = raw.trim().replaceAll('\\', '/');
    if (path.isEmpty) return null;
    path = path.replaceFirst(RegExp(r'^/?storage/emulated/\d+/'), '');
    path = path.replaceFirst(RegExp(r'^/?sdcard/'), '');
    path = path.replaceAll(RegExp(r'^/+|/+$'), '');
    if (path.isEmpty) return null;
    final primary = path.split('/').first;
    if (!_allowedPrimaryDirs.contains(primary)) return null;
    return path;
  }

  List<String> _albumCandidates(VideoItem media) {
    final candidates = <String>[];
    void add(String? value) {
      if (value != null && value.isNotEmpty && !candidates.contains(value)) {
        candidates.add(value);
      }
    }

    add(_sanitizeAlbum(media.originAlbum));
    if (media.origin == 'camera') add('DCIM/Camera');
    add('DCIM/Camera');
    return candidates;
  }

  Future<bool> _exportToDevice(
    VideoItem media,
    File file,
    String fileName,
  ) async {
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';

    const videoExts = {
      'mp4',
      'mkv',
      'avi',
      'mov',
      'webm',
      '3gp',
      'm4v',
      'mpg',
      'mpeg',
    };
    const imageExts = {
      'jpg',
      'jpeg',
      'png',
      'webp',
      'gif',
      'bmp',
      'heic',
      'heif',
    };

    final isVideo = videoExts.contains(ext);
    final isImage = imageExts.contains(ext);
    final sourceSize = await file.length();
    _log(
      'export: name=$fileName ext=$ext isVideo=$isVideo isImage=$isImage '
      'src=${file.path} size=$sourceSize origin=${media.origin} '
      'originAlbum="${media.originAlbum}"',
    );

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
              ? await PhotoManager.editor.saveVideo(
                  file,
                  title: fileName,
                  relativePath: album,
                )
              : await PhotoManager.editor.saveImage(
                  bytes!,
                  title: fileName,
                  relativePath: album,
                  filename: fileName,
                );
          _log(
            'export: saved assetId=${asset.id} relativePath=${asset.relativePath}',
          );
          if (asset.id.isEmpty) continue;

          final written = await asset.file;
          final exists = written != null && await written.exists();
          final size = exists ? await written.length() : -1;
          _log(
            'export: verify path=${written?.path} exists=$exists size=$size '
            'expected=$sourceSize',
          );
          if (exists && size > 0) return true;

          _log('export: verification FAILED for album="$album", trying next');
        } catch (e) {
          _log('export: album="$album" rejected: $e');
        }
      }
      _log('export: all album candidates failed');
      return false;
    }

    return _exportToDownloads(file, fileName, sourceSize);
  }

  static const MethodChannel _mediaStoreChannel = MethodChannel(
    'secure_player/media_store',
  );

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
          _log(
            'downloads: MediaStore uri=$uri bytes=$bytes expected=$sourceSize',
          );
          if (bytes == sourceSize) return true;
          _log('downloads: byte-count mismatch — treating as failure');
        } else {
          _log(
            'downloads: MediaStore returned null (see SecuroBoxRestore tag)',
          );
        }
      } on MissingPluginException catch (e) {
        _log('downloads: native handler MISSING ($e)');
      } on PlatformException catch (e) {
        _log('downloads: PlatformException $e');
      } catch (e) {
        _log('downloads: unexpected $e');
      }

      _log('downloads: FAILED — vault copy will be kept');
      return false;
    }

    if (Platform.isIOS) {
      const maxPickerExportBytes = 128 * 1024 * 1024;
      if (sourceSize > maxPickerExportBytes) {
        _log('iOS export: file exceeds safe in-memory export limit');
        return false;
      }
      try {
        final bytes = await file.readAsBytes();
        if (bytes.length != sourceSize) return false;
        final dot = fileName.lastIndexOf('.');
        final extension = dot >= 0 && dot < fileName.length - 1
            ? fileName.substring(dot + 1).toLowerCase()
            : null;
        SessionManager.instance.beginTrustedInteraction();
        try {
          final savedPath = await FilePicker.platform.saveFile(
            fileName: fileName,
            type: extension == null ? FileType.any : FileType.custom,
            allowedExtensions: extension == null ? null : [extension],
            bytes: bytes,
          );
          _log(
            'iOS export: picker result=${savedPath == null ? 'cancelled' : 'saved'}',
          );
          return savedPath != null;
        } finally {
          SessionManager.instance.endTrustedInteraction();
        }
      } catch (e) {
        _log('iOS export: failed ($e)');
        return false;
      }
    }

    try {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], subject: fileName),
      );
    } catch (_) {}
    _log(
      'downloads: non-Android share sheet — not treated as a verified write',
    );
    return false;
  }

  Future<bool> restoreToDeviceAndRemove(
    VideoItem media,
    String decryptedPath,
    String fileName,
  ) async {
    final file = File(decryptedPath);
    int size = 0;
    _log(
      '=== restore START id=${media.id} title="${media.title}" '
      'type=${media.type} encrypted=${media.encrypted} vaultPath=${media.path}',
    );
    try {
      if (!await file.exists()) {
        _log('restore ABORT: decrypted source missing at $decryptedPath');
        return false;
      }
      size = await file.length();
      _log('restore: decrypted source=$decryptedPath size=$size');
      if (!await _exportToDevice(media, file, fileName)) {
        _log('restore ABORT: export failed — vault copy KEPT');
        return false;
      }
      _log('restore: export VERIFIED on device');
    } catch (e) {
      _log('restore ABORT: exception during export ($e) — vault copy KEPT');
      return false;
    }

    try {
      await _addToDownloadHistory(
        fileName: fileName,
        filePath: decryptedPath,
        fileSize: _formatBytes(size),
      );
    } catch (_) {}

    var removed = false;
    try {
      removed = await permanentlyDeleteMedia(media.id);
    } catch (e) {
      _log('restore: permanentlyDeleteMedia threw $e');
      removed = false;
    }

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
    notifyChanged();
    _log('=== restore END removed=$removed id=${media.id}');
    return removed;
  }

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
      final downloadData =
          '$id|$fileName|$fileSize|completed|$date|$filePath||::1.0';

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
