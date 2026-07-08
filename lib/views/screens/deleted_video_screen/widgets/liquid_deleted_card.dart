import 'package:flutter/material.dart';
import '../../../../models/app_models.dart';
import '../../../../utils/liquid_colors.dart';

class LiquidDeletedCard extends StatefulWidget {
  final VideoItem video;
  final VoidCallback onRestore;
  final VoidCallback onDelete;
  final String Function(DateTime) formatDate;
  final IconData Function(String) getIcon;
  final Color Function(String) getColor;
  final int index;
  final int? daysRemaining;

  const LiquidDeletedCard({
    super.key,
    required this.video,
    required this.onRestore,
    required this.onDelete,
    required this.formatDate,
    required this.getIcon,
    required this.getColor,
    required this.index,
    this.daysRemaining,
  });

  @override
  State<LiquidDeletedCard> createState() => _LiquidDeletedCardState();
}

class _LiquidDeletedCardState extends State<LiquidDeletedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: widget.index * 100), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getDaysRemainingColor(int days) {
    if (days <= 5) return LiquidColors.error;
    if (days <= 15) return LiquidColors.warning;
    return LiquidColors.success;
  }

  @override
  Widget build(BuildContext context) {
    final iconData = widget.getIcon(widget.video.type);
    final iconColor = widget.getColor(widget.video.type);
    final isLocked = widget.video.isLocked;
    final daysRemaining = widget.daysRemaining ?? 30;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Dismissible(
            key: Key('${widget.video.id}_${widget.index}'),
            direction: DismissDirection.horizontal,
            background: _buildSwipeBackground(true),
            secondaryBackground: _buildSwipeBackground(false),
            confirmDismiss: (direction) => _confirmDismiss(direction),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    LiquidColors.backgroundLight.withValues(alpha: 0.9),
                    LiquidColors.backgroundMid.withValues(alpha: 0.95),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isLocked
                      ? LiquidColors.warning.withValues(alpha: 0.3)
                      : iconColor.withValues(alpha: 0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isLocked ? LiquidColors.warning : iconColor)
                        .withValues(alpha: 0.1),
                    blurRadius: 15,
                    spreadRadius: 0,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _buildIcon(iconData, iconColor, isLocked),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildInfo(iconColor, isLocked, daysRemaining),
                    ),
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(IconData iconData, Color iconColor, bool isLocked) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (context, double value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: isLocked
                    ? [
                        LiquidColors.warning.withValues(alpha: 0.3),
                        LiquidColors.warning.withValues(alpha: 0.1),
                      ]
                    : [
                        iconColor.withValues(alpha: 0.3),
                        iconColor.withValues(alpha: 0.1),
                      ],
                center: Alignment.center,
                radius: 0.8,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isLocked
                    ? LiquidColors.warning.withValues(alpha: 0.3)
                    : iconColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Center(
              child: Icon(
                isLocked ? Icons.lock_outline_rounded : iconData,
                color: isLocked ? LiquidColors.warning : iconColor,
                size: 32,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfo(Color iconColor, bool isLocked, int daysRemaining) {
    final daysColor = _getDaysRemainingColor(daysRemaining);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.video.title,
          style: TextStyle(
            color: isLocked ? LiquidColors.warning : LiquidColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),

        if (widget.video.deletedDate != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: daysColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: daysColor.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  daysRemaining <= 5
                      ? Icons.warning_amber_rounded
                      : Icons.timer_outlined,
                  size: 14,
                  color: daysColor,
                ),
                const SizedBox(width: 4),
                Text(
                  daysRemaining <= 0
                      ? 'Auto-delete today'
                      : 'Auto-delete in $daysRemaining days',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: daysColor,
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 8),

        if (widget.video.deletedDate != null)
          Row(
            children: [
              Icon(Icons.access_time, size: 14, color: LiquidColors.textTertiary),
              const SizedBox(width: 4),
              Text(
                'Deleted ${widget.formatDate(widget.video.deletedDate!)}',
                style: TextStyle(fontSize: 12, color: LiquidColors.textTertiary),
              ),
            ],
          ),

        const SizedBox(height: 8),

        Wrap(
          spacing: 8,
          children: [
            _buildChip(widget.video.type.toUpperCase(), iconColor),
            _buildChip(widget.video.category, LiquidColors.success),
          ],
        ),
      ],
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        _buildActionButton(
          icon: Icons.restore,
          color: LiquidColors.success,
          onTap: widget.onRestore,
        ),
        const SizedBox(height: 8),
        _buildActionButton(
          icon: Icons.delete_forever,
          color: LiquidColors.error,
          onTap: widget.onDelete,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (context, double value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  color.withValues(alpha: 0.2),
                  color.withValues(alpha: 0.1),
                ],
                center: Alignment.center,
                radius: 0.8,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.2),
                  blurRadius: 10,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              onPressed: onTap,
              icon: Icon(icon, color: color, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSwipeBackground(bool isLeft) {
    final color = isLeft ? LiquidColors.success : LiquidColors.error;
    final icon = isLeft ? Icons.restore : Icons.delete_forever;
    final text = isLeft ? 'Restore' : 'Delete';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.8)],
          begin: isLeft ? Alignment.centerLeft : Alignment.centerRight,
          end: isLeft ? Alignment.centerRight : Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
      padding: EdgeInsets.only(left: isLeft ? 20 : 0, right: isLeft ? 0 : 20),
      child: Row(
        mainAxisAlignment: isLeft
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        children: [
          if (isLeft) ...[
            Icon(icon, color: LiquidColors.textPrimary, size: 28),
            const SizedBox(width: 10),
            Text(
              text,
              style: TextStyle(
                color: LiquidColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ] else ...[
            Text(
              text,
              style: TextStyle(
                color: LiquidColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 10),
            Icon(icon, color: LiquidColors.textPrimary, size: 28),
          ],
        ],
      ),
    );
  }

  Future<bool?> _confirmDismiss(DismissDirection direction) async {
    if (direction == DismissDirection.startToEnd) {
      widget.onRestore();
      return false;
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => _buildDeleteDialog(),
      );
      if (confirm == true) {
        widget.onDelete();
      }
      return false;
    }
  }

  Widget _buildDeleteDialog() {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [LiquidColors.backgroundLight, LiquidColors.backgroundMid],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: LiquidColors.error.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    LiquidColors.error.withValues(alpha: 0.3),
                    LiquidColors.error.withValues(alpha: 0.1),
                  ],
                  center: Alignment.center,
                  radius: 0.8,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Icon(
                  Icons.delete_forever,
                  color: LiquidColors.error,
                  size: 30,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Hide File?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: LiquidColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '"${widget.video.title}" will be hidden from the app. You can recover it later using your Recovery Key.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: LiquidColors.textSecondary),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: LiquidColors.textTertiary),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: LiquidColors.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LiquidColors.error,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Delete',
                      style: TextStyle(color: LiquidColors.textPrimary),
                    ),
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
