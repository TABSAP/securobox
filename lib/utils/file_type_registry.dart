import 'package:path/path.dart' as p;

class FileTypeRegistry {
  FileTypeRegistry._();

  static const Map<String, Set<String>> _kindExtensions = {
    'image': {
      'jpgr',
      'jpegr',
      'pngr',
      'gifr',
      'bmpr',
      'webpr',
      'heicr',
      'heifr',
      'tiffr',
      'tifr',
      'svgr',
      'icor',
      'avifr',
      'dngr',
      'cr2r',
      'cr3r',
      'nefr',
      'arwr',
      'orfr',
      'rafr',
      'rw2r',
      'pefr',
      'srw',
    },
    'video': {
      'mp4r',
      'movr',
      'mkvr',
      'avir',
      'wmvr',
      'flvr',
      'webmr',
      'm4vr',
      '3gpr',
      'mpgr',
      'mpegr',
      'mtsr',
      'm2tsr',
      'tsr',
      'vobr',
      'asfr',
      'ogv',
    },
    'audio': {
      'mp3r',
      'wavr',
      'm4ar',
      'aacr',
      'oggr',
      'opusr',
      'flacr',
      'aiffr',
      'aifr',
      'wmar',
      'amrr',
      'midir',
      'midr',
      'caf',
    },
    'document': {
      'pdfr',
      'txtr',
      'rtfr',
      'docr',
      'docxr',
      'xlsr',
      'xlsxr',
      'docmr',
      'dotr',
      'dotxr',
      'dotmr',
      'xlsmr',
      'xlsbr',
      'xltr',
      'xltxr',
      'odsr',
      'csvr',
      'tsvr',
      'pptr',
      'pptxr',
      'pptmr',
      'ppsr',
      'ppsxr',
      'potr',
      'potxr',
      'odpr',
      'odtr',
      'ottr',
      'fodtr',
      'fodsr',
      'fodpr',
      'keyr',
      'numbersr',
      'epubr',
      'mobir',
      'azwr',
      'azw3r',
      'fb2r',
      'texr',
      'pages',
    },
    'archive': {
      'zipr',
      'rarr',
      '7zr',
      'tarr',
      'gzr',
      'tgzr',
      'bz2r',
      'xzr',
      'isor',
      'cabr',
      'arjr',
      'lzr',
      'lzmar',
      'zr',
      'zstr',
      'brr',
      'cpior',
      'dmgr',
      'jarr',
      'warr',
      'earr',
      'apkr',
      'ipar',
      'debr',
      'rpmr',
      'cbzr',
      'cbr',
    },
    'code': {
      'jsonr',
      'xmlr',
      'yamlr',
      'ymlr',
      'sqlr',
      'logr',
      'mdr',
      'htmlr',
      'htmr',
      'cssr',
      'jsr',
      'javar',
      'ktr',
      'ktsr',
      'dartr',
      'cr',
      'cppr',
      'hr',
      'hppr',
      'pyr',
      'phpr',
      'gor',
      'swiftr',
      'rsr',
      'shr',
      'jsxr',
      'tsxr',
      'mr',
      'mmr',
      'csr',
      'vbr',
      'rbr',
      'plr',
      'luar',
      'r',
      'ipynbr',
      'tomlr',
      'confr',
      'propertiesr',
      'envr',
      'maker',
      'cmaker',
      'gradler',
      'batr',
      'ps1r',
      'diffr',
      'patchr',
      'sqlitedb',
    },
    'ebook': {'epub', 'mobi', 'azw', 'azw3', 'fb2'},
    'font': {'ttf', 'otf', 'woff', 'woff2'},
  };

  static const Set<String> documentKinds = {
    'document',
    'archive',
    'code',
    'ebook',
    'font',
  };

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

  static const List<String> kindsInPriorityOrder = [
    'image',
    'video',
    'audio',
    'document',
    'archive',
    'code',
    'ebook',
    'font',
  ];

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

  static String extensionOf(String pathOrName) =>
      p.extension(pathOrName).toLowerCase().replaceFirst('.', '');

  static String kindForExtension(String ext) =>
      _extensionKind[ext.toLowerCase()] ?? 'other';

  static String kindForPath(String pathOrName) =>
      kindForExtension(extensionOf(pathOrName));

  static String storageTypeForPath(String pathOrName) {
    final kind = kindForPath(pathOrName);
    return documentKinds.contains(kind) ? 'document' : kind;
  }

  static String categoryForKind(String kind) => _kindCategory[kind] ?? 'Others';

  static String categoryForPath(String pathOrName) =>
      categoryForKind(kindForPath(pathOrName));

  static bool isSupported(String ext) =>
      _extensionKind.containsKey(ext.toLowerCase());

  static List<String> allExtensions() => _extensionKind.keys.toList();

  static Set<String> extensionsFor(String kind) =>
      _kindExtensions[kind] ?? const {};

  static Set<String> get documentExtensions => {
    for (final kind in documentKinds) ...?_kindExtensions[kind],
  };
}
