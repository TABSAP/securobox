import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/utils/media_importer.dart';
import 'package:video_player_app/utils/vault_context.dart';
import 'package:video_player_app/widgets/app_card.dart';
import 'package:video_player_app/widgets/app_spacing.dart';

/// Foreground album rules: selected albums are scanned while the owner opens
/// this screen. New files remain in a review queue until explicitly imported.
class AutoImportScreen extends StatefulWidget {
  const AutoImportScreen({super.key});

  @override
  State<AutoImportScreen> createState() => _AutoImportScreenState();
}

class _AutoImportScreenState extends State<AutoImportScreen> {
  String get _rulesKey => VaultContext.instance.isDecoy
      ? 'autoImportRules_decoy'
      : 'autoImportRules';
  String get _seenKey => VaultContext.instance.isDecoy
      ? 'autoImportedAssetIds_decoy'
      : 'autoImportedAssetIds';

  List<AssetPathEntity> _albums = [];
  final Set<String> _rules = {};
  final List<AssetEntity> _queue = [];
  final Map<String, String> _originPaths = {};
  final Set<String> _selected = {};
  bool _loading = true;
  bool _busy = false;
  bool _scanning = false;
  bool _keepOriginals = true;
  bool _permissionDenied = false;
  String? _loadError;
  String? _scanError;
  bool _savingRule = false;
  Timer? _scanTimer;
  int _rulesRevision = 0;
  bool _rescanRequested = false;
  bool _loadingAlbums = false;

