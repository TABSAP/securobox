import 'package:flutter/cupertino.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_ids.dart';
class AppOpenAdService {
  static AppOpenAd? _appOpenAd;
  static bool _isAdShown = false;

  static void loadAd() {
    AppOpenAd.load(
      adUnitId: AdIds.appOpenAndroid,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          _appOpenAd!.show();
        },
        onAdFailedToLoad: (error) {
          debugPrint('AppOpenAd failed: $error');
        },
      ),
    );


  }

  static void showAdIfAvailable() {
    if (_appOpenAd == null || _isAdShown) return;

    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _appOpenAd = null;
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _appOpenAd = null;
      },
    );

    _appOpenAd!.show();
    _isAdShown = true; // ONE TIME ONLY
  }
}
