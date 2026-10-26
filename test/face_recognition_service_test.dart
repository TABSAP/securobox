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

  test('Face recognition enrollment, verification, and clear lifecycle', () async {
    final service = FaceRecognitionService.instance;

    // Initially not enrolled
    expect(await service.isEnrolled(), isFalse);

    // Create 5 consistent mock feature vectors (166 values each)
    const len = 166;
    final baseVector = List<double>.generate(len, (i) => (i % 10) * 0.1);
    final samples = List.generate(
      FaceRecognitionService.enrollSamples,
      (sIdx) => List<double>.generate(
        len,
        (i) => baseVector[i] + (sIdx * 0.005),
      ),
    );

    // Enroll
    await service.enroll(samples);
    expect(await service.isEnrolled(), isTrue);

    // Verify with a matching candidate
    final matchingCandidate = List<double>.generate(
      len,
      (i) => baseVector[i] + 0.008,
    );
    final matchResult = await service.verifyVector(matchingCandidate);
    expect(matchResult.matched, isTrue);

    // Verify with a non-matching candidate
    final dissimilarCandidate = List<double>.generate(
      len,
      (i) => baseVector[i] + 0.5,
    );
    final mismatchResult = await service.verifyVector(dissimilarCandidate);
    expect(mismatchResult.matched, isFalse);

    // Clear enrollment
    await service.clearEnrollment();
    expect(await service.isEnrolled(), isFalse);
  });
}
