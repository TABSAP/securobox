import 'dart:async';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

Future<Uint8List> pbkdf2(
  Uint8List password,
  Uint8List salt,
  int iterations,
  int dkLen,
) {
  return _Pbkdf2Worker.instance.run(password, salt, iterations, dkLen);
}

void prewarmPbkdf2() => _Pbkdf2Worker.instance.prewarm();

class _Pbkdf2Worker {
  _Pbkdf2Worker._();
  static final _Pbkdf2Worker instance = _Pbkdf2Worker._();

  SendPort? _sendPort;
  Completer<void>? _starting;
  final Map<int, Completer<Uint8List>> _pending = {};
  int _nextId = 0;

  void prewarm() {
    _ensureStarted().catchError((_) {});
  }

  Future<Uint8List> run(
    Uint8List password,
    Uint8List salt,
    int iterations,
    int dkLen,
  ) async {
    try {
      // Bound the worker-startup handshake: if the isolate spawns but never
      // reports back (rare, but would otherwise hang forever), fall back to a
      // one-shot compute() so hashing never blocks indefinitely.
      await _ensureStarted().timeout(const Duration(seconds: 5));
    } catch (_) {
      return compute(_pbkdf2Entry, (password, salt, iterations, dkLen));
    }
    if (_sendPort == null) {
      return compute(_pbkdf2Entry, (password, salt, iterations, dkLen));
    }
    final id = _nextId++;
    final completer = Completer<Uint8List>();
    _pending[id] = completer;
    try {
      _sendPort!.send([id, password, salt, iterations, dkLen]);
    } catch (_) {
      _pending.remove(id);
      return compute(_pbkdf2Entry, (password, salt, iterations, dkLen));
    }
    return completer.future;
  }

  Future<void> _ensureStarted() {
    if (_sendPort != null) return Future.value();
    final existing = _starting;
    if (existing != null) return existing.future;

    final starting = _starting = Completer<void>();
    final receive = ReceivePort();
    receive.listen((message) {
      if (message is SendPort) {
        _sendPort = message;
        if (!starting.isCompleted) starting.complete();
      } else if (message is List) {
        final id = message[0] as int;
        final result = message[1] as Uint8List;
        _pending.remove(id)?.complete(result);
      }
    });
    Isolate.spawn(_workerMain, receive.sendPort).catchError((Object e) {
      receive.close();
      _starting = null;
      if (!starting.isCompleted) starting.completeError(e);
      return Isolate.current;
    });
    return starting.future;
  }
}

void _workerMain(SendPort toMain) {
  final port = ReceivePort();
  toMain.send(port.sendPort);
  port.listen((message) {
    final req = message as List;
    final id = req[0] as int;
    final result = _pbkdf2Sync(
      req[1] as Uint8List,
      req[2] as Uint8List,
      req[3] as int,
      req[4] as int,
    );
    toMain.send([id, result]);
  });
}

Uint8List _pbkdf2Entry((Uint8List, Uint8List, int, int) args) =>
    _pbkdf2Sync(args.$1, args.$2, args.$3, args.$4);

Uint8List _pbkdf2Sync(
  Uint8List password,
  Uint8List salt,
  int iterations,
  int dkLen,
) {
  final hmac = Hmac(sha256, password);
  const blockSize = 32;
  final blocks = (dkLen / blockSize).ceil();
  final result = Uint8List(dkLen);
  int offset = 0;
  for (int i = 1; i <= blocks; i++) {
    final block = Uint8List(salt.length + 4)
      ..setRange(0, salt.length, salt)
      ..[salt.length] = (i >> 24) & 0xff
      ..[salt.length + 1] = (i >> 16) & 0xff
      ..[salt.length + 2] = (i >> 8) & 0xff
      ..[salt.length + 3] = i & 0xff;

    var u = Uint8List.fromList(hmac.convert(block).bytes);
    final t = Uint8List.fromList(u);
    for (int j = 1; j < iterations; j++) {
      u = Uint8List.fromList(hmac.convert(u).bytes);
      for (int k = 0; k < blockSize; k++) {
        t[k] ^= u[k];
      }
    }
    final remaining = dkLen - offset;
    final copy = remaining < blockSize ? remaining : blockSize;
    result.setRange(offset, offset + copy, t);
    offset += copy;
  }
  return result;
}
