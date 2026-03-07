import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../utils/liquid_colors.dart';


class LiquidFileItem extends StatefulWidget {
  final File file;
  final int index;
  final VoidCallback onRemove;
  final String Function(File) getFileType;
  final IconData Function(String) getFileIcon;
  final Color Function(String) getFileColor;

  const LiquidFileItem({
    super.key,
    required this.file,
    required this.index,
    required this.onRemove,
    required this.getFileType,
    required this.getFileIcon,
    required this.getFileColor,
  });

  @override
  State<LiquidFileItem> createState() => _LiquidFileItemState();
}

class _LiquidFileItemState extends State<LiquidFileItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _slideAnimation = Tween<double>(begin: 50, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
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

  String _formatFileSize(File file) {
    try {
      final size = file.lengthSync();
      if (size < 1024) {
        return '${size} B';
      } else if (size < 1024 * 1024) {
        return '${(size / 1024).toStringAsFixed(1)} KB';
      } else {
        return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
    } catch (e) {
      return 'Unknown size';
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileType = widget.getFileType(widget.file);
    final fileColor = widget.getFileColor(fileType);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Transform.translate(
        offset: Offset(0, _slideAnimation.value),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                LiquidColors.backgroundLight.withOpacity(0.9),
                LiquidColors.backgroundMid.withOpacity(0.95),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: fileColor.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: fileColor.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListTile(
            leading: TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (context, double value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          fileColor.withOpacity(0.3),
                          fileColor.withOpacity(0.1),
                        ],
                        center: Alignment.center,
                        radius: 0.8,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: fileColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        widget.getFileIcon(fileType),
                        color: fileColor,
                        size: 24,
                      ),
                    ),
                  ),
                );
              },
            ),
            title: Text(
              p.basename(widget.file.path),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatFileSize(widget.file),
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: fileColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: fileColor.withOpacity(0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    fileType.toUpperCase(),
                    style: TextStyle(
                      color: fileColor,
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            trailing: TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (context, double value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: LiquidColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: LiquidColors.error.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: IconButton(
                      onPressed: widget.onRemove,
                      icon: const Icon(
                        Icons.close_rounded,
                        color: LiquidColors.error,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}