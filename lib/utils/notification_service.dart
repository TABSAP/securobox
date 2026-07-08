import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A single in-app notification (an update or new-feature announcement).
class AppNotification {
  final String id;
  final String title;
  final String body;
  final int timestamp; // millis since epoch
  final String kind; // 'update' | 'feature' | 'info'
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

/// App-wide, device-level notification store. Notifications persist across
/// launches and are surfaced by a bell icon in the Library app bar. New
/// notifications are added automatically when the app is updated to a new
/// version and when real events happen (a break-in, a completed import, etc.).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const String _storeKey = 'app_notifications_v1';
  static const String _versionKey = 'app_notifications_last_version';

  /// The current, most-recent-first list of notifications.
  final ValueNotifier<List<AppNotification>> notifications =
      ValueNotifier<List<AppNotification>>(const []);

  /// Unread count, for the bell badge.
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
      final raw =
          jsonEncode(notifications.value.map((n) => n.toJson()).toList());
      await prefs.setString(_storeKey, raw);
    } catch (_) {}
  }

  void _publish(List<AppNotification> list) {
    // Copy first — callers may pass a const/unmodifiable list.
    final sorted = List<AppNotification>.of(list)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    notifications.value = List.unmodifiable(sorted);
    unreadCount.value = sorted.where((n) => !n.read).length;
  }

  /// Detects version changes and ensures the relevant notifications exist.
  Future<void> _seedForCurrentVersion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final info = await PackageInfo.fromPlatform();
      final current = '${info.version}+${info.buildNumber}';
      final last = prefs.getString(_versionKey);

      // Update notification when the installed version changes.
      if (last == null) {
        // First run — set the version baseline only. Real, event-driven
        // notifications are added later as things actually happen.
        await prefs.setString(_versionKey, current);
      } else if (last != current) {
        final existing = notifications.value.toList();
        final existingIds = existing.map((n) => n.id).toSet();
        final id = 'update_$current';
        if (!existingIds.contains(id)) {
          existing.add(AppNotification(
            id: id,
            title: 'App updated',
            body: 'SecuroBox was updated to version ${info.version}. '
                'Tap to see what\'s new.',
            timestamp: DateTime.now().millisecondsSinceEpoch,
            kind: 'update',
          ));
          _publish(existing);
          await _persist();
        }
        await prefs.setString(_versionKey, current);
      }
    } catch (_) {
      // If version lookup fails, leave the existing notifications untouched.
    }
  }

  /// Adds a notification programmatically (deduped by id). Useful for future
  /// server-driven or event-driven alerts.
  Future<void> add({
    required String id,
    required String title,
    required String body,
    String kind = 'info',
  }) async {
    if (notifications.value.any((n) => n.id == id)) return;
    final list = notifications.value.toList()
      ..add(AppNotification(
        id: id,
        title: title,
        body: body,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        kind: kind,
      ));
    _publish(list);
    await _persist();
  }

  /// Adds an event-driven notification with a unique, time-based id. Use this
  /// for real, in-the-moment alerts (a break-in, a completed import, etc.).
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
