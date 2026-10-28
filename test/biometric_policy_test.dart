import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_app/utils/biometric_policy.dart';

class FakeAuth extends LocalAuthentication {
  FakeAuth(this.enrolled, {this.result = true});
  final List<BiometricType> enrolled;
  final bool result;
  int calls = 0;
  bool? biometricOnlyReceived;
  @override
  Future<List<BiometricType>> getAvailableBiometrics() async => enrolled;
  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<dynamic> authMessages = const [],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) async {
    calls++;
    biometricOnlyReceived = biometricOnly;
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test(
    'Android Face Unlock uses its eligible system biometric prompt',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final auth = FakeAuth([BiometricType.strong, BiometricType.weak]);
      expect(
        await BiometricPolicy.authenticate(
          auth,
          reason: 'Unlock',
          requested: BiometricModality.face,
        ),
        isTrue,
      );
      expect(auth.calls, 1);
      expect(auth.biometricOnlyReceived, isTrue);
    },
  );

  test('Android strict fingerprint selection remains unsupported', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final auth = FakeAuth([BiometricType.strong, BiometricType.weak]);
    await expectLater(
      BiometricPolicy.authenticate(
        auth,
        reason: 'Test',
        requested: BiometricModality.fingerprint,
      ),
      throwsA(isA<UnsupportedBiometricModality>()),
    );
    expect(auth.calls, 0);
  });
  test(
    'legacy Android Face Unlock preference invokes eligible biometric prompt',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      SharedPreferences.setMockInitialValues({
        'biometric_face': true,
        'biometric': false,
      });
      final auth = FakeAuth([BiometricType.strong]);
      expect(
        await BiometricPolicy.authenticate(auth, reason: 'Unlock'),
        isTrue,
      );
      expect(auth.calls, 1);
      expect(auth.biometricOnlyReceived, isTrue);
      expect(
        (await SharedPreferences.getInstance()).getBool('biometric_face'),
        isTrue,
      );
    },
  );
  test('explicit device biometric preference accepts the OS method', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({
      'biometric_face': true,
      'biometric': true,
    });
    final auth = FakeAuth([BiometricType.strong]);
    expect(await BiometricPolicy.authenticate(auth, reason: 'Unlock'), isTrue);
    expect(auth.calls, 1);
    expect(auth.biometricOnlyReceived, isTrue);
  });
  for (final requested in [
    BiometricModality.face,
    BiometricModality.fingerprint,
  ]) {
    test(
      'iOS $requested rejects the other modality before native authentication',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        final other = requested == BiometricModality.face
            ? BiometricType.fingerprint
            : BiometricType.face;
        final auth = FakeAuth([other]);
        await expectLater(
          BiometricPolicy.authenticate(
            auth,
            reason: 'Test',
            requested: requested,
          ),
          throwsA(isA<UnsupportedBiometricModality>()),
        );
        expect(auth.calls, 0);
      },
    );
    test('iOS $requested accepts matching device biometry only', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final type = requested == BiometricModality.face
          ? BiometricType.face
          : BiometricType.fingerprint;
      final auth = FakeAuth([type]);
      expect(
        await BiometricPolicy.authenticate(
          auth,
          reason: 'Test',
          requested: requested,
        ),
        isTrue,
      );
      expect(auth.biometricOnlyReceived, isTrue);
    });
  }
  test('missing enrollment never invokes authentication', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final auth = FakeAuth([]);
    await expectLater(
      BiometricPolicy.authenticate(auth, reason: 'Test'),
      throwsA(isA<UnsupportedBiometricModality>()),
    );
    expect(auth.calls, 0);
  });
  test(
    'native rejection is not changed into success or another prompt',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final auth = FakeAuth([BiometricType.face], result: false);
      expect(
        await BiometricPolicy.authenticate(
          auth,
          reason: 'Test',
          requested: BiometricModality.face,
        ),
        isFalse,
      );
      expect(auth.calls, 1);
    },
  );
}
