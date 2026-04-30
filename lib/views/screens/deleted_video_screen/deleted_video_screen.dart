import 'package:flutter/material.dart';
import 'package:video_player_app/views/screens/deleted_video_screen/widgets/view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:intl/intl.dart';

class DeletedVideosScreen extends StatefulWidget {
  final VoidCallback? onVideosChanged;

  const DeletedVideosScreen({
    super.key,
    this.onVideosChanged,
  });

  @override
  State<DeletedVideosScreen> createState() => _DeletedVideosScreenState();
}

class _DeletedVideosScreenState extends State<DeletedVideosScreen>
    with SingleTickerProviderStateMixin {
  List<VideoItem> _deletedVideos = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadDeletedVideos();
    _searchController.addListener(_onSearchChanged);

    // Auto-delete old files after loading
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoDeleteOldFiles();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();
  }

  // Auto-delete files older than 30 days
  Future<void> _autoDeleteOldFiles() async {
    try {
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      bool hasDeleted = false;

      final prefs = await SharedPreferences.getInstance();
      final mediaList = prefs.getStringList('videoLibrary') ?? [];
      final updatedMediaList = <String>[];

      for (final mediaData in mediaList) {
        try {
          final video = VideoItem.fromStorageString(mediaData);

          // Check if video is deleted and old
          if (video.isDeleted && video.deletedDate != null) {
            if (video.deletedDate!.isBefore(thirtyDaysAgo)) {
              // Delete the actual file
              try {
                final file = File(video.path);
                if (await file.exists()) {
                  await file.delete();
                }
              } catch (e) {
                debugPrint('Error deleting file ${video.title}: $e');
              }
              hasDeleted = true;
              continue; // Skip adding to updated list (permanently delete)
            }
          }
          updatedMediaList.add(mediaData);
        } catch (e) {
          debugPrint('Error parsing video: $e');
        }
      }

      if (hasDeleted) {
        await prefs.setStringList('videoLibrary', updatedMediaList);
        await _loadDeletedVideos();

        if (mounted) {
          _showSnackBar(
            'Old files (30+ days) auto-deleted',
            LiquidColors.error,
          );
        }
      }
    } catch (e) {
      debugPrint('Error in auto-delete: $e');
    }
  }

  Future<void> _loadDeletedVideos() async {
    setState(() => _isLoading = true);

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
            debugPrint('Error parsing database video: $e');
          }
        }

        _deletedVideos.sort((a, b) {
          if (a.deletedDate == null) return 1;
          if (b.deletedDate == null) return -1;
          return b.deletedDate!.compareTo(a.deletedDate!);
        });

        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading database videos: $e');
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged() => setState(() {});

  List<VideoItem> get _filteredVideos {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) return _deletedVideos;
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
          final restoredVideo = VideoItem(
            id: parts[0],
            title: parts[1],
            path: parts[2],
            type: parts[3],
            isLocked: parts[4] == 'true',
            category: parts[5],
            isDeleted: false,
            deletedDate: null,
          ).toStorageString();
          updatedMediaList.add(restoredVideo);
        } else {
          updatedMediaList.add(mediaData);
        }
      }

      await prefs.setStringList('videoLibrary', updatedMediaList);

      _showSnackBar('"${video.title}" restored successfully', LiquidColors.success);

      await _loadDeletedVideos();

      if (widget.onVideosChanged != null) {
        widget.onVideosChanged!();
      }
    } catch (e) {
      debugPrint('Error restoring video: $e');
      _showErrorDialog('Failed to restore video');
    }
  }

  Future<void> _permanentDelete(VideoItem video) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mediaList = prefs.getStringList('videoLibrary') ?? [];
      final updatedMediaList = <String>[];

      for (final mediaData in mediaList) {
        final parts = mediaData.split('|');
        if (parts[0] != video.id) {
          updatedMediaList.add(mediaData);
        } else {
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
      _showSnackBar('"${video.title}" permanently deleted', LiquidColors.error);
      await _loadDeletedVideos();

      if (widget.onVideosChanged != null) {
        widget.onVideosChanged!();
      }

    } catch (e) {
      debugPrint('Error deleting video: $e');
      _showErrorDialog('Failed to delete video');
    }
  }

  Future<void> _clearAllDeleted() async {
    if (_deletedVideos.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final mediaList = prefs.getStringList('videoLibrary') ?? [];
      final updatedMediaList = <String>[];

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
      _showSnackBar('Trash emptied successfully', LiquidColors.error);
      await _loadDeletedVideos();

      if (widget.onVideosChanged != null) {
        widget.onVideosChanged!();
      }

    } catch (e) {
      debugPrint('Error clearing database videos: $e');
      _showErrorDialog('Failed to empty trash');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                LiquidColors.backgroundLight,
                LiquidColors.backgroundMid,
              ],
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
                child: const Center(
                  child: Icon(Icons.error, color: LiquidColors.error, size: 30),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Error',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade400,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: LiquidColors.accentBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('OK', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == LiquidColors.success ? Icons.restore : Icons.delete_forever,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showClearAllDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                LiquidColors.backgroundLight,
                LiquidColors.backgroundMid,
              ],
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
                child: const Center(
                  child: Icon(Icons.delete_sweep, color: LiquidColors.error, size: 30),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Empty Trash?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'All ${_deletedVideos.length} deleted files will be permanently removed. This action cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade400,
                  height: 1.5,
                ),
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
                        side: BorderSide(color: Colors.grey.shade700),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: Colors.grey.shade400),
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
                      child: const Text(
                        'Empty Trash',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true) {
      await _clearAllDeleted();
    }
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
        return LiquidColors.accentBlue;
      case 'image':
        return LiquidColors.success;
      case 'audio':
        return LiquidColors.accentPurple;
      case 'document':
        return LiquidColors.accentOrange;
      default:
        return LiquidColors.accentPink;
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
    } else if (difference.inDays < 30) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('dd MMM yyyy').format(date);
    }
  }

  // Get days remaining before auto-delete
  int _getDaysRemaining(DateTime deletedDate) {
    final now = DateTime.now();
    final deleteDate = deletedDate.add(const Duration(days: 30));
    return deleteDate.difference(now).inDays;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                LiquidColors.backgroundDeep,
                LiquidColors.backgroundMid,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        leading: TweenAnimationBuilder(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 600),
          curve: Curves.elasticOut,
          builder: (context, double value, child) {
            return Transform.scale(
              scale: value,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            );
          },
        ),
        title: TweenAnimationBuilder(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 600),
          curve: Curves.elasticOut,
          builder: (context, double value, child) {
            return Transform.scale(
              scale: value,
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LiquidColors.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: LiquidColors.error.withValues(alpha: 0.3),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.delete_outline, color: Colors.white, size: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recycle Bin',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: Colors.white,
                        ),
                      ),
                      if (_deletedVideos.isNotEmpty)
                        Text(
                          'Auto-delete after 30 days',
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
          },
        ),
        actions: [
          if (_deletedVideos.isNotEmpty)
            TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (context, double value, child) {
                return Transform.scale(
                  scale: value,
                  child: IconButton(
                    icon: const Icon(Icons.delete_sweep, color: Colors.white),
                    tooltip: 'Empty Trash',
                    onPressed: _showClearAllDialog,
                  ),
                );
              },
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              LiquidColors.backgroundDeep,
              LiquidColors.backgroundMid,
              LiquidColors.backgroundLight,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              children: [
                _buildSearchBar(),
                if (!_isLoading && _deletedVideos.isNotEmpty) _buildInfoBar(),
                Expanded(
                  child: _isLoading
                      ? _buildLoadingState()
                      : _filteredVideos.isEmpty
                      ? LiquidDeletedEmptyState(
                    hasSearch: _searchController.text.isNotEmpty,
                    onBackPressed: () => Navigator.pop(context),
                  )
                      : _buildList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            LiquidColors.backgroundLight.withValues(alpha: 0.9),
            LiquidColors.backgroundMid.withValues(alpha: 0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: LiquidColors.error.withValues(alpha: 0.1),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TweenAnimationBuilder(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 600),
        curve: Curves.elasticOut,
        builder: (context, double value, child) {
          return Transform.scale(
            scale: value,
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    LiquidColors.backgroundDeep.withValues(alpha: 0.8),
                    LiquidColors.backgroundMid.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: LiquidColors.error.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: LiquidColors.error),
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
                      onPressed: () => _searchController.clear(),
                      icon: Icon(
                        Icons.close,
                        color: LiquidColors.error,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${_filteredVideos.length} ${_filteredVideos.length == 1 ? 'file' : 'files'}',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 12,
            ),
          ),
          if (_searchController.text.isNotEmpty)
            TextButton(
              onPressed: () => _searchController.clear(),
              child: Text(
                'Clear search',
                style: TextStyle(
                  color: LiquidColors.error,
                  fontSize: 12,
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
          TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 800),
            curve: Curves.elasticOut,
            builder: (context, double value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        LiquidColors.error.withValues(alpha: 0.3),
                        LiquidColors.error.withValues(alpha: 0.1),
                      ],
                      center: Alignment.center,
                      radius: 0.8,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: LiquidColors.error,
                      strokeWidth: 3,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            'Loading deleted files...',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _loadDeletedVideos,
      color: LiquidColors.error,
      backgroundColor: LiquidColors.backgroundLight,
      strokeWidth: 2.5,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredVideos.length,
        itemBuilder: (context, index) {
          final video = _filteredVideos[index];
          final daysRemaining = video.deletedDate != null
              ? _getDaysRemaining(video.deletedDate!)
              : 30;

          return LiquidDeletedCard(
            video: video,
            daysRemaining: daysRemaining,
            onRestore: () => _restoreVideo(video),
            onDelete: () => _permanentDelete(video),
            formatDate: _formatDate,
            getIcon: _getMediaIcon,
            getColor: _getMediaColor,
            index: index,
          );
        },
      ),
    );
  }
}