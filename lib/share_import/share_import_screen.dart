import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'package:video_player_app/utils/category_service.dart';
import 'package:video_player_app/utils/category_style.dart';
import 'package:video_player_app/utils/file_type_registry.dart';
import 'package:video_player_app/utils/flush_bar_helper.dart';
import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/utils/media_helper.dart';
import 'package:video_player_app/utils/media_importer.dart';
import 'package:video_player_app/utils/responsive.dart';
import 'package:video_player_app/widgets/app_spacing.dart';

/// Preview screen shown when the user shares one or more files into SecuroBox
/// from the OS share sheet. It lets the user pick a destination category,
/// toggle encryption, deselect duplicates, and import into the vault.
class ShareImportScreen extends StatefulWidget {
  const ShareImportScreen({
    super.key,
    required this.paths,
    this.onDone,
  });

  /// Absolute file paths of the shared files (already on disk).
  final List<String> paths;

  /// Optional callback invoked after a successful import (pop/refresh). When
  /// null, the screen simply calls [Navigator.maybePop].
  final VoidCallback? onDone;

  @override
  State<ShareImportScreen> createState() => _ShareImportScreenState();
}

/// One incoming shared file, with everything the preview needs to render it.
class _ImportEntry {
  _ImportEntry({
    required this.path,
    required this.name,
    required this.kind,
    required this.autoCategory,
    required this.size,
    required this.available,
    required this.selected,
    required this.duplicate,
  });

  final String path;
  final String name;
  final String kind;
  final String autoCategory;
  final int size;
  final bool available;
  bool selected;
  bool duplicate;
}

class _ShareImportScreenState extends State<ShareImportScreen> {
  final List<_ImportEntry> _entries = [];
  List<CategoryInfo> _categories = [];

  bool _loading = true;
  bool _encrypt = true;

  /// null = "Auto (by file type)"; otherwise a category KEY to force all files.
  String? _forcedCategoryKey;

  // Progress overlay state.
  bool _importing = false;
  int _progressDone = 0;
  int _progressTotal = 0;
  String _progressName = '';

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    final existing = await MediaImporter.instance.existingTitlesLower();
    List<CategoryInfo> categories = [];
    try {
      final all = await CategoryService.instance.load();
      categories = all
          .where((c) => !c.hidden && c.type != 'favorite')
          .toList();
    } catch (_) {
      categories = [];
    }

    final entries = <_ImportEntry>[];
    // Track within-batch duplicates by "name|size"; the first occurrence is
    // kept, later identical ones are flagged.
    final seenInBatch = <String>{};

    for (final path in widget.paths) {
      final name = p.basename(path);
      final kind = FileTypeRegistry.kindForPath(path);
      final autoCategory = FileTypeRegistry.categoryForPath(path);

      int size = 0;
      bool available = true;
      final file = File(path);
      try {
        if (await file.exists()) {
          size = await file.length();
        } else {
          available = false;
        }
      } catch (_) {
        size = 0;
      }

      final lower = name.toLowerCase();
      final lowerNoExt = p.basenameWithoutExtension(path).toLowerCase();
      final batchKey = '$lower|$size';
      final duplicateInBatch = seenInBatch.contains(batchKey);
      seenInBatch.add(batchKey);
      final duplicateInVault =
          existing.contains(lower) || existing.contains(lowerNoExt);
      final duplicate = duplicateInVault || duplicateInBatch;

      entries.add(_ImportEntry(
        path: path,
        name: name,
        kind: kind,
        autoCategory: autoCategory,
        size: size,
        available: available,
        // Duplicates (and unavailable files) default to deselected.
        selected: available && !duplicate,
        duplicate: duplicate,
      ));
    }

