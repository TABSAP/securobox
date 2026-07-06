import 'dart:io';

import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class AppRating {
  AppRating._();

  static const _packageId = 'app.securobox.vault';
  static const _appStoreId = '';

  static const _kImportCountKey = 'rating_import_count';
  static const _kAskedKey = 'rating_asked_v1';
  static const _promptAfterImports = 3;

  static final InAppReview _review = InAppReview.instance;

  static Future<void> rateNow() async {
    if (Platform.isIOS) {
      try {
        if (await _review.isAvailable()) {
          await _review.requestReview();
          return;
        }
      } catch (_) {}
    }
    await openStore();
  }

  static Future<void> openStore() async {
    if (Platform.isIOS) {
      if (_appStoreId.isNotEmpty) {
        final launched = await _launch(
          Uri.parse('https://apps.apple.com/app/id$_appStoreId?action=write-review'),
        );
        if (launched) return;
        try {
          await _review.openStoreListing(appStoreId: _appStoreId);
        } catch (_) {}
      }
      return;
    }

    if (await _launch(Uri.parse('market://details?id=$_packageId'))) return;
    await _launch(
      Uri.parse('https://play.google.com/store/apps/details?id=$_packageId'),
    );
  }

  static Future<bool> _launch(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  static Future<void> recordImportAndMaybeAsk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kAskedKey) ?? false) return;
      final count = (prefs.getInt(_kImportCountKey) ?? 0) + 1;
      await prefs.setInt(_kImportCountKey, count);
      if (count >= _promptAfterImports && await _review.isAvailable()) {
        await prefs.setBool(_kAskedKey, true);
        await _review.requestReview();
      }
    } catch (_) {}
  }
}
