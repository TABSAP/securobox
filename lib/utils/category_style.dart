import 'package:flutter/material.dart';

import 'package:video_player_app/models/app_models.dart';

class CategoryStyle {
  CategoryStyle._();

  static const Color _videos = Color(0xFF6366F1);
  static const Color _photos = Color(0xFF10B981);
  static const Color _audio = Color(0xFF8B5CF6);
  static const Color _documents = Color(0xFFF59E0B);
  static const Color _favorites = Color(0xFFF43F5E);
  static const Color _others = Color(0xFF64748B);

  static const List<Color> _palette = [
    Color(0xFF6366F1),
    Color(0xFF10B981),
    Color(0xFF8B5CF6),
    Color(0xFFF59E0B),
    Color(0xFFF43F5E),
    Color(0xFF0EA5E9),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
    Color(0xFFF97316),
    Color(0xFF84CC16),
  ];

  static Color forCategory(String category) {
    switch (category.toLowerCase()) {
      case 'videos':
        return _videos;
      case 'photos':
        return _photos;
      case 'audio':
        return _audio;
      case 'documents':
        return _documents;
      case 'favorites':
        return _favorites;
      case 'others':
        return _others;
    }
    var hash = 0;
    for (final unit in category.toLowerCase().codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return _palette[hash % _palette.length];
  }

  static Color forItem(VideoItem item) {
    switch (item.type) {
      case 'video':
        return _videos;
      case 'image':
        return _photos;
      case 'audio':
        return _audio;
      case 'document':
        return _documents;
    }
    if (item.isFavorite) return _favorites;
    return forCategory(item.category);
  }
}