    if (!mounted) return;
    setState(() {
      _entries
        ..clear()
        ..addAll(entries);
      _categories = categories;
      _loading = false;
    });
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    double value = bytes.toDouble();
    int unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final str = unit == 0
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(value >= 100 ? 0 : 1);
    return '$str ${units[unit]}';
  }

  /// Display name of the forced category, or null when in Auto mode.
  String? get _forcedCategoryName {
    if (_forcedCategoryKey == null) return null;
    for (final c in _categories) {
      if (c.key == _forcedCategoryKey) return c.name;
    }
    return _forcedCategoryKey;
  }

  String _effectiveCategory(_ImportEntry e) =>
      _forcedCategoryName ?? e.autoCategory;

  Iterable<_ImportEntry> get _available => _entries.where((e) => e.available);

  int get _selectedCount =>
      _entries.where((e) => e.available && e.selected).length;

  bool get _allSelected =>
      _available.isNotEmpty && _available.every((e) => e.selected);

  void _toggleSelectAll() {
    final target = !_allSelected;
    setState(() {
      for (final e in _available) {
        e.selected = target;
      }
    });
  }

  // ── Import ─────────────────────────────────────────────────────────────

  Future<void> _import() async {
    final selected =
        _entries.where((e) => e.available && e.selected).toList();
    if (selected.isEmpty) return;

    setState(() {
      _importing = true;
      _progressDone = 0;
      _progressTotal = selected.length;
      _progressName = selected.first.name;
    });

    final items = [
      for (final e in selected)
        PickedMedia(
          File(e.path),
          originalName: e.name,
          origin: 'file',
        ),
    ];

    ImportResult? result;
    try {
      result = await MediaImporter.instance.importFiles(
        items: items,
        category: _forcedCategoryKey,
        encrypt: _encrypt,
        onProgress: (done, total) {
          if (!mounted) return;
          setState(() {
            _progressDone = done;
            _progressTotal = total;
            final idx = done - 1;
            if (idx >= 0 && idx < selected.length) {
              _progressName = selected[idx].name;
            }
          });
        },
      );
    } catch (_) {
      result = null;
    }

    if (!mounted) return;
    setState(() => _importing = false);

    if (result == null || result.added == 0) {
      if (context.mounted) {
        FlushBarHelper.flushBarErrorMessage(
          'Import failed. Please try again.',
          context,
        );
      }
      return;
    }

    final buffer = StringBuffer(
      '${result.added} file${result.added == 1 ? '' : 's'} imported',
    );
    if (result.failed > 0) {
      buffer.write(' · ${result.failed} failed');
    }
    if (context.mounted) {
      FlushBarHelper.flushBarSuccessMessage(buffer.toString(), context);
    }

    if (widget.onDone != null) {
      widget.onDone!.call();
    } else {
      await Navigator.maybePop(context);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final inset = context.contentInset(phone: AppSpace.md);

    return Scaffold(
      backgroundColor: LiquidColors.backgroundDeep,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          SafeArea(
            top: false,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _entries.isEmpty || _available.isEmpty
                    ? _buildEmptyState()
                    : _buildContent(inset),
          ),
          if (_importing) _buildProgressOverlay(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: LiquidColors.backgroundDeep,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: LiquidColors.systemOverlayStyle,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_rounded, color: LiquidColors.textPrimary),
        onPressed: _importing ? null : () => Navigator.maybePop(context),
      ),
      title: Text(
        'Import to SecuroBox',
        style: TextStyle(
          color: LiquidColors.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_rounded,
              size: 56,
              color: LiquidColors.textTertiary,
            ),
            AppSpace.h16,
            Text(
              'No files to import',
              style: TextStyle(
                color: LiquidColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            AppSpace.h8,
            Text(
              'The shared files could not be found.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: LiquidColors.textTertiary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(double inset) {
    final availableCount = _available.length;

    return Column(
      children: [
        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              inset,
              AppSpace.sm,
              inset,
              AppSpace.md,
            ),
            children: [
              _buildHeader(availableCount),
              AppSpace.h16,
              _buildDestinationCard(),
              AppSpace.h12,
              _buildEncryptCard(),
              AppSpace.h24,
              _buildFilesHeader(),
              AppSpace.h8,
              ..._buildFileRows(),
            ],
          ),
        ),
        _buildBottomBar(inset),
      ],
    );
  }

  Widget _buildHeader(int availableCount) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: LiquidColors.indigo.withValues(alpha: 0.12),
            borderRadius: AppRadius.rMd,
          ),
          child: Icon(
            Icons.download_rounded,
            color: LiquidColors.indigo,
            size: 24,
          ),
        ),
        AppSpace.w12,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                availableCount == 1
                    ? '1 file'
                    : '$availableCount files',
                style: TextStyle(
                  color: LiquidColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Review before adding to your vault',
                style: TextStyle(
                  color: LiquidColors.textTertiary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  BoxDecoration get _cardDecoration => BoxDecoration(
        color: LiquidColors.backgroundLight.withValues(alpha: 0.55),
        borderRadius: AppRadius.rLg,
        border: Border.all(color: LiquidColors.cardBorder),
      );

  Widget _buildDestinationCard() {
    return Container(
      decoration: _cardDecoration,
      padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
            child: Text(
              'Destination',
              style: TextStyle(
                color: LiquidColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          AppSpace.h12,
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
              children: [
                _buildCategoryChip(
                  label: 'Auto (by file type)',
                  color: LiquidColors.indigo,
                  selected: _forcedCategoryKey == null,
                  onTap: () => setState(() => _forcedCategoryKey = null),
                  icon: Icons.auto_awesome_rounded,
                ),
                for (final c in _categories)
                  _buildCategoryChip(
                    label: c.name,
                    color: CategoryStyle.forCategory(c.name),
                    selected: _forcedCategoryKey == c.key,
                    onTap: () =>
                        setState(() => _forcedCategoryKey = c.key),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpace.sm),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.16)
                : LiquidColors.surfaceMuted,
            borderRadius: AppRadius.rPill,
            border: Border.all(
              color: selected ? color : LiquidColors.cardBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: selected ? color : LiquidColors.textSecondary),
                AppSpace.w4,
              ] else ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                AppSpace.w8,
              ],
              Text(
                label,
                style: TextStyle(
                  color:
                      selected ? LiquidColors.textPrimary : LiquidColors.textSecondary,
                  fontSize: 13.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEncryptCard() {
    return Container(
      decoration: _cardDecoration,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.xs,
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: _encrypt,
        activeThumbColor: Colors.white,
        activeTrackColor: LiquidColors.indigo,
        onChanged: (v) => setState(() => _encrypt = v),
        title: Text(
          'Encrypt files',
          style: TextStyle(
            color: LiquidColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          'Recommended — stores files encrypted in your vault',
          style: TextStyle(
            color: LiquidColors.textTertiary,
            fontSize: 12.5,
          ),
        ),
        secondary: Icon(
          _encrypt ? Icons.lock_rounded : Icons.lock_open_rounded,
          color: _encrypt ? LiquidColors.indigo : LiquidColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildFilesHeader() {
    return Row(
      children: [
        Text(
          'Files',
          style: TextStyle(
            color: LiquidColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: _available.isEmpty ? null : _toggleSelectAll,
          style: TextButton.styleFrom(
            foregroundColor: LiquidColors.indigo,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            _allSelected ? 'Deselect all' : 'Select all',
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildFileRows() {
    final rows = <Widget>[];
    for (int i = 0; i < _entries.length; i++) {
      if (i > 0) {
        rows.add(const SizedBox(height: AppSpace.sm));
      }
      rows.add(_buildFileRow(_entries[i]));
    }
    return rows;
  }

  Widget _buildFileRow(_ImportEntry e) {
    final category = _effectiveCategory(e);
    final accent = CategoryStyle.forCategory(category);
    final enabled = e.available;

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Container(
        decoration: _cardDecoration,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: 10,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: AppRadius.rSm,
              ),
              child: Icon(
                MediaHelper.getMediaIcon(e.kind),
                color: accent,
                size: 22,
              ),
            ),
            AppSpace.w12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          e.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: LiquidColors.textPrimary,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (e.duplicate) ...[
                        AppSpace.w8,
                        _buildDuplicatePill(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    enabled
                        ? '${_formatSize(e.size)} · $category'
                        : 'File unavailable',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: LiquidColors.textTertiary,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            AppSpace.w8,
            Checkbox(
              value: e.selected,
              onChanged: enabled
                  ? (v) => setState(() => e.selected = v ?? false)
                  : null,
              activeColor: LiquidColors.indigo,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              side: BorderSide(color: LiquidColors.cardBorder, width: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDuplicatePill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: LiquidColors.warning.withValues(alpha: 0.15),
        borderRadius: AppRadius.rPill,
      ),
      child: Text(
        'Duplicate',
        style: TextStyle(
          color: LiquidColors.warning,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildBottomBar(double inset) {
    final count = _selectedCount;
    final enabled = count > 0 && !_importing;

    return Container(
      padding: EdgeInsets.fromLTRB(
        inset,
        AppSpace.md,
        inset,
        AppSpace.md,
      ),
      decoration: BoxDecoration(
        color: LiquidColors.backgroundDeep,
        border: Border(top: BorderSide(color: LiquidColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton(
            onPressed: enabled ? _import : null,
            style: FilledButton.styleFrom(
              backgroundColor: LiquidColors.indigo,
              disabledBackgroundColor:
                  LiquidColors.indigo.withValues(alpha: 0.35),
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.rLg),
            ),
            child: Text(
              count == 0
                  ? 'Select files to import'
                  : 'Import $count file${count == 1 ? '' : 's'}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressOverlay() {
    final total = _progressTotal == 0 ? 1 : _progressTotal;
    final value = (_progressDone / total).clamp(0.0, 1.0);

    return Positioned.fill(
      child: AbsorbPointer(
        child: Container(
          color: LiquidColors.scrim,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(AppSpace.xl),
          child: Container(
            padding: const EdgeInsets.all(AppSpace.lg),
            constraints: const BoxConstraints(maxWidth: 360),
            decoration: BoxDecoration(
              color: LiquidColors.backgroundLight,
              borderRadius: AppRadius.rXl,
              border: Border.all(color: LiquidColors.cardBorder),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Importing $_progressDone of $_progressTotal…',
                  style: TextStyle(
                    color: LiquidColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                AppSpace.h8,
                Text(
                  _progressName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: LiquidColors.textTertiary,
                    fontSize: 13,
                  ),
                ),
                AppSpace.h16,
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: value,
                    minHeight: 8,
                    backgroundColor: LiquidColors.surfaceMuted,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(LiquidColors.indigo),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
