import 'package:path/path.dart' as p;

class TitleHelper {
  TitleHelper._();

  static const _cameraPrefixes = [
    'IMG_', 'VID_', 'DSC_', 'DSCN', 'MVI_', 'MOV_', 'P_', 'PXL_',
    'GOPR', 'GH01', 'GP01', 'SAM_', 'WP_', 'OPS_', 'WIN_',
    'photo_', 'video_', 'image_', 'screenshot_',
  ];

  static String prettyTitleFromFilename(String filename) {
    var name = p.basenameWithoutExtension(filename).trim();
    if (name.isEmpty) return 'Untitled';

    for (final prefix in _cameraPrefixes) {
      if (name.toLowerCase().startsWith(prefix.toLowerCase())) {
        name = name.substring(prefix.length);
        break;
      }
    }

    name = name.replaceAll(RegExp(r'[_\-\.]+'), ' ').trim();
    name = name.replaceAll(RegExp(r'\s+'), ' ');

    if (name.isEmpty) return 'Untitled';

    if (RegExp(r'^[A-Z0-9 ]+$').hasMatch(name)) {
      name = name
          .toLowerCase()
          .split(' ')
          .map((w) => w.isEmpty
              ? w
              : w[0].toUpperCase() + w.substring(1))
          .join(' ');
    }

    if (name.length > 60) {
      name = '${name.substring(0, 57).trim()}…';
    }

    return name;
  }

  static String prettyTitleFromUrl(Uri uri, {String fallback = 'Downloaded'}) {
    final segments = uri.pathSegments
        .where((s) => s.isNotEmpty)
        .toList();
    if (segments.isEmpty) {
      return _withTimestamp(fallback);
    }
    final last = Uri.decodeComponent(segments.last);
    if (last.isEmpty || !last.contains(RegExp(r'[a-zA-Z]'))) {
      return _withTimestamp(fallback);
    }
    return prettyTitleFromFilename(last);
  }

  static String _withTimestamp(String base) {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$base ${now.year}-$m-$d';
  }
}
