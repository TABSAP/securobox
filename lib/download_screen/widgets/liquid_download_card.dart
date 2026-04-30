import 'dart:io';
import 'package:flutter/material.dart';
import '../../utils/liquid_colors.dart';

class LiquidDownloadCard extends StatefulWidget {
  final String fileName;
  final String fileSize;
  final String status;
  final String date;
  final String videoPath;
  final VoidCallback? onSave;
  final VoidCallback? onShare;
  final bool fileExists;
  final int index;

  const LiquidDownloadCard({
    super.key,
    required this.fileName,
    required this.fileSize,
    required this.status,
    required this.date,
    required this.videoPath,
    this.onSave,
    this.onShare,
    required this.fileExists,
    required this.index,
  });

  @override
  State<LiquidDownloadCard> createState() => _LiquidDownloadCardState();
}

class _LiquidDownloadCardState extends State<LiquidDownloadCard>
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

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    Future.delayed(Duration(milliseconds: widget.index * 100), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.tryParse(dateString);
      if (date == null) return dateString;

      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 365) {
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      } else if (difference.inDays > 30) {
        return '${(difference.inDays / 30).floor()} months ago';
      } else if (difference.inDays > 7) {
        return '${(difference.inDays / 7).floor()} weeks ago';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} days ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hours ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minutes ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = widget.status.toLowerCase() == 'completed';
    final statusColor = isCompleted ? LiquidColors.success : LiquidColors.warning;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
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
                color: statusColor.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: statusColor.withOpacity(0.1),
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
                  _buildStatusIcon(isCompleted, statusColor),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildInfoSection(isCompleted, statusColor),
                  ),
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(bool isCompleted, Color statusColor) {
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
                colors: [
                  statusColor.withOpacity(0.3),
                  statusColor.withOpacity(0.1),
                ],
                center: Alignment.center,
                radius: 0.8,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: statusColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Center(
              child: Icon(
                isCompleted ? Icons.check_circle_rounded : Icons.download_done_rounded,
                color: statusColor,
                size: 32,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoSection(bool isCompleted, Color statusColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.fileName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _buildChip(
              widget.status.toUpperCase(),
              statusColor,
            ),
            _buildChip(
              widget.fileSize,
              LiquidColors.accentBlue,
            ),
            _buildChip(
              _formatDate(widget.date),
              LiquidColors.accentPurple,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.2),
            color.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 0.5,
        ),
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
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.fileExists)
          _buildActionButton(
            icon: Icons.save_alt_rounded,
            color: LiquidColors.accentBlue,
            onTap: widget.onSave,
          ),
        if (widget.fileExists) const SizedBox(width: 8),
        _buildActionButton(
          icon: Icons.share_rounded,
          color: LiquidColors.success,
          onTap: widget.onShare,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
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
                  color.withOpacity(0.2),
                  color.withOpacity(0.1),
                ],
                center: Alignment.center,
                radius: 0.8,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              onPressed: onTap,
              icon: Icon(
                icon,
                color: color,
                size: 20,
              ),
              padding: EdgeInsets.zero,
            ),
          ),
        );
      },
    );
  }
}
