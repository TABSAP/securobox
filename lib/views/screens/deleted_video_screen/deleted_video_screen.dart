import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player_app/widgets/app_loader.dart';
import 'package:video_player_app/widgets/app_spacing.dart';
import 'package:video_player_app/widgets/vault_thumbnail.dart';
import 'package:video_player_app/utils/responsive.dart';
import 'package:video_player_app/history_screen/widgets/view.dart';
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

  // Multi-select state: long-press a card to enter selection mode, then tap
  // cards to toggle. Bulk restore / permanent-delete act on the selection.
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadDeletedVideos();
    _searchController.addListener(_onSearchChanged);

    // _autoDeleteOldFiles surfaces a FlushBar (an overlay route), so it must
    // never run during build, nor after this screen is disposed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _autoDeleteOldFiles();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _animationController.dispose();

    super.dispose();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
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

  // ---- Multi-select ---------------------------------------------------------

  bool get _allSelected =>
      _filteredVideos.isNotEmpty &&
      _filteredVideos.every((v) => _selectedIds.contains(v.id));

  void _enterSelection(VideoItem video) {
    HapticFeedback.mediumImpact();
    setState(() {
      _selectionMode = true;
      _selectedIds.add(video.id);
    });
  }

  void _toggleSelect(VideoItem video) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedIds.remove(video.id)) {
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(video.id);
      }
    });
  }

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelectAll() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_allSelected) {
        _selectedIds.clear();
        _selectionMode = false;
      } else {
        _selectedIds.addAll(_filteredVideos.map((v) => v.id));
        _selectionMode = true;
      }
    });
  }

  Future<void> _restoreSelected() async {
    if (_selectedIds.isEmpty) return;
    HapticFeedback.lightImpact();
    final ids = Set<String>.from(_selectedIds);
    try {
      final prefs = await SharedPreferences.getInstance();
      final mediaList =
          prefs.getStringList(VaultContext.instance.libraryKey) ?? [];
      final updatedMediaList = <String>[];

      for (final mediaData in mediaList) {
        try {
          final v = VideoItem.fromStorageString(mediaData);
          if (ids.contains(v.id)) {
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
        '${ids.length} ${ids.length == 1 ? "file" : "files"} restored',
        context,
      );
      _exitSelection();
      await _loadDeletedVideos();
      widget.onVideosChanged?.call();
    } catch (e) {
      _showErrorDialog('Failed to restore files');
    }
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final ids = Set<String>.from(_selectedIds);
    final confirmed = await _confirmDeleteForever(
      'Delete ${ids.length} ${ids.length == 1 ? "file" : "files"} forever?',
      'The selected ${ids.length == 1 ? "file" : "files"} will be permanently '
          'deleted from your vault. This cannot be undone.',
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
          if (ids.contains(v.id)) {
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
        '${ids.length} ${ids.length == 1 ? "file" : "files"} permanently deleted',
        context,
      );
      _exitSelection();
      await _loadDeletedVideos();
      widget.onVideosChanged?.call();
    } catch (e) {
      _showErrorDialog('Failed to delete files');
    }
  }

  // ---------------------------------------------------------------------------

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
            color: LiquidColors.backgroundLight,
            borderRadius: BorderRadius.circular(AppRadius.xl),
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
                  color: LiquidColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
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
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        side: BorderSide(color: LiquidColors.cardBorder),
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
                          borderRadius: BorderRadius.circular(AppRadius.sm),
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
            color: LiquidColors.backgroundLight,
            borderRadius: BorderRadius.circular(AppRadius.xl),
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
                  color: LiquidColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Center(
                  child: Icon(
                    Icons.error_outline_rounded,
                    color: LiquidColors.error,
                    size: 30,
                  ),
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
                  backgroundColor: LiquidColors.indigo,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
                child: const Text(
                  'OK',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showClearAllDialog() async {
    HapticFeedback.lightImpact();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: LiquidColors.backgroundLight,
            borderRadius: BorderRadius.circular(AppRadius.xl),
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
                  color: LiquidColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Center(
                  child: Icon(
                    Icons.delete_sweep_rounded,
                    color: LiquidColors.error,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Empty Recycle Bin?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
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
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        side: BorderSide(color: LiquidColors.cardBorder),
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
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                      ),
                      child: const Text(
                        'Empty Bin',
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
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

  Color _daysColor(int days) {
    if (days <= 5) return LiquidColors.error;
    if (days <= 15) return LiquidColors.warning;
    return LiquidColors.success;
  }

  @override
  Widget build(BuildContext context) {
    final inset = context.contentInset(phone: AppSpace.md);
    return PopScope(
      canPop: !_selectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exitSelection();
      },
      child: Scaffold(
        backgroundColor: LiquidColors.backgroundDeep,
        appBar: _selectionMode ? _buildSelectionAppBar() : _buildDefaultAppBar(),
        body: SafeArea(
          top: false,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(inset, 0, inset, AppSpace.sm),
                    child: _buildSearchBar(),
                  ),
                  if (!_isLoading && _deletedVideos.isNotEmpty)
                    _buildInfoBar(inset),
                  Expanded(
                    child: _isLoading
                        ? _buildLoadingState()
                        : _filteredVideos.isEmpty
                        ? _buildEmptyState(
                            hasSearch: _searchController.text.isNotEmpty,
                          )
                        : _buildList(inset),
                  ),
                  if (_selectionMode) _buildSelectionActionBar(inset),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildDefaultAppBar() {
    return AppBar(
      backgroundColor: LiquidColors.backgroundDeep,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: LiquidColors.systemOverlayStyle,
      titleSpacing: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_rounded, color: LiquidColors.textPrimary),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Recycle Bin',
        style: TextStyle(
          color: LiquidColors.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
      actions: [
        if (_deletedVideos.isNotEmpty) ...[
          Tooltip(
            message: 'Select',
            child: IconButton(
              icon: Icon(
                Icons.checklist_rounded,
                color: LiquidColors.textPrimary,
              ),
              onPressed: () {
                if (_filteredVideos.isNotEmpty) {
                  _enterSelection(_filteredVideos.first);
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Tooltip(
              message: 'Empty bin',
              child: IconButton(
                icon: Icon(
                  Icons.delete_sweep_rounded,
                  color: LiquidColors.error,
                ),
                onPressed: _showClearAllDialog,
              ),
            ),
          ),
        ],
      ],
    );
  }

  PreferredSizeWidget _buildSelectionAppBar() {
    return AppBar(
      backgroundColor: LiquidColors.backgroundDeep,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: LiquidColors.systemOverlayStyle,
      titleSpacing: 0,
      leading: IconButton(
        icon: Icon(Icons.close_rounded, color: LiquidColors.textPrimary),
        onPressed: _exitSelection,
      ),
      title: Text(
        '${_selectedIds.length} selected',
        style: TextStyle(
          color: LiquidColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: TextButton(
            onPressed: _toggleSelectAll,
            child: Text(
              _allSelected ? 'Clear' : 'All',
              style: TextStyle(
                color: LiquidColors.indigo,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionActionBar(double inset) {
    final count = _selectedIds.length;
    final enabled = count > 0;
    return Container(
      padding: EdgeInsets.fromLTRB(inset, AppSpace.sm, inset, AppSpace.sm),
      decoration: BoxDecoration(
        color: LiquidColors.backgroundDeep,
        border: Border(top: BorderSide(color: LiquidColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: _buildBarButton(
                icon: Icons.restore_rounded,
                label: 'Restore',
                color: LiquidColors.indigo,
                enabled: enabled,
                onTap: _restoreSelected,
              ),
            ),
            const SizedBox(width: AppSpace.sm + 2),
            Expanded(
              child: _buildBarButton(
                icon: Icons.delete_forever_rounded,
                label: 'Delete',
                color: LiquidColors.error,
                enabled: enabled,
                onTap: _deleteSelected,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Material(
      color: enabled
          ? color.withValues(alpha: 0.12)
          : LiquidColors.surfaceMuted,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: enabled ? color : LiquidColors.textTertiary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: enabled ? color : LiquidColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      style: TextStyle(color: LiquidColors.textPrimary, fontSize: 15),
      cursorColor: LiquidColors.indigo,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: LiquidColors.surfaceMuted,
        hintText: 'Search deleted files',
        hintStyle: TextStyle(color: LiquidColors.textTertiary, fontSize: 15),
        prefixIcon: Icon(
          Icons.search_rounded,
          color: LiquidColors.textTertiary,
          size: 20,
        ),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  color: LiquidColors.textTertiary,
                  size: 20,
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  _searchController.clear();
                  FocusScope.of(context).unfocus();
                },
              ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: LiquidColors.indigo, width: 1.4),
        ),
      ),
    );
  }

  Widget _buildInfoBar(double inset) {
    final count = _filteredVideos.length;
    return Padding(
      padding: EdgeInsets.fromLTRB(inset, 0, inset, AppSpace.sm),
      child: Row(
        children: [
          Text(
            '$count ${count == 1 ? 'file' : 'files'}',
            style: TextStyle(
              color: LiquidColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Icon(
            Icons.schedule_rounded,
            size: 14,
            color: LiquidColors.textTertiary,
          ),
          const SizedBox(width: 5),
          Text(
            'Auto-deletes after 30 days',
            style: TextStyle(color: LiquidColors.textTertiary, fontSize: 12),
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
          const AppLoader(size: 56),
          const SizedBox(height: AppSpace.md),
          Text(
            'Loading deleted files…',
            style: TextStyle(color: LiquidColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({required bool hasSearch}) {
    final accent = hasSearch ? LiquidColors.indigo : LiquidColors.error;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasSearch
                    ? Icons.search_off_rounded
                    : Icons.delete_outline_rounded,
                color: accent,
                size: 42,
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            Text(
              hasSearch ? 'No matching files' : 'Recycle Bin is empty',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: LiquidColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              hasSearch
                  ? 'Try a different search term.'
                  : 'Deleted files appear here and are kept for 30 days before they are removed for good.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: LiquidColors.textSecondary,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            if (!hasSearch) ...[
              const SizedBox(height: AppSpace.lg),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Back to Library',
                  style: TextStyle(
                    color: LiquidColors.indigo,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildList(double inset) {
    final videos = _filteredVideos;
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        inset,
        AppSpace.xs,
        inset,
        AppSpace.xl + 40,
      ),
      itemCount: videos.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpace.sm + 2),
      itemBuilder: (context, index) => _buildCard(videos[index]),
    );
  }

  Widget _buildCard(VideoItem video) {
    final deletedDate = video.deletedDate;
    final daysRemaining = deletedDate != null
        ? _getDaysRemaining(deletedDate)
        : 30;
    final daysColor = _daysColor(daysRemaining);
    final isLocked = video.isLocked;
    final selected = _selectedIds.contains(video.id);

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      padding: const EdgeInsets.all(AppSpace.sm + 2),
      decoration: BoxDecoration(
        color: selected
            ? LiquidColors.indigo.withValues(alpha: 0.10)
            : LiquidColors.backgroundLight.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: selected ? LiquidColors.indigo : LiquidColors.cardBorder,
          width: selected ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          VaultThumbnail(
            item: video,
            width: 54,
            height: 54,
            radius: 14,
            iconSize: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  video.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: LiquidColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  deletedDate != null
                      ? 'Deleted ${_formatDate(deletedDate)}  ·  ${video.category}'
                      : video.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: LiquidColors.textTertiary,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    _buildStatusPill(
                      icon: isLocked
                          ? Icons.lock_outline_rounded
                          : (daysRemaining <= 5
                                ? Icons.warning_amber_rounded
                                : Icons.schedule_rounded),
                      label: isLocked
                          ? 'Locked'
                          : (daysRemaining <= 0
                                ? 'Removes today'
                                : '$daysRemaining ${daysRemaining == 1 ? 'day' : 'days'} left'),
                      color: isLocked ? LiquidColors.warning : daysColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          if (_selectionMode)
            _buildCheckIndicator(selected)
          else
            Column(
              children: [
                _buildActionButton(
                  icon: Icons.restore_rounded,
                  color: LiquidColors.indigo,
                  tooltip: 'Restore',
                  onTap: () => _confirmRestore(video),
                ),
                const SizedBox(height: AppSpace.sm),
                _buildActionButton(
                  icon: Icons.delete_forever_rounded,
                  color: LiquidColors.error,
                  tooltip: 'Delete forever',
                  onTap: () => _permanentDelete(video),
                ),
              ],
            ),
        ],
      ),
    );

    // In selection mode: tap toggles, swipe is disabled. Otherwise: long-press
    // enters selection, and swipe restores / deletes as before.
    if (_selectionMode) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _toggleSelect(video),
        onLongPress: () => _toggleSelect(video),
        child: card,
      );
    }

    return Dismissible(
      key: Key('deleted_${video.id}'),
      direction: DismissDirection.horizontal,
      background: _buildSwipeBackground(isRestore: true),
      secondaryBackground: _buildSwipeBackground(isRestore: false),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await _confirmRestore(video);
        } else {
          await _permanentDelete(video);
        }
        return false;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: () => _enterSelection(video),
        child: card,
      ),
    );
  }

  Widget _buildCheckIndicator(bool selected) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: selected ? LiquidColors.indigo : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? LiquidColors.indigo : LiquidColors.cardBorder,
          width: 1.6,
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
          : null,
    );
  }

  Widget _buildStatusPill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: color.withValues(alpha: 0.22)),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildSwipeBackground({required bool isRestore}) {
    final color = isRestore ? LiquidColors.indigo : LiquidColors.error;
    final icon = isRestore
        ? Icons.restore_rounded
        : Icons.delete_forever_rounded;
    final text = isRestore ? 'Restore' : 'Delete';

    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      alignment: isRestore ? Alignment.centerLeft : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isRestore) ...[
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ] else ...[
            Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Icon(icon, color: color, size: 24),
          ],
        ],
      ),
    );
  }
}
