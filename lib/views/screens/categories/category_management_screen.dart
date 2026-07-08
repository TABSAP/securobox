import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:video_player_app/utils/category_service.dart';
import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/widgets/app_spacing.dart';

/// Unified category management: default (built-in) and custom categories live
/// together in one reorderable list. Users can rename and hide/show every
/// category, reorder them all, and delete custom ones (defaults can only be
/// hidden). All persistence goes through [CategoryService].
class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  static const int _maxLength = 24;
  static final RegExp _allowed = RegExp(r'^[A-Za-z0-9 _\-]+$');

  /// Filter pseudo-categories that can never be used as a custom name.
  static const List<String> _reserved = ['All', 'Favorites'];

  List<CategoryInfo> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final list = await CategoryService.instance.load();
    if (!mounted) return;
    setState(() {
      _items = list;
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

  /// Validates [name] and returns an error string, or null when valid.
  /// [originalKey] is supplied on rename so the item's own name/key is allowed.
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

  /// Shows the add/rename dialog. Returns the trimmed valid name, or null when
  /// cancelled. When [originalName] is provided the dialog is in rename mode.
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

            return AlertDialog(
              backgroundColor: LiquidColors.backgroundLight,
              surfaceTintColor: Colors.transparent,
              shape:
                  const RoundedRectangleBorder(borderRadius: AppRadius.rLg),
              title: Text(
                originalName == null ? 'New category' : 'Rename category',
                style: TextStyle(
                  color: LiquidColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: TextField(
                controller: controller,
                autofocus: true,
                maxLength: _maxLength,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => submit(),
                onChanged: (_) {
                  if (errorText != null) setLocal(() => errorText = null);
                },
                style: TextStyle(color: LiquidColors.textPrimary),
                cursorColor: LiquidColors.indigo,
                decoration: InputDecoration(
                  hintText: 'e.g. Receipts',
                  hintStyle: TextStyle(color: LiquidColors.textTertiary),
                  errorText: errorText,
                  counterStyle: TextStyle(color: LiquidColors.textTertiary),
                  filled: true,
                  fillColor:
                      LiquidColors.backgroundDeep.withValues(alpha: 0.6),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppRadius.rMd,
                    borderSide: BorderSide(color: LiquidColors.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppRadius.rMd,
                    borderSide:
                        BorderSide(color: LiquidColors.indigo, width: 1.5),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: AppRadius.rMd,
                    borderSide: BorderSide(color: LiquidColors.error),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: AppRadius.rMd,
                    borderSide:
                        BorderSide(color: LiquidColors.error, width: 1.5),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: LiquidColors.textSecondary),
                  ),
                ),
                FilledButton(
                  onPressed: submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: LiquidColors.indigo,
                    foregroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.rMd,
                    ),
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
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
        title: Text(
          'Manage Categories',
          style: TextStyle(
            color: LiquidColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'New category',
            onPressed: _addCategory,
            icon: Icon(Icons.add_rounded, color: LiquidColors.indigo),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: LiquidColors.indigo),
            )
          : _buildList(),
      bottomNavigationBar: _loading
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _addCategory,
                  style: FilledButton.styleFrom(
                    backgroundColor: LiquidColors.indigo,
                    foregroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.rLg,
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text(
                    'New category',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildList() {
    return ReorderableListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      itemCount: _items.length,
      onReorderItem: _onReorder,
      proxyDecorator: (child, index, animation) => Material(
        color: Colors.transparent,
        child: child,
      ),
      itemBuilder: (context, index) {
        final item = _items[index];
        return Padding(
          key: ValueKey(item.key),
          padding: const EdgeInsets.only(bottom: 10),
          child: _CategoryTile(
            item: item,
            index: index,
            icon: _iconFor(item),
            onRename: () => _renameCategory(item),
            onToggleHidden: () => _toggleHidden(item),
            onDelete: item.isDefault ? null : () => _deleteCategory(item),
          ),
        );
      },
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final CategoryInfo item;
  final int index;
  final IconData icon;
  final VoidCallback onRename;
  final VoidCallback onToggleHidden;
  final VoidCallback? onDelete;

  const _CategoryTile({
    required this.item,
    required this.index,
    required this.icon,
    required this.onRename,
    required this.onToggleHidden,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
      decoration: BoxDecoration(
        color: LiquidColors.backgroundLight.withValues(alpha: 0.55),
        borderRadius: AppRadius.rLg,
        border: Border.all(color: LiquidColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: LiquidColors.indigo.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: LiquidColors.indigo, size: 20),
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Icon(
                Icons.drag_indicator_rounded,
                color: LiquidColors.textTertiary,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );

    return Opacity(opacity: item.hidden ? 0.5 : 1.0, child: card);
  }

  Widget _pill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: LiquidColors.textPrimary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: LiquidColors.textTertiary,
          fontSize: 11,
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
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      icon: Icon(icon, color: color, size: 20),
    );
  }
}
