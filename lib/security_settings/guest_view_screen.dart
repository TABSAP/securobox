import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_app/models/app_models.dart';
import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/utils/media_opener.dart';
import 'package:video_player_app/utils/vault_context.dart';
import 'package:video_player_app/widgets/app_card.dart';
import 'package:video_player_app/widgets/app_spacing.dart';
import 'package:video_player_app/widgets/vault_thumbnail.dart';

/// Lets the owner choose a small, read-only set of files before handing over
/// the device. The guest route has no library navigation or file actions.
class GuestViewScreen extends StatefulWidget {
  const GuestViewScreen({super.key});

  @override
  State<GuestViewScreen> createState() => _GuestViewScreenState();
}

class _GuestViewScreenState extends State<GuestViewScreen> {
  List<VideoItem> _items = const [];
  final Set<String> _selected = {};
  final TextEditingController _searchController = TextEditingController();
  bool _loading = true;
  bool _starting = false;
  String? _loadError;
  int _invalidRows = 0;
  String _query = '';
  String _filter = 'All';

  List<VideoItem> get _visibleItems {
    final q = _query.trim().toLowerCase();
    return _items.where((item) {
      final matchesType =
          _filter == 'All' ||
          (_filter == 'Photos' && item.type == 'image') ||
          (_filter == 'Videos' && item.type == 'video');
      return matchesType && (q.isEmpty || item.title.toLowerCase().contains(q));
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      // Parse each row independently so one damaged preference entry cannot
      // make the service's broad catch turn the entire picker into an empty UI.
      final prefs = await SharedPreferences.getInstance();
      final rows =
          prefs.getStringList(VaultContext.instance.libraryKey) ?? const [];
      final items = <VideoItem>[];
      var invalid = 0;
      for (final row in rows) {
        try {
          final item = VideoItem.fromStorageString(row);
          if (!item.isDeleted &&
              (item.type == 'image' || item.type == 'video')) {
            items.add(item);
          }
        } catch (_) {
          invalid++;
        }
      }
      items.sort((a, b) => b.id.compareTo(a.id));
      if (mounted) {
        setState(() {
          _items = items;
          _invalidRows = invalid;
          _selected.retainAll(items.map((item) => item.id));
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError =
              'Vault media could not be loaded. Your files have not been changed.';
        });
      }
    }
  }

  void _toggleAllVisible() {
    final visibleIds = _visibleItems.map((item) => item.id).toSet();
    final allSelected =
        visibleIds.isNotEmpty && visibleIds.every(_selected.contains);
    setState(() {
      if (allSelected) {
        _selected.removeAll(visibleIds);
      } else {
        _selected.addAll(visibleIds);
      }
    });
    HapticFeedback.selectionClick();
  }

  Future<void> _startGuestView() async {
    if (_starting) return;
    final chosen = _items.where((m) => _selected.contains(m.id)).toList();
    if (chosen.isEmpty) return;
    setState(() => _starting = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final appPinEnabled = prefs.getBool('appLock') ?? false;
      final biometricEnabled =
          (prefs.getBool('biometric') ?? false) ||
          (prefs.getBool('biometric_face') ?? false);
      if (!appPinEnabled && !biometricEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Enable a PIN or biometrics in Security before using Guest View.',
              ),
            ),
          );
        }
        return;
      }
      if (!mounted) return;
      if (!await authenticateForProtected(
        context,
        'Authenticate to start Guest View',
        requireAuth: true,
      )) {
        return;
      }
      if (!mounted) return;
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => _GuestOnlyView(items: chosen)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Guest View could not be started. Your vault files were not changed.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: LiquidColors.backgroundDeep,
    appBar: AppBar(
      backgroundColor: LiquidColors.backgroundDeep,
      surfaceTintColor: Colors.transparent,
      title: const Text('Guest View'),
      actions: [
        IconButton(
          tooltip: 'Reload vault media',
          onPressed: _loading ? null : _load,
          icon: AnimatedRotation(
            turns: _loading ? 1 : 0,
            duration: const Duration(milliseconds: 500),
            child: const Icon(Icons.refresh_rounded),
          ),
        ),
      ],
    ),
    body: _loading
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: LiquidColors.indigo),
                const SizedBox(height: AppSpace.md),
                Text(
                  'Loading your vault media…',
                  style: TextStyle(color: LiquidColors.textSecondary),
                ),
              ],
            ),
          )
        : _loadError != null
        ? _stateMessage(
            icon: Icons.cloud_off_rounded,
            title: 'Vault media is unavailable',
            message: _loadError!,
            action: FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          )
        : _items.isEmpty
        ? _emptyVault
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.md,
                  AppSpace.sm,
                  AppSpace.md,
                  AppSpace.sm,
                ),
                child: Column(
                  children: [
                    _introCard,
                    const SizedBox(height: AppSpace.md),
                    TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _query = value),
                      decoration: InputDecoration(
                        hintText: 'Search photos and videos',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                        filled: true,
                        fillColor: LiquidColors.backgroundLight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(
                            color: LiquidColors.cardBorder,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(
                            color: LiquidColors.cardBorder,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpace.sm),
                    Row(
                      children: [
                        for (final type in const [
                          'All',
                          'Photos',
                          'Videos',
                        ]) ...[
                          _filterChip(type),
                          const SizedBox(width: AppSpace.xs),
                        ],
                        const Spacer(),
                        TextButton(
                          onPressed: _visibleItems.isEmpty
                              ? null
                              : _toggleAllVisible,
                          child: Text(
                            _visibleItems.isNotEmpty &&
                                    _visibleItems.every(
                                      (item) => _selected.contains(item.id),
                                    )
                                ? 'Clear'
                                : 'Select all',
                          ),
                        ),
                      ],
                    ),
                    if (_invalidRows > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpace.xs),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 15,
                              color: LiquidColors.warning,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '$_invalidRows unreadable vault entr${_invalidRows == 1 ? 'y' : 'ies'} skipped. Other media is still available.',
                                style: TextStyle(
                                  color: LiquidColors.warning,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: _visibleItems.isEmpty
                    ? _stateMessage(
                        icon: Icons.search_off_rounded,
                        title: 'No matching media',
                        message:
                            'Try another search or choose a different filter.',
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpace.md,
                          AppSpace.xs,
                          AppSpace.md,
                          AppSpace.md,
                        ),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: AppSpace.sm,
                              mainAxisSpacing: AppSpace.sm,
                              childAspectRatio: .78,
                            ),
                        itemCount: _visibleItems.length,
                        itemBuilder: (context, index) =>
                            _mediaCard(_visibleItems[index], index),
                      ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.md,
                    AppSpace.sm,
                    AppSpace.md,
                    AppSpace.md,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _selected.isEmpty || _starting
                          ? null
                          : _startGuestView,
                      icon: _starting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.lock_open_rounded),
                      label: Text(
                        _starting
                            ? 'Preparing secure view…'
                            : 'Start guest view · ${_selected.length}',
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
  );

  Widget get _introCard => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpace.md),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          LiquidColors.indigo.withValues(alpha: .16),
          LiquidColors.backgroundLight,
          LiquidColors.backgroundLight.withValues(alpha: .8),
        ],
      ),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(color: LiquidColors.indigo.withValues(alpha: .18)),
    ),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: LiquidColors.indigo.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(Icons.visibility_rounded, color: LiquidColors.indigo),
        ),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Share a little. Keep the rest private.',
                style: TextStyle(
                  color: LiquidColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Select what guests can view. Your authentication is required to exit.',
                style: TextStyle(
                  color: LiquidColors.textSecondary,
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget get _emptyVault => _stateMessage(
    icon: Icons.photo_library_outlined,
    title: 'No photos or videos in your vault yet',
    message:
        'Import media into SecuroBox first. It will appear here for you to choose what a guest can see.',
    action: TextButton.icon(
      onPressed: _load,
      icon: const Icon(Icons.refresh_rounded),
      label: const Text('Refresh'),
    ),
  );

  Widget _stateMessage({
    required IconData icon,
    required String title,
    required String message,
    Widget? action,
  }) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: LiquidColors.indigo.withValues(alpha: .1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 30, color: LiquidColors.indigo),
          ),
          const SizedBox(height: AppSpace.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: LiquidColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: LiquidColors.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          if (action != null) ...[const SizedBox(height: AppSpace.md), action],
        ],
      ),
    ),
  );

  Widget _filterChip(String type) {
    final selected = _filter == type;
    final count = switch (type) {
      'Photos' => _items.where((item) => item.type == 'image').length,
      'Videos' => _items.where((item) => item.type == 'video').length,
      _ => _items.length,
    };
    return ChoiceChip(
      label: Text('$type $count'),
      selected: selected,
      onSelected: (_) => setState(() => _filter = type),
      selectedColor: LiquidColors.indigo.withValues(alpha: .16),
      labelStyle: TextStyle(
        color: selected ? LiquidColors.indigo : LiquidColors.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide(
        color: selected
            ? LiquidColors.indigo.withValues(alpha: .45)
            : LiquidColors.cardBorder,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _mediaCard(VideoItem item, int index) {
    final selected = _selected.contains(item.id);
    return TweenAnimationBuilder<double>(
      key: ValueKey('guest-${item.id}'),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 250 + (index.clamp(0, 7) * 30)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - value)),
          child: child,
        ),
      ),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(
            () => selected ? _selected.remove(item.id) : _selected.add(item.id),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: LiquidColors.backgroundLight,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? LiquidColors.indigo : LiquidColors.cardBorder,
              width: selected ? 1.8 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: LiquidColors.indigo.withValues(alpha: .12),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md - 1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      VaultThumbnail(
                        item: item,
                        width: double.infinity,
                        height: double.infinity,
                        radius: 0,
                        iconSize: 30,
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: AnimatedScale(
                          scale: selected ? 1 : .86,
                          duration: const Duration(milliseconds: 160),
                          child: Container(
                            width: 27,
                            height: 27,
                            decoration: BoxDecoration(
                              color: selected
                                  ? LiquidColors.indigo
                                  : Colors.black.withValues(alpha: .34),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: .85),
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              selected
                                  ? Icons.check_rounded
                                  : Icons.circle_outlined,
                              size: selected ? 18 : 15,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      if (item.type == 'video')
                        Positioned(
                          left: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: .55),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.play_arrow_rounded,
                                  size: 13,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 2),
                                Text(
                                  'VIDEO',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: .4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: LiquidColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: LiquidColors.textTertiary,
                          fontSize: 10,
                        ),
                      ),
                    ],
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

class _GuestOnlyView extends StatefulWidget {
  const _GuestOnlyView({required this.items});
  final List<VideoItem> items;

  @override
  State<_GuestOnlyView> createState() => _GuestOnlyViewState();
}

class _GuestOnlyViewState extends State<_GuestOnlyView> {
  bool _authenticating = false;

  Future<void> _leave() async {
    if (_authenticating) return;
    _authenticating = true;
    try {
      final ok = await authenticateForProtected(
        context,
        'Authenticate to leave Guest View',
        requireAuth: true,
      );
      if (ok && mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication could not be completed. Try again.'),
          ),
        );
      }
    } finally {
      _authenticating = false;
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _leave();
    },
    child: Scaffold(
      backgroundColor: LiquidColors.backgroundDeep,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: LiquidColors.backgroundDeep,
        title: const Text('Guest View'),
        actions: [
          TextButton.icon(
            onPressed: _leave,
            icon: const Icon(Icons.lock_rounded),
            label: const Text('Exit'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(AppSpace.md),
        itemCount: widget.items.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpace.sm),
        itemBuilder: (context, index) {
          final item = widget.items[index];
          return AppCard(
            child: ListTile(
              leading: VaultThumbnail(
                item: item,
                width: 52,
                height: 52,
                radius: 12,
              ),
              title: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: LiquidColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              trailing: Icon(
                Icons.play_circle_outline_rounded,
                color: LiquidColors.indigo,
              ),
              onTap: () async {
                HapticFeedback.selectionClick();
                await openVaultMedia(context, item);
              },
            ),
          );
        },
      ),
    ),
  );
}
