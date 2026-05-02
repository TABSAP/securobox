import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/export.dart';
import 'package:uuid/uuid.dart';

class VaultCrypto {
  VaultCrypto._();
  static final VaultCrypto instance = VaultCrypto._();

  static const _kMasterKey = 'vault_master_key_v1';
  static const _kKeyLengthBytes = 32;
  static const _kIvLengthBytes = 16;
  static const _kChunkBytes = 64 * 1024;
  static const _kTempPrefix = 'sp_dec_';
  static const _kVaultDirName = 'vault';

  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  Uint8List? _cachedKey;

  Uint8List _randomBytes(int length) {
    final r = Random.secure();
    return Uint8List.fromList(List<int>.generate(length, (_) => r.nextInt(256)));
  }

  Future<Uint8List> _getMasterKey() async {
    if (_cachedKey != null) return _cachedKey!;
    final stored = await _secure.read(key: _kMasterKey);
    if (stored != null) {
      _cachedKey = base64Decode(stored);
      return _cachedKey!;
    }
    final fresh = _randomBytes(_kKeyLengthBytes);
    await _secure.write(key: _kMasterKey, value: base64Encode(fresh));
    _cachedKey = fresh;
    return fresh;
  }

  Future<Directory> _vaultDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, _kVaultDirName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> _tempDir() async {
    final tmp = await getTemporaryDirectory();
    final dir = Directory(p.join(tmp.path, 'sp_decrypted'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String> importEncrypted(File source, {String? subdir}) async {
    final key = await _getMasterKey();
    final iv = _randomBytes(_kIvLengthBytes);
    final baseDir = await _vaultDir();
    final outDir = subdir == null
        ? baseDir
        : await Directory(p.join(baseDir.path, subdir)).create(recursive: true);
    final ext = p.extension(source.path);
    final outName = '${const Uuid().v4()}$ext.enc';
    final outPath = p.join(outDir.path, outName);

    await _processFile(
      srcPath: source.path,
      dstPath: outPath,
      key: key,
      iv: iv,
      writeIvHeader: true,
    );

    return outPath;
  }

  Future<String> decryptToTemp(String encryptedPath) async {
    final key = await _getMasterKey();
    final encFile = File(encryptedPath);
    final raf = await encFile.open();
    final iv = await raf.read(_kIvLengthBytes);
    await raf.close();

    if (iv.length != _kIvLengthBytes) {
      throw const FormatException('Encrypted file IV missing or truncated');
    }

    final temp = await _tempDir();
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
        await for (final entity in temp.list()) {
          try {
            if (entity is File) await entity.delete();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  Future<void> deleteEncryptedFile(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
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
