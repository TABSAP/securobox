import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class AppRating {
  AppRating._();

  static const _packageId = 'app.securobox.vault';
  static const _storeUrl =
      'https://play.google.com/store/apps/details?id=$_packageId';

  static const _kImportCountKey = 'rating_import_count';
  static const _kAskedKey = 'rating_asked_v1';
  static const _promptAfterImports = 3;

  static final InAppReview _review = InAppReview.instance;

  static Future<void> rateNow() async {
    try {
      if (await _review.isAvailable()) {
        await _review.requestReview();
        return;
      }
    } catch (_) {}
    await openStore();
  }

  static Future<void> openStore() async {
    try {
      await _review.openStoreListing();
      return;
    } catch (_) {}
    try {
      await launchUrl(
        Uri.parse(_storeUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
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
