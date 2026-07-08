import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/utils/responsive.dart';
import 'package:video_player_app/widgets/app_loader.dart';
import 'package:video_player_app/widgets/app_spacing.dart';

/// A read-only, offline listing of what's inside an already-decrypted archive
/// file on disk. Supports listing of zip/tar/gz/tgz/bz2/xz; other formats
/// (rar/7z/iso) fall back to a graceful "can't preview" state. Never opens or
/// extracts inner files — it only shows their names/sizes.
class ArchiveViewerScreen extends StatefulWidget {
  const ArchiveViewerScreen({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  /// Absolute path to the already-decrypted archive on disk.
  final String filePath;

  /// Display title for the AppBar (may lack an extension).
  final String fileName;

  @override
  State<ArchiveViewerScreen> createState() => _ArchiveViewerScreenState();
}

/// One row in the listing.
class _Entry {
  const _Entry({
    required this.name,
    required this.isDirectory,
    required this.size,
  });

  final String name;
  final bool isDirectory;
  final int size;
}

enum _Status { loading, loaded, error }

/// Cap the displayed list so huge archives don't hang the UI.
const int _kMaxEntries = 2000;

class _ArchiveViewerScreenState extends State<ArchiveViewerScreen> {
  _Status _status = _Status.loading;
  List<_Entry> _entries = const [];
  int _totalCount = 0; // total entries (files, before display cap)
  int _totalSize = 0; // total uncompressed size in bytes
  int _overflow = 0; // how many entries beyond the display cap

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await _parse();
      if (!mounted) return;
      setState(() {
        _entries = result.entries;
        _totalCount = result.totalCount;
        _totalSize = result.totalSize;
        _overflow = result.overflow;
        _status = _Status.loaded;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = _Status.error);
    }
  }

  Future<_ParseResult> _parse() async {
    final ext = p.extension(widget.filePath).toLowerCase();
    final lowerName = widget.fileName.toLowerCase();

    // Formats we can't list inside the app — bail out gracefully.
    if (ext == '.rar' || ext == '.7z' || ext == '.iso') {
      throw const _UnsupportedArchive();
    }

    final bytes = await File(widget.filePath).readAsBytes();

    switch (ext) {
      case '.zip':
        return _fromArchive(ZipDecoder().decodeBytes(bytes));

      case '.tar':
        return _fromArchive(TarDecoder().decodeBytes(bytes));

      case '.gz':
      case '.tgz':
        final inner = GZipDecoder().decodeBytes(bytes);
        return _fromMaybeTar(
          inner,
          isTar: ext == '.tgz' || _looksLikeTarName(lowerName),
          singleName: _stripSuffix(widget.fileName, '.gz'),
        );

      case '.bz2':
        final inner = BZip2Decoder().decodeBytes(bytes);
        return _fromMaybeTar(
          inner,
          isTar: _looksLikeTarName(lowerName),
          singleName: _stripSuffix(widget.fileName, '.bz2'),
        );

      case '.xz':
        final inner = XZDecoder().decodeBytes(bytes);
        return _fromMaybeTar(
          inner,
          isTar: _looksLikeTarName(lowerName),
          singleName: _stripSuffix(widget.fileName, '.xz'),
        );

      default:
        throw const _UnsupportedArchive();
    }
  }

  /// A `.gz`/`.bz2`/`.xz` may wrap a tar (`.tar.gz`, `.tgz`, …) or a single
  /// file. Decode the tar if it looks like one, otherwise present one entry.
  _ParseResult _fromMaybeTar(
    List<int> inner, {
    required bool isTar,
    required String singleName,
  }) {
    if (isTar) {
      return _fromArchive(TarDecoder().decodeBytes(inner));
    }
    return _ParseResult(
      entries: [
        _Entry(name: singleName, isDirectory: false, size: inner.length),
      ],
      totalCount: 1,
      totalSize: inner.length,
      overflow: 0,
    );
  }

  /// Collect metadata only (name/size/isFile) — never touches entry `.content`,
  /// so large archives stay light on memory.
  _ParseResult _fromArchive(Archive archive) {
    final all = <_Entry>[];
    var totalSize = 0;
    for (final f in archive.files) {
      final isDir = f.isDirectory;
      final size = f.size;
      if (!isDir) totalSize += size;
      all.add(_Entry(name: f.name, isDirectory: isDir, size: size));
    }

    // Directories first, then files; each group sorted case-insensitively.
    all.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    final overflow = all.length > _kMaxEntries ? all.length - _kMaxEntries : 0;
    final shown = overflow > 0 ? all.sublist(0, _kMaxEntries) : all;

    return _ParseResult(
      entries: shown,
      totalCount: all.length,
      totalSize: totalSize,
      overflow: overflow,
    );
  }

  static bool _looksLikeTarName(String lowerName) =>
      lowerName.endsWith('.tar.gz') ||
      lowerName.endsWith('.tar.bz2') ||
      lowerName.endsWith('.tar.xz') ||
      lowerName.endsWith('.tgz') ||
      lowerName.endsWith('.tbz') ||
      lowerName.endsWith('.tbz2') ||
      lowerName.endsWith('.txz') ||
      lowerName.endsWith('.tar');

  static String _stripSuffix(String name, String suffix) {
    if (name.toLowerCase().endsWith(suffix)) {
      return name.substring(0, name.length - suffix.length);
    }
    return name;
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
          icon: Icon(Icons.arrow_back_rounded, color: LiquidColors.textPrimary),
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
      body: SafeArea(top: false, child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_status) {
      case _Status.loading:
        return const Center(child: AppLoader(size: 40));
      case _Status.error:
        return _buildError(context);
      case _Status.loaded:
        return _buildList(context);
    }
  }

  Widget _buildError(BuildContext context) {
    final inset = context.contentInset(phone: 16);
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: inset + 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: LiquidColors.indigo.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.folder_zip_outlined,
                size: 40,
                color: LiquidColors.indigo,
              ),
            ),
            AppSpace.h24,
            Text(
              "Can't preview this archive",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: LiquidColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            AppSpace.h8,
            Text(
              "This archive format can't be listed inside the app.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: LiquidColors.textSecondary,
                fontSize: 14,
                height: 1.35,
              ),
            ),
            AppSpace.h12,
            Text(
              widget.fileName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: LiquidColors.textTertiary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final inset = context.contentInset(phone: 16);

    if (_entries.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: inset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            Expanded(
              child: Center(
                child: Text(
                  'This archive is empty.',
                  style: TextStyle(
                    color: LiquidColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: inset),
          child: _buildHeader(),
        ),
        Expanded(
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(inset, 4, inset, inset + 12),
            itemCount: _entries.length + (_overflow > 0 ? 1 : 0),
            separatorBuilder: (_, _) => Divider(
              height: 1,
              thickness: 1,
              color: LiquidColors.divider,
            ),
            itemBuilder: (context, index) {
              if (_overflow > 0 && index == _entries.length) {
                return _buildOverflowRow();
              }
              return _buildRow(_entries[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final fileCount = _totalCount;
    final label =
        '${_countLabel(fileCount)}  ·  ${_formatSize(_totalSize)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
      child: Text(
        label,
        style: TextStyle(
          color: LiquidColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildRow(_Entry entry) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: LiquidColors.surfaceMuted,
              borderRadius: AppRadius.rSm,
            ),
            child: Icon(
              entry.isDirectory
                  ? Icons.folder_rounded
                  : Icons.insert_drive_file_rounded,
              size: 20,
              color: LiquidColors.indigo,
            ),
          ),
          AppSpace.w12,
          Expanded(
            child: Text(
              _displayName(entry.name),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: LiquidColors.textPrimary,
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (!entry.isDirectory) ...[
            AppSpace.w8,
            Text(
              _formatSize(entry.size),
              style: TextStyle(
                color: LiquidColors.textTertiary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOverflowRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Text(
        'and $_overflow more…',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: LiquidColors.textTertiary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Show the last path segment as the primary name for readability.
  static String _displayName(String fullPath) {
    final trimmed = fullPath.endsWith('/')
        ? fullPath.substring(0, fullPath.length - 1)
        : fullPath;
    final slash = trimmed.lastIndexOf('/');
    final name = slash >= 0 ? trimmed.substring(slash + 1) : trimmed;
    return name.isEmpty ? fullPath : name;
  }

  static String _countLabel(int count) =>
      count == 1 ? '1 item' : '$count items';

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    const units = ['KB', 'MB', 'GB', 'TB'];
    var size = bytes / 1024;
    var unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    final str = size >= 100 || size == size.roundToDouble()
        ? size.toStringAsFixed(0)
        : size.toStringAsFixed(1);
    return '$str ${units[unit]}';
  }
}

class _ParseResult {
  const _ParseResult({
    required this.entries,
    required this.totalCount,
    required this.totalSize,
    required this.overflow,
  });

  final List<_Entry> entries;
  final int totalCount;
  final int totalSize;
  final int overflow;
}

/// Sentinel thrown for formats we intentionally don't list; caught by [_load]
/// which flips into the graceful error state.
class _UnsupportedArchive implements Exception {
  const _UnsupportedArchive();
}