  @override
  void initState() {
    super.initState();
    _loadAlbums();
    _scanTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (mounted && !_busy && !_savingRule) _scanQueue();
    });
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAlbums() async {
    if (_loadingAlbums || _busy || _savingRule) return;
    _loadingAlbums = true;
    _rulesRevision++;
    setState(() {
      _loading = true;
      _permissionDenied = false;
      _loadError = null;
    });
    try {
      final permission = await PhotoManager.requestPermissionExtend();
      if (!permission.hasAccess) {
        if (mounted) {
          setState(() {
            _loading = false;
            _permissionDenied = true;
            _queue.clear();
            _selected.clear();
            _originPaths.clear();
          });
        }
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      _rules
        ..clear()
        ..addAll(prefs.getStringList(_rulesKey) ?? const []);
      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.common,
      );
      if (mounted) {
        setState(() {
          _albums = albums;
          _loading = false;
        });
      }
      await _scanQueue();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError =
              'Albums could not be loaded. Check Gallery access and try again.';
        });
      }
    } finally {
      _loadingAlbums = false;
    }
  }

  Future<void> _toggleRule(AssetPathEntity album, bool enabled) async {
    if (_savingRule || _busy || _loading) return;
    final before = Set<String>.from(_rules);
    setState(() {
      _savingRule = true;
      _rulesRevision++;
      if (enabled) {
        _rules.add(album.id);
      } else {
        _rules.remove(album.id);
      }
      // No old selection can be imported while a different rule set is pending.
      _queue.clear();
      _selected.clear();
      _originPaths.clear();
      _scanError = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setStringList(_rulesKey, _rules.toList())) {
        throw StateError('save failed');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _rulesRevision++;
        _rules
          ..clear()
          ..addAll(before);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Album rule could not be saved. Try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _savingRule = false);
        await _scanQueue();
      }
    }
  }

  Future<void> _scanQueue() async {
    if (!mounted || _loading || _busy || _savingRule || _permissionDenied) {
      return;
    }
    if (_scanning) {
      _rescanRequested = true;
      return;
    }
    final revision = _rulesRevision;
    final ruleSnapshot = Set<String>.from(_rules);
    setState(() => _scanning = true);
    try {
      if (ruleSnapshot.isEmpty) {
        setState(() {
          _queue.clear();
          _selected.clear();
          _originPaths.clear();
          _scanError = null;
        });
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final seen = (prefs.getStringList(_seenKey) ?? const []).toSet();
      final candidates = <String, AssetEntity>{};
      final originPaths = <String, String>{};
      for (final album in _albums.where((a) => ruleSnapshot.contains(a.id))) {
        var page = 0;
        while (candidates.length < 100) {
          final assets = await album.getAssetListPaged(page: page++, size: 100);
          if (!mounted || revision != _rulesRevision) return;
          for (final asset in assets) {
            if (candidates.length >= 100) break;
            if (!seen.contains(asset.id) &&
                (asset.type == AssetType.image ||
                    asset.type == AssetType.video)) {
              candidates.putIfAbsent(asset.id, () => asset);
              originPaths.putIfAbsent(asset.id, () => album.name);
            }
          }
          if (assets.length < 100) break;
        }
      }
      if (mounted && revision == _rulesRevision) {
        setState(() {
          final previousIds = _queue.map((a) => a.id).toSet();
          // Keep manual deselections during periodic scans; select only new items.
          _selected.removeWhere((id) => !candidates.containsKey(id));
          _selected.addAll(
            candidates.keys.where((id) => !previousIds.contains(id)),
          );
          _queue
            ..clear()
            ..addAll(candidates.values);
          _originPaths
            ..clear()
            ..addAll(originPaths);
          _scanError = null;
        });
      }
    } catch (_) {
      if (mounted && revision == _rulesRevision) {
        setState(
          () => _scanError =
              'Could not scan the selected albums. Check Gallery access and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
      if (mounted && (_rescanRequested || revision != _rulesRevision)) {
        _rescanRequested = false;
        unawaited(_scanQueue());
      }
    }
  }

  Future<void> _importSelected() async {
    if (_busy || _scanning || _savingRule || _loading || _rules.isEmpty) return;
    final chosen = _queue.where((a) => _selected.contains(a.id)).toList();
    if (chosen.isEmpty) return;
    setState(() => _busy = true);
    final stagedFiles = <File>[];
    try {
      final picked = <PickedMedia>[];
      final tempDir = await getTemporaryDirectory();
      for (final asset in chosen) {
        final source = await asset.file;
        if (source == null || !await source.exists()) continue;
        final title = await asset.titleAsync;
        final relativePath = _originPaths[asset.id] ?? '';
        final safeTemp = File(
          p.join(
            tempDir.path,
            'securobox_auto_${DateTime.now().microsecondsSinceEpoch}_${stagedFiles.length}${p.extension(title)}',
          ),
        );
        stagedFiles.add(safeTemp);
        await source.copy(safeTemp.path);
        picked.add(
          PickedMedia(
            safeTemp,
            galleryAssetId: asset.id,
            originalName: title.isEmpty ? asset.title : title,
            origin: 'gallery',
            originAlbum: relativePath,
          ),
        );
      }
      final result = await MediaImporter.instance.importFiles(
        items: picked,
        encrypt: true,
        deleteOriginalsOverride: !_keepOriginals,
      );
      if (result.added == picked.length && result.added > 0) {
        final prefs = await SharedPreferences.getInstance();
        final seen = (prefs.getStringList(_seenKey) ?? const []).toSet()
          ..addAll(picked.map((a) => a.galleryAssetId).whereType<String>());
        await prefs.setStringList(_seenKey, seen.toList());
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${result.added} imported · ${result.failed} failed'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Import could not be completed. Gallery originals are kept; review the queue and retry.',
            ),
          ),
        );
      }
    } finally {
      for (final file in stagedFiles) {
        try {
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
      if (mounted) {
        setState(() => _busy = false);
        await _scanQueue();
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: LiquidColors.backgroundDeep,
    appBar: AppBar(
      backgroundColor: LiquidColors.backgroundDeep,
      surfaceTintColor: Colors.transparent,
      title: const Text('Auto-import'),
      actions: [
        IconButton(
          onPressed: _busy || _loading || _savingRule ? null : _loadAlbums,
          tooltip: 'Refresh albums',
          icon: AnimatedRotation(
            turns: _loading || _scanning ? 1 : 0,
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeInOutCubic,
            child: const Icon(Icons.refresh_rounded),
          ),
        ),
      ],
    ),
    body: _permissionDenied || _loadError != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _permissionDenied
                        ? Icons.photo_library_outlined
                        : Icons.error_outline,
                    size: 42,
                    color: LiquidColors.indigo,
                  ),
                  const SizedBox(height: AppSpace.md),
                  Text(
                    _permissionDenied
                        ? 'Allow photo and video access to choose albums.'
                        : _loadError!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: LiquidColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpace.md),
                  FilledButton.icon(
                    onPressed: _permissionDenied
                        ? PhotoManager.openSetting
                        : _loadAlbums,
                    icon: Icon(
                      _permissionDenied ? Icons.settings : Icons.refresh,
                    ),
                    label: Text(
                      _permissionDenied ? 'Open settings' : 'Try again',
                    ),
                  ),
                ],
              ),
            ),
          )
        : Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.md,
                  AppSpace.sm,
                  AppSpace.md,
                  120,
                ),
                children: [
                  _introCard(),
                  const SizedBox(height: AppSpace.lg),
                  _sectionHeader(
                    'MONITORED ALBUMS',
                    trailing: '${_rules.length} selected',
                  ),
                  const SizedBox(height: AppSpace.sm),
                  if (_scanError != null) ...[
                    _scanErrorCard(),
                    const SizedBox(height: AppSpace.sm),
                  ],
                  for (var i = 0; i < _albums.length; i++) ...[
                    _albumCard(_albums[i], i),
                    const SizedBox(height: 9),
                  ],
                  const SizedBox(height: AppSpace.md),
                  _sectionHeader(
                    'REVIEW QUEUE',
                    trailing: '${_queue.length} new',
                  ),
                  const SizedBox(height: AppSpace.sm),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _queuePanel(
                      key: ValueKey('${_queue.length}:${_rules.length}'),
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                  _originalsSetting(),
                ],
              ),
              if (_busy)
                Positioned.fill(
                  child: ColoredBox(
                    color: LiquidColors.backgroundDeep.withValues(alpha: .72),
                    child: Center(
                      child: AppCard(
                        elevated: true,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 30,
                              height: 30,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: LiquidColors.indigo,
                              ),
                            ),
                            const SizedBox(height: AppSpace.md),
                            Text(
                              'Securing selected media…',
                              style: TextStyle(
                                color: LiquidColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: AppSpace.xs),
                            Text(
                              'Your Gallery originals are protected by your setting.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: LiquidColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (!_busy &&
                  !_loading &&
                  _rules.isNotEmpty &&
                  _queue.isNotEmpty &&
                  _selected.isNotEmpty)
                Positioned(
                  left: AppSpace.md,
                  right: AppSpace.md,
                  bottom: AppSpace.sm,
                  child: SafeArea(
                    top: false,
                    child: FilledButton.icon(
                      onPressed: _scanning || _savingRule
                          ? null
                          : _importSelected,
                      icon: const Icon(Icons.lock_rounded),
                      label: Text('Import ${_selected.length} selected'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                      ),
                    ),
                  ),
                ),
            ],
          ),
  );

  Widget _introCard() => Container(
    padding: const EdgeInsets.all(AppSpace.lg),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          LiquidColors.indigo.withValues(alpha: .18),
          LiquidColors.backgroundLight,
          LiquidColors.backgroundLight.withValues(alpha: .72),
        ],
      ),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(color: LiquidColors.indigo.withValues(alpha: .18)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: LiquidColors.indigo.withValues(alpha: .15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: LiquidColors.indigo,
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Keep your vault up to date',
                    style: TextStyle(
                      color: LiquidColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Choose albums to watch',
                    style: TextStyle(
                      color: LiquidColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.md),
        Text(
          'New photos and videos appear in a review queue while this screen is open. Gallery originals stay safe unless you choose otherwise.',
          style: TextStyle(
            color: LiquidColors.textSecondary,
            height: 1.45,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: AppSpace.md),
        Row(
          children: [
            Icon(Icons.shield_outlined, size: 15, color: LiquidColors.success),
            const SizedBox(width: 6),
            Text(
              'Review first · originals kept by default',
              style: TextStyle(
                color: LiquidColors.success,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _sectionHeader(String title, {required String trailing}) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: TextStyle(
            color: LiquidColors.textTertiary,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.15,
          ),
        ),
      ),
      Text(
        trailing,
        style: TextStyle(
          color: LiquidColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );

  Widget _albumCard(AssetPathEntity album, int index) {
    final enabled = _rules.contains(album.id);
    return TweenAnimationBuilder<double>(
      key: ValueKey('album-${album.id}'),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + (index.clamp(0, 6) * 35)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - value)),
          child: child,
        ),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: enabled
              ? LiquidColors.indigo.withValues(alpha: .075)
              : LiquidColors.backgroundLight.withValues(alpha: .72),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: enabled
                ? LiquidColors.indigo.withValues(alpha: .35)
                : LiquidColors.cardBorder,
          ),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: LiquidColors.indigo.withValues(alpha: .07),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: _savingRule || _busy || _loading
                ? null
                : () => _toggleRule(album, !enabled),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.md,
                vertical: 11,
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: enabled
                          ? LiquidColors.indigo.withValues(alpha: .17)
                          : LiquidColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      _albumIcon(album.name),
                      color: enabled
                          ? LiquidColors.indigo
                          : LiquidColors.textTertiary,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          album.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: LiquidColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FutureBuilder<int>(
                          future: album.assetCountAsync,
                          builder: (context, snapshot) => Text(
                            snapshot.hasError
                                ? 'Media count unavailable'
                                : '${snapshot.data ?? 0} media files',
                            style: TextStyle(
                              color: LiquidColors.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Switch.adaptive(
                    value: enabled,
                    onChanged: _savingRule || _busy || _loading
                        ? null
                        : (value) => _toggleRule(album, value),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _albumIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('camera')) return Icons.camera_alt_rounded;
    if (n.contains('screenshot')) return Icons.screenshot_rounded;
    if (n.contains('download')) return Icons.download_rounded;
    if (n.contains('video')) return Icons.videocam_rounded;
    if (n.contains('whatsapp')) return Icons.chat_rounded;
    return Icons.photo_album_rounded;
  }

  Widget _scanErrorCard() => AppCard(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpace.md,
      vertical: AppSpace.sm,
    ),
    child: Row(
      children: [
        Icon(Icons.warning_amber_rounded, color: LiquidColors.warning),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Text(
            _scanError!,
            style: TextStyle(color: LiquidColors.textSecondary, fontSize: 12),
          ),
        ),
        IconButton(
          onPressed: _scanQueue,
          tooltip: 'Retry scan',
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
  );

  Widget _queuePanel({Key? key}) {
    if (_queue.isEmpty) {
      final title = _scanning
          ? 'Scanning selected albums…'
          : _rules.isEmpty
          ? 'Choose an album to begin'
          : 'You’re all caught up';
      final subtitle = _rules.isEmpty
          ? 'New media from selected albums will appear here.'
          : 'New photos and videos will appear here for review.';
      return Container(
        key: key,
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpace.lg),
        decoration: BoxDecoration(
          color: LiquidColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: LiquidColors.cardBorder),
        ),
        child: Column(
          children: [
            Icon(
              _rules.isEmpty
                  ? Icons.collections_bookmark_outlined
                  : Icons.check_circle_outline_rounded,
              size: 30,
              color: LiquidColors.textTertiary,
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              title,
              style: TextStyle(
                color: LiquidColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: LiquidColors.textTertiary, fontSize: 12),
            ),
          ],
        ),
      );
    }
    return Column(
      key: key,
      children: [
        for (final asset in _queue)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.sm,
                vertical: 4,
              ),
              child: CheckboxListTile(
                value: _selected.contains(asset.id),
                onChanged: (value) => setState(
                  () => value == true
                      ? _selected.add(asset.id)
                      : _selected.remove(asset.id),
                ),
                secondary: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: LiquidColors.indigo.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    asset.type == AssetType.video
                        ? Icons.videocam_rounded
                        : Icons.image_rounded,
                    color: LiquidColors.indigo,
                    size: 19,
                  ),
                ),
                title: Text(
                  asset.title ?? 'Media',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: LiquidColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                subtitle: Text(
                  '${asset.type == AssetType.video ? 'Video' : 'Photo'} · ${_originPaths[asset.id] ?? 'Gallery'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: LiquidColors.textTertiary,
                    fontSize: 11,
                  ),
                ),
                activeColor: LiquidColors.indigo,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                controlAffinity: ListTileControlAffinity.trailing,
              ),
            ),
          ),
      ],
    );
  }

  Widget _originalsSetting() => AppCard(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpace.md,
      vertical: AppSpace.sm,
    ),
    child: SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      value: _keepOriginals,
      onChanged: (value) => setState(() => _keepOriginals = value),
      secondary: Icon(Icons.backup_rounded, color: LiquidColors.indigo),
      title: Text(
        'Keep Gallery originals',
        style: TextStyle(
          color: LiquidColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
      subtitle: Text(
        'Recommended · remove them later if you choose',
        style: TextStyle(color: LiquidColors.textTertiary, fontSize: 11),
      ),
    ),
  );
}
