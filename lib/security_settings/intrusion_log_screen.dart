import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/intrusion_service.dart';
import '../utils/liquid_circular_progress.dart';
import '../utils/liquid_colors.dart';
import '../utils/vault_crypto.dart';

class IntrusionLogScreen extends StatefulWidget {
  const IntrusionLogScreen({super.key});

  @override
  State<IntrusionLogScreen> createState() => IntrusionLogScreenState();
}

class IntrusionLogScreenState extends State<IntrusionLogScreen>
    with SingleTickerProviderStateMixin {
  List<IntrusionEntry> _entries = [];
  bool _loading = true;
  bool _detectionOn = false;
  final Map<int, String> _decryptedPaths = {};

  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _enter.dispose();
    VaultCrypto.instance.wipeAllTempCache();
    super.dispose();
  }

  void reload() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    final entries = await IntrusionService.instance.getLog();
    final detectionOn = await IntrusionService.instance.isEnabled();
    if (!mounted) return;

    final paths = <int, String>{};
    for (final e in entries) {
      try {
        final temp = await VaultCrypto.instance.decryptToTemp(
          e.encryptedPath,
          forceReal: true,
        );
        paths[e.timestamp] = temp;
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _detectionOn = detectionOn;
      _decryptedPaths
        ..clear()
        ..addAll(paths);
      _loading = false;
    });
    _enter.forward(from: 0);
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];

  String _time(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m ${d.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _fullDate(DateTime d) =>
      '${_months[d.month - 1]} ${d.day}, ${d.year}  ·  ${_time(d)}';

  String _relative(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inSeconds < 45) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) {
      return '${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'} ago';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays} ${diff.inDays == 1 ? 'day' : 'days'} ago';
    }
    if (diff.inDays < 30) {
      final w = diff.inDays ~/ 7;
      return '$w ${w == 1 ? 'week' : 'weeks'} ago';
    }
    return '${_months[d.month - 1]} ${d.day}';
  }

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final dDay = DateTime(d.year, d.month, d.day);
    final today = DateTime(now.year, now.month, now.day);
    final delta = today.difference(dDay).inDays;
    if (delta == 0) return 'Today';
    if (delta == 1) return 'Yesterday';
    if (delta < 7) return _weekdays[d.weekday - 1];
    return '${_months[d.month - 1]} ${d.day}, ${d.year}';
  }

  List<_DayBucket> get _buckets {
    final sorted = [..._entries]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final out = <_DayBucket>[];
    for (final e in sorted) {
      final d = e.when;
      final key = DateTime(d.year, d.month, d.day);
      if (out.isNotEmpty && out.last.day == key) {
        out.last.entries.add(e);
      } else {
        out.add(_DayBucket(key, _dayLabel(d), [e]));
      }
    }
    return out;
  }

  Future<bool> _confirmDelete(IntrusionEntry entry) async {
    HapticFeedback.lightImpact();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmSheet(
        icon: Icons.delete_outline_rounded,
        accent: LiquidColors.error,
        title: 'Delete this capture?',
        message: 'The photo will be permanently removed from the encrypted log.',
        confirmLabel: 'Delete',
        onCancel: () => Navigator.pop(ctx, false),
        onConfirm: () => Navigator.pop(ctx, true),
      ),
    );
    if (ok != true) return false;
    await IntrusionService.instance.deleteEntry(entry);
    await _load();
    return true;
  }

  Future<void> _confirmClearAll() async {
    HapticFeedback.lightImpact();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmSheet(
        icon: Icons.delete_sweep_rounded,
        accent: LiquidColors.error,
        title: 'Clear the entire log?',
        message:
            'All ${_entries.length} break-in ${_entries.length == 1 ? 'photo' : 'photos'} will be permanently removed.',
        confirmLabel: 'Clear all',
        onCancel: () => Navigator.pop(ctx, false),
        onConfirm: () => Navigator.pop(ctx, true),
      ),
    );
    if (ok != true) return;
    await IntrusionService.instance.clearAll();
    await _load();
  }

  void _viewFull(IntrusionEntry entry, String path) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (ctx) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(
            _fullDate(entry.when),
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          actions: [
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
              onPressed: () async {
                final deleted = await _confirmDelete(entry);
                if (deleted && ctx.mounted) Navigator.of(ctx).pop();
              },
            ),
          ],
        ),
        body: Center(
          child: Hero(
            tag: 'intrusion_${entry.timestamp}',
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Image.file(
                File(path),
                errorBuilder: (_, _, _) => Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.broken_image_rounded,
                          color: Colors.white38, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        'This capture could not be opened.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LiquidColors.backgroundDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: LiquidColors.textPrimary),
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [LiquidColors.error, LiquidColors.accentOrange],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.shield_moon_rounded,
                  color: Colors.white, size: 19),
            ),
            const SizedBox(width: 12),
            Text(
              'Break-in Log',
              style: TextStyle(
                color: LiquidColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 19,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        actions: [
          if (_entries.isNotEmpty)
            IconButton(
              tooltip: 'Clear all',
              icon: Icon(Icons.delete_sweep_rounded, color: LiquidColors.error),
              onPressed: _confirmClearAll,
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: LiquidColors.backgroundGradient),
        child: _loading
            ? const Center(child: LiquidCircularProgress(size: 88))
            : _entries.isEmpty
                ? _emptyState()
                : CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(child: _summaryBanner()),
                      ..._buildSections(),
                      const SliverToBoxAdapter(child: SizedBox(height: 28)),
                    ],
                  ),
      ),
    );
  }

  Widget _summaryBanner() {
    final last = _entries.isEmpty
        ? null
        : _entries
            .map((e) => e.timestamp)
            .reduce((a, b) => a > b ? a : b);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              LiquidColors.error.withValues(alpha: 0.14),
              LiquidColors.accentOrange.withValues(alpha: 0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: LiquidColors.error.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: LiquidColors.error.withValues(alpha: 0.18),
                border:
                    Border.all(color: LiquidColors.error.withValues(alpha: 0.4)),
              ),
              child: Icon(Icons.gpp_maybe_rounded,
                  color: LiquidColors.error, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${_entries.length}',
                          style: TextStyle(
                            color: LiquidColors.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                          ),
                        ),
                        TextSpan(
                          text:
                              '  failed unlock ${_entries.length == 1 ? 'attempt' : 'attempts'}',
                          style: TextStyle(
                            color: LiquidColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    last == null
                        ? ''
                        : 'Most recent: ${_relative(DateTime.fromMillisecondsSinceEpoch(last))}',
                    style: TextStyle(
                        color: LiquidColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            _detectionPill(),
          ],
        ),
      ),
    );
  }

  Widget _detectionPill() {
    final on = _detectionOn;
    final c = on ? LiquidColors.success : LiquidColors.textTertiary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(on ? Icons.videocam_rounded : Icons.videocam_off_rounded,
              size: 13, color: c),
          const SizedBox(width: 5),
          Text(
            on ? 'ON' : 'OFF',
            style: TextStyle(
                color: c, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSections() {
    final buckets = _buckets;
    var globalIndex = 0;
    final slivers = <Widget>[];
    for (final bucket in buckets) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Row(
              children: [
                Text(
                  bucket.label.toUpperCase(),
                  style: TextStyle(
                    color: LiquidColors.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 1,
                    color: LiquidColors.divider,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${bucket.entries.length}',
                  style: TextStyle(
                    color: LiquidColors.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      slivers.add(
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) {
              final idx = globalIndex + i;
              return _entryCard(bucket.entries[i], idx);
            },
            childCount: bucket.entries.length,
          ),
        ),
      );
      globalIndex += bucket.entries.length;
    }
    return slivers;
  }

  Widget _entryCard(IntrusionEntry entry, int index) {
    final path = _decryptedPaths[entry.timestamp];
    final start = (index * 0.06).clamp(0.0, 0.55);
    final anim = CurvedAnimation(
      parent: _enter,
      curve: Interval(start, (start + 0.45).clamp(0.0, 1.0), curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: anim,
      builder: (context, child) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
          offset: Offset(0, (1 - anim.value) * 14),
          child: child,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: path == null ? null : () => _viewFull(entry, path),
            onLongPress: () => _confirmDelete(entry),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: LiquidColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: LiquidColors.cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: LiquidColors.shadow,
                    blurRadius: 14,
                    spreadRadius: -4,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _thumbnail(entry, path),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.lock_open_rounded,
                                size: 14, color: LiquidColors.error),
                            const SizedBox(width: 6),
                            Text(
                              'Wrong PIN entered',
                              style: TextStyle(
                                color: LiquidColors.textPrimary,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.schedule_rounded,
                                size: 12, color: LiquidColors.textTertiary),
                            const SizedBox(width: 5),
                            Text(
                              _time(entry.when),
                              style: TextStyle(
                                  color: LiquidColors.textSecondary,
                                  fontSize: 12),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 3,
                              height: 3,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: LiquidColors.textTertiary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _relative(entry.when),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: LiquidColors.textTertiary,
                                    fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.more_horiz_rounded,
                        color: LiquidColors.textTertiary),
                    onPressed: () => _confirmDelete(entry),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _thumbnail(IntrusionEntry entry, String? path) {
    Widget fallback() => Container(
          color: LiquidColors.backgroundDeep,
          alignment: Alignment.center,
          child: Icon(Icons.broken_image_rounded,
              color: LiquidColors.textTertiary, size: 28),
        );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: path == null ? null : () => _viewFull(entry, path),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: SizedBox(
              width: 74,
              height: 74,
              child: path == null
                  ? fallback()
                  : Hero(
                      tag: 'intrusion_${entry.timestamp}',
                      child: Image.file(
                        File(path),
                        fit: BoxFit.cover,
                        cacheWidth: 240,
                        cacheHeight: 240,
                        errorBuilder: (_, _, _) => fallback(),
                      ),
                    ),
            ),
          ),
          if (path != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(13)),
                child: Container(
                  height: 22,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.55),
                        Colors.black.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                  alignment: Alignment.bottomRight,
                  padding: const EdgeInsets.only(right: 4, bottom: 3),
                  child: const Icon(Icons.fullscreen_rounded,
                      color: Colors.white, size: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return ListView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.12),
        Center(
          child: Column(
            children: [
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      LiquidColors.success.withValues(alpha: 0.22),
                      LiquidColors.success.withValues(alpha: 0.0),
                    ],
                  ),
                ),
                child: Icon(Icons.verified_user_rounded,
                    size: 54, color: LiquidColors.success),
              ),
              const SizedBox(height: 22),
              Text(
                'All clear',
                style: TextStyle(
                  color: LiquidColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 44),
                child: Text(
                  'No failed unlock attempts have been recorded. If someone enters a wrong PIN, a silent front-camera photo will be captured and stored here — encrypted, never in your gallery.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: LiquidColors.textSecondary,
                    fontSize: 13,
                    height: 1.55,
                  ),
                ),
              ),
              if (!_detectionOn) ...[
                const SizedBox(height: 22),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: LiquidColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: LiquidColors.warning.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 18, color: LiquidColors.warning),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Break-in detection is off. Turn it on in Security Settings to start capturing intruders.',
                          style: TextStyle(
                            color: LiquidColors.textSecondary,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DayBucket {
  final DateTime day;
  final String label;
  final List<IntrusionEntry> entries;
  _DayBucket(this.day, this.label, this.entries);
}

class _ConfirmSheet extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String message;
  final String confirmLabel;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const _ConfirmSheet({
    required this.icon,
    required this.accent,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: LiquidColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.18),
              blurRadius: 26,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.16),
                border: Border.all(color: accent.withValues(alpha: 0.4)),
              ),
              child: Icon(icon, color: accent, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: LiquidColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: LiquidColors.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: BorderSide(color: LiquidColors.cardBorder),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13)),
                      foregroundColor: LiquidColors.textSecondary,
                    ),
                    child: const Text('Cancel',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13)),
                    ),
                    child: Text(confirmLabel,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
