import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:video_player_app/utils/pbkdf2.dart';

class RecoveryQuestion {
  const RecoveryQuestion(this.id, this.prompt);
  final String id;
  final String prompt;
}

class RecoveryQuestionsService {
  RecoveryQuestionsService._();
  static final instance = RecoveryQuestionsService._();

  static const questions = <RecoveryQuestion>[
    RecoveryQuestion('first_school', 'What was the name of your first school?'),
    RecoveryQuestion('childhood_city', 'In what city did you grow up?'),
    RecoveryQuestion('first_pet', 'What was the name of your first pet?'),
    RecoveryQuestion(
      'favorite_teacher',
      'What was the surname of a favorite teacher?',
    ),
    RecoveryQuestion('first_job', 'What was your first job?'),
    RecoveryQuestion('favorite_book', 'What was a favorite book as a child?'),
    RecoveryQuestion(
      'memorable_place',
      'What is the name of a memorable place?',
    ),
    RecoveryQuestion(
      'family_nickname',
      'What nickname did your family use for you?',
    ),
  ];

  static const _recordKey = 'pin_recovery_questions_v1';
  static const _legacyRecoveryKeys = ['recovery_hash_v2', 'recovery_salt_v2'];
  static const _attemptKey = 'pin_recovery_failed_attempts_v1';
  static const _lockoutKey = 'pin_recovery_lockout_until_v1';
  static const _iterations = 120000;
  static const _answerBytes = 32;
  static const _saltBytes = 16;
  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static String normalizeAnswer(String answer) =>
      answer.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static String? validateAnswers(
    List<String> questionIds,
    List<String> answers,
  ) {
    if (questionIds.length != 3 || answers.length != 3) {
      return 'Choose and answer all three recovery questions.';
    }
    if (questionIds.toSet().length != 3 ||
        questionIds.any((id) => !questions.any((q) => q.id == id))) {
      return 'Choose three different questions.';
    }
    final normalized = answers.map(normalizeAnswer).toList();
    if (normalized.any((answer) => answer.length < 3)) {
      return 'Each answer must contain at least three characters.';
    }
    if (normalized.any((answer) => answer.length > 80)) {
      return 'Keep each answer under 80 characters.';
    }
    if (normalized.toSet().length != normalized.length) {
      return 'Use a different answer for each question.';
    }
    return null;
  }

  Future<bool> isEnabled() async {
    for (final key in _legacyRecoveryKeys) {
      try {
        await _secure.delete(key: key);
      } catch (_) {}
    }
    return (await _secure.read(key: _recordKey)) != null;
  }

  Future<List<RecoveryQuestion>> getPrompts() async {
    final record = await _readRecord();
    return (record['entries'] as List<dynamic>)
        .map((entry) {
          final id = (entry as Map<String, dynamic>)['id'] as String;
          return questions.firstWhere((question) => question.id == id);
        })
        .toList(growable: false);
  }

  Future<void> save({
    required List<String> questionIds,
    required List<String> answers,
  }) async {
    final validation = validateAnswers(questionIds, answers);
    if (validation != null) throw ArgumentError(validation);
    final random = Random.secure();
    final entries = <Map<String, String>>[];
    for (var i = 0; i < questionIds.length; i++) {
      final salt = Uint8List.fromList(
        List<int>.generate(_saltBytes, (_) => random.nextInt(256)),
      );
      final hash = await _hash(answers[i], salt);
      entries.add({
        'id': questionIds[i],
        'salt': base64Encode(salt),
        'hash': base64Encode(hash),
      });
    }
    await _secure.write(
      key: _recordKey,
      value: jsonEncode({
        'version': 1,
        'iterations': _iterations,
        'entries': entries,
      }),
    );
    try {
      await _clearThrottle();
    } catch (_) {}
    for (final key in _legacyRecoveryKeys) {
      try {
        await _secure.delete(key: key);
      } catch (_) {}
    }
  }

  Future<bool> verify(List<String> answers) async {
    final remaining = await lockoutRemaining();
    if (remaining > Duration.zero) return false;
    final record = await _readRecord();
    final entries = record['entries'] as List<dynamic>;
    if (answers.length != entries.length || entries.length != 3) {
      return _recordFailure();
    }
    final iterations = record['iterations'] as int;
    var difference = 0;
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i] as Map<String, dynamic>;
      final salt = base64Decode(entry['salt'] as String);
      final expected = base64Decode(entry['hash'] as String);
      if (salt.length != _saltBytes || expected.length != _answerBytes) {
        throw const FormatException('Recovery question data is damaged.');
      }
      final candidate = await _hash(answers[i], salt, iterations: iterations);
      difference |= _constantTimeDifference(expected, candidate);
    }
    if (difference == 0) {
      await _clearThrottle();
      return true;
    }
    return _recordFailure();
  }

  Future<Duration> lockoutRemaining() async {
    final raw = await _secure.read(key: _lockoutKey);
    final epoch = int.tryParse(raw ?? '') ?? 0;
    final millis = epoch - DateTime.now().millisecondsSinceEpoch;
    return millis > 0 ? Duration(milliseconds: millis) : Duration.zero;
  }

  Future<void> clear() async {
    await _secure.delete(key: _recordKey);
    await _clearThrottle();
  }

  Future<Map<String, dynamic>> _readRecord() async {
    final raw = await _secure.read(key: _recordKey);
    if (raw == null) throw StateError('Recovery questions are not configured.');
    try {
      final record = jsonDecode(raw) as Map<String, dynamic>;
      final entries = record['entries'] as List<dynamic>;
      final iterations = record['iterations'] as int;
      if (record['version'] != 1 ||
          entries.length != 3 ||
          iterations < _iterations ||
          iterations > 500000 ||
          entries.any((entry) {
            final map = entry as Map<String, dynamic>;
            return !questions.any((q) => q.id == map['id']) ||
                map['salt'] is! String ||
                map['hash'] is! String;
          })) {
        throw const FormatException();
      }
      if (entries
              .map((e) => (e as Map<String, dynamic>)['id'])
              .toSet()
              .length !=
          3) {
        throw const FormatException();
      }
      return record;
    } on Object {
      throw const FormatException('Recovery question data is damaged.');
    }
  }

  Future<Uint8List> _hash(
    String answer,
    Uint8List salt, {
    int iterations = _iterations,
  }) => pbkdf2(
    Uint8List.fromList(utf8.encode(normalizeAnswer(answer))),
    salt,
    iterations,
    _answerBytes,
  );

  Future<bool> _recordFailure() async {
    final raw = await _secure.read(key: _attemptKey);
    final attempts = (int.tryParse(raw ?? '') ?? 0) + 1;
    await _secure.write(key: _attemptKey, value: '$attempts');
    if (attempts >= 5) {
      final exponent = min(attempts - 5, 5);
      final waitSeconds = min(30 * (1 << exponent), 900);
      await _secure.write(
        key: _lockoutKey,
        value: DateTime.now()
            .add(Duration(seconds: waitSeconds))
            .millisecondsSinceEpoch
            .toString(),
      );
    }
    return false;
  }

  Future<void> _clearThrottle() async {
    await _secure.delete(key: _attemptKey);
    await _secure.delete(key: _lockoutKey);
  }

  int _constantTimeDifference(Uint8List expected, Uint8List candidate) {
    if (expected.length != candidate.length) return 1;
    var difference = 0;
    for (var i = 0; i < expected.length; i++) {
      difference |= expected[i] ^ candidate[i];
    }
    return difference;
  }
}
