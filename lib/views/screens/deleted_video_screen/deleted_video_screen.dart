import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player_app/history_screen/widgets/view.dart';
import 'package:video_player_app/utils/liquid_circular_progress.dart';
import 'package:video_player_app/utils/vault_context.dart';
import 'package:video_player_app/utils/vault_crypto.dart';
import 'package:video_player_app/views/screens/deleted_video_screen/widgets/view.dart';

class DeletedVideosScreen extends StatefulWidget {
  final VoidCallback? onVideosChanged;

  const DeletedVideosScreen({super.key, this.onVideosChanged});

  @override
  State<DeletedVideosScreen> createState() => _DeletedVideosScreenState();
}

class _DeletedVideosScreenState extends State<DeletedVideosScreen>
    with SingleTickerProviderStateMixin {
  final List<VideoItem> _deletedVideos = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadDeletedVideos();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onSearchChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoDeleteOldFiles();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.removeListener(_onSearchChanged);
    _searchFocusNode.dispose();
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
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _animationController.forward();
  }

  Future<void> _autoDeleteOldFiles() async {
    try {
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      bool hasHidden = false;

      final prefs = await SharedPreferences.getInstance();
      final mediaList =
          prefs.getStringList(VaultContext.instance.libraryKey) ?? [];
      final updatedMediaList = <String>[];

      for (final mediaData in mediaList) {
        try {
          final video = VideoItem.fromStorageString(mediaData);

          if (video.isDeleted &&
              !video.isHidden &&
              video.deletedDate != null &&
              video.deletedDate!.isBefore(thirtyDaysAgo)) {
            video.isHidden = true;
            updatedMediaList.add(video.toStorageString());
            hasHidden = true;
          } else {
            updatedMediaList.add(mediaData);
          }
        } catch (e) {
          updatedMediaList.add(mediaData);
        }
      }

      if (hasHidden) {
        await prefs.setStringList(
          VaultContext.instance.libraryKey,
          updatedMediaList,
        );
        await _loadDeletedVideos();

        if (mounted) {
          FlushBarHelper.flushBarErrorMessage(
            'Old files (30+ days) hidden — recoverable via email',
            context,
          );
        }
      }
    } on Object catch (_) { /* ignored */ }
  }

  Future<void> _loadDeletedVideos() async {
    setState(() => _isLoading = true);

    try {
      await Future.delayed(const Duration(milliseconds: 300));
      final prefs = await SharedPreferences.getInstance();
      final mediaList =
          prefs.getStringList(VaultContext.instance.libraryKey) ?? [];

      setState(() {
        _deletedVideos.clear();

        for (final mediaData in mediaList) {
          try {
            final video = VideoItem.fromStorageString(mediaData);
            if (video.isDeleted && !video.isHidden) {
              _deletedVideos.add(video);
            }
          } on Object catch (_) { /* ignored */ }
        }

        _deletedVideos.sort((a, b) {
          if (a.deletedDate == null) return 1;
          if (b.deletedDate == null) return -1;
          return b.deletedDate!.compareTo(a.deletedDate!);
        });

        _isLoading = false;
      });
    } catch (e) {
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

  Future<void> _confirmRestore(VideoItem video) async {
    await _restoreVideo(video);
  }

  Future<void> _restoreVideo(VideoItem video) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mediaList =
          prefs.getStringList(VaultContext.instance.libraryKey) ?? [];
      final updatedMediaList = <String>[];

      for (final mediaData in mediaList) {
        try {
          final v = VideoItem.fromStorageString(mediaData);
          if (v.id == video.id) {
            v.isDeleted = false;
            v.deletedDate = null;
            v.isHidden = false;
            updatedMediaList.add(v.toStorageString());
          } else {
            updatedMediaList.add(mediaData);
          }
        } catch (e) {
          updatedMediaList.add(mediaData);
        }
      }

      await prefs.setStringList(
        VaultContext.instance.libraryKey,
        updatedMediaList,
      );
      if (!mounted) return;
      FlushBarHelper.flushBarSuccessMessage(
        '"${video.title}" restored successfully',
        context,
      );
      await _loadDeletedVideos();

      if (widget.onVideosChanged != null) {
        widget.onVideosChanged!();
      }
    } catch (e) {
      _showErrorDialog('Failed to restore video');
    }
  }

  Future<bool?> _confirmDeleteForever(String title, String body) {
    return showDialog<bool>(
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
                child: Center(
                  child: Icon(
                    Icons.delete_forever_rounded,
                    color: LiquidColors.error,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: LiquidColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                body,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: LiquidColors.textSecondary,
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
                      child: const Text(
                        'Delete',
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
  }

  Future<void> _permanentDelete(VideoItem video) async {
    final confirmed = await _confirmDeleteForever(
      'Delete forever?',
      '"${video.title}" will be permanently deleted from your vault. '
          'This cannot be undone.',
    );
    if (confirmed != true || !mounted) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final mediaList =
          prefs.getStringList(VaultContext.instance.libraryKey) ?? [];
      final updatedMediaList = <String>[];

      for (final mediaData in mediaList) {
        try {
          final v = VideoItem.fromStorageString(mediaData);
          if (v.id == video.id) {
            await VaultCrypto.instance.deleteEncryptedFile(v.path);
          } else {
            updatedMediaList.add(mediaData);
          }
        } catch (e) {
          updatedMediaList.add(mediaData);
        }
      }

      await prefs.setStringList(
        VaultContext.instance.libraryKey,
        updatedMediaList,
      );
      if (!mounted) return;
      FlushBarHelper.flushBarSuccessMessage(
        '"${video.title}" permanently deleted',
        context,
      );
      await _loadDeletedVideos();

      if (widget.onVideosChanged != null) {
        widget.onVideosChanged!();
      }
    } catch (e) {
      _showErrorDialog('Failed to delete file');
    }
  }

  Future<void> _clearAllDeleted() async {
    if (_deletedVideos.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final mediaList =
          prefs.getStringList(VaultContext.instance.libraryKey) ?? [];
      final updatedMediaList = <String>[];

      int removed = 0;
      for (final mediaData in mediaList) {
        try {
          final v = VideoItem.fromStorageString(mediaData);
          if (v.isDeleted && !v.isHidden) {
            await VaultCrypto.instance.deleteEncryptedFile(v.path);
            removed++;
          } else {
            updatedMediaList.add(mediaData);
          }
        } catch (e) {
          if (kDebugMode) {
          }
          updatedMediaList.add(mediaData);
        }
      }

      await prefs.setStringList(
        VaultContext.instance.libraryKey,
        updatedMediaList,
      );
      if (!mounted) return;
      FlushBarHelper.flushBarSuccessMessage(
        '$removed ${removed == 1 ? "file" : "files"} permanently deleted',
        context,
      );
      await _loadDeletedVideos();

      if (widget.onVideosChanged != null) {
        widget.onVideosChanged!();
      }
    } catch (e) {
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
                child: Center(
                  child: Icon(Icons.error, color: LiquidColors.error, size: 30),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Error',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: LiquidColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: LiquidColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: LiquidColors.accentBlue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'OK',
                  style: TextStyle(color: LiquidColors.textPrimary),
                ),
              ),
            ],
          ),
        ),
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
                child: Center(
                  child: Icon(
                    Icons.delete_sweep,
                    color: LiquidColors.error,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Empty Trash?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: LiquidColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'All ${_deletedVideos.length} files will be permanently deleted from your vault. This cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: LiquidColors.textSecondary,
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
              colors: [LiquidColors.backgroundDeep, LiquidColors.backgroundMid],
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
                icon: Icon(Icons.arrow_back, color: LiquidColors.textPrimary),
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
                mainAxisSize: MainAxisSize.min,
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
                    child: Center(
                      child: Icon(
                        Icons.delete_outline,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recycle Bin',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: LiquidColors.textPrimary,
                          ),
                        ),
                        if (_deletedVideos.isNotEmpty)
                          Text(
                            'Auto-delete after 30 days',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: LiquidColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
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
                    icon: Icon(
                      Icons.delete_sweep,
                      color: LiquidColors.textPrimary,
                    ),
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
    final hasQuery = _searchController.text.isNotEmpty;
    final active = hasQuery || _searchFocusNode.hasFocus;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: LiquidColors.textPrimary.withValues(
            alpha: active ? 0.07 : 0.05,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              color: active ? LiquidColors.error : LiquidColors.textTertiary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                textInputAction: TextInputAction.search,
                style: TextStyle(
                  color: LiquidColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                cursorColor: LiquidColors.error,
                decoration: InputDecoration(
                  hintText: 'Search deleted files',
                  hintStyle: TextStyle(
                    color: LiquidColors.textTertiary,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: ScaleTransition(scale: anim, child: child),
              ),
              child: hasQuery
                  ? GestureDetector(
                      key: const ValueKey('clear'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _searchController.clear();
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Icon(
                          Icons.close_rounded,
                          color: LiquidColors.textTertiary,
                          size: 18,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('empty')),
            ),
          ],
        ),
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
            style: TextStyle(color: LiquidColors.textSecondary, fontSize: 12),
          ),
          if (_searchController.text.isNotEmpty)
            TextButton(
              onPressed: () => _searchController.clear(),
              child: Text(
                'Clear search',
                style: TextStyle(color: LiquidColors.error, fontSize: 12),
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
                child: LiquidCircularProgress(
                  size: 96,
                  strokeWidth: 6,
                  colors: [
                    LiquidColors.error,
                    LiquidColors.accentOrange,
                    LiquidColors.warning,
                  ],
                  glowColor: LiquidColors.error,
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            'Loading deleted files...',
            style: TextStyle(color: LiquidColors.textSecondary, fontSize: 14),
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
            onRestore: () => _confirmRestore(video),
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
