import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/export.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player_app/utils/vault_context.dart';

class VaultCrypto {
  VaultCrypto._();
  static final VaultCrypto instance = VaultCrypto._();

  static String? lastSelfTestResult;

  static const _kKeyLengthBytes = 32;
  static const _kIvLengthBytes = 16;
  static const _kTempPrefix = 'sp_dec_';

  static const _allMasterKeyIds = [
    'vault_master_key_v1',
    'vault_master_key_decoy_v1',
  ];
  static const _allVaultDirNames = ['vault', 'vault_decoy'];
  static const _allTempDirNames = ['sp_decrypted', 'sp_decrypted_decoy'];

  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  Uint8List? _cachedRealKey;
  Uint8List? _cachedDecoyKey;

  Uint8List _randomBytes(int length) {
    final r = Random.secure();
    return Uint8List.fromList(List<int>.generate(length, (_) => r.nextInt(256)));
  }

  Future<Uint8List> _getMasterKey({bool forceReal = false}) async {
    final decoy = !forceReal && VaultContext.instance.isDecoy;
    if (decoy && _cachedDecoyKey != null) return _cachedDecoyKey!;
    if (!decoy && _cachedRealKey != null) return _cachedRealKey!;

    final keyId = decoy ? _allMasterKeyIds[1] : _allMasterKeyIds[0];
    final stored = await _secure.read(key: keyId);
    final Uint8List key;
    if (stored != null) {
      key = base64Decode(stored);
    } else {
      key = _randomBytes(_kKeyLengthBytes);
      await _secure.write(key: keyId, value: base64Encode(key));
    }
    if (decoy) {
      _cachedDecoyKey = key;
    } else {
      _cachedRealKey = key;
    }
    return key;
  }

  Future<Directory> _vaultDir({bool forceReal = false}) async {
    final decoy = !forceReal && VaultContext.instance.isDecoy;
    final name = decoy ? _allVaultDirNames[1] : _allVaultDirNames[0];
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, name));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> _tempDir({bool forceReal = false}) async {
    final decoy = !forceReal && VaultContext.instance.isDecoy;
    final name = decoy ? _allTempDirNames[1] : _allTempDirNames[0];
    final tmp = await getTemporaryDirectory();
    final dir = Directory(p.join(tmp.path, name));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String> importEncrypted(
    File source, {
    String? subdir,
    bool forceReal = false,
  }) async {
    final key = await _getMasterKey(forceReal: forceReal);
    final iv = _randomBytes(_kIvLengthBytes);
    final baseDir = await _vaultDir(forceReal: forceReal);
    final outDir = subdir == null
        ? baseDir
        : await Directory(p.join(baseDir.path, subdir)).create(recursive: true);
    final ext = p.extension(source.path);
    final outName = '${const Uuid().v4()}$ext.enc';
    final outPath = p.join(outDir.path, outName);

    final sourceLength = await source.length();

    await _processFile(
      srcPath: source.path,
      dstPath: outPath,
      key: key,
      iv: iv,
      writeIvHeader: true,
    );

    final outFile = File(outPath);
    final outLength = await outFile.exists() ? await outFile.length() : -1;
    if (outLength != sourceLength + _kIvLengthBytes) {
      try {
        if (await outFile.exists()) await outFile.delete();
      } catch (_) {}
      throw StateError(
        'Encrypted import verification failed for ${source.path}: '
        'expected ${sourceLength + _kIvLengthBytes} bytes, got $outLength.',
      );
    }

    return outPath;
  }

  Future<String> decryptToTemp(
    String encryptedPath, {
    bool forceReal = false,
  }) async {
    final key = await _getMasterKey(forceReal: forceReal);
    final encFile = File(encryptedPath);
    final raf = await encFile.open();
    final iv = await raf.read(_kIvLengthBytes);
    await raf.close();

    if (iv.length != _kIvLengthBytes) {
      throw const FormatException('Encrypted file IV missing or truncated');
    }

    final temp = await _tempDir(forceReal: forceReal);
    final origExt = encryptedPath.endsWith('.enc')
        ? p.extension(encryptedPath.substring(0, encryptedPath.length - 4))
        : p.extension(encryptedPath);
    final outName = '$_kTempPrefix${const Uuid().v4()}$origExt';
    final outPath = p.join(temp.path, outName);

    await _processFile(
      srcPath: encryptedPath,
      dstPath: outPath,
      key: key,
      iv: Uint8List.fromList(iv),
      writeIvHeader: false,
      skipFirstBytes: _kIvLengthBytes,
    );

    return outPath;
  }

  Future<void> wipeTempCache() async {
    try {
      final temp = await _tempDir();
      if (await temp.exists()) {
        await for (final entity in temp.list(recursive: true)) {
          try {
            if (entity is File) await entity.delete();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  Future<void> wipeAllTempCache() async {
    try {
      final tmp = await getTemporaryDirectory();
      for (final name in _allTempDirNames) {
        final dir = Directory(p.join(tmp.path, name));
        if (await dir.exists()) {
          await for (final entity in dir.list(recursive: true)) {
            try {
              if (entity is File) await entity.delete();
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }

  Future<void> revokeSession() async {
    _cachedRealKey = null;
    _cachedDecoyKey = null;
    await wipeAllTempCache();
  }

  Future<void> deleteEncryptedFile(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  Future<void> resetAll() async {
    _cachedRealKey = null;
    _cachedDecoyKey = null;
    try {
      final docs = await getApplicationDocumentsDirectory();
      for (final name in _allVaultDirNames) {
        final d = Directory(p.join(docs.path, name));
        if (await d.exists()) await d.delete(recursive: true);
      }
    } catch (_) {}
    try {
      final tmp = await getTemporaryDirectory();
      for (final name in _allTempDirNames) {
        final d = Directory(p.join(tmp.path, name));
        if (await d.exists()) await d.delete(recursive: true);
      }
    } catch (_) {}
    for (final keyId in _allMasterKeyIds) {
      try {
        await _secure.delete(key: keyId);
      } catch (_) {}
    }
  }

  Future<String> selfTest() async {
    final tmp = await getTemporaryDirectory();
    final id = const Uuid().v4();
    final srcPath = p.join(tmp.path, 'sp_test_src_$id');
    final encPath = p.join(tmp.path, 'sp_test_enc_$id');
    final decPath = p.join(tmp.path, 'sp_test_dec_$id');

    try {
      final original = Uint8List.fromList(
        List<int>.generate(70_000, (i) => i % 256),
      );
      await File(srcPath).writeAsBytes(original);

      final key = await _getMasterKey();
      final iv = _randomBytes(_kIvLengthBytes);

      await _processFile(
        srcPath: srcPath,
        dstPath: encPath,
        key: key,
        iv: iv,
        writeIvHeader: true,
      );

      final encSize = await File(encPath).length();
      if (encSize != original.length + _kIvLengthBytes) {
        return 'FAIL: encrypted size $encSize, expected ${original.length + _kIvLengthBytes}';
      }

      final raf = await File(encPath).open();
      final readIv = await raf.read(_kIvLengthBytes);
      await raf.close();

      if (readIv.length != _kIvLengthBytes) {
        return 'FAIL: read IV length ${readIv.length}';
      }
      for (int i = 0; i < _kIvLengthBytes; i++) {
        if (readIv[i] != iv[i]) {
          return 'FAIL: IV header byte $i differs (wrote=${iv[i]}, read=${readIv[i]})';
        }
      }

      await _processFile(
        srcPath: encPath,
        dstPath: decPath,
        key: key,
        iv: Uint8List.fromList(readIv),
        writeIvHeader: false,
        skipFirstBytes: _kIvLengthBytes,
      );

      final decoded = await File(decPath).readAsBytes();
      if (decoded.length != original.length) {
        return 'FAIL: decoded length ${decoded.length}, expected ${original.length}';
      }
      for (int i = 0; i < original.length; i++) {
        if (decoded[i] != original[i]) {
          return 'FAIL: byte $i differs (orig=${original[i]}, dec=${decoded[i]})';
        }
      }
      return 'OK';
    } catch (e, st) {
      return 'FAIL: $e\n$st';
    } finally {
      for (final pth in [srcPath, encPath, decPath]) {
        try {
          final f = File(pth);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
    }
  }

  Future<void> _processFile({
    required String srcPath,
    required String dstPath,
    required Uint8List key,
    required Uint8List iv,
    required bool writeIvHeader,
    int skipFirstBytes = 0,
  }) async {
    return compute(_processFileIsolate, {
      'src': srcPath,
      'dst': dstPath,
      'key': key,
      'iv': iv,
      'header': writeIvHeader,
      'skip': skipFirstBytes,
    });
  }
}

void _processFileIsolate(Map<String, dynamic> args) {
  final src = args['src'] as String;
  final dst = args['dst'] as String;
  final key = args['key'] as Uint8List;
  final iv = args['iv'] as Uint8List;
  final writeIvHeader = args['header'] as bool;
  final skip = args['skip'] as int;

  final cipher = CTRStreamCipher(AESEngine())
    ..init(true, ParametersWithIV<KeyParameter>(KeyParameter(key), iv));

  final input = File(src).openSync();
  final output = File(dst).openSync(mode: FileMode.write);

  try {
    if (writeIvHeader) {
      output.writeFromSync(iv);
    }
    if (skip > 0) {
      input.setPositionSync(skip);
    }
    final buffer = Uint8List(64 * 1024);
    while (true) {
      final read = input.readIntoSync(buffer);
      if (read <= 0) break;
      final chunk = read == buffer.length ? buffer : buffer.sublist(0, read);
      final processed = cipher.process(Uint8List.fromList(chunk));
      output.writeFromSync(processed);
    }
  } finally {
    input.closeSync();
    output.closeSync();
  }
}
