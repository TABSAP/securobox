import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
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

class DisguiseService extends ChangeNotifier {
  DisguiseService._();
  static final DisguiseService instance = DisguiseService._();

  static const _channel = MethodChannel('secure_player/disguise');

  static const List<DisguiseOption> options = [
    DisguiseOption(
      key: 'default',
      label: 'SecuroBox',
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

  String _currentKey = 'default';
  String get currentKey => _currentKey;

  DisguiseOption get currentOption =>
      options.firstWhere((o) => o.key == _currentKey, orElse: () => options.first);

  DisguiseOption optionFor(String key) =>
      options.firstWhere((o) => o.key == key, orElse: () => options.first);

  Future<void> load() async {
    final value = await getCurrent();
    if (value != _currentKey) {
      _currentKey = value;
      notifyListeners();
    }
  }

  Future<String> getCurrent() async {
    if (!isSupported) return _currentKey;
    try {
      final value = await _channel.invokeMethod<String>('getCurrent');
      return value ?? _currentKey;
    } catch (_) {
      return _currentKey;
    }
  }

  Future<bool> set(String key) async {
    if (!isSupported) {
      if (key != _currentKey) {
        _currentKey = key;
        notifyListeners();
      }
      return false;
    }
    try {
      final ok = await _channel.invokeMethod<bool>('set', {'name': key});
      final success = ok ?? false;
      if (success && key != _currentKey) {
        _currentKey = key;
        notifyListeners();
      }
      return success;
    } catch (_) {
      return false;
    }
  }
}
