import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'vault_context.dart';

/// A single category — either a built-in (default) one backed by a media type,
/// or a user-created custom one.
///
/// [key] is the STABLE identifier that media items are stored under
/// (`VideoItem.category`). It never changes, so renaming a category only
/// changes its display [name] and never orphans files. For defaults the key is
/// the canonical name ('Videos', 'Photos', …); for custom categories the key
/// equals the (original) name.
class CategoryInfo {
  final String key;
  final String? type; // 'video' | 'image' | 'audio' | 'document' | 'other'
  final bool isDefault;
  String name;
  bool hidden;

  CategoryInfo({
    required this.key,
    required this.type,
    required this.isDefault,
    required this.name,
    this.hidden = false,
  });

  Map<String, dynamic> toJson() => {
        'key': key,
        'type': type,
        'def': isDefault,
        'name': name,
        'hidden': hidden,
      };

  factory CategoryInfo.fromJson(Map<String, dynamic> j) => CategoryInfo(
        key: j['key'] as String,
        type: j['type'] as String?,
        isDefault: (j['def'] as bool?) ?? false,
        name: (j['name'] as String?) ?? (j['key'] as String),
        hidden: (j['hidden'] as bool?) ?? false,
      );
}

/// Manages the unified set of categories (defaults + custom): their display
/// names, visibility and order. Persisted as an ordered JSON list in
/// SharedPreferences. The list of custom category names is also mirrored into
/// [VaultContext.customCategoriesKey] so the importer and list screens keep
/// working unchanged.
class CategoryService {
  CategoryService._();
  static final CategoryService instance = CategoryService._();

  /// Notifies listeners (e.g. the dashboard) whenever categories change.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Canonical built-in categories, in their natural order. 'Favorites' is a
  /// smart category (type 'favorite') backed by each item's `isFavorite` flag
  /// rather than by a media type or a stored category name.
  static const List<(String, String)> defaults = [
    ('Favorites', 'favorite'),
    ('Videos', 'video'),
    ('Photos', 'image'),
    ('Audio', 'audio'),
    ('Documents', 'document'),
    ('Archives', 'archive'),
    ('Code', 'code'),
    ('eBooks', 'ebook'),
    ('Fonts', 'font'),
    ('Others', 'other'),
  ];

  String get _configKey => VaultContext.instance.categoriesConfigKey;
  String get _customKey => VaultContext.instance.customCategoriesKey;

  /// Loads the ordered category list, initialising/repairing it as needed so
  /// every built-in default is always present (appended if missing).
  Future<List<CategoryInfo>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_configKey);

    List<CategoryInfo> list = [];
    if (raw != null && raw.isNotEmpty) {
      try {
        list = (jsonDecode(raw) as List)
            .map((e) => CategoryInfo.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        list = [];
      }
    }

    if (list.isEmpty) {
      // First run (or corrupt): seed defaults, then migrate any legacy custom
      // categories that were stored under customCategoriesKey.
      list = [
        for (final d in defaults)
          CategoryInfo(
              key: d.$1, type: d.$2, isDefault: true, name: d.$1),
      ];
      final legacyCustom = prefs.getStringList(_customKey) ?? const [];
      for (final name in legacyCustom) {
        if (list.any((c) => c.key.toLowerCase() == name.toLowerCase())) {
          continue;
        }
        list.add(CategoryInfo(
            key: name, type: null, isDefault: false, name: name));
      }
      await _persist(list);
    } else {
      // Ensure any newly-added built-in default is present.
      var changed = false;
      for (final d in defaults) {
        if (!list.any((c) => c.key == d.$1)) {
          list.add(CategoryInfo(
              key: d.$1, type: d.$2, isDefault: true, name: d.$1));
          changed = true;
        }
      }
      if (changed) await _persist(list);
    }

    return list;
  }

  Future<void> _persist(List<CategoryInfo> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _configKey,
      jsonEncode(list.map((c) => c.toJson()).toList()),
    );
    // Keep the legacy custom-name list in sync for the importer/list screens.
    await prefs.setStringList(
      _customKey,
      list.where((c) => !c.isDefault).map((c) => c.name).toList(),
    );
  }

  /// Persists a full replacement list (used after reordering).
  Future<void> save(List<CategoryInfo> list) async {
    await _persist(list);
    revision.value++;
  }

  Future<void> rename(String key, String newName) async {
    final list = await load();
    final c = list.firstWhere((e) => e.key == key, orElse: () => list.first);
    c.name = newName;
    // For custom categories the key follows the name so filtering keeps working.
    if (!c.isDefault) {
      final renamed = CategoryInfo(
        key: newName,
        type: null,
        isDefault: false,
        name: newName,
        hidden: c.hidden,
      );
      final idx = list.indexOf(c);
      list[idx] = renamed;
    }
    await save(list);
  }

  Future<void> setHidden(String key, bool hidden) async {
    final list = await load();
    for (final c in list) {
      if (c.key == key) c.hidden = hidden;
    }
    await save(list);
  }

  Future<void> addCustom(String name) async {
    final list = await load();
    if (list.any((c) => c.name.toLowerCase() == name.toLowerCase() ||
        c.key.toLowerCase() == name.toLowerCase())) {
      return;
    }
    list.add(CategoryInfo(
        key: name, type: null, isDefault: false, name: name));
    await save(list);
  }

  /// Deletes a custom category. Defaults cannot be deleted (hide them instead).
  Future<void> deleteCustom(String key) async {
    final list = await load();
    list.removeWhere((c) => c.key == key && !c.isDefault);
    await save(list);
  }

  Future<void> reorder(List<CategoryInfo> ordered) async {
    await save(ordered);
  }
}
