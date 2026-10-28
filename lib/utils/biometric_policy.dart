import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum BiometricModality { device, face, fingerprint }

class UnsupportedBiometricModality implements Exception {
  const UnsupportedBiometricModality(this.message);
  final String message;
}

class BiometricPolicy {
  static bool supports(
    TargetPlatform platform,
    BiometricModality requested,
    List<BiometricType> enrolled,
  ) {
    if (enrolled.isEmpty) return false;
    if (requested == BiometricModality.device) return true;
    if (platform != TargetPlatform.iOS) return false;
    final requiredType = requested == BiometricModality.face
        ? BiometricType.face
        : BiometricType.fingerprint;
    return enrolled.toSet().length == 1 && enrolled.contains(requiredType);
  }

  static Future<bool> authenticate(
    LocalAuthentication auth, {
    required String reason,
    BiometricModality? requested,
    bool sensitiveTransaction = false,
  }) async {
    if (requested == null) {
      final prefs = await SharedPreferences.getInstance();
      requested =
          !(prefs.getBool('biometric') ?? false) &&
              (prefs.getBool('biometric_face') ?? false)
          ? BiometricModality.face
          : BiometricModality.device;
    }
    final effectiveRequest =
        defaultTargetPlatform == TargetPlatform.android &&
            requested == BiometricModality.face
        ? BiometricModality.device
        : requested;
    final enrolled = await auth.getAvailableBiometrics();
    if (!supports(defaultTargetPlatform, effectiveRequest, enrolled)) {
      throw UnsupportedBiometricModality(
        effectiveRequest == BiometricModality.device
            ? 'No eligible biometric is available. Use your SecuroBox PIN.'
            : 'This device cannot enforce the selected biometric method. Use your SecuroBox PIN. To allow any eligible biometric, enable Device biometrics in Security settings.',
      );
    }
    return auth.authenticate(
      localizedReason: reason,
      biometricOnly: true,
      sensitiveTransaction: sensitiveTransaction,
      persistAcrossBackgrounding: true,
    );
  }
}
