import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/app_models.dart';

class DeletedVideosScreen extends StatefulWidget {
  final VoidCallback? onVideosChanged;

  const DeletedVideosScreen({
    super.key,
    this.onVideosChanged,
  });

  @override
  State<DeletedVideosScreen> createState() => _DeletedVideosScreenState();
}

class _DeletedVideosScreenState extends State<DeletedVideosScreen> {
  List<VideoItem> _deletedVideos = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDeletedVideos();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDeletedVideos() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 300));

      final prefs = await SharedPreferences.getInstance();
      final mediaList = prefs.getStringList('videoLibrary') ?? [];

      setState(() {
        _deletedVideos.clear();

        for (final mediaData in mediaList) {
          try {
            final video = VideoItem.fromStorageString(mediaData);
            if (video.isDeleted) {
              _deletedVideos.add(video);
            }
          } catch (e) {
            debugPrint('Error parsing deleted video: $e');
          }
        }

        // Sort by deletion date (newest first)
        _deletedVideos.sort((a, b) {
          if (a.deletedDate == null) return 1;
          if (b.deletedDate == null) return -1;
          return b.deletedDate!.compareTo(a.deletedDate!);
        });

        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading deleted videos: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    setState(() {});
  }

  List<VideoItem> get _filteredVideos {
    final query = _searchController.text.toLowerCase();

    if (query.isEmpty) {
      return _deletedVideos;
    }

    return _deletedVideos.where((video) {
      return video.title.toLowerCase().contains(query) ||
          video.category.toLowerCase().contains(query) ||
          video.type.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _restoreVideo(VideoItem video) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mediaList = prefs.getStringList('videoLibrary') ?? [];
      final updatedMediaList = <String>[];

      for (final mediaData in mediaList) {
        final parts = mediaData.split('|');
        if (parts[0] == video.id) {
          // Restore this video
          final restoredVideo = VideoItem(
            id: parts[0],
            title: parts[1],
            path: parts[2],
            type: parts[3],
            isLocked: parts[4] == 'true',
            category: parts[5],
            isDeleted: false, // Mark as not deleted
            deletedDate: null, // Clear deletion date
          ).toStorageString();

          updatedMediaList.add(restoredVideo);
        } else {
          updatedMediaList.add(mediaData);
        }
      }

      await prefs.setStringList('videoLibrary', updatedMediaList);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.restore, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    '"${video.title}" restored successfully'),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      // Refresh list
      await _loadDeletedVideos();

      // Notify parent
      if (widget.onVideosChanged != null) {
        widget.onVideosChanged!();
      }
    } catch (e) {
      debugPrint('Error restoring video: $e');
      _showErrorDialog('Failed to restore video');
    }
  }

  Future<void> _permanentDelete(VideoItem video) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A3E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            const Icon(Icons.delete_forever, color: Colors.red),
            const SizedBox(width: 8),
            Text(
              'Delete Forever?',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Text(
          '"${video.title}" will be permanently deleted. This action cannot be undone.',
          style: TextStyle(color: Colors.grey.shade400),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final mediaList = prefs.getStringList('videoLibrary') ?? [];
        final updatedMediaList = <String>[];

        // Remove the video completely
        for (final mediaData in mediaList) {
          final parts = mediaData.split('|');
          if (parts[0] != video.id) {
            updatedMediaList.add(mediaData);
          } else {
            // Also delete the file from storage
            try {
              final file = File(video.path);
              if (await file.exists()) {
                await file.delete();
              }
            } catch (e) {
              debugPrint('Error deleting file: $e');
            }
          }
        }

        await prefs.setStringList('videoLibrary', updatedMediaList);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${video.title}" permanently deleted'),
            backgroundColor: Colors.red,
          ),
        );

        // Refresh list
        await _loadDeletedVideos();

      } catch (e) {
        debugPrint('Error deleting video: $e');
        _showErrorDialog('Failed to delete video');
      }
    }
  }

  Future<void> _clearAllDeleted() async {
    if (_deletedVideos.isEmpty) return;

    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A3E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            const Icon(Icons.delete_sweep, color: Colors.red),
            const SizedBox(width: 8),
            Text(
              'Empty Trash?',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Text(
          'All ${_deletedVideos.length} deleted videos will be permanently removed. This action cannot be undone.',
          style: TextStyle(color: Colors.grey.shade400),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Empty Trash'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final mediaList = prefs.getStringList('videoLibrary') ?? [];
        final updatedMediaList = <String>[];

        // Delete all files from storage first
        for (final video in _deletedVideos) {
          try {
            final file = File(video.path);
            if (await file.exists()) {
              await file.delete();
            }
          } catch (e) {
            debugPrint('Error deleting file ${video.title}: $e');
          }
        }

        // Keep only non-deleted videos
        for (final mediaData in mediaList) {
          try {
            final video = VideoItem.fromStorageString(mediaData);
            if (!video.isDeleted) {
              updatedMediaList.add(mediaData);
            }
          } catch (e) {
            debugPrint('Error parsing video: $e');
          }
        }

        await prefs.setStringList('videoLibrary', updatedMediaList);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Trash emptied successfully'),
            backgroundColor: Colors.red,
          ),
        );

        // Refresh list
        await _loadDeletedVideos();

      } catch (e) {
        debugPrint('Error clearing deleted videos: $e');
        _showErrorDialog('Failed to empty trash');
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A3E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 8),
            Text(
              'Error',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(color: Colors.grey.shade400),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoCard(VideoItem video, int index) {
    final iconData = _getMediaIcon(video.type);
    final iconColor = _getMediaColor(video.type);
    final isLocked = video.isLocked;

    return Dismissible(
      key: Key('${video.id}_$index'),
      direction: DismissDirection.horizontal,
      background: Container(
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: Row(
          children: [
            const Icon(Icons.restore, color: Colors.white, size: 28),
            const SizedBox(width: 10),
            const Text(
              'Restore',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.delete_forever, color: Colors.white, size: 28),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await _restoreVideo(video);
          return false;
        } else {
          bool confirm = await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1A1A3E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Delete Permanently?',
                style: TextStyle(color: Colors.white),
              ),
              content: Text(
                'Delete "${video.title}" permanently?',
                style: TextStyle(color: Colors.grey.shade400),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );

          if (confirm) {
            await _permanentDelete(video);
          }
          return false;
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: const Color(0xFF1A1A3E),
          borderRadius: BorderRadius.circular(16),
          elevation: 0,
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
                // Media Icon
                Container(
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
                        iconColor.withOpacity(0.2),
                        iconColor.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isLocked
                          ? Colors.orange.withOpacity(0.3)
                          : iconColor.withOpacity(0.3),
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
                ),
                const SizedBox(width: 16),
                // Media Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        style: TextStyle(
                          color: isLocked ? Colors.orange : Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      // Deletion Info
                      if (video.deletedDate != null)
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Deleted ${_formatDate(video.deletedDate!)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        children: [
                          // Type Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: iconColor.withValues(alpha: .1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              video.type.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: iconColor,
                              ),
                            ),
                          ),
                          // Category Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: .1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              video.category,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Action Buttons
                Column(
                  children: [
                    // Restore Button
                    Container(
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
                      child: IconButton(
                        onPressed: () => _restoreVideo(video),
                        icon: const Icon(
                          Icons.restore,
                          color: Colors.green,
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        tooltip: 'Restore',
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Delete Button
                    Container(
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
                        onPressed: () => _permanentDelete(video),
                        icon: const Icon(
                          Icons.delete_forever,
                          color: Colors.red,
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        tooltip: 'Delete Forever',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A3E),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: .1),
                width: 1,
              ),
            ),
            child: Center(
              child: Icon(
                _searchController.text.isNotEmpty
                    ? Icons.search_off_rounded
                    : Icons.delete_outline_rounded,
                size: 50,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _searchController.text.isNotEmpty
                ? 'No Deleted Files Found'
                : 'Trash is Empty',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _searchController.text.isNotEmpty
                ? 'Try a different search term'
                : 'Deleted files will appear here',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to Library'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4788FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: Color(0xFF4788FF),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading deleted videos...',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getMediaIcon(String type) {
    switch (type) {
      case 'video':
        return Icons.video_library_rounded;
      case 'image':
        return Icons.image_rounded;
      case 'audio':
        return Icons.music_note_rounded;
      case 'document':
        return Icons.description_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color _getMediaColor(String type) {
    switch (type) {
      case 'video':
        return const Color(0xFF4788FF);
      case 'image':
        return const Color(0xFF00C853);
      case 'audio':
        return const Color(0xFF9C27B0);
      case 'document':
        return const Color(0xFFFF9800);
      default:
        return const Color(0xFF607D8B);
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('dd MMM yyyy').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A3E),
      appBar: AppBar(
        title: const Text(
          'Recycle Bin',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1A1A3E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back,color: Colors.white,),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_deletedVideos.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep,color: Colors.white,),
              tooltip: 'Empty Trash',
              onPressed: _clearAllDeleted,
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF141432),
            child: Container(
              height: 45,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A3E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: .1),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search deleted files...',
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      onPressed: () {
                        _searchController.clear();
                      },
                      icon: Icon(
                        Icons.close,
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
          ),
          // File Count
          if (!_isLoading && _deletedVideos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_filteredVideos.length} deleted ${_filteredVideos.length == 1 ? 'file' : 'files'}',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        _searchController.clear();
                      },
                      child: Text(
                        'Clear search',
                        style: TextStyle(
                          color: const Color(0xFF4788FF),
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          // List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadDeletedVideos,
              color: const Color(0xFF4788FF),
              backgroundColor: const Color(0xFF1A1A3E),
              child: _isLoading
                  ? _buildLoadingState()
                  : _filteredVideos.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _filteredVideos.length,
                itemBuilder: (context, index) {
                  return _buildVideoCard(_filteredVideos[index], index);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}