import 'dart:io' show Platform;
import 'package:flutter/services.dart';

class DisguiseOption {
  final String key;
  final String label;
  final String assetIcon;

  const DisguiseOption({
    required this.key,
    required this.label,
    required this.assetIcon,
  });
}

class DisguiseService {
  DisguiseService._();
  static final DisguiseService instance = DisguiseService._();

  static const _channel = MethodChannel('secure_player/disguise');

  static const List<DisguiseOption> options = [
    DisguiseOption(
      key: 'default',
      label: 'Secure Player',
      assetIcon: 'assets/disguise/default.png',
    ),
    DisguiseOption(
      key: 'calculator',
      label: 'Calculator',
      assetIcon: 'assets/disguise/calculator.png',
    ),
    DisguiseOption(
      key: 'notes',
      label: 'Notes',
      assetIcon: 'assets/disguise/notes.png',
    ),
    DisguiseOption(
      key: 'weather',
      label: 'Weather',
      assetIcon: 'assets/disguise/weather.png',
    ),
    DisguiseOption(
      key: 'compass',
      label: 'Compass',
      assetIcon: 'assets/disguise/compass.png',
    ),
    DisguiseOption(
      key: 'utilities',
      label: 'Utilities',
      assetIcon: 'assets/disguise/utilities.png',
    ),
  ];

  bool get isSupported => Platform.isAndroid;

  Future<String> getCurrent() async {
    if (!isSupported) return 'default';
    try {
      final value = await _channel.invokeMethod<String>('getCurrent');
      return value ?? 'default';
    } catch (_) {
      return 'default';
    }
  }

  Future<bool> set(String key) async {
    if (!isSupported) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('set', {'name': key});
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }
}
