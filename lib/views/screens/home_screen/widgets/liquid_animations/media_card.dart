import 'package:flutter/material.dart';
import '../../../../../models/app_models.dart';

import '../../../../../utils/media_helper.dart';

class MediaCard extends StatelessWidget {
  final VideoItem media;
  final VoidCallback? onTap;
  final VoidCallback? onCategoryTap;
  final VoidCallback? onLockTap;
  final VoidCallback? onDownloadTap;
  final VoidCallback? onDeleteTap;
  final Function(String)? onCategorySelected;
  final List<String> categories;

  const MediaCard({
    super.key,
    required this.media,
    this.onTap,
    this.onCategoryTap,
    this.onLockTap,
    this.onDownloadTap,
    this.onDeleteTap,
    this.onCategorySelected,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    final iconData = MediaHelper.getMediaIcon(media.type);
    final iconColor = MediaHelper.getMediaColor(media.type);
    final isLocked = media.isLocked;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: const Color(0xFF1A1A3E),
        borderRadius: BorderRadius.circular(16),
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: .05),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                _buildThumbnail(iconData, iconColor, isLocked),
                const SizedBox(width: 16),
                _buildInfo(media, isLocked, iconColor),
                _buildActions(context, isLocked, iconColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(IconData iconData, Color iconColor, bool isLocked) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isLocked
              ? [
            Colors.orange.withValues(alpha: .2),
            Colors.orange.withValues(alpha: .1),
          ]
              : [
            iconColor.withValues(alpha: .2),
            iconColor.withValues(alpha: .1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLocked
              ? Colors.orange.withValues(alpha: .3)
              : iconColor.withValues(alpha: .3),
          width: 1,
        ),
      ),
      child: Center(
        child: Icon(
          isLocked ? Icons.lock_outline_rounded : iconData,
          color: isLocked ? Colors.orange : iconColor,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildInfo(VideoItem media, bool isLocked, Color iconColor) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            media.title,
            style: TextStyle(
              color: isLocked ? Colors.orange : Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _buildTypeChip(media, isLocked, iconColor),
              if (!isLocked) _buildCategoryChip(media),
              if (isLocked) _buildLockedChip(),
              Text(
                MediaHelper.formatDate(media.id),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(VideoItem media, bool isLocked, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isLocked
            ? Colors.orange.withValues(alpha: .1)
            : iconColor.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isLocked
              ? Colors.orange.withValues(alpha: .3)
              : iconColor.withValues(alpha: .3),
          width: 1,
        ),
      ),
      child: Text(
        media.type.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isLocked ? Colors.orange : iconColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCategoryChip(VideoItem media) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.green.withValues(alpha: .3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.category, size: 10, color: Colors.green),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              media.category,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.green,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.orange.withValues(alpha: .3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_rounded, size: 10, color: Colors.orange),
          const SizedBox(width: 4),
          Text(
            'Locked',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, bool isLocked, Color iconColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isLocked) _buildCategoryButton(context),
        if (!isLocked) const SizedBox(width: 8),
        _buildLockButton(isLocked),
        const SizedBox(width: 8),
        Column(
          children: [
            _buildDownloadButton(context, isLocked, iconColor),
            const SizedBox(height: 7),
            _buildDeleteButton(context, isLocked),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryButton(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onCategorySelected,
      itemBuilder: (context) => categories
          .where((c) => c != "All")
          .map((category) => PopupMenuItem(
        value: category,
        child: Row(
          children: [
            Icon(
              Icons.category,
              size: 18,
              color: const Color(0xFF4788FF),
            ),
            const SizedBox(width: 8),
            Text(category),
          ],
        ),
      ))
          .toList(),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.green.withValues(alpha: .3),
            width: 1,
          ),
        ),
        child: const Center(
          child: Icon(
            Icons.category,
            color: Colors.green,
            size: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildLockButton(bool isLocked) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isLocked
            ? Colors.orange.withValues(alpha: .1)
            : Colors.white.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isLocked
              ? Colors.orange.withValues(alpha: .3)
              : Colors.white.withValues(alpha: .1),
          width: 1,
        ),
      ),
      child: IconButton(
        onPressed: onLockTap,
        icon: Icon(
          isLocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
          color: isLocked ? Colors.orange : Colors.white,
          size: 20,
        ),
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildDownloadButton(BuildContext context, bool isLocked, Color iconColor) {
    if (!isLocked) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF4788FF).withValues(alpha: .1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF4788FF).withValues(alpha: .3),
            width: 1,
          ),
        ),
        child: IconButton(
          onPressed: onDownloadTap,
          icon: const Icon(
            Icons.download_rounded,
            color: Color(0xFF4788FF),
            size: 20,
          ),
          padding: EdgeInsets.zero,
        ),
      );
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.grey.withValues(alpha: .3),
          width: 1,
        ),
      ),
      child: IconButton(
        onPressed: onDownloadTap,
        icon: Icon(
          Icons.download_rounded,
          color: Colors.grey.withValues(alpha: .5),
          size: 20,
        ),
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildDeleteButton(BuildContext context, bool isLocked) {
    if (!isLocked) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.red.withValues(alpha: .3),
            width: 1,
          ),
        ),
        child: IconButton(
          onPressed: onDeleteTap,
          icon: const Icon(
            Icons.delete_outline_rounded,
            color: Colors.red,
            size: 20,
          ),
          padding: EdgeInsets.zero,
        ),
      );
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.grey.withValues(alpha: .3),
          width: 1,
        ),
      ),
      child: IconButton(
        onPressed: onDeleteTap,
        icon: Icon(
          Icons.delete_outline_rounded,
          color: Colors.grey.withValues(alpha: .5),
          size: 20,
        ),
        padding: EdgeInsets.zero,
      ),
    );
  }
}