import 'package:flutter/material.dart';

import 'package:video_player_app/models/app_models.dart';

/// Central source of truth for the colour that represents a category.
///
/// The rest of the app deliberately stays monochrome-indigo, but a few surfaces
/// (Recently Added, category accents) benefit from a distinct, stable hue per
/// category. Keeping the mapping here means every screen renders the same file
/// in the same colour, and adding a new default category is a one-line change.
class CategoryStyle {
  CategoryStyle._();

  // Fixed hues for the built-in categories. Chosen to stay clean and modern:
  // saturated but not neon, and legible on both light and dark backgrounds.
  static const Color _videos = Color(0xFF6366F1); // indigo
  static const Color _photos = Color(0xFF10B981); // emerald
  static const Color _audio = Color(0xFF8B5CF6); // violet
  static const Color _documents = Color(0xFFF59E0B); // amber
  static const Color _favorites = Color(0xFFF43F5E); // rose
  static const Color _archives = Color(0xFF0EA5E9); // sky
  static const Color _code = Color(0xFF14B8A6); // teal
  static const Color _ebooks = Color(0xFFF97316); // orange
  static const Color _fonts = Color(0xFFEC4899); // pink
  static const Color _others = Color(0xFF64748B); // slate

  // Palette used to give custom categories a stable, distinct colour derived
  // from their name (so the same category always looks the same).
  static const List<Color> _palette = [
    Color(0xFF6366F1), // indigo
    Color(0xFF10B981), // emerald
    Color(0xFF8B5CF6), // violet
    Color(0xFFF59E0B), // amber
    Color(0xFFF43F5E), // rose
    Color(0xFF0EA5E9), // sky
    Color(0xFFEC4899), // pink
    Color(0xFF14B8A6), // teal
    Color(0xFFF97316), // orange
    Color(0xFF84CC16), // lime
  ];

  /// Colour for a category identified by its display name or storage key.
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
      case 'archives':
        return _archives;
      case 'code':
        return _code;
      case 'ebooks':
        return _ebooks;
      case 'fonts':
        return _fonts;
      case 'others':
        return _others;
    }
    // Custom category — stable colour from a hash of its name.
    var hash = 0;
    for (final unit in category.toLowerCase().codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return _palette[hash % _palette.length];
  }

  /// Colour that best represents a single file, preferring its media type so a
  /// photo reads "green" even when filed under a custom album.
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
      case 'archive':
        return _archives;
      case 'code':
        return _code;
      case 'ebook':
        return _ebooks;
      case 'font':
        return _fonts;
    }
    if (item.isFavorite) return _favorites;
    return forCategory(item.category);
  }
}
