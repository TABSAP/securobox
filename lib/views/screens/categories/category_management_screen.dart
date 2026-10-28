import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:video_player_app/utils/category_service.dart';
import 'package:video_player_app/utils/category_lock_service.dart';
import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/utils/flush_bar_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_app/widgets/app_spacing.dart';
import 'package:video_player_app/widgets/liquid_glass_surface.dart';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  static const int _maxLength = 24;
  static final RegExp _allowed = RegExp(r'^[A-Za-z0-9 _\-]+$');

  static const List<String> _reserved = ['All', 'Favorites'];

  List<CategoryInfo> _items = [];
  Set<String> _locked = {};
  bool _loading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final list = await CategoryService.instance.load();
    final locked = await CategoryLockService.instance.lockedKeys();
    if (!mounted) return;
    setState(() {
      _items = list;
      _locked = locked;
      _loading = false;
    });
  }

  IconData _iconFor(CategoryInfo item) {
    if (!item.isDefault) return Icons.folder_rounded;
    switch (item.type) {
      case 'favorite':
        return Icons.favorite_rounded;
      case 'video':
        return Icons.movie_rounded;
      case 'image':
        return Icons.photo_rounded;
      case 'audio':
        return Icons.music_note_rounded;
      case 'document':
        return Icons.description_rounded;
      case 'other':
      default:
        return Icons.folder_copy_rounded;
    }
  }

  String? _validate(String name, {String? originalKey}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Please enter a name';
    if (trimmed.length > _maxLength) {
      return 'Keep it under $_maxLength characters';
    }
    if (!_allowed.hasMatch(trimmed)) {
      return 'Only letters, numbers, spaces, - and _';
    }
    final lower = trimmed.toLowerCase();
    if (_reserved.any((r) => r.toLowerCase() == lower)) {
      return '"$trimmed" is reserved';
    }
    for (final c in _items) {
      if (c.key == originalKey) continue;
      if (c.name.toLowerCase() == lower || c.key.toLowerCase() == lower) {
        return '"$trimmed" already exists';
      }
    }
    return null;
  }

  Future<void> _addCategory() async {
    final name = await _showEditDialog();
    if (name == null) return;
    await CategoryService.instance.addCustom(name);
    await _reload();
  }

  Future<void> _renameCategory(CategoryInfo item) async {
    final name = await _showEditDialog(
      originalName: item.name,
      originalKey: item.key,
    );
    if (name == null || name == item.name) return;
    await CategoryService.instance.rename(item.key, name);
    await _reload();
  }

  Future<void> _toggleHidden(CategoryInfo item) async {
    HapticFeedback.selectionClick();
    await CategoryService.instance.setHidden(item.key, !item.hidden);
    await _reload();
  }

  Future<void> _toggleLock(CategoryInfo item) async {
    final prefs = await SharedPreferences.getInstance();
    final hasGate =
        (prefs.getBool('appLock') ?? false) ||
        (prefs.getBool('biometric') ?? false) ||
        (prefs.getBool('biometric_face') ?? false);
    if (!hasGate) {
      if (mounted) {
        FlushBarHelper.flushBarWarningMessage(
          'Set up a PIN or biometrics in Security first.',
          context,
        );
      }
      return;
    }
    final lock = !_locked.contains(item.key.toLowerCase());
    await CategoryLockService.instance.setLocked(item.key, lock);
    await _reload();
  }

  Future<void> _deleteCategory(CategoryInfo item) async {
    HapticFeedback.selectionClick();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LiquidColors.backgroundLight,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.rLg),
        title: Text(
          'Delete category?',
          style: TextStyle(
            color: LiquidColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          "Delete '${item.name}'? Files stay in your vault; they just won't "
          'appear under this category.',
          style: TextStyle(color: LiquidColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: LiquidColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: TextStyle(
                color: LiquidColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    HapticFeedback.selectionClick();
    await CategoryService.instance.deleteCustom(item.key);
    await _reload();
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    HapticFeedback.selectionClick();
    setState(() {
      final moved = _items.removeAt(oldIndex);
      _items.insert(newIndex, moved);
    });
    await CategoryService.instance.reorder(_items);
    await _reload();
  }

  Future<String?> _showEditDialog({String? originalName, String? originalKey}) {
    final controller = TextEditingController(text: originalName ?? '');
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        String? errorText;
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            void submit() {
              HapticFeedback.selectionClick();
              final value = controller.text.trim();
              final err = _validate(value, originalKey: originalKey);
              if (err != null) {
                setLocal(() => errorText = err);
                return;
              }
              Navigator.pop(ctx, value);
            }

            final theme = Theme.of(ctx);
            return Dialog(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              child: LiquidGlassSurface(
                borderRadius: AppRadius.lg,
                blur: 24,
                tintOpacity: 0,
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      originalName == null ? 'New category' : 'Rename category',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      maxLength: _maxLength,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => submit(),
                      onChanged: (_) {
                        if (errorText != null) setLocal(() => errorText = null);
                      },
                      style: TextStyle(color: theme.colorScheme.onSurface),
                      cursorColor: theme.colorScheme.primary,
                      decoration: InputDecoration(
                        hintText: 'e.g. Receipts',
                        hintStyle: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.48,
                          ),
                        ),
                        errorText: errorText,
                        errorStyle: TextStyle(color: theme.colorScheme.error),
                        counterStyle: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.48,
                          ),
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surface.withValues(
                          alpha: theme.brightness == Brightness.dark
                              ? 0.24
                              : 0.48,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: AppRadius.rMd,
                          borderSide: BorderSide(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.12,
                            ),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: AppRadius.rMd,
                          borderSide: BorderSide(
                            color: theme.colorScheme.primary,
                            width: 1.5,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: AppRadius.rMd,
                          borderSide: BorderSide(
                            color: theme.colorScheme.error,
                          ),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: AppRadius.rMd,
                          borderSide: BorderSide(
                            color: theme.colorScheme.error,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _dialogAction(
                          context: ctx,
                          label: 'Cancel',
                          onPressed: () => Navigator.pop(ctx),
                        ),
                        const SizedBox(width: 10),
                        _dialogAction(
                          context: ctx,
                          label: 'Save',
                          primary: true,
                          onPressed: submit,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _dialogAction({
    required BuildContext context,
    required String label,
    required VoidCallback onPressed,
    bool primary = false,
  }) {
    final theme = Theme.of(context);
    return LiquidGlassSurface(
      borderRadius: 14,
      blur: 14,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 88, minHeight: 46),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  label,
                  style: TextStyle(
                    color: primary
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor.withValues(alpha: 0.78),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: LiquidColors.systemOverlayStyle,
        title: Text(
          'Manage Categories',
          style: TextStyle(
            color: LiquidColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: LiquidGlassSurface(
              borderRadius: 13,
              blur: 14,
              child: Material(
                color: Colors.transparent,
                child: IconButton(
                  tooltip: 'New category',
                  onPressed: _addCategory,
                  icon: Icon(
                    Icons.add_rounded,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: LiquidColors.indigo))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _buildSearchBar(theme),
                ),
                Expanded(child: _buildList()),
              ],
            ),
      bottomNavigationBar: _loading
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                height: 52,
                child: LiquidGlassSurface(
                  borderRadius: AppRadius.lg,
                  blur: 20,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _addCategory,
                      borderRadius: AppRadius.rLg,
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_rounded,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'New category',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return LiquidGlassSurface(
      borderRadius: AppRadius.md,
      blur: 18,
      child: SizedBox(
        height: 52,
        child: TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 15),
          cursorColor: theme.colorScheme.primary,
          onChanged: (value) => setState(() => _searchQuery = value.trim()),
          decoration: InputDecoration(
            isDense: true,
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            hintText: 'Search categories',
            hintStyle: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.48),
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            suffixIcon: _searchQuery.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    icon: Icon(
                      Icons.close_rounded,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.55,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    final filteredItems = _searchQuery.isEmpty
        ? _items
        : _items
              .where(
                (item) => item.name.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ),
              )
              .toList();

    Widget buildTile(CategoryInfo item, int index) => Padding(
      key: ValueKey(item.key),
      padding: const EdgeInsets.only(bottom: 10),
      child: _CategoryTile(
        item: item,
        index: index,
        icon: _iconFor(item),
        onRename: () => _renameCategory(item),
        onToggleHidden: () => _toggleHidden(item),
        onToggleLock: () => _toggleLock(item),
        isLocked: _locked.contains(item.key.toLowerCase()),
        onDelete: item.isDefault ? null : () => _deleteCategory(item),
      ),
    );

    if (filteredItems.isEmpty) {
      return Center(
        child: Text(
          _searchQuery.isEmpty ? 'No categories yet' : 'No matching categories',
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.58),
          ),
        ),
      );
    }

    final padding = const EdgeInsets.fromLTRB(16, 14, 16, 24);
    if (_searchQuery.isNotEmpty) {
      return ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: padding,
        itemCount: filteredItems.length,
        itemBuilder: (context, index) => buildTile(filteredItems[index], index),
      );
    }
    return ReorderableListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: padding,
      itemCount: filteredItems.length,
      onReorderItem: _onReorder,
      proxyDecorator: (child, index, animation) =>
          Material(color: Colors.transparent, child: child),
      itemBuilder: (context, index) => buildTile(filteredItems[index], index),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final CategoryInfo item;
  final int index;
  final IconData icon;
  final VoidCallback onRename;
  final VoidCallback onToggleHidden;
  final VoidCallback onToggleLock;
  final bool isLocked;
  final VoidCallback? onDelete;

  const _CategoryTile({
    required this.item,
    required this.index,
    required this.icon,
    required this.onRename,
    required this.onToggleHidden,
    required this.onToggleLock,
    required this.isLocked,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final card = LiquidGlassSurface(
      borderRadius: AppRadius.lg,
      blur: 18,
      padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
      tintColor: isLocked ? LiquidColors.indigo : null,
      tintOpacity: isLocked ? 0.07 : 0,
      child: Row(
        children: [
          LiquidGlassSurface(
            borderRadius: 12,
            blur: 12,
            tintColor: LiquidColors.indigo,
            tintOpacity: 0.12,
            child: SizedBox(
              width: 42,
              height: 42,
              child: Icon(icon, color: LiquidColors.indigo, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: LiquidColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (item.isDefault) ...[
                      const SizedBox(width: 8),
                      _pill('Default'),
                    ],
                  ],
                ),
                if (item.hidden)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Hidden',
                      style: TextStyle(
                        color: LiquidColors.textTertiary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _action(
            tooltip: 'Rename',
            icon: Icons.edit_rounded,
            color: LiquidColors.textSecondary,
            onPressed: onRename,
          ),
          _action(
            tooltip: isLocked ? 'Unlock category' : 'Lock category',
            icon: isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
            color: isLocked ? LiquidColors.indigo : LiquidColors.textSecondary,
            onPressed: onToggleLock,
          ),
          _action(
            tooltip: item.hidden ? 'Show' : 'Hide',
            icon: item.hidden
                ? Icons.visibility_rounded
                : Icons.visibility_off_rounded,
            color: LiquidColors.textSecondary,
            onPressed: onToggleHidden,
          ),
          if (onDelete != null)
            _action(
              tooltip: 'Delete',
              icon: Icons.delete_outline_rounded,
              color: LiquidColors.error,
              onPressed: onDelete!,
            ),
          ReorderableDragStartListener(
            index: index,
            child: LiquidGlassSurface(
              borderRadius: 10,
              blur: 10,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                child: Icon(
                  Icons.drag_indicator_rounded,
                  color: LiquidColors.textTertiary,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Opacity(opacity: item.hidden ? 0.5 : 1.0, child: card);
  }

  Widget _pill(String label) {
    return LiquidGlassSurface(
      borderRadius: 999,
      blur: 10,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      child: Text(
        label,
        style: TextStyle(
          color: LiquidColors.textTertiary,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _action({
    required String tooltip,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    final isDestructive = color == LiquidColors.error;
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      icon: LiquidGlassSurface(
        borderRadius: 10,
        blur: 10,
        tintColor: isDestructive ? color : null,
        tintOpacity: isDestructive ? 0.1 : 0,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }
}
