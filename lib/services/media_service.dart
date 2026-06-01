import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:local_auth/local_auth.dart';
import 'package:share_plus/share_plus.dart';

import '../models/app_models.dart';
import '../utils/session_manager.dart';
import '../utils/vault_context.dart';

class MediaService {
  String get _storageKey => VaultContext.instance.libraryKey;
  String get _downloadHistoryKey => VaultContext.instance.downloadHistoryKey;

  /// Gallery album / folder name that downloaded media is filed under.
  static const String galleryAlbum = 'SecuroBox';

  final LocalAuthentication _localAuth = LocalAuthentication();
  List<VideoItem> _mediaList = [];

  List<VideoItem> get mediaList => _mediaList;

  Future<List<VideoItem>> loadMedia() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mediaList = prefs.getStringList(_storageKey) ?? [];

      final loadedList = mediaList
          .map((data) => VideoItem.fromStorageString(data))
          .where((item) => !item.isDeleted)
          .toList()
        ..sort((a, b) => b.id.compareTo(a.id));

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
      final mediaList = prefs.getStringList(_storageKey) ?? [];

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

  Future<bool> toggleMediaLock(VideoItem media) async {
    try {
      final updatedMedia = media.copyWith(isLocked: !media.isLocked);
      final prefs = await SharedPreferences.getInstance();
      final mediaList = prefs.getStringList(_storageKey) ?? [];

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
      final mediaList = prefs.getStringList(_storageKey) ?? [];

      final index = mediaList.indexWhere((item) => item.startsWith(media.id));
      if (index != -1) {
        mediaList[index] = deletedMedia.toStorageString();
        await prefs.setStringList(_storageKey, mediaList);

        _mediaList.removeWhere((item) => item.id == media.id);
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
      final mediaList = prefs.getStringList(_storageKey) ?? [];

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
      final mediaList = prefs.getStringList(_storageKey) ?? [];

      VideoItem? mediaItem;
      try {
        mediaItem = mediaList
            .map((data) => VideoItem.fromStorageString(data))
            .firstWhere((item) => item.id == mediaId);
      } catch (e) {

        mediaItem = null;
      }

      if (mediaItem != null) {
        final file = File(mediaItem.path);
        if (await file.exists()) {
          await file.delete();
        }
      }

      mediaList.removeWhere((item) => item.startsWith(mediaId));
      await prefs.setStringList(_storageKey, mediaList);

      _mediaList.removeWhere((item) => item.id == mediaId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<VideoItem>> getDeletedMedia() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mediaList = prefs.getStringList(_storageKey) ?? [];

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
    // The OS biometric prompt backgrounds/defocuses the app; flag it as a
    // trusted round-trip so resume doesn't auto-lock on top of it and freeze.
    SessionManager.instance.beginTrustedInteraction();
    try {
      final bool canCheck = await _localAuth.canCheckBiometrics;
      final bool supported = await _localAuth.isDeviceSupported();
      if (!canCheck && !supported) return false;
      // Note: getAvailableBiometrics() returns an empty list on many Android
      // devices even when biometrics are enrolled — don't gate on it.
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
      final mediaList = prefs.getStringList(_storageKey) ?? [];

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
      final mediaList = prefs.getStringList(_storageKey) ?? [];

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
