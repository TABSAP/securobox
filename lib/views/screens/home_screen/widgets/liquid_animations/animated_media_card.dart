import 'package:flutter/material.dart';
import 'package:video_player_app/widgets/app_spacing.dart';
import 'package:video_player_app/widgets/vault_thumbnail.dart';
import '../../../../../models/app_models.dart';
import '../../../../../utils/media_helper.dart';
import '../../../../../utils/liquid_colors.dart';

class AnimatedMediaCard extends StatefulWidget {
  final VideoItem media;
  final VoidCallback? onTap;
  final VoidCallback? onCategoryTap;
  final VoidCallback? onDownloadTap;
  final VoidCallback? onDeleteTap;
  final VoidCallback? onRenameTap;
  final Function(String)? onCategorySelected;
  final VoidCallback? onFavoriteToggle;
  final List<String> categories;
  final int index;

  const AnimatedMediaCard({
    super.key,
    required this.media,
    this.onTap,
    this.onCategoryTap,
    this.onDownloadTap,
    this.onDeleteTap,
    this.onCategorySelected,
    this.onFavoriteToggle,
    required this.categories,
    required this.index,
    required this.onRenameTap,
  });

  @override
  State<AnimatedMediaCard> createState() => _AnimatedMediaCardState();
}

class _AnimatedMediaCardState extends State<AnimatedMediaCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entry;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _fade = CurvedAnimation(parent: _entry, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entry, curve: Curves.easeOutCubic));
    final delayMs = widget.index.clamp(0, 6) * 28;
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (mounted) _entry.forward();
    });
  }

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  VideoItem get _m => widget.media;
  Color get _accent => LiquidColors.getMediaColor(_m.type);

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.97 : 1.0,
            duration: const Duration(milliseconds: 130),
            curve: Curves.easeOut,
            child: _buildCard(context),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpace.sm + 2),
      padding: const EdgeInsets.all(AppSpace.sm + 2),
      decoration: BoxDecoration(
        color: LiquidColors.backgroundLight.withValues(
          alpha: _pressed ? 0.78 : 0.55,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: LiquidColors.cardBorder),
      ),
      child: Row(
        children: [
          _buildThumbnail(),
          const SizedBox(width: 12),
          Expanded(child: _buildInfo()),
          const SizedBox(width: 4),
          _buildActions(context),
        ],
      ),
    );
  }

  Widget _buildThumbnail() {
    return SizedBox(
      width: 54,
      height: 54,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          VaultThumbnail(
            item: _m,
            width: 54,
            height: 54,
            radius: 15,
            iconSize: 24,
          ),
          if (_m.isFavorite)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: LiquidColors.backgroundLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.favorite_rounded,
                  size: 12,
                  color: LiquidColors.accentPink,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _m.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: LiquidColors.textPrimary,
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _m.type.toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: _accent,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${_m.category}  ·  ${MediaHelper.formatDate(_m.id)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  color: LiquidColors.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    return _iconButton(
      icon: Icons.more_vert_rounded,
      color: LiquidColors.textSecondary,
      onTap: () => _showActionMenu(context),
      tooltip: 'More',
    );
  }

  Widget _iconButton({
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
    String? tooltip,
  }) {
    final enabled = onTap != null;
    final btn = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: enabled
                ? color.withValues(alpha: 0.10)
                : LiquidColors.textPrimary.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: enabled
                  ? color.withValues(alpha: 0.22)
                  : LiquidColors.textPrimary.withValues(alpha: 0.05),
            ),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip, child: btn) : btn;
  }

  Future<void> _showActionMenu(BuildContext context) async {
    final position = _menuPositionFor(context);
    if (position == null) return;

    final choice = await showMenu<String>(
      context: context,
      position: position,
      color: LiquidColors.backgroundLight,
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: LiquidColors.textPrimary.withValues(alpha: 0.08),
        ),
      ),
      items: [
        _menuItem(
          'favorite',
          _m.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          _m.isFavorite ? 'Remove favorite' : 'Add to favorites',
          LiquidColors.accentPink,
        ),
        _menuItem(
          'rename',
          Icons.drive_file_rename_outline_rounded,
          'Rename',
          LiquidColors.accentBlue,
        ),
        _menuItem(
          'category',
          Icons.label_outline_rounded,
          'Change category',
          LiquidColors.success,
        ),
        _menuItem(
          'download',
          Icons.download_rounded,
          'Save to gallery',
          LiquidColors.accentPurple,
        ),
        const PopupMenuDivider(height: 6),
        _menuItem(
          'delete',
          Icons.delete_outline_rounded,
          'Move to trash',
          LiquidColors.error,
        ),
      ],
    );

    if (!mounted) return;
    switch (choice) {
      case 'favorite':
        widget.onFavoriteToggle?.call();
        break;
      case 'rename':
        widget.onRenameTap?.call();
        break;
      case 'category':
        if (context.mounted) _showCategoryMenu(context);
        break;
      case 'download':
        widget.onDownloadTap?.call();
        break;
      case 'delete':
        widget.onDeleteTap?.call();
        break;
    }
  }

  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label,
    Color color,
  ) {
    return PopupMenuItem<String>(
      value: value,
      height: 44,
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: LiquidColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showCategoryMenu(BuildContext context) {
    final position = _menuPositionFor(context);
    if (position == null) return;

    showMenu<String>(
      context: context,
      position: position,
      color: LiquidColors.backgroundLight,
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: LiquidColors.textPrimary.withValues(alpha: 0.08),
        ),
      ),
      items: widget.categories.where((c) => c != 'All').map((category) {
        final selected = category == _m.category;
        return PopupMenuItem<String>(
          value: category,
          height: 42,
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 16,
                color: selected
                    ? LiquidColors.success
                    : LiquidColors.textTertiary,
              ),
              const SizedBox(width: 12),
              Text(
                category,
                style: TextStyle(
                  color: selected
                      ? LiquidColors.textPrimary
                      : LiquidColors.textSecondary,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    ).then((value) {
      if (value != null) widget.onCategorySelected?.call(value);
    });
  }

  RelativeRect? _menuPositionFor(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null || !box.hasSize) return null;
    return RelativeRect.fromRect(
      Rect.fromPoints(
        box.localToGlobal(box.size.topRight(Offset.zero), ancestor: overlay),
        box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
  }
}
