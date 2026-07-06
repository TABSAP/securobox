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
  static const _kTagLengthBytes = 32;
  static const _kTempPrefix = 'sp_dec_';

  // New files use authenticated encryption: a 4-byte magic marks the format,
  // then [IV(16)][AES-256-CTR ciphertext][HMAC-SHA256 tag(32)]. Files written by
  // older builds have no magic (they start with the raw IV) and are still
  // decrypted, just without tamper-detection.
  static const List<int> _kMagic = [0x53, 0x42, 0x45, 0x31]; // 'SBE1'
  static const _kMagicLength = 4;

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

  final Map<String, String> _plainCache = {};

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

    await _encryptFile(srcPath: source.path, dstPath: outPath, key: key, iv: iv);

    final outFile = File(outPath);
    final outLength = await outFile.exists() ? await outFile.length() : -1;
    final expected =
        _kMagicLength + _kIvLengthBytes + sourceLength + _kTagLengthBytes;
    if (outLength != expected) {
      try {
        if (await outFile.exists()) await outFile.delete();
      } catch (_) {}
      throw StateError(
        'Encrypted import verification failed for ${source.path}: '
        'expected $expected bytes, got $outLength.',
      );
    }

    return outPath;
  }

  Future<String> decryptToTemp(
    String encryptedPath, {
    bool forceReal = false,
  }) async {
    final cached = _plainCache[encryptedPath];
    if (cached != null && await File(cached).exists()) {
      return cached;
    }

    final key = await _getMasterKey(forceReal: forceReal);
    final encFile = File(encryptedPath);
    final raf = await encFile.open();
    final magic = await raf.read(_kMagicLength);
    await raf.close();

    final authenticated = magic.length == _kMagicLength &&
        magic[0] == _kMagic[0] &&
        magic[1] == _kMagic[1] &&
        magic[2] == _kMagic[2] &&
        magic[3] == _kMagic[3];

    final temp = await _tempDir(forceReal: forceReal);
    final origExt = encryptedPath.endsWith('.enc')
        ? p.extension(encryptedPath.substring(0, encryptedPath.length - 4))
        : p.extension(encryptedPath);
    final outName = '$_kTempPrefix${const Uuid().v4()}$origExt';
    final outPath = p.join(temp.path, outName);

    await _decryptFile(
      srcPath: encryptedPath,
      dstPath: outPath,
      key: key,
      authenticated: authenticated,
    );

    _plainCache[encryptedPath] = outPath;
    return outPath;
  }

  bool hasCachedPlaintext(String encryptedPath) =>
      _plainCache.containsKey(encryptedPath);

  Future<void> wipeTempCache() async {
    _plainCache.clear();
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
    _plainCache.clear();
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

      await _encryptFile(srcPath: srcPath, dstPath: encPath, key: key, iv: iv);

      final encSize = await File(encPath).length();
      final expected =
          _kMagicLength + _kIvLengthBytes + original.length + _kTagLengthBytes;
      if (encSize != expected) {
        return 'FAIL: encrypted size $encSize, expected $expected';
      }

      await _decryptFile(
        srcPath: encPath,
        dstPath: decPath,
        key: key,
        authenticated: true,
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

      final tampered = await File(encPath).readAsBytes();
      tampered[_kMagicLength + _kIvLengthBytes + 10] ^= 0xFF;
      final tamPath = p.join(tmp.path, 'sp_test_tam_$id');
      await File(tamPath).writeAsBytes(tampered);
      bool rejected = false;
      try {
        await _decryptFile(
          srcPath: tamPath,
          dstPath: decPath,
          key: key,
          authenticated: true,
        );
      } catch (_) {
        rejected = true;
      }
      try {
        final tf = File(tamPath);
        if (await tf.exists()) await tf.delete();
      } catch (_) {}
      if (!rejected) {
        return 'FAIL: tampered ciphertext was not rejected';
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

  Future<void> _encryptFile({
    required String srcPath,
    required String dstPath,
    required Uint8List key,
    required Uint8List iv,
  }) async {
    return compute(_encryptIsolate, {
      'src': srcPath,
      'dst': dstPath,
      'key': key,
      'iv': iv,
    });
  }

  Future<void> _decryptFile({
    required String srcPath,
    required String dstPath,
    required Uint8List key,
    required bool authenticated,
  }) async {
    return compute(_decryptIsolate, {
      'src': srcPath,
      'dst': dstPath,
      'key': key,
      'auth': authenticated,
    });
  }
}

Uint8List _deriveMacKey(Uint8List masterKey) {
  final mac = HMac(SHA256Digest(), 64)..init(KeyParameter(masterKey));
  return mac.process(Uint8List.fromList(utf8.encode('securobox-mac-v1')));
}

bool _ctEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

void _encryptIsolate(Map<String, dynamic> args) {
  final src = args['src'] as String;
  final dst = args['dst'] as String;
  final key = args['key'] as Uint8List;
  final iv = args['iv'] as Uint8List;

  final macKey = _deriveMacKey(key);
  final mac = HMac(SHA256Digest(), 64)..init(KeyParameter(macKey));
  final cipher = CTRStreamCipher(AESEngine())
    ..init(true, ParametersWithIV<KeyParameter>(KeyParameter(key), iv));

  final input = File(src).openSync();
  final output = File(dst).openSync(mode: FileMode.write);
  try {
    output.writeFromSync(Uint8List.fromList(VaultCrypto._kMagic));
    output.writeFromSync(iv);
    mac.update(iv, 0, iv.length);

    final buffer = Uint8List(64 * 1024);
    while (true) {
      final read = input.readIntoSync(buffer);
      if (read <= 0) break;
      final chunk = read == buffer.length ? buffer : buffer.sublist(0, read);
      final ct = cipher.process(Uint8List.fromList(chunk));
      output.writeFromSync(ct);
      mac.update(ct, 0, ct.length);
    }
    final tag = Uint8List(32);
    mac.doFinal(tag, 0);
    output.writeFromSync(tag);
  } finally {
    input.closeSync();
    output.closeSync();
  }
}

void _decryptIsolate(Map<String, dynamic> args) {
  final src = args['src'] as String;
  final dst = args['dst'] as String;
  final key = args['key'] as Uint8List;
  final authenticated = args['auth'] as bool;

  final ivLen = VaultCrypto._kIvLengthBytes;

  if (!authenticated) {
    final input = File(src).openSync();
    final output = File(dst).openSync(mode: FileMode.write);
    try {
      final iv = input.readSync(ivLen);
      final cipher = CTRStreamCipher(AESEngine())
        ..init(
          true,
          ParametersWithIV<KeyParameter>(
            KeyParameter(key),
            Uint8List.fromList(iv),
          ),
        );
      final buffer = Uint8List(64 * 1024);
      while (true) {
        final read = input.readIntoSync(buffer);
        if (read <= 0) break;
        final chunk = read == buffer.length ? buffer : buffer.sublist(0, read);
        final pt = cipher.process(Uint8List.fromList(chunk));
        output.writeFromSync(pt);
      }
    } finally {
      input.closeSync();
      output.closeSync();
    }
    return;
  }

  final magicLen = VaultCrypto._kMagicLength;
  final tagLen = VaultCrypto._kTagLengthBytes;
  final fileLen = File(src).lengthSync();
  final ctStart = magicLen + ivLen;
  final ctEnd = fileLen - tagLen;
  if (ctEnd < ctStart) {
    throw StateError('Encrypted file is truncated.');
  }

  final macKey = _deriveMacKey(key);
  final mac = HMac(SHA256Digest(), 64)..init(KeyParameter(macKey));

  final input = File(src).openSync();
  final output = File(dst).openSync(mode: FileMode.write);
  var ok = false;
  try {
    input.setPositionSync(magicLen);
    final iv = input.readSync(ivLen);
    mac.update(Uint8List.fromList(iv), 0, ivLen);
    final cipher = CTRStreamCipher(AESEngine())
      ..init(
        true,
        ParametersWithIV<KeyParameter>(
          KeyParameter(key),
          Uint8List.fromList(iv),
        ),
      );

    var remaining = ctEnd - ctStart;
    final buffer = Uint8List(64 * 1024);
    while (remaining > 0) {
      final toRead = remaining < buffer.length ? remaining : buffer.length;
      final read = input.readIntoSync(buffer, 0, toRead);
      if (read <= 0) break;
      final chunk = buffer.sublist(0, read);
      mac.update(chunk, 0, read);
      final pt = cipher.process(chunk);
      output.writeFromSync(pt);
      remaining -= read;
    }

    input.setPositionSync(ctEnd);
    final tag = input.readSync(tagLen);
    final computed = Uint8List(32);
    mac.doFinal(computed, 0);
    if (!_ctEqual(computed, Uint8List.fromList(tag))) {
      throw StateError('Integrity check failed — file was modified.');
    }
    ok = true;
  } finally {
    input.closeSync();
    output.closeSync();
    if (!ok) {
      try {
        final f = File(dst);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
  }
}
