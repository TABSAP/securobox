import 'package:path/path.dart' as p;

/// Single source of truth mapping file extensions → a "kind" → a default
/// category, plus the MIME types each kind covers.
///
/// Adding support for a new file type is intentionally a one-line change here:
/// drop the extension into the relevant kind's set (and, if introducing a brand
/// new kind, add it to [_kindCategory], [kindsInPriorityOrder], the category
/// defaults in CategoryService, the icon in MediaHelper, and the colour in
/// CategoryStyle). Everything else — detection, categorisation, the share
/// intent filters, the file picker — reads from this registry.
class FileTypeRegistry {
  FileTypeRegistry._();

  /// Extension → kind. Extensions are lowercase, without a leading dot.
  ///
  /// A few extensions are inherently ambiguous across kinds (e.g. `.ts` is both
  /// MPEG-transport-stream video and TypeScript source). Each extension is
  /// assigned to exactly one kind here for deterministic detection; `.ts` is
  /// treated as video in this media-first vault.
  static const Map<String, Set<String>> _kindExtensions = {
    'image': {
      'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'heic', 'heif', 'tiff',
      'tif', 'svg', 'ico', 'avif',
      // RAW camera formats
      'dng', 'cr2', 'cr3', 'nef', 'arw', 'orf', 'raf', 'rw2', 'pef', 'srw',
    },
    'video': {
      'mp4', 'mov', 'mkv', 'avi', 'wmv', 'flv', 'webm', 'm4v', '3gp', 'mpg',
      'mpeg', 'mts', 'm2ts', 'ts', 'vob', 'asf', 'ogv',
    },
    'audio': {
      'mp3', 'wav', 'm4a', 'aac', 'ogg', 'opus', 'flac', 'aiff', 'aif', 'wma',
      'amr', 'midi', 'mid', 'caf',
    },
    'document': {
      'pdf', 'txt', 'rtf', 'doc', 'docx', 'odt', 'pages', 'xls', 'xlsx',
      'xlsm', 'ods', 'csv', 'tsv', 'ppt', 'pptx', 'pps', 'ppsx', 'odp',
    },
    'archive': {
      'zip', 'rar', '7z', 'tar', 'gz', 'tgz', 'bz2', 'xz', 'iso',
    },
    'code': {
      'json', 'xml', 'yaml', 'yml', 'sql', 'log', 'md', 'html', 'htm', 'css',
      'js', 'java', 'kt', 'kts', 'dart', 'c', 'cpp', 'h', 'hpp', 'py', 'php',
      'go', 'swift', 'rs', 'sh',
    },
    'ebook': {
      'epub', 'mobi', 'azw', 'azw3', 'fb2',
    },
    'font': {
      'ttf', 'otf', 'woff', 'woff2',
    },
  };

  /// Kinds that all live under the single "Documents" category. The fine-grained
  /// kind is still used to pick the right viewer (archive listing, font
  /// specimen, …); only the *category* is collapsed, keeping the library simple.
  static const Set<String> documentKinds = {
    'document', 'archive', 'code', 'ebook', 'font',
  };

  /// Kind → default category display name (must match CategoryService defaults).
  static const Map<String, String> _kindCategory = {
    'image': 'Photos',
    'video': 'Videos',
    'audio': 'Audio',
    'document': 'Documents',
    'archive': 'Documents',
    'code': 'Documents',
    'ebook': 'Documents',
    'font': 'Documents',
  };

  /// Priority order used when building a reverse lookup, so a duplicated
  /// extension resolves deterministically to the first-listed kind.
  static const List<String> kindsInPriorityOrder = [
    'image', 'video', 'audio', 'document', 'archive', 'code', 'ebook', 'font',
  ];

  // Reverse index (extension → kind), built once from [_kindExtensions].
  static final Map<String, String> _extensionKind = _buildExtensionIndex();

  static Map<String, String> _buildExtensionIndex() {
    final map = <String, String>{};
    for (final kind in kindsInPriorityOrder) {
      for (final ext in _kindExtensions[kind] ?? const <String>{}) {
        map.putIfAbsent(ext, () => kind);
      }
    }
    return map;
  }

  /// Normalises a path/name to a bare lowercase extension (no dot).
  static String extensionOf(String pathOrName) =>
      p.extension(pathOrName).toLowerCase().replaceFirst('.', '');

  /// The kind for an extension, or `'other'` if unknown.
  static String kindForExtension(String ext) =>
      _extensionKind[ext.toLowerCase()] ?? 'other';

  /// The kind for a path/name, or `'other'` if unknown.
  static String kindForPath(String pathOrName) =>
      kindForExtension(extensionOf(pathOrName));

  /// The type stored on a vault item (`VideoItem.type`). Media keeps its own
  /// type; every document-ish kind collapses to `'document'` so it lives in the
  /// Documents category and is filtered/counted there. Viewers still route on
  /// the fine-grained [kindForPath] of the real file, so archives and fonts keep
  /// their dedicated viewers.
  static String storageTypeForPath(String pathOrName) {
    final kind = kindForPath(pathOrName);
    return documentKinds.contains(kind) ? 'document' : kind;
  }

  /// The default category name for a kind (unknown kinds → 'Others').
  static String categoryForKind(String kind) =>
      _kindCategory[kind] ?? 'Others';

  /// The default category name for a path/name.
  static String categoryForPath(String pathOrName) =>
      categoryForKind(kindForPath(pathOrName));

  /// Whether an extension is recognised by any kind.
  static bool isSupported(String ext) =>
      _extensionKind.containsKey(ext.toLowerCase());

  /// All recognised extensions (no dots), e.g. for the file picker.
  static List<String> allExtensions() => _extensionKind.keys.toList();

  /// Extensions belonging to a kind.
  static Set<String> extensionsFor(String kind) =>
      _kindExtensions[kind] ?? const {};
}
