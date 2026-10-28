import 'package:flutter/foundation.dart';

class AdConfig {
  AdConfig._();

  static const _androidBannerId = String.fromEnvironment(
    'ADMOB_ANDROID_BANNER_ID',
  );
  static const _iosBannerId = String.fromEnvironment('ADMOB_IOS_BANNER_ID');
  static const _androidAppOpenId = String.fromEnvironment(
    'ADMOB_ANDROID_APP_OPEN_ID',
  );
  static const _iosAppOpenId = String.fromEnvironment('ADMOB_IOS_APP_OPEN_ID');
  static const _testAndroidBannerId = 'ca-app-pub-3940256099942544/6300978111';
  static const _testIosBannerId = 'ca-app-pub-3940256099942544/2934735716';
  static const _testAndroidAppOpenId = 'ca-app-pub-3940256099942544/9257395921';
  static const _testIosAppOpenId = 'ca-app-pub-3940256099942544/5575463023';

  static bool get isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static String? get settingsBannerId {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _configuredOrTest(_androidBannerId, _testAndroidBannerId);
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return _configuredOrTest(_iosBannerId, _testIosBannerId);
    }
    return null;
  }

  static String? get appOpenId {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _configuredOrTest(_androidAppOpenId, _testAndroidAppOpenId);
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return _configuredOrTest(_iosAppOpenId, _testIosAppOpenId);
    }
    return null;
  }

  static String? _configuredOrTest(String configured, String test) {
    if (configured.isNotEmpty) return configured;
    return kDebugMode ? test : null;
  }
}
