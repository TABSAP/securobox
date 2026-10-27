import 'dart:io';
import 'package:flutter/services.dart';

// ignore: public_member_api_docs
class LiquidGlassHelper {
  LiquidGlassHelper._();

  static const MethodChannel _channel = MethodChannel('native_liquid_tab_bar');

  // ignore: public_member_api_docs
  static Future<bool> isLiquidGlassSupported() async {
    if (!Platform.isIOS) return false;
    try {
      final bool supported = await _channel.invokeMethod(
        'isLiquidGlassSupported',
      );
      return supported;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
