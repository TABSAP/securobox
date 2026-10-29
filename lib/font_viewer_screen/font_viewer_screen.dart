import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/utils/responsive.dart';
import 'package:video_player_app/widgets/app_loader.dart';
import 'package:video_player_app/widgets/app_spacing.dart';

class FontViewerScreen extends StatefulWidget {
  final String filePath;

  final String fileName;

  const FontViewerScreen({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  State<FontViewerScreen> createState() => _FontViewerScreenState();
}

abstract class _FontResult {
  const _FontResult();
}

class _LoadedFont extends _FontResult {
  final String family;

  final int sizeBytes;

  const _LoadedFont(this.family, this.sizeBytes);
}

class _UnsupportedFont extends _FontResult {
  final int? sizeBytes;

  const _UnsupportedFont(this.sizeBytes);
}

class _FontViewerScreenState extends State<FontViewerScreen> {
  late final Future<_FontResult> _future;

  static const List<String> _sizes = ['12', '16', '20', '28', '36'];

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_FontResult> _load() async {
    final ext = p.extension(widget.filePath).toLowerCase();

    if (ext == '.woff' || ext == '.woff2') {
      int? size;
      try {
        size = await File(widget.filePath).length();
      } catch (_) {
        size = null;
      }
      return _UnsupportedFont(size);
    }

    if (ext != '.ttf' && ext != '.otf') {
      int? size;
      try {
        size = await File(widget.filePath).length();
      } catch (_) {
        size = null;
      }
      return _UnsupportedFont(size);
    }

    try {
      final bytes = await File(widget.filePath).readAsBytes();
      final family = 'previewFont_${identityHashCode(this)}';
      final loader = FontLoader(family)
        ..addFont(Future.value(ByteData.view(bytes.buffer)));
      await loader.load();
      return _LoadedFont(family, bytes.length);
    } catch (_) {
      return _UnsupportedFont(null);
    }
  }

  String _formatBytes(int? bytes) {
    if (bytes == null) return 'N/A';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
      body: FutureBuilder<_FontResult>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: AppLoader(size: 40));
          }
          final result = snapshot.data ?? const _UnsupportedFont(null);
          if (result is _LoadedFont) return _buildSpecimen(result);
          return _buildUnavailable(result as _UnsupportedFont);
        },
      ),
    );
  }

  Widget _buildSpecimen(_LoadedFont font) {
    final family = font.family;
    final inset = context.contentInset(phone: 16);
    final baseName = p.basenameWithoutExtension(widget.filePath);
    final sample = baseName.isEmpty ? 'Aa Bb Cc' : baseName;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(inset, AppSpace.md, inset, AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _card(
            child: Text(
              sample,
              style: TextStyle(
                fontFamily: family,
                fontSize: 48,
                height: 1.15,
                color: LiquidColors.textPrimary,
              ),
            ),
          ),
          AppSpace.h16,
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _glyphLine('ABCDEFGHIJKLMNOPQRSTUVWXYZ', family),
                AppSpace.h12,
                _glyphLine('abcdefghijklmnopqrstuvwxyz', family),
                AppSpace.h12,
                _glyphLine('0123456789 !@#\$%^&*()', family),
              ],
            ),
          ),
          AppSpace.h24,
          _sectionLabel('Pangram'),
          AppSpace.h12,
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < _sizes.length; i++) ...[
                  if (i > 0) ...[
                    AppSpace.h16,
                    Divider(height: 1, color: LiquidColors.divider),
                    AppSpace.h16,
                  ],
                  _pangramRow(_sizes[i], family),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glyphLine(String text, String family) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: family,
        fontSize: 22,
        height: 1.3,
        color: LiquidColors.textPrimary,
      ),
    );
  }

  Widget _pangramRow(String size, String family) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$size px',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: LiquidColors.textTertiary,
          ),
        ),
        AppSpace.h8,
        Text(
          'The quick brown fox jumps over the lazy dog',
          style: TextStyle(
            fontFamily: family,
            fontSize: double.parse(size),
            height: 1.3,
            color: LiquidColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
        color: LiquidColors.textSecondary,
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: LiquidColors.surfaceMuted,
        borderRadius: AppRadius.rLg,
        border: Border.all(color: LiquidColors.cardBorder),
      ),
      child: child,
    );
  }

  Widget _buildUnavailable(_UnsupportedFont result) {
    final inset = context.contentInset(phone: 16);
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: inset, vertical: AppSpace.xl),
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
                Icons.font_download_outlined,
                size: 44,
                color: LiquidColors.indigo,
              ),
            ),
            AppSpace.h24,
            Text(
              'Preview unavailable',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: LiquidColors.textPrimary,
              ),
            ),
            AppSpace.h8,
            Text(
              "This font format can't be previewed inside the app yet.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.4,
                color: LiquidColors.textSecondary,
              ),
            ),
            AppSpace.h24,
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.md,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: LiquidColors.surfaceMuted,
                borderRadius: AppRadius.rMd,
                border: Border.all(color: LiquidColors.cardBorder),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.fileName,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: LiquidColors.textPrimary,
                    ),
                  ),
                  AppSpace.h4,
                  Text(
                    _formatBytes(result.sizeBytes),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: LiquidColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
