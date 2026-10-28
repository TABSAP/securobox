import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_app/utils/face_recognition_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() async {
    await FaceRecognitionService.instance.clearEnrollment();
  });

  test(
    'Face recognition enrollment, verification, and clear lifecycle',
    () async {
      final service = FaceRecognitionService.instance;

      expect(await service.isEnrolled(), isFalse);

      const len = 166;
      final baseVector = List<double>.generate(len, (i) => (i % 10) * 0.1);
      final samples = List.generate(
        FaceRecognitionService.enrollSamples,
        (sIdx) =>
            List<double>.generate(len, (i) => baseVector[i] + (sIdx * 0.005)),
      );

      await service.enroll(samples);
      expect(await service.isEnrolled(), isTrue);

      final matchingCandidate = List<double>.generate(
        len,
        (i) => baseVector[i] + 0.008,
      );
      final matchResult = await service.verifyVector(matchingCandidate);
      expect(matchResult.matched, isTrue);

      final dissimilarCandidate = List<double>.generate(
        len,
        (i) => baseVector[i] + 0.5,
      );
      final mismatchResult = await service.verifyVector(dissimilarCandidate);
      expect(mismatchResult.matched, isFalse);

      await service.clearEnrollment();
      expect(await service.isEnrolled(), isFalse);
    },
  );
}
