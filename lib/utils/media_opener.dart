import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:video_player_app/archive_viewer_screen/archive_viewer_screen.dart';
import 'package:video_player_app/audio_hear_screen/audio_hear_screen.dart';
import 'package:video_player_app/document_viewer_screen/document_viewer_screen.dart';
import 'package:video_player_app/font_viewer_screen/font_viewer_screen.dart';
import 'package:video_player_app/models/app_models.dart';
import 'package:video_player_app/pdf_reader_screen/pdf_reader_screen.dart';
import 'package:video_player_app/services/media_service.dart';
import 'package:video_player_app/utils/file_type_registry.dart';
import 'package:video_player_app/utils/flush_bar_helper.dart';
import 'package:video_player_app/utils/pin_crypto.dart';
import 'package:video_player_app/utils/vault_crypto.dart';
import 'package:video_player_app/video_player_screen/video_player_screen.dart';
import 'package:video_player_app/widgets/decrypt_gate.dart';
import 'package:video_player_app/widgets/image_viewer_screen.dart';
import 'package:video_player_app/widgets/liquid_bottom_nav.dart';
import 'package:video_player_app/widgets/pin_unlock_dialog.dart';

final MediaService _mediaService = MediaService();

Future<bool> authenticateForProtected(
  BuildContext context,
  String reason, {
  bool requireAuth = false,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final biometricEnabled =
      (prefs.getBool('biometric') ?? false) ||
      (prefs.getBool('biometric_face') ?? false);
  final appLockEnabled = prefs.getBool('appLock') ?? false;

  if (!biometricEnabled && !appLockEnabled) return !requireAuth;

  if (biometricEnabled &&
      await _mediaService.authenticateUser(reason: reason)) {
    return true;
  }
  if (!context.mounted) return false;

  if (appLockEnabled) {
    if (!await PinCrypto.instance.hasPin()) {
      if (context.mounted) {
        FlushBarHelper.flushBarErrorMessage('No PIN is set', context);
      }
      return false;
    }
    final pinLength = await PinCrypto.instance.getPinLength();
    if (!context.mounted) return false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => PinUnlockDialog(pinLength: pinLength),
    );
    return ok == true;
  }

  return false;
}

Future<void> openVaultMedia(
  BuildContext context,
  VideoItem media, {
  VoidCallback? onChanged,
}) async {
  if (media.isLocked) {
    final ok = await authenticateForProtected(
      context,
      'Authenticate to open locked media',
    );
    if (!ok) {
      if (context.mounted) {
        FlushBarHelper.flushBarErrorMessage(
          'Verify with biometrics, Face ID or PIN to open this item',
          context,
        );
      }
      return;
    }
  }

  final resolvedPath = media.encrypted
      ? await VaultCrypto.instance.resolveStoredFilePath(media.path)
      : (media.path.isNotEmpty && await File(media.path).exists())
      ? media.path
      : null;
  if (resolvedPath == null) {
    if (context.mounted) {
      FlushBarHelper.flushBarErrorMessage(
        'This file is missing from the device. Re-import it to open it again.',
        context,
      );
    }
    return;
  }
  if (resolvedPath != media.path) {
    media.path = resolvedPath;
    await _mediaService.updateMediaPath(media.id, resolvedPath);
  }
  if (!context.mounted) return;

  Widget viewerFor(String path) {
    switch (media.type.toLowerCase()) {
      case 'video':
        return VideoPlayerScreen(videoPath: path, videoTitle: media.title);
      case 'image':
        return ImageViewerScreen(path: path, title: media.title);
      case 'audio':
        return AudioPlayerScreen(filePath: path, fileName: media.title);
      default:
        if (p.extension(path).toLowerCase() == '.pdf') {
          return PDFReaderScreen(filePath: path, fileName: media.title);
        }
        switch (FileTypeRegistry.kindForPath(path)) {
          case 'archive':
            return ArchiveViewerScreen(filePath: path, fileName: media.title);
          case 'font':
            return FontViewerScreen(filePath: path, fileName: media.title);
          default:
            return DocumentViewerScreen(filePath: path, fileName: media.title);
        }
    }
  }

  final mediaType = media.type.toLowerCase();
  final hideBottomNav =
      mediaType == 'video' ||
      mediaType == 'audio' ||
      mediaType == 'document' ||
      mediaType == 'pdf';
  final previousBottomNavVisibility = AppNav.bottomBarVisible.value;
  if (hideBottomNav) AppNav.bottomBarVisible.value = false;
  try {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DecryptGate(
          source: media.path,
          encrypted: media.encrypted,
          encryptionVersion: media.encryptionVersion,
          builder: (_, path) => viewerFor(path),
        ),
      ),
    );
  } finally {
    if (hideBottomNav) {
      AppNav.bottomBarVisible.value = previousBottomNavVisibility;
    }
  }
  onChanged?.call();
}
