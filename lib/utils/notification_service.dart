import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final int timestamp;
  final String kind;
  bool read;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.kind = 'info',
    this.read = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'ts': timestamp,
    'kind': kind,
    'read': read,
  };

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id: j['id'] as String,
    title: j['title'] as String,
    body: j['body'] as String,
    timestamp: j['ts'] as int,
    kind: (j['kind'] as String?) ?? 'info',
    read: (j['read'] as bool?) ?? false,
  );
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const String _storeKey = 'app_notifications_v1';
  static const String _versionKey = 'app_notifications_last_version';

  final ValueNotifier<List<AppNotification>> notifications =
      ValueNotifier<List<AppNotification>>(const []);

  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  bool _initialised = false;

  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;
    await _load();
    await _seedForCurrentVersion();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storeKey);
      if (raw == null || raw.isEmpty) {
        _publish(const []);
        return;
      }
      final decoded = (jsonDecode(raw) as List)
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
          .toList();
      _publish(decoded);
    } catch (_) {
      _publish(const []);
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(
        notifications.value.map((n) => n.toJson()).toList(),
      );
      await prefs.setString(_storeKey, raw);
    } catch (_) {}
  }

  void _publish(List<AppNotification> list) {
    final sorted = List<AppNotification>.of(list)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    notifications.value = List.unmodifiable(sorted);
    unreadCount.value = sorted.where((n) => !n.read).length;
  }

  Future<void> _seedForCurrentVersion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final info = await PackageInfo.fromPlatform();
      final current = '${info.version}+${info.buildNumber}';
      final last = prefs.getString(_versionKey);

      if (last == null) {
        await prefs.setString(_versionKey, current);
      } else if (last != current) {
        final existing = notifications.value.toList();
        final existingIds = existing.map((n) => n.id).toSet();
        final id = 'update_$current';
        if (!existingIds.contains(id)) {
          existing.add(
            AppNotification(
              id: id,
              title: 'App updated',
              body:
                  'SecuroBox was updated to version ${info.version}. '
                  'Tap to see what\'s new.',
              timestamp: DateTime.now().millisecondsSinceEpoch,
              kind: 'update',
            ),
          );
          _publish(existing);
          await _persist();
        }
        await prefs.setString(_versionKey, current);
      }
    } catch (_) {}
  }

  Future<void> add({
    required String id,
    required String title,
    required String body,
    String kind = 'info',
  }) async {
    if (notifications.value.any((n) => n.id == id)) return;
    final list = notifications.value.toList()
      ..add(
        AppNotification(
          id: id,
          title: title,
          body: body,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          kind: kind,
        ),
      );
    _publish(list);
    await _persist();
  }

  Future<void> addEvent({
    required String title,
    required String body,
    String kind = 'info',
  }) async {
    final id = 'evt_${DateTime.now().microsecondsSinceEpoch}';
    await add(id: id, title: title, body: body, kind: kind);
  }

  Future<void> markAllRead() async {
    for (final n in notifications.value) {
      n.read = true;
    }
    _publish(notifications.value.toList());
    await _persist();
  }

  Future<void> remove(String id) async {
    final list = notifications.value.where((n) => n.id != id).toList();
    _publish(list);
    await _persist();
  }

  Future<void> clearAll() async {
    _publish(const []);
    await _persist();
  }
}
