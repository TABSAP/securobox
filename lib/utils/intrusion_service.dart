import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'vault_crypto.dart';

class IntrusionEntry {
  final int timestamp;
  final String encryptedPath;

  IntrusionEntry({required this.timestamp, required this.encryptedPath});

  String toStorageString() => '$timestamp|$encryptedPath';

  factory IntrusionEntry.fromStorageString(String s) {
    final parts = s.split('|');
    return IntrusionEntry(
      timestamp: int.tryParse(parts[0]) ?? 0,
      encryptedPath: parts.length > 1 ? parts[1] : '',
    );
  }

  DateTime get when => DateTime.fromMillisecondsSinceEpoch(timestamp);
}

class IntrusionService {
  IntrusionService._();
  static final IntrusionService instance = IntrusionService._();

  static const _kEnabledKey = 'intrusion_enabled';
  static const _kLogKey = 'intrusion_log_v1';
  static const _kSubdir = 'intrusions';

  bool _capturing = false;

  final ValueNotifier<int> logCount = ValueNotifier<int>(0);

  Future<void> refreshCount() async {
    logCount.value = await count();
  }

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kEnabledKey) ?? true;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabledKey, value);
  }

  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  Future<bool> captureSilently() async {
    if (_capturing) return false;
    if (!await isEnabled()) return false;

    final permission = await Permission.camera.status;
    if (!permission.isGranted) return false;

    _capturing = true;
    CameraController? controller;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return false;
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      controller = CameraController(
        front,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      final pic = await controller.takePicture();

      final tempFile = File(pic.path);
      final encryptedPath = await VaultCrypto.instance.importEncrypted(
        tempFile,
        subdir: _kSubdir,
        forceReal: true,
      );

      try {
        await tempFile.delete();
      } catch (_) {}

      final prefs = await SharedPreferences.getInstance();
      final log = prefs.getStringList(_kLogKey) ?? [];
      final entry = IntrusionEntry(
        timestamp: DateTime.now().millisecondsSinceEpoch,
        encryptedPath: encryptedPath,
      );
      log.add(entry.toStorageString());
      await prefs.setStringList(_kLogKey, log);
      logCount.value = log.length;

      return true;
    } catch (_) {
      return false;
    } finally {
      try {
        await controller?.dispose();
      } catch (_) {}
      _capturing = false;
    }
  }

  Future<List<IntrusionEntry>> getLog() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kLogKey) ?? [];
    return raw
        .map(IntrusionEntry.fromStorageString)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<void> deleteEntry(IntrusionEntry entry) async {
    await VaultCrypto.instance.deleteEncryptedFile(entry.encryptedPath);
    final prefs = await SharedPreferences.getInstance();
    final log = prefs.getStringList(_kLogKey) ?? [];
    log.removeWhere((s) => s.startsWith('${entry.timestamp}|'));
    await prefs.setStringList(_kLogKey, log);
    logCount.value = log.length;
  }

  Future<void> clearAll() async {
    final entries = await getLog();
    for (final e in entries) {
      await VaultCrypto.instance.deleteEncryptedFile(e.encryptedPath);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLogKey);
    logCount.value = 0;
  }

  Future<int> count() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kLogKey) ?? [];
    return raw.length;
  }
}
