import 'package:path/path.dart' as p;

class TitleHelper {
  TitleHelper._();

  static const _leadingNoisePrefixes = [
    'whatsapp image', 'whatsapp video', 'whatsapp audio', 'whatsapp ',
    'screen recording', 'screen_recording', 'screenrecording',
    'screenshot_', 'screenshot-', 'screenshot ',
    'voice recorder', 'voice memo', 'voice ', 'voice_', 'voice-',
    'recording_', 'recording-', 'recording ',
    'fb_img_', 'fb_img', 'facebook_', 'messenger_', 'telegram ',
    'signal-', 'snapchat-', 'snapchat_', 'instagram_', 'twitter_',
    'received_', 'received-', 'downloaded_', 'download_',
    'img_', 'vid_', 'aud_', 'dsc_', 'dscn', 'mvi_', 'mvimg_', 'mov_',
    'pxl_', 'gopr', 'gh01', 'gp01', 'sam_', 'wp_', 'ops_', 'win_',
    'cymera_', 'capture_', 'capture-', 'snap_', 'photo_', 'video_',
    'image_', 'audio_', 'pic_', 'tmp_', 'temp_', 'untitled_', 'img-',
    'vid-', 'aud-', 'ptt-',
  ];

  static const _datePatterns = [
    r'\b\d{4}[-_ ]?\d{2}[-_ ]?\d{2}\b',
    r'\b\d{2}[-_]\d{2}[-_]\d{4}\b',
    r'\bat\s+\d{1,2}[\._-]\d{2}([\._-]\d{2})?\s*(am|pm)?\b',
    r'\b\d{1,2}[\._-]\d{2}[\._-]\d{2}\b',
    r'\b\d{6}\b',
    r'\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\s+\d{1,2}(st|nd|rd|th)?\b',
  ];

  static String smartName(String filename, {String? type}) {
    var name = p.basenameWithoutExtension(filename).trim();
    if (name.isEmpty) return _typedFallback(type);

    final sorted = _leadingNoisePrefixes.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final prefix in sorted) {
      if (name.toLowerCase().startsWith(prefix)) {
        name = name.substring(prefix.length);
        break;
      }
    }

    for (final pat in _datePatterns) {
      name = name.replaceAll(RegExp(pat, caseSensitive: false), ' ');
    }

    name = name.replaceAll(
      RegExp(
        r'\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b',
        caseSensitive: false,
      ),
      ' ',
    );
    name = name.replaceAll(RegExp(r'\d{8,}'), ' ');
    name = name.replaceAll(RegExp(r'\b[0-9a-f]{12,}\b', caseSensitive: false), ' ');

    name = name.replaceAll(RegExp(r'\(\s*\d+\s*\)'), ' ');
    name = name.replaceAll(RegExp(r'\bcopy\s+of\b', caseSensitive: false), ' ');
    name = name.replaceAll(RegExp(r'[\-_ ]+copy\b', caseSensitive: false), ' ');
    name = name.replaceAll(RegExp(r'\(\s*copy\s*\)', caseSensitive: false), ' ');

    name = name.replaceAll(RegExp(r'[_\-\.]+'), ' ');
    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();
    name = name.replaceAll(RegExp(r'^[\s\W_]+'), '');
    name = name.replaceAll(RegExp(r'[\s\W_]+$'), '');
    name = name.trim();

    if (name.isEmpty ||
        !RegExp(r'[A-Za-z]').hasMatch(name) ||
        RegExp(r'^[\d\s]+$').hasMatch(name)) {
      return _typedFallback(type);
    }

    name = _smartTitleCase(name);

    if (name.length > 60) name = '${name.substring(0, 57).trim()}…';
    return name;
  }

  static String prettyTitleFromFilename(String filename) =>
      smartName(filename);

  static String prettyTitleFromUrl(Uri uri, {String fallback = 'Downloaded'}) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return _withTimestamp(fallback);
    final last = Uri.decodeComponent(segments.last);
    if (last.isEmpty || !last.contains(RegExp(r'[a-zA-Z]'))) {
      return _withTimestamp(fallback);
    }
    return smartName(last);
  }

  static String _typedFallback(String? type) {
    final base = switch ((type ?? '').toLowerCase()) {
      'video' => 'Video',
      'image' => 'Photo',
      'audio' => 'Audio',
      'document' || 'pdf' => 'Document',
      _ => 'File',
    };
    return _withTimestamp(base);
  }

  static String _smartTitleCase(String name) {
    final hasLower = name.contains(RegExp(r'[a-z]'));
    final hasUpper = name.contains(RegExp(r'[A-Z]'));
    if (hasLower && hasUpper) return name;
    return name
        .toLowerCase()
        .split(' ')
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  static String _withTimestamp(String base) {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$base ${now.year}-$m-$d';
  }
}
