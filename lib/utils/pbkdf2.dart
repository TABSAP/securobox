import 'dart:async';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// PBKDF2-HMAC-SHA256, computed on a long-lived background isolate.
///
/// The KDF runs 100k iterations — far too heavy for the UI thread (it froze the
/// lock screen the instant the last PIN digit landed). Offloading it with
/// `compute()` fixed the freeze, but `compute()` spawns a *fresh* isolate on
/// every call, and that spawn latency (~100–300 ms) showed up as a delay when
/// creating, confirming or entering a PIN.
///
/// So a single worker isolate is started once and reused for every hash. Call
/// [prewarmPbkdf2] when a PIN screen opens to spawn it ahead of time — then even
/// the first hash is instant (only the unavoidable KDF math remains, and that
/// runs off the UI thread so the keypad stays at 60fps). If the isolate can't be
/// spawned for any reason, it transparently falls back to a one-shot `compute()`.
Future<Uint8List> pbkdf2(
  Uint8List password,
  Uint8List salt,
  int iterations,
  int dkLen,
) {
  return _Pbkdf2Worker.instance.run(password, salt, iterations, dkLen);
}

/// Spawns the worker isolate ahead of time so the first hash doesn't pay
/// isolate-spawn latency. Cheap and idempotent — safe to call on every PIN
/// screen's `initState`.
void prewarmPbkdf2() => _Pbkdf2Worker.instance.prewarm();

/// Owns the persistent worker isolate and multiplexes requests onto it.
class _Pbkdf2Worker {
  _Pbkdf2Worker._();
  static final _Pbkdf2Worker instance = _Pbkdf2Worker._();

  SendPort? _sendPort;
  Completer<void>? _starting;
  final Map<int, Completer<Uint8List>> _pending = {};
  int _nextId = 0;

  void prewarm() {
    // Fire-and-forget; failures are tolerated (run() falls back to compute()).
    _ensureStarted().catchError((_) {});
  }

  Future<Uint8List> run(
    Uint8List password,
    Uint8List salt,
    int iterations,
    int dkLen,
  ) async {
    try {
      await _ensureStarted();
    } catch (_) {
      // Worker unavailable — fall back to a one-shot isolate via compute().
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
        // [id, resultBytes]
        final id = message[0] as int;
        final result = message[1] as Uint8List;
        _pending.remove(id)?.complete(result);
      }
    });
    Isolate.spawn(_workerMain, receive.sendPort).catchError((Object e) {
      receive.close();
      _starting = null;
      if (!starting.isCompleted) starting.completeError(e);
      return Isolate.current; // satisfy the Future<Isolate> return type
    });
    return starting.future;
  }
}

/// Worker isolate entry point: receives `[id, password, salt, iterations, dkLen]`
/// requests and replies with `[id, resultBytes]`.
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

/// `compute()` fallback entry — unpacks the record and runs the core.
Uint8List _pbkdf2Entry((Uint8List, Uint8List, int, int) args) =>
    _pbkdf2Sync(args.$1, args.$2, args.$3, args.$4);

/// Synchronous PBKDF2-HMAC-SHA256 core. Pure Dart, safe in any isolate.
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
