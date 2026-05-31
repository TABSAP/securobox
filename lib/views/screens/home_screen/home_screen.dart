import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_app/utils/liquid_circular_progress.dart';
import 'package:video_player_app/utils/responsive.dart';
import 'package:video_player_app/utils/pin_crypto.dart';
import 'package:video_player_app/utils/vault_context.dart';
import 'package:video_player_app/views/screens/secure_camera/secure_camera_screen.dart';
import 'package:video_player_app/widgets/pin_unlock_dialog.dart';
import '../../../views/screens/home_screen/widgets/view.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onVideosChanged;

  const HomeScreen({super.key, this.onVideosChanged});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  String get _customCategoriesPrefKey =>
      VaultContext.instance.customCategoriesKey;

  final List<VideoItem> _allMedia = [];
  final List<VideoItem> _filteredMedia = [];
  final List<String> _customCategories = [];
  bool isDeleteData = true;
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;
  String _selectedCategory = "All";

  List<String> get _allCategoriesForFilter {
    final base = MediaHelper.mediaCategories;
    if (_customCategories.isEmpty) return base;
    final set = base.map((c) => c.toLowerCase()).toSet();
    final extras = _customCategories
        .where((c) => !set.contains(c.toLowerCase()))
        .toList();
    return [...base, ...extras];
  }

  late AnimationController _headerAnimationController;
  late Animation<double> _headerFadeAnimation;
  late Animation<Offset> _headerSlideAnimation;

  final MediaService _mediaService = MediaService();

  @override
  void initState() {
    super.initState();
    _loadMedia();

    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onSearchFocusChanged);

    _headerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _headerFadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _headerAnimationController, curve: Curves.easeIn),
    );

    _headerSlideAnimation =
        Tween<Offset>(begin: const Offset(0, -0.5), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _headerAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _headerAnimationController.forward();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchFocusNode.dispose();
    _headerAnimationController.dispose();
    super.dispose();
  }

  // Debounced: filtering the whole vault and rebuilding the screen on every
  // keystroke causes visible lag on large libraries.
  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 280), () {
      if (mounted) _filterMedia();
    });
  }

  void _onSearchFocusChanged() {
    if (mounted) setState(() {});
  }

  void _filterMedia() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      _filteredMedia.clear();

      if (query.isEmpty && _selectedCategory == "All") {
        _filteredMedia.addAll(_allMedia);
        return;
      }

      final selectedCat = _selectedCategory.trim().toLowerCase();
      for (final media in _allMedia) {
        bool matchesCategory =
            _selectedCategory == "All" ||
            media.category.trim().toLowerCase() == selectedCat;

        bool matchesSearch =
            query.isEmpty ||
            media.title.toLowerCase().contains(query) ||
            media.category.toLowerCase().contains(query);

        if (matchesCategory && matchesSearch) {
          _filteredMedia.add(media);
        }
      }
    });
  }

  Future<void> refreshVideos() async {
    await _loadMedia();
  }

  Future<void> _openAddSheet() async {
    HapticFeedback.lightImpact();
    await AddToVaultSheet.show(
      context,
      onImported: () async {
        await _loadMedia();
        widget.onVideosChanged?.call();
      },
    );
  }

  Future<void> _openSecureCamera() async {
    HapticFeedback.lightImpact();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SecureCameraScreen()),
    );
    if (mounted) {
      await _loadMedia();
      widget.onVideosChanged?.call();
    }
  }

  Future<void> _loadMedia() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final results = await Future.wait([
        _mediaService.loadMedia(),
        _readCustomCategories(),
      ]);
      final mediaList = results[0] as List<VideoItem>;
      final customs = results[1] as List<String>;

      if (!mounted) return;

      setState(() {
        _allMedia
          ..clear()
          ..addAll(mediaList);
        _customCategories
          ..clear()
          ..addAll(customs);
        if (_selectedCategory != 'All' &&
            !_allCategoriesForFilter
                .map((c) => c.toLowerCase())
                .contains(_selectedCategory.toLowerCase())) {
          _selectedCategory = 'All';
        }
        _filterMedia();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<List<String>> _readCustomCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_customCategoriesPrefKey) ?? const <String>[];
    } catch (_) {
      return const <String>[];
    }
  }

  Future<void> _updateMediaCategory(VideoItem media, String newCategory) async {
    final success = await _mediaService.updateMediaCategory(media, newCategory);
    if (success) {
      await _loadMedia();
    }
  }

  /// Identity gate for any action on a locked item. Tries biometric / Face ID
  /// via the OS prompt first; if that's unavailable, cancelled or fails, falls
  /// back to the app PIN. Returns true only when the user verified.
  Future<bool> _unlockProtectedItem({required String reason}) async {
    if (await _mediaService.authenticateUser(reason: reason)) return true;
    if (!mounted) return false;
    return _verifyWithAppPin();
  }

  /// Verifies the vault's PIN through the unlock dialog.
  Future<bool> _verifyWithAppPin() async {
    if (!await PinCrypto.instance.hasPin()) {
      if (mounted) {
        FlushBarHelper.flushBarErrorMessage('No PIN is set', context);
      }
      return false;
    }
    final pinLength = await PinCrypto.instance.getPinLength();
    if (!mounted) return false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => PinUnlockDialog(pinLength: pinLength),
    );
    return ok == true;
  }

  Future<void> _renameMedia(VideoItem media) async {
    if (media.isLocked) {
      final authenticated = await _unlockProtectedItem(
        reason: 'Authenticate to rename locked media',
      );
      if (!authenticated) return;
    }

    if (!mounted) return;

    final TextEditingController renameController = TextEditingController(
      text: media.title,
    );

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: LiquidContainer(
          gradient: LiquidColors.cardGradient,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    gradient: LiquidColors.secondaryGradient,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: LiquidColors.secondaryStart.withValues(
                          alpha: 0.4,
                        ),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.drive_file_rename_outline,
                      color: LiquidColors.textPrimary,
                      size: 35,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Rename File',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: LiquidColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  media.title,
                  style: TextStyle(
                    color: LiquidColors.textSecondary,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        LiquidColors.backgroundDeep.withValues(alpha: 0.8),
                        LiquidColors.backgroundMid.withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: LiquidColors.primaryStart.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: renameController,
                    style: TextStyle(color: LiquidColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Enter new name',
                      hintStyle: TextStyle(color: LiquidColors.textTertiary),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.title,
                        color: LiquidColors.accentBlue,
                        size: 20,
                      ),
                    ),
                    autofocus: true,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: LiquidColors.textTertiary,
                              width: 1,
                            ),
                          ),
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
                        onPressed: () {
                          if (renameController.text.trim().isNotEmpty) {
                            Navigator.pop(
                              dialogContext,
                              renameController.text.trim(),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: LiquidColors.accentBlue,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                          shadowColor: LiquidColors.accentBlue.withValues(
                            alpha: 0.4,
                          ),
                        ),
                        child: Text(
                          'Rename',
                          style: TextStyle(
                            color: LiquidColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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

    if (result != null && result.isNotEmpty && mounted) {
      try {
        setState(() => _isLoading = true);

        final success = await _mediaService.renameMedia(media, result);

        if (!mounted) return;
        setState(() => _isLoading = false);

        if (success) {
          await _loadMedia();
          if (widget.onVideosChanged != null) {
            widget.onVideosChanged!();
          }
          if (mounted) {
            FlushBarHelper.flushBarSuccessMessage(
              'File renamed successfully',
              context,
            );
          }
        } else {
          if (mounted) {
            FlushBarHelper.flushBarErrorMessage(
              'Failed to rename file. The name might already exist or contain invalid characters.',
              context,
            );
          }
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          FlushBarHelper.flushBarErrorMessage(
            'Error: ${e.toString()}',
            context,
          );
        }
      }
    }
  }

  Future<void> _deleteMedia(VideoItem media) async {
    if (media.isLocked) {
      final authenticated = await _unlockProtectedItem(
        reason: 'Authenticate to delete locked media',
      );
      if (!authenticated) return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => DeleteDialog(
        title: media.title,
        onConfirm: () async {
          await _mediaService.softDeleteMedia(media);
          if (!mounted) return;
          await _loadMedia();
          widget.onVideosChanged?.call();
          if (!mounted) return;
          FlushBarHelper.flushBarSuccessMessage('Moved to trash', context);
        },
      ),
    );
  }

  static const Set<String> _knownExtensions = {
    'mp4',
    'mkv',
    'avi',
    'mov',
    'webm',
    '3gp',
    'm4v',
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
    'bmp',
    'heic',
    'heif',
    'mp3',
    'wav',
    'aac',
    'ogg',
    'm4a',
    'flac',
    'opus',
    'pdf',
    'doc',
    'docx',
    'txt',
    'rtf',
    'epub',
  };

  String _saveFileNameFor(VideoItem media) {
    String path = media.path;
    if (path.toLowerCase().endsWith('.enc')) {
      path = path.substring(0, path.length - 4);
    }

    String ext = _extractKnownExt(path);
    if (ext.isEmpty) ext = _extractKnownExt(media.title);
    if (ext.isEmpty) ext = _defaultExtForType(media.type);

    final title = media.title.trim();
    final base = title.isEmpty ? 'file' : _stripKnownExt(title);
    return ext.isEmpty ? base : '$base.$ext';
  }

  String _extractKnownExt(String name) {
    final basenameStart = name.lastIndexOf(RegExp(r'[/\\]'));
    final basename = basenameStart < 0
        ? name
        : name.substring(basenameStart + 1);
    final dot = basename.lastIndexOf('.');
    if (dot < 0 || dot >= basename.length - 1) return '';
    final candidate = basename.substring(dot + 1).toLowerCase();
    return _knownExtensions.contains(candidate) ? candidate : '';
  }

  String _stripKnownExt(String name) {
    final ext = _extractKnownExt(name);
    if (ext.isEmpty) return name;
    return name.substring(0, name.length - ext.length - 1);
  }

  String _defaultExtForType(String type) {
    switch (type.toLowerCase()) {
      case 'video':
        return 'mp4';
      case 'image':
        return 'jpg';
      case 'audio':
        return 'mp3';
      case 'document':
      case 'pdf':
        return 'pdf';
      default:
        return '';
    }
  }

  void _showDownloadConfirmation(VideoItem media) async {
    if (media.isLocked) {
      final authenticated = await _unlockProtectedItem(
        reason: 'Authenticate to download locked media',
      );
      if (!authenticated) return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => DownloadDialog(
        title: media.title,
        path: media.path,
        onConfirm: () async {
          if (media.path.isEmpty || !await File(media.path).exists()) {
            if (!mounted) return;
            FlushBarHelper.flushBarErrorMessage('File not found', context);
            return;
          }

          String savePath = media.path;
          bool decryptedToTemp = false;

          if (media.encrypted) {
            if (!mounted) return;
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) =>
                  const Center(child: LiquidCircularProgress(size: 96)),
            );
            try {
              savePath = await VaultCrypto.instance.decryptToTemp(media.path);
              decryptedToTemp = true;
            } catch (_) {
              if (!mounted) return;
              Navigator.of(context, rootNavigator: true).pop();
              FlushBarHelper.flushBarErrorMessage(
                'Failed to decrypt file',
                context,
              );
              return;
            }
            if (!mounted) return;
            Navigator.of(context, rootNavigator: true).pop();
          }

          final saveName = _saveFileNameFor(media);

          try {
            final success = await _mediaService.downloadFile(
              filePath: savePath,
              fileName: saveName,
            );
            if (!mounted) return;
            if (success) {
              FlushBarHelper.flushBarSuccessMessage(
                '$saveName saved to the "SecuroBox" album',
                context,
              );
            } else {
              FlushBarHelper.flushBarErrorMessage('Download failed', context);
            }
          } finally {
            if (decryptedToTemp) {
              await VaultCrypto.instance.wipeTempCache();
            }
          }
        },
      ),
    );
  }

  Future<void> _onRefresh() async {
    try {
      if (!mounted) return;
      setState(() => _isLoading = true);
      await _loadMedia();
      if (!mounted) return;
      FlushBarHelper.flushBarSuccessMessage(
        'Refreshed ${_filteredMedia.length} files',
        context,
      );
    } catch (e) {
      if (!mounted) return;
      FlushBarHelper.flushBarErrorMessage('Refresh failed', context);
    }
  }

  Future<void> _toggleMediaLock(VideoItem media) async {
    if (media.isLocked) {
      final authenticated = await _unlockProtectedItem(
        reason: 'Authenticate to unlock media',
      );
      if (!authenticated) {
        if (!mounted) return;
        FlushBarHelper.flushBarErrorMessage(
          'Verify with biometrics, Face ID or PIN to unlock',
          context,
        );
        return;
      }
    }

    final success = await _mediaService.toggleMediaLock(media);
    if (success && mounted) {
      await _loadMedia();
    }
  }

  Future<void> _openMedia(VideoItem media) async {
    if (media.isLocked) {
      final authenticated = await _unlockProtectedItem(
        reason: 'Authenticate to open locked media',
      );
      if (!authenticated) {
        if (!mounted) return;
        FlushBarHelper.flushBarErrorMessage(
          'Verify with biometrics, Face ID or PIN to open this item',
          context,
        );
        return;
      }
    }

    if (media.path.isEmpty || !await File(media.path).exists()) {
      if (!mounted) return;
      FlushBarHelper.flushBarErrorMessage('File not found', context);
      return;
    }

    String playPath = media.path;
    if (media.encrypted) {
      try {
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: LiquidCircularProgress(size: 96)),
        );
        playPath = await VaultCrypto.instance.decryptToTemp(media.path);
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).pop();
      } catch (e) {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          FlushBarHelper.flushBarErrorMessage(
            'Failed to decrypt file',
            context,
          );
        }
        return;
      }
    }

    switch (media.type.toLowerCase()) {
      case 'video':
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                VideoPlayerScreen(videoPath: playPath, videoTitle: media.title),
          ),
        ).then((_) async {
          if (media.encrypted) await VaultCrypto.instance.wipeTempCache();
          if (mounted) _loadMedia();
        });
        break;

      case 'image':
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Scaffold(
              backgroundColor: LiquidColors.backgroundDeep,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back, color: LiquidColors.textPrimary),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  media.title,
                  style: TextStyle(color: LiquidColors.textPrimary),
                ),
              ),
              body: Center(
                child: InteractiveViewer(
                  child: Image.file(
                    File(playPath),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image,
                              color: LiquidColors.error,
                              size: 60,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Unable to load image',
                              style: TextStyle(color: LiquidColors.textPrimary),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        break;

      case 'audio':
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                AudioPlayerScreen(filePath: playPath, fileName: media.title),
          ),
        ).then((_) async {
          if (media.encrypted) await VaultCrypto.instance.wipeTempCache();
        });
        break;

      case 'pdf':
      case 'document':
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                PDFReaderScreen(filePath: playPath, fileName: media.title),
          ),
        ).then((_) async {
          if (media.encrypted) await VaultCrypto.instance.wipeTempCache();
        });
        break;

      default:
        _showGenericFileDialog(media);
        break;
    }
  }

  void _showGenericFileDialog(VideoItem media) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: LiquidContainer(
          gradient: LiquidColors.cardGradient,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LiquidColors.secondaryGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: LiquidColors.secondaryStart.withValues(
                          alpha: 0.4,
                        ),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.insert_drive_file_rounded,
                      color: LiquidColors.textPrimary,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  media.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: LiquidColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'File Type: ${media.type.toUpperCase()}',
                  style: TextStyle(color: LiquidColors.textSecondary),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LiquidColors.accentBlue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Close',
                    style: TextStyle(color: LiquidColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LiquidBackground(
      animate: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const AppBarTitleWidget(),
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  LiquidColors.backgroundDeep.withValues(alpha: 0.85),
                  LiquidColors.backgroundMid.withValues(alpha: 0.6),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          actions: [
            _buildAppBarAction(
              icon: Icons.photo_camera_rounded,
              tooltip: 'Secure Camera',
              onTap: _openSecureCamera,
            ),
            SizedBox(width: 10),
            _buildAppBarAction(
              icon: Icons.delete_outline_rounded,
              tooltip: 'Recycle Bin',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DeletedVideosScreen(
                      onVideosChanged: () => _loadMedia(),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        floatingActionButton: _buildAddFab(),
        body: Column(
          children: [
            _buildAnimatedHeader(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) =>
                    FadeTransition(opacity: anim, child: child),
                child: _isLoading && _allMedia.isEmpty
                    ? KeyedSubtree(
                        key: const ValueKey('loading'),
                        child: _buildLoadingState(),
                      )
                    : _filteredMedia.isEmpty
                    ? KeyedSubtree(
                        key: const ValueKey('empty'),
                        child: _buildEmptyState(),
                      )
                    : KeyedSubtree(
                        key: const ValueKey('list'),
                        child: _buildMediaListWithRefresh(),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddFab() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openAddSheet,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [LiquidColors.accentBlue, LiquidColors.accentPurple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: LiquidColors.accentBlue.withValues(alpha: 0.45),
                blurRadius: 22,
                spreadRadius: -2,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.add_rounded, color: Colors.white, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBarAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 40,
              decoration: BoxDecoration(
                color: LiquidColors.textPrimary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: LiquidColors.textPrimary.withValues(alpha: 0.08),
                ),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: LiquidColors.textPrimary, size: 20),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedHeader() {
    return FadeTransition(
      opacity: _headerFadeAnimation,
      child: SlideTransition(
        position: _headerSlideAnimation,
        child: _buildHeader(),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            LiquidColors.backgroundDeep.withValues(alpha: 0.8),
            LiquidColors.backgroundDeep.withValues(alpha: 0.0),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: LiquidColors.textPrimary.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        children: [
          _buildSearchBar(),
          const SizedBox(height: 12),
          _buildCategoryFilter(),
          const SizedBox(height: 6),
          _buildFilterInfo(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final hasQuery = _searchController.text.isNotEmpty;
    final focused = _searchFocusNode.hasFocus;
    final active = hasQuery || focused;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: LiquidColors.textPrimary.withValues(alpha: active ? 0.07 : 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            color: active ? LiquidColors.accentBlue : LiquidColors.textTertiary,
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
              cursorColor: LiquidColors.accentBlue,
              decoration: InputDecoration(
                hintText: 'Search your vault',
                hintStyle: TextStyle(
                  color: LiquidColors.textTertiary,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                // Every state set explicitly — otherwise the focused state
                // falls back to the app theme's blue input border.
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
    );
  }

  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 36,
      child: ShaderMask(
        shaderCallback: (rect) {
          return const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            stops: [0.0, 0.03, 0.95, 1.0],
            colors: [
              Colors.transparent,
              Colors.black,
              Colors.black,
              Colors.transparent,
            ],
          ).createShader(rect);
        },
        blendMode: BlendMode.dstIn,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          itemCount: _allCategoriesForFilter.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final categories = _allCategoriesForFilter;
            final category = categories[index];
            final isSelected = _selectedCategory == category;
            final isCustom = !MediaHelper.mediaCategories.contains(category);
            return _CategoryPill(
              label: category,
              selected: isSelected,
              isCustom: isCustom,
              onTap: () {
                HapticFeedback.selectionClick();
                // Tapping the active category again clears back to "All".
                // _filterMedia() runs its own setState, so set the field
                // first and call it directly — no nested setState.
                _selectedCategory = isSelected ? "All" : category;
                _filterMedia();
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterInfo() {
    final hasFilters =
        _selectedCategory != "All" || _searchController.text.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${_filteredMedia.length} ${_filteredMedia.length == 1 ? "item" : "items"}',
            style: TextStyle(
              color: LiquidColors.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: hasFilters
                ? GestureDetector(
                    key: const ValueKey('clear-filters'),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _selectedCategory = "All";
                        _searchController.clear();
                      });
                      _filterMedia();
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.refresh_rounded,
                          color: LiquidColors.accentBlue,
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Clear filters',
                          style: TextStyle(
                            color: LiquidColors.accentBlue,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(key: ValueKey('no-filters'), height: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _SkeletonCard(delayMs: index * 80),
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasFilters =
        _searchController.text.isNotEmpty || _selectedCategory != "All";
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: LiquidColors.accentBlue,
      backgroundColor: LiquidColors.backgroundLight,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.55,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            LiquidColors.accentBlue.withValues(alpha: 0.18),
                            LiquidColors.accentBlue.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                      child: Icon(
                        hasFilters
                            ? Icons.search_off_rounded
                            : Icons.lock_outline_rounded,
                        size: 36,
                        color: LiquidColors.accentBlue,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      hasFilters ? 'No matches' : 'Your vault is empty',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: LiquidColors.textPrimary,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hasFilters
                          ? 'Try a different search term or category to find what you\'re looking for.'
                          : 'Files you import are encrypted and stored only on this device — never in the cloud.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: LiquidColors.textTertiary,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 22),
                    if (!hasFilters)
                      _PrimaryAction(
                        icon: Icons.add_rounded,
                        label: 'Add your first file',
                        onTap: _openAddSheet,
                      ),
                    if (hasFilters)
                      _PrimaryAction(
                        icon: Icons.refresh_rounded,
                        label: 'Clear filters',
                        onTap: () {
                          setState(() {
                            _selectedCategory = "All";
                            _searchController.clear();
                          });
                          _filterMedia();
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaListWithRefresh() {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: LiquidColors.accentBlue,
      backgroundColor: LiquidColors.backgroundLight,
      strokeWidth: 3,
      displacement: 50,
      edgeOffset: 0,
      triggerMode: RefreshIndicatorTriggerMode.anywhere,
      child: ListView.builder(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(
          context.contentInset(phone: 16),
          16,
          context.contentInset(phone: 16),
          16,
        ),
        itemCount: _filteredMedia.length,
        itemBuilder: (context, index) {
          final media = _filteredMedia[index];
          return AnimatedMediaCard(
            media: media,
            categories: MediaHelper.mediaCategories,
            index: index,
            onTap: () => _openMedia(media),
            onCategorySelected: (category) =>
                _updateMediaCategory(media, category),
            onLockTap: () => _toggleMediaLock(media),
            onDownloadTap: () => _showDownloadConfirmation(media),
            onDeleteTap: () => _deleteMedia(media),
            onRenameTap: () => _renameMedia(media),
          );
        },
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isCustom;
  final VoidCallback onTap;

  const _CategoryPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.isCustom = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isCustom
        ? LiquidColors.accentPurple
        : LiquidColors.accentBlue;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.16)
                : LiquidColors.textPrimary.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? accent
                  : LiquidColors.textPrimary.withValues(alpha: 0.08),
              width: selected ? 1.2 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isCustom) ...[
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: selected ? 1 : 0.7),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? LiquidColors.textPrimary
                      : LiquidColors.textSecondary,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatefulWidget {
  final int delayMs;

  const _SkeletonCard({required this.delayMs});

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _controller.repeat();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Container(
          height: 84,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: LiquidColors.textPrimary.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: LiquidColors.textPrimary.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            children: [
              _shimmerBox(width: 60, height: 60, radius: 12, t: t),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _shimmerBox(
                      width: double.infinity,
                      height: 14,
                      radius: 4,
                      t: t,
                    ),
                    const SizedBox(height: 8),
                    _shimmerBox(width: 120, height: 10, radius: 4, t: t),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _shimmerBox(width: 24, height: 24, radius: 6, t: t),
            ],
          ),
        );
      },
    );
  }

  Widget _shimmerBox({
    required double width,
    required double height,
    required double radius,
    required double t,
  }) {
    final shift = (t * 2 - 1).clamp(-1.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: width,
        height: height,
        color: LiquidColors.textPrimary.withValues(alpha: 0.05),
        foregroundDecoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(shift - 0.3, 0),
            end: Alignment(shift + 0.3, 0),
            colors: [
              LiquidColors.textPrimary.withValues(alpha: 0.0),
              LiquidColors.textPrimary.withValues(alpha: 0.08),
              LiquidColors.textPrimary.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PrimaryAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          decoration: BoxDecoration(
            color: LiquidColors.accentBlue,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: LiquidColors.accentBlue.withValues(alpha: 0.35),
                blurRadius: 18,
                spreadRadius: -4,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
