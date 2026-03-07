import 'package:flutter/material.dart';
import '../../../../../models/app_models.dart';
import '../../../../../utils/media_helper.dart';
import '../../../../../utils/liquid_colors.dart';
import 'liquid_background.dart';

class AnimatedMediaCard extends StatefulWidget {
  final VideoItem media;
  final VoidCallback? onTap;
  final VoidCallback? onCategoryTap;
  final VoidCallback? onLockTap;
  final VoidCallback? onDownloadTap;
  final VoidCallback? onDeleteTap;
  final VoidCallback? onRenameTap;
  final Function(String)? onCategorySelected;
  final List<String> categories;
  final int index;

  const AnimatedMediaCard({
    super.key,
    required this.media,
    this.onTap,
    this.onCategoryTap,
    this.onLockTap,
    this.onDownloadTap,
    this.onDeleteTap,
    this.onCategorySelected,
    required this.categories,
    required this.index, required this.onRenameTap,
  });

  @override
  State<AnimatedMediaCard> createState() => _AnimatedMediaCardState();
}

class _AnimatedMediaCardState extends State<AnimatedMediaCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    // Start animation with delay based on index
    Future.delayed(Duration(milliseconds: widget.index * 100), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final iconData = MediaHelper.getMediaIcon(widget.media.type);
    final mediaColor = LiquidColors.getMediaColor(widget.media.type);
    final mediaGradient = LiquidColors.getMediaGradient(widget.media.type);
    final isLocked = widget.media.isLocked;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: LiquidContainer(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (isLocked ? LiquidColors.warning : mediaColor).withOpacity(0.3),
              blurRadius: 15,
              spreadRadius: 0,
              offset: const Offset(0, 8),
            ),
          ],
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  LiquidColors.backgroundLight.withOpacity(0.9),
                  LiquidColors.backgroundMid.withOpacity(0.95),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: (isLocked ? LiquidColors.warning : mediaColor).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                _buildAnimatedThumbnail(mediaGradient, iconData, isLocked),
                const SizedBox(width: 16),
                _buildInfo(widget.media, isLocked, mediaColor),
                _buildActions(context, isLocked, mediaColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedThumbnail(Gradient gradient, IconData iconData, bool isLocked) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.elasticOut,
      builder: (context, double value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              gradient: isLocked
                  ? LinearGradient(
                colors: [LiquidColors.warning, LiquidColors.accentOrange],
              )
                  : gradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: (isLocked ? LiquidColors.warning : LiquidColors.primaryStart).withOpacity(0.4),
                  blurRadius: 15,
                  spreadRadius: 1,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                isLocked ? Icons.lock_outline_rounded : iconData,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfo(VideoItem media, bool isLocked, Color mediaColor) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            media.title,
            style: TextStyle(
              color: isLocked ? LiquidColors.warning : Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              shadows: [
                Shadow(
                  color: (isLocked ? LiquidColors.warning : mediaColor).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _buildAnimatedChip(
                media.type.toUpperCase(),
                isLocked ? LiquidColors.warning : mediaColor,
              ),
              if (!isLocked) _buildAnimatedChip(media.category, LiquidColors.success),
              if (isLocked) _buildAnimatedChip('Locked', LiquidColors.warning),
              Text(
                MediaHelper.formatDate(media.id),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade400,
                ),
              ),

            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedChip(String label, Color color) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      builder: (context, double value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.3), width: 1),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActions(BuildContext context, bool isLocked, Color mediaColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isLocked) _buildAnimatedActionButton(
          icon: Icons.category,
          color: LiquidColors.success,
          onTap: () => _showCategoryMenu(context),
        ),
        if (!isLocked) const SizedBox(width: 8),
        Column(
          children: [
            _buildAnimatedActionButton(icon: Icons.more_vert, color: Colors.white, onTap: widget.onRenameTap,isDisabled: isLocked),
            const SizedBox(height: 8),
            _buildAnimatedActionButton(
              icon: isLocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
              color: isLocked ? LiquidColors.warning : Colors.white,
              onTap: widget.onLockTap,
            ),
          ],
        ),
        const SizedBox(width: 8),
        Column(
          children: [
            _buildAnimatedActionButton(
              icon: Icons.download_rounded,
              color: LiquidColors.accentBlue,
              onTap: widget.onDownloadTap,
              isDisabled: isLocked,
            ),
            const SizedBox(height: 8),
            _buildAnimatedActionButton(
              icon: Icons.delete_outline_rounded,
              color: LiquidColors.error,
              onTap: widget.onDeleteTap,
              isDisabled: isLocked,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAnimatedActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
    bool isDisabled = false,
  }) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      curve: Curves.elasticOut,
      builder: (context, double value, child) {
        return Transform.scale(
          scale: value,
          child: GestureDetector(
            onTap: isDisabled ? null : onTap,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    color.withValues(alpha:  isDisabled ? 0.1 : 0.2),
                    color.withValues(alpha:  isDisabled ? 0.05 : 0.1),
                  ],
                  center: Alignment.center,
                  radius: 0.8,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: color.withOpacity(isDisabled ? 0.1 : 0.3),
                  width: 1,
                ),
                boxShadow: isDisabled
                    ? null
                    : [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 0,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: isDisabled ? Colors.grey.shade600 : color,
                size: 20,
              ),
            ),
          ),
        );
      },
    );
  }

  void _showCategoryMenu(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu(
      context: context,
      position: position,
      elevation: 8,
      color: LiquidColors.backgroundLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: LiquidColors.primaryStart.withOpacity(0.3), width: 1),
      ),
      items: widget.categories
          .where((c) => c != "All")
          .map((category) => PopupMenuItem(
        value: category,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      LiquidColors.primaryStart,
                      LiquidColors.primaryEnd,
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                category,
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ))
          .toList(),
    ).then((value) {
      if (value != null && widget.onCategorySelected != null) {
        widget.onCategorySelected!(value);
      }
    });
  }
}