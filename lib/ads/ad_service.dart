import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ad_config.dart';

class AdService {
  AdService._();

  static final AdService instance = AdService._();

  final ValueNotifier<bool> privacyOptionsRequired = ValueNotifier(false);
  Future<void>? _initialization;
  Future<void>? _consentInfoUpdate;
  bool _consentFormAttempted = false;
  bool _sdkReady = false;
  bool _appOpenLoading = false;
  bool _appOpenShowing = false;
  bool _appOpenAttempted = false;
  AppOpenAd? _appOpenAd;
  DateTime? _appOpenLoadedAt;

  void _log(String message) {
    if (kDebugMode) debugPrint(message);
  }

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    if (!AdConfig.isSupportedPlatform) return;
    if (!kDebugMode &&
        AdConfig.settingsBannerId == null &&
        AdConfig.appOpenId == null) {
      return;
    }
    try {
      await MobileAds.instance.initialize();
      _sdkReady = true;
    } catch (error) {
      _sdkReady = false;
      _initialization = null;
      _log('Ad SDK initialization failed: $error');
      return;
    }

    final updated = Completer<void>();
    _consentInfoUpdate = updated.future;
    void finishUpdate() {
      unawaited(_refreshPrivacyOptionsStatus());
      if (!updated.isCompleted) updated.complete();
    }

    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        finishUpdate,
        (error) {
          _log('Ad consent info update failed: ${error.message}');
          finishUpdate();
        },
      );
    } catch (error) {
      _log('Ad consent info update failed: $error');
      finishUpdate();
    }
  }

  Future<bool> prepareForAds() async {
    await initialize();
    if (!_sdkReady) return false;
    try {
      await _consentInfoUpdate?.timeout(const Duration(seconds: 8));
    } on TimeoutException {}

    if (!_consentFormAttempted) {
      _consentFormAttempted = true;
      final completed = Completer<void>();
      try {
        await ConsentForm.loadAndShowConsentFormIfRequired((error) {
          if (error != null) {
            _log('Ad consent form failed: ${error.message}');
          }
          if (!completed.isCompleted) completed.complete();
        }).timeout(const Duration(seconds: 30));
        if (!completed.isCompleted) completed.complete();
      } on TimeoutException {
        if (!completed.isCompleted) completed.complete();
      } catch (error) {
        _log('Ad consent form failed: $error');
        if (!completed.isCompleted) completed.complete();
      }
      await completed.future;
      await _refreshPrivacyOptionsStatus();
    }

    try {
      return await ConsentInformation.instance.canRequestAds();
    } catch (error) {
      _log('Could not read ad consent status: $error');
      return false;
    }
  }

  Future<void> showPrivacyOptions() async {
    try {
      await ConsentForm.showPrivacyOptionsForm((error) {
        if (error != null) {
          _log('Privacy options form failed: ${error.message}');
        }
      });
    } catch (error) {
      _log('Privacy options form failed: $error');
    } finally {
      await _refreshPrivacyOptionsStatus();
    }
  }

  Future<void> showAppOpenAd() async {
    if (!AdConfig.isSupportedPlatform || _appOpenShowing || _appOpenAttempted) {
      return;
    }
    _appOpenAttempted = true;
    try {
      final preferences = await SharedPreferences.getInstance();
      final lastShownMillis = preferences.getInt('lastAppOpenAdShownAt');
      final lastShown = lastShownMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(lastShownMillis);
      if (lastShown != null &&
          DateTime.now().difference(lastShown) < const Duration(minutes: 30)) {
        return;
      }
      if (!await prepareForAds()) return;
      await _loadAppOpenAd();
      final ad = _appOpenAd;
      if (ad == null) return;
      _appOpenAd = null;
      _appOpenShowing = true;
      ad.fullScreenContentCallback = FullScreenContentCallback<AppOpenAd>(
        onAdShowedFullScreenContent: (_) {
          unawaited(_storeLastAppOpenShown(preferences));
        },
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _appOpenShowing = false;
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          _log('App open ad failed to show: ${error.message}');
          ad.dispose();
          _appOpenShowing = false;
        },
      );
      await ad.show();
    } catch (error) {
      _log('App open ad request failed: $error');
      _appOpenShowing = false;
    } finally {
      _appOpenAttempted = false;
    }
  }

  Future<void> _storeLastAppOpenShown(SharedPreferences preferences) async {
    try {
      await preferences.setInt(
        'lastAppOpenAdShownAt',
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (error) {
      _log('Could not save App Open ad frequency cap: $error');
    }
  }

  Future<void> _loadAppOpenAd() async {
    final existing = _appOpenAd;
    if (existing != null &&
        _appOpenLoadedAt != null &&
        DateTime.now().difference(_appOpenLoadedAt!) <
            const Duration(hours: 4)) {
      return;
    }
    existing?.dispose();
    _appOpenAd = null;
    if (_appOpenLoading) return;
    final adUnitId = AdConfig.appOpenId;
    if (adUnitId == null) return;
    _appOpenLoading = true;
    final loaded = Completer<void>();
    try {
      await AppOpenAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(nonPersonalizedAds: true),
        adLoadCallback: AppOpenAdLoadCallback(
          onAdLoaded: (ad) {
            _appOpenAd = ad;
            _appOpenLoadedAt = DateTime.now();
            if (!loaded.isCompleted) loaded.complete();
          },
          onAdFailedToLoad: (error) {
            _log('App open ad failed to load: ${error.message}');
            if (!loaded.isCompleted) loaded.complete();
          },
        ),
      );
      await loaded.future.timeout(const Duration(seconds: 10));
    } on TimeoutException {
      _log('App open ad load timed out');
    } finally {
      _appOpenLoading = false;
    }
  }

  Future<void> _refreshPrivacyOptionsStatus() async {
    try {
      final status = await ConsentInformation.instance
          .getPrivacyOptionsRequirementStatus();
      privacyOptionsRequired.value =
          status == PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      privacyOptionsRequired.value = false;
    }
  }
}
