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
import 'package:video_player_app/video_player_screen/video_player_screen.dart';
import 'package:video_player_app/widgets/decrypt_gate.dart';
import 'package:video_player_app/widgets/image_viewer_screen.dart';
import 'package:video_player_app/widgets/pin_unlock_dialog.dart';

final MediaService _mediaService = MediaService();

/// Authenticates the user before opening a locked item, honouring the same
/// biometric/PIN settings the vault uses elsewhere. Returns true when access is
/// granted (or when no protection is enabled).
Future<bool> authenticateForProtected(
  BuildContext context,
  String reason,
) async {
  final prefs = await SharedPreferences.getInstance();
  final biometricEnabled = (prefs.getBool('biometric') ?? false) ||
      (prefs.getBool('biometric_face') ?? false);
  final appLockEnabled = prefs.getBool('appLock') ?? false;

  if (!biometricEnabled && !appLockEnabled) return true;

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

/// Opens a vault [media] item in the correct in-app viewer, pushed onto the
/// CURRENT navigator. Because it pushes the viewer directly on top of whatever
/// screen the user tapped from (dashboard, a category list, search results),
/// pressing Back returns them to exactly that screen — the back stack stays
/// intuitive no matter where the item was opened from.
///
/// Handles unlocking locked items, decrypting to a temp file, and routing by
/// type (video / image / audio / document, with PDFs and Office/text documents
/// each getting their dedicated viewer). [onChanged] is called after the viewer
/// closes so the caller can refresh (e.g. a video's last-position/thumbnail).
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

  if (media.path.isEmpty || !await File(media.path).exists()) {
    if (context.mounted) {
      FlushBarHelper.flushBarErrorMessage('File not found', context);
    }
    return;
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
        // Everything filed under Documents shares one stored type, so pick the
        // viewer from the file's real extension: PDFs get the PDF reader,
        // archives get the archive listing, fonts get a specimen, and the rest
        // (Word/Excel/PowerPoint, text, code, EPUB/FB2 ebooks, …) go to the
        // document viewer, which degrades gracefully for formats it can't read.
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

  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => DecryptGate(
        source: media.path,
        encrypted: media.encrypted,
        builder: (_, path) => viewerFor(path),
      ),
    ),
  );
  onChanged?.call();
}
