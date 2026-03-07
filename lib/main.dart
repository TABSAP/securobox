import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_screenshot_blocker/flutter_screenshot_blocker.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'app.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
 await MobileAds.instance.initialize();
  FlutterScreenshotBlocker.enableScreenshotBlocking();
  await FlutterDownloader.initialize(
    debug: true,
  );
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system views overlay style
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
  runApp(const MyApp());
}


