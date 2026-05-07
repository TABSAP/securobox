import 'package:flutter/material.dart';
import '../../utils/liquid_colors.dart';

class _FileKind {
  final String label;
  final IconData icon;
  final Color color;

  const _FileKind(this.label, this.icon, this.color);

  static const _video = _FileKind(
    'Video',
    Icons.movie_outlined,
    LiquidColors.accentBlue,
  );
  static const _audio = _FileKind(
    'Audio',
    Icons.audiotrack_rounded,
    LiquidColors.accentPurple,
  );
  static const _image = _FileKind(
    'Photo',
    Icons.image_outlined,
    LiquidColors.success,
  );
  static const _document = _FileKind(
    'Document',
    Icons.description_outlined,
    LiquidColors.accentOrange,
  );
  static const _archive = _FileKind(
    'Archive',
    Icons.folder_zip_outlined,
    LiquidColors.warning,
  );
  static const _code = _FileKind(
    'Code',
    Icons.code_rounded,
    LiquidColors.accentPink,
  );
  static const _other = _FileKind(
    'File',
    Icons.insert_drive_file_outlined,
    Color(0xFF9CA3AF),
  );

  static _FileKind from(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0) return _other;
    final ext = path.substring(dot + 1).toLowerCase();
    if (const {
      'mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'm4v',
      'mpg', 'mpeg', '3gp', 'webm', 'ts', 'mts', 'm2ts',
    }.contains(ext)) {
      return _video;
    }
    if (const {
      'mp3', 'wav', 'aac', 'flac', 'ogg', 'm4a', 'wma',
      'aiff', 'alac', 'opus', 'mid', 'midi', 'amr', 'ape',
      'ra', 'rm', 'mka', 'm4b', 'm4p', 'ac3', 'dts',
    }.contains(ext)) {
      return _audio;
    }
    if (const {
      'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'tiff', 'tif',
      'svg', 'ico', 'heic', 'heif', 'raw', 'cr2', 'nef', 'arw', 'dng',
    }.contains(ext)) {
      return _image;
    }
    if (const {
      'pdf', 'doc', 'docx', 'txt', 'rtf', 'odt', 'ppt', 'pptx',
      'xls', 'xlsx', 'csv', 'md', 'markdown', 'html', 'htm',
      'epub', 'mobi', 'azw3', 'tex', 'latex', 'xml', 'json', 'yaml', 'yml',
    }.contains(ext)) {
      return _document;
    }
    if (const {
      'zip', 'rar', '7z', 'tar', 'gz', 'bz2', 'xz',
      'iso', 'dmg', 'pkg', 'deb', 'rpm', 'cab',
    }.contains(ext)) {
      return _archive;
    }
    if (const {
      'dart', 'java', 'cpp', 'c', 'h', 'py', 'js', 'ts',
      'php', 'rb', 'go', 'rs', 'swift', 'kt', 'cs',
    }.contains(ext)) {
      return _code;
    }
    return _other;
  }
}

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
    final kind = _FileKind.from(widget.videoPath);

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
                  LiquidColors.backgroundLight.withValues(alpha: 0.9),
                  LiquidColors.backgroundMid.withValues(alpha: 0.95),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: kind.color.withValues(alpha: 0.25),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: kind.color.withValues(alpha: 0.12),
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
                  _buildTypeIcon(kind, isCompleted),
                  const SizedBox(width: 16),
                  Expanded(child: _buildInfoSection(kind, isCompleted)),
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeIcon(_FileKind kind, bool isCompleted) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                kind.color.withValues(alpha: 0.32),
                kind.color.withValues(alpha: 0.10),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: kind.color.withValues(alpha: 0.4),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: kind.color.withValues(alpha: 0.25),
                blurRadius: 12,
                spreadRadius: -2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Icon(kind.icon, color: kind.color, size: 32),
          ),
        ),
        if (isCompleted)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: LiquidColors.success,
                shape: BoxShape.circle,
                border: Border.all(
                  color: LiquidColors.backgroundLight,
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInfoSection(_FileKind kind, bool isCompleted) {
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
              kind.label.toUpperCase(),
              kind.color,
              icon: kind.icon,
              prominent: true,
            ),
            _buildChip(widget.fileSize, LiquidColors.accentBlue),
            _buildChip(_formatDate(widget.date), LiquidColors.accentPurple),
          ],
        ),
      ],
    );
  }

  Widget _buildChip(
    String label,
    Color color, {
    IconData? icon,
    bool prominent = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: prominent ? 9 : 10,
        vertical: prominent ? 5 : 4,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: prominent ? 0.28 : 0.2),
            color.withValues(alpha: prominent ? 0.14 : 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: prominent ? 0.5 : 0.3),
          width: prominent ? 1 : 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: prominent ? FontWeight.w800 : FontWeight.w600,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
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
                  color.withValues(alpha: 0.2),
                  color.withValues(alpha: 0.1),
                ],
                center: Alignment.center,
                radius: 0.8,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: 1,
              ),
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
