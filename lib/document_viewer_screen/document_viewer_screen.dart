import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/widgets/app_spacing.dart';
import 'package:video_player_app/widgets/app_loader.dart';
import 'package:xml/xml.dart';

/// A fully offline, self-contained document previewer for the secure vault.
///
/// It is handed an ALREADY-DECRYPTED plaintext file on disk (the caller
/// decrypts first) and renders it locally — nothing is ever shared with other
/// apps or the network. Supports plain-text formats, and Office Open XML
/// documents (`.docx`, `.xlsx`, `.pptx`). Any other type — including the legacy
/// binary `.doc/.xls/.ppt` — or any parse failure falls back to a graceful
/// "preview not available" state instead of crashing.
///
/// PDFs are intentionally NOT handled here — the app has a dedicated PDF
/// viewer and this screen is only ever given non-PDF documents.
class DocumentViewerScreen extends StatefulWidget {
  /// Path to the decrypted plaintext file on disk. The real extension is
  /// derived from this path (not [fileName], which is only a display title).
  final String filePath;

  /// Display title shown in the AppBar. May lack a file extension.
  final String fileName;

  const DocumentViewerScreen({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

// ─────────────────────────────────────────────────────────────────────────
// Parsed content models
// ─────────────────────────────────────────────────────────────────────────

abstract class _DocContent {
  const _DocContent();
}

/// Monospaced, selectable plain text (optionally truncated).
class _TextContent extends _DocContent {
  final String text;
  const _TextContent(this.text);
}

/// Readable paragraphs (Word documents).
class _ParagraphsContent extends _DocContent {
  final List<String> paragraphs;
  const _ParagraphsContent(this.paragraphs);
}

/// A 2D grid (spreadsheets).
class _TableContent extends _DocContent {
  final List<List<String>> rows;
  final bool truncated;
  const _TableContent(this.rows, this.truncated);
}

/// Slide-by-slide text (presentations).
class _SlidesContent extends _DocContent {
  final List<List<String>> slides;
  const _SlidesContent(this.slides);
}

/// Graceful fallback for anything that cannot be previewed.
class _UnsupportedContent extends _DocContent {
  const _UnsupportedContent();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  late final Future<_DocContent> _future;

  static const int _maxTextBytes = 500 * 1024; // ~500 KB
  static const int _maxRows = 200;
  static const int _maxCols = 30;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DocContent> _load() async {
    try {
      final ext = p.extension(widget.filePath).toLowerCase();
      switch (ext) {
        case '.txt':
        case '.csv':
        case '.log':
        case '.md':
        case '.markdown':
        case '.json':
        case '.xml':
        case '.html':
        case '.htm':
        case '.rtf':
        case '.tex':
        case '.yaml':
        case '.yml':
        case '.ini':
        case '.tsv':
        // Source code & data files are plain text — show them in the text view.
        case '.sql':
        case '.css':
        case '.js':
        case '.ts':
        case '.java':
        case '.kt':
        case '.kts':
        case '.dart':
        case '.c':
        case '.cpp':
        case '.h':
        case '.hpp':
        case '.py':
        case '.php':
        case '.go':
        case '.swift':
        case '.rs':
        case '.sh':
          return await _loadText();
        case '.docx':
          return await _loadDocx();
        case '.xlsx':
          return await _loadXlsx();
        case '.pptx':
          return await _loadPptx();
        case '.epub':
          return await _loadEpub();
        case '.fb2':
          return await _loadFb2();
        case '.odt':
        case '.ods':
        case '.odp':
          return await _loadOdf();
        default:
          return const _UnsupportedContent();
      }
    } catch (_) {
      // Never surface a red error screen — fall back gracefully.
      return const _UnsupportedContent();
    }
  }

  // ── Plain text ───────────────────────────────────────────────────────────
  Future<_DocContent> _loadText() async {
    final file = File(widget.filePath);
    final length = await file.length();
    final truncated = length > _maxTextBytes;

    List<int> bytes;
    if (truncated) {
      final builder = BytesBuilder();
      await for (final chunk in file.openRead(0, _maxTextBytes)) {
        builder.add(chunk);
      }
      bytes = builder.takeBytes();
    } else {
      bytes = await file.readAsBytes();
    }

    String content;
    try {
      content = utf8.decode(bytes);
    } catch (_) {
      // Lenient fallback: latin1 maps every byte to a code point, never throws.
      content = latin1.decode(bytes);
    }

    if (truncated) {
      content = '$content\n\n… (truncated — showing the first 500 KB)';
    }
    return _TextContent(content);
  }

  // ── Word (.docx) ─────────────────────────────────────────────────────────
  Future<_DocContent> _loadDocx() async {
    final archive = ZipDecoder().decodeBytes(
      File(widget.filePath).readAsBytesSync(),
    );
    final entry = archive.findFile('word/document.xml');
    if (entry == null) return const _UnsupportedContent();

    final doc = XmlDocument.parse(utf8.decode(entry.content));
    final paragraphs = <String>[];
    for (final para in _byLocalName(doc.rootElement, 'p')) {
      final buffer = StringBuffer();
      for (final t in _byLocalName(para, 't')) {
        buffer.write(t.innerText);
      }
      paragraphs.add(buffer.toString());
    }
    if (paragraphs.every((line) => line.trim().isEmpty)) {
      return const _UnsupportedContent();
    }
    return _ParagraphsContent(paragraphs);
  }

  // ── Excel (.xlsx) ────────────────────────────────────────────────────────
  Future<_DocContent> _loadXlsx() async {
    final archive = ZipDecoder().decodeBytes(
      File(widget.filePath).readAsBytesSync(),
    );

    // Shared strings table (may be absent for numeric-only sheets).
    final sharedStrings = <String>[];
    final sharedEntry = archive.findFile('xl/sharedStrings.xml');
    if (sharedEntry != null) {
      final sharedDoc = XmlDocument.parse(utf8.decode(sharedEntry.content));
      for (final si in _byLocalName(sharedDoc.rootElement, 'si')) {
        final buffer = StringBuffer();
        for (final t in _byLocalName(si, 't')) {
          buffer.write(t.innerText);
        }
        sharedStrings.add(buffer.toString());
      }
    }

    final sheetEntry = archive.findFile('xl/worksheets/sheet1.xml');
    if (sheetEntry == null) return const _UnsupportedContent();
    final sheetDoc = XmlDocument.parse(utf8.decode(sheetEntry.content));

    final grid = <List<String>>[];
    var truncated = false;
    var maxColUsed = 0;

    for (final row in _byLocalName(sheetDoc.rootElement, 'row')) {
      if (grid.length >= _maxRows) {
        truncated = true;
        break;
      }
      final cellsByIndex = <int, String>{};
      var seq = 0;
      for (final c in _byLocalName(row, 'c')) {
        final ref = c.getAttribute('r');
        int colIndex;
        if (ref != null) {
          colIndex = _refToColumn(ref);
        } else {
          colIndex = seq;
        }
        seq = colIndex + 1;

        final valueEl = _byLocalName(c, 'v').firstOrNull;
        final inlineEl = _byLocalName(c, 't').firstOrNull;
        String value;
        final type = c.getAttribute('t');
        if (type == 's' && valueEl != null) {
          final idx = int.tryParse(valueEl.innerText.trim());
          value = (idx != null && idx >= 0 && idx < sharedStrings.length)
              ? sharedStrings[idx]
              : '';
        } else if (type == 'inlineStr' && inlineEl != null) {
          value = inlineEl.innerText;
        } else {
          value = valueEl?.innerText ?? '';
        }

        if (colIndex < _maxCols) {
          cellsByIndex[colIndex] = value;
          if (colIndex + 1 > maxColUsed) maxColUsed = colIndex + 1;
        } else {
          truncated = true;
        }
      }
      final rowList = List<String>.generate(
        maxColUsed,
        (i) => cellsByIndex[i] ?? '',
      );
      grid.add(rowList);
    }

    if (grid.isEmpty) return const _UnsupportedContent();

    // Normalise every row to the widest row so the table is rectangular.
    for (final r in grid) {
      while (r.length < maxColUsed) {
        r.add('');
      }
    }
    return _TableContent(grid, truncated);
  }

  // ── PowerPoint (.pptx) ───────────────────────────────────────────────────
  Future<_DocContent> _loadPptx() async {
    final archive = ZipDecoder().decodeBytes(
      File(widget.filePath).readAsBytesSync(),
    );

    final slideRegex = RegExp(r'^ppt/slides/slide(\d+)\.xml$');
    final slideEntries = <MapEntry<int, ArchiveFile>>[];
    for (final file in archive.files) {
      final match = slideRegex.firstMatch(file.name);
      if (match != null) {
        slideEntries.add(MapEntry(int.parse(match.group(1)!), file));
      }
    }
    if (slideEntries.isEmpty) return const _UnsupportedContent();
    slideEntries.sort((a, b) => a.key.compareTo(b.key));

    final slides = <List<String>>[];
    for (final entry in slideEntries) {
      final doc = XmlDocument.parse(utf8.decode(entry.value.content));
      final lines = <String>[];
      for (final t in _byLocalName(doc.rootElement, 't')) {
        final text = t.innerText;
        if (text.trim().isNotEmpty) lines.add(text);
      }
      slides.add(lines);
    }
    return _SlidesContent(slides);
  }

  // ── eBook (.epub) ────────────────────────────────────────────────────────
  Future<_DocContent> _loadEpub() async {
    final archive = ZipDecoder().decodeBytes(
      File(widget.filePath).readAsBytesSync(),
    );

    // Reading order: META-INF/container.xml → OPF → <spine> of <itemref>s,
    // resolved to hrefs via the <manifest>. Falls back to name-sorted XHTML.
    final order = <String>[];
    try {
      final container = archive.findFile('META-INF/container.xml');
      if (container != null) {
        final cdoc = XmlDocument.parse(utf8.decode(container.content));
        final rootfile = _byLocalName(cdoc.rootElement, 'rootfile').firstOrNull;
        final opfPath = rootfile?.getAttribute('full-path');
        final opf = opfPath == null ? null : archive.findFile(opfPath);
        if (opf != null) {
          final odoc = XmlDocument.parse(utf8.decode(opf.content));
          final manifest = <String, String>{};
          for (final item in _byLocalName(odoc.rootElement, 'item')) {
            final id = item.getAttribute('id');
            final href = item.getAttribute('href');
            if (id != null && href != null) manifest[id] = href;
          }
          final base = p.dirname(opfPath!);
          for (final ref in _byLocalName(odoc.rootElement, 'itemref')) {
            final href = manifest[ref.getAttribute('idref')];
            if (href == null) continue;
            order.add(base == '.' ? href : p.normalize('$base/$href'));
          }
        }
      }
    } catch (_) {
      // Fall through to the name-sorted fallback below.
    }
    if (order.isEmpty) {
      order.addAll(
        archive.files
            .where((f) =>
                f.isFile &&
                RegExp(r'\.(x?html?|htm)$', caseSensitive: false)
                    .hasMatch(f.name))
            .map((f) => f.name)
            .toList()
          ..sort(),
      );
    }

    final paragraphs = <String>[];
    for (final path in order) {
      final entry = archive.findFile(path);
      if (entry == null) continue;
      for (final para in _htmlParagraphs(entry.content)) {
        paragraphs.add(para);
        if (paragraphs.length >= 6000) {
          paragraphs.add('… (truncated)');
          break;
        }
      }
      if (paragraphs.length >= 6000) break;
    }
    if (paragraphs.every((line) => line.trim().isEmpty)) {
      return const _UnsupportedContent();
    }
    return _ParagraphsContent(paragraphs);
  }

  // ── OpenDocument (.odt / .ods / .odp) ────────────────────────────────────
  Future<_DocContent> _loadOdf() async {
    final archive = ZipDecoder().decodeBytes(
      File(widget.filePath).readAsBytesSync(),
    );
    final entry = archive.findFile('content.xml');
    if (entry == null) return const _UnsupportedContent();

    final doc = XmlDocument.parse(utf8.decode(entry.content));
    final paragraphs = <String>[];
    // OpenDocument paragraphs are <text:p> (local name 'p'); this reads text
    // from documents, spreadsheets and presentations alike.
    for (final para in _byLocalName(doc.rootElement, 'p')) {
      final text = para.innerText.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (text.isNotEmpty) paragraphs.add(text);
    }
    if (paragraphs.isEmpty) return const _UnsupportedContent();
    return _ParagraphsContent(paragraphs);
  }

  // ── eBook (.fb2 — FictionBook XML) ───────────────────────────────────────
  Future<_DocContent> _loadFb2() async {
    final raw = utf8.decode(
      File(widget.filePath).readAsBytesSync(),
      allowMalformed: true,
    );
    final doc = XmlDocument.parse(raw);
    final paragraphs = <String>[];
    for (final body in _byLocalName(doc.rootElement, 'body')) {
      for (final para in _byLocalName(body, 'p')) {
        final text = para.innerText.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (text.isNotEmpty) paragraphs.add(text);
      }
    }
    if (paragraphs.isEmpty) return const _UnsupportedContent();
    return _ParagraphsContent(paragraphs);
  }

  /// Extracts readable paragraphs from an (X)HTML chapter's raw bytes. Prefers
  /// well-formed XML parsing (paragraph elements, else the body text); falls
  /// back to stripping tags so malformed markup still yields text.
  Iterable<String> _htmlParagraphs(List<int> bytes) {
    final out = <String>[];
    try {
      final doc = XmlDocument.parse(utf8.decode(bytes, allowMalformed: true));
      final body = _byLocalName(doc.rootElement, 'body').firstOrNull ??
          doc.rootElement;
      final ps = _byLocalName(body, 'p').toList();
      if (ps.isNotEmpty) {
        for (final para in ps) {
          final text = para.innerText.replaceAll(RegExp(r'\s+'), ' ').trim();
          if (text.isNotEmpty) out.add(text);
        }
      } else {
        final text = body.innerText.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (text.isNotEmpty) out.add(text);
      }
    } catch (_) {
      final stripped = utf8
          .decode(bytes, allowMalformed: true)
          .replaceAll(RegExp(r'<[^>]*>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (stripped.isNotEmpty) out.add(stripped);
    }
    return out;
  }

  // ── XML helpers (namespace-robust, match by local name) ──────────────────
  Iterable<XmlElement> _byLocalName(XmlElement root, String local) {
    return root.descendants
        .whereType<XmlElement>()
        .where((e) => e.name.local == local);
  }

  /// Converts a cell reference like "AB12" to a 0-based column index.
  int _refToColumn(String ref) {
    var col = 0;
    for (final code in ref.codeUnits) {
      if (code >= 65 && code <= 90) {
        col = col * 26 + (code - 64);
      } else if (code >= 97 && code <= 122) {
        col = col * 26 + (code - 96);
      } else {
        break; // reached the digits of the reference
      }
    }
    return col > 0 ? col - 1 : 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LiquidColors.backgroundDeep,
      appBar: AppBar(
        backgroundColor: LiquidColors.backgroundDeep,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: LiquidColors.systemOverlayStyle,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: LiquidColors.textPrimary,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          widget.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: LiquidColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: FutureBuilder<_DocContent>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: AppLoader(size: 40));
          }
          final content = snapshot.data ?? const _UnsupportedContent();
          return _buildContent(content);
        },
      ),
    );
  }

  Widget _buildContent(_DocContent content) {
    if (content is _TextContent) return _buildText(content);
    if (content is _ParagraphsContent) return _buildParagraphs(content);
    if (content is _TableContent) return _buildTable(content);
    if (content is _SlidesContent) return _buildSlides(content);
    return _buildUnsupported();
  }

  // ── Renderers ────────────────────────────────────────────────────────────
  Widget _buildText(_TextContent content) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(AppSpace.md),
      child: SelectableText(
        content.text,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13.5,
          height: 1.5,
          color: LiquidColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildParagraphs(_ParagraphsContent content) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.lg,
        vertical: AppSpace.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final para in content.paragraphs)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SelectableText(
                para.isEmpty ? ' ' : para,
                style: TextStyle(
                  fontSize: 15.5,
                  height: 1.55,
                  color: LiquidColors.textPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTable(_TableContent content) {
    final borderColor = LiquidColors.cardBorder;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Container(
              decoration: BoxDecoration(
                color: LiquidColors.backgroundLight.withValues(alpha: 0.55),
                border: Border.all(color: borderColor),
                borderRadius: AppRadius.rMd,
              ),
              clipBehavior: Clip.antiAlias,
              child: Table(
                defaultColumnWidth: const IntrinsicColumnWidth(),
                border: TableBorder(
                  horizontalInside: BorderSide(color: LiquidColors.divider),
                  verticalInside: BorderSide(color: LiquidColors.divider),
                ),
                children: [
                  for (var r = 0; r < content.rows.length; r++)
                    TableRow(
                      decoration: r == 0
                          ? BoxDecoration(color: LiquidColors.surfaceMuted)
                          : null,
                      children: [
                        for (final cell in content.rows[r])
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                            child: Text(
                              cell,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: r == 0
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: r == 0
                                    ? LiquidColors.textPrimary
                                    : LiquidColors.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          if (content.truncated)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.sm),
              child: Text(
                'Large sheet — showing the first $_maxRows rows and $_maxCols columns.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: LiquidColors.textTertiary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSlides(_SlidesContent content) {
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(AppSpace.md),
      itemCount: content.slides.length,
      separatorBuilder: (_, _) => AppSpace.h12,
      itemBuilder: (context, index) {
        final lines = content.slides[index];
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpace.md),
          decoration: BoxDecoration(
            color: LiquidColors.backgroundLight.withValues(alpha: 0.55),
            border: Border.all(color: LiquidColors.cardBorder),
            borderRadius: AppRadius.rMd,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Slide ${index + 1}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: LiquidColors.indigo,
                ),
              ),
              AppSpace.h8,
              if (lines.isEmpty)
                Text(
                  'No text on this slide.',
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: LiquidColors.textTertiary,
                  ),
                )
              else
                for (final line in lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: SelectableText(
                      line,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: LiquidColors.textPrimary,
                      ),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUnsupported() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: LiquidColors.indigo.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.description_outlined,
                size: 44,
                color: LiquidColors.indigo,
              ),
            ),
            AppSpace.h24,
            Text(
              'Preview not available',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: LiquidColors.textPrimary,
              ),
            ),
            AppSpace.h8,
            Text(
              "This file type can't be previewed inside the app yet.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: LiquidColors.textSecondary,
              ),
            ),
            AppSpace.h12,
            Text(
              widget.fileName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: LiquidColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
