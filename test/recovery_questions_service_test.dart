import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_app/utils/recovery_questions_service.dart';

void main() {
  const ids = ['first_school', 'childhood_city', 'first_pet'];
  const answers = ['Maple Elementary', 'North Harbor', 'Milo'];

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('normalizes answers and rejects duplicate or weak setup answers', () {
    expect(
      RecoveryQuestionsService.normalizeAnswer('  North   HARBOR '),
      'north harbor',
    );
    expect(RecoveryQuestionsService.validateAnswers(ids, answers), isNull);
    expect(
      RecoveryQuestionsService.validateAnswers([
        'first_school',
        'first_school',
        'first_pet',
      ], answers),
      isNotNull,
    );
    expect(
      RecoveryQuestionsService.validateAnswers(ids, [
        'same answer',
        ' SAME   ANSWER ',
        'third answer',
      ]),
      isNotNull,
    );
    expect(
      RecoveryQuestionsService.validateAnswers(ids, [
        'ab',
        answers[1],
        answers[2],
      ]),
      isNotNull,
    );
  });

  test(
    'stores only salted verifiers and verifies all answers together',
    () async {
      final service = RecoveryQuestionsService.instance;
      await service.save(questionIds: ids, answers: answers);

      expect(await service.isEnabled(), isTrue);
      expect((await service.getPrompts()).map((question) => question.id), ids);
      final stored = await const FlutterSecureStorage().read(
        key: 'pin_recovery_questions_v1',
      );
      expect(stored, isNotNull);
      expect(stored, isNot(contains('Maple Elementary')));
      expect(stored, isNot(contains('North Harbor')));

      expect(
        await service.verify([' maple   elementary ', 'north harbor', 'MILO']),
        isTrue,
      );
      expect(
        await service.verify(['Maple Elementary', 'wrong city', 'Milo']),
        isFalse,
      );
      expect(await service.lockoutRemaining(), Duration.zero);
    },
  );

  test('new setup removes legacy recovery key material', () async {
    FlutterSecureStorage.setMockInitialValues({
      'recovery_hash_v2': 'legacy-hash',
      'recovery_salt_v2': 'legacy-salt',
    });
    await RecoveryQuestionsService.instance.save(
      questionIds: ids,
      answers: answers,
    );

    const storage = FlutterSecureStorage();
    expect(await storage.read(key: 'recovery_hash_v2'), isNull);
    expect(await storage.read(key: 'recovery_salt_v2'), isNull);
    expect(await storage.read(key: 'pin_recovery_questions_v1'), isNotNull);
  });

  test(
    'five failed answer sets apply a cooldown before another verification',
    () async {
      final service = RecoveryQuestionsService.instance;
      await service.save(questionIds: ids, answers: answers);
      for (var attempt = 0; attempt < 5; attempt++) {
        expect(
          await service.verify(['wrong one', 'wrong two', 'wrong three']),
          isFalse,
        );
      }
      expect(await service.lockoutRemaining(), greaterThan(Duration.zero));
      expect(await service.verify(answers), isFalse);
    },
  );
}
