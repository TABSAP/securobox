import 'package:flutter/material.dart';
import '../../../views/screens/home_screen/widgets/view.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onVideosChanged;

  const HomeScreen({
    super.key,
    this.onVideosChanged,
  });

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final List<VideoItem> _allMedia = [];
  final List<VideoItem> _filteredMedia = [];
  bool isDeleteData = true;
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = "All";

  late AnimationController _headerAnimationController;
  late Animation<double> _headerFadeAnimation;
  late Animation<Offset> _headerSlideAnimation;

  final MediaService _mediaService = MediaService();

  @override
  void initState() {
    super.initState();
    _loadMedia();

    _searchController.addListener(_onSearchChanged);

    _headerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _headerFadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _headerAnimationController,
        curve: Curves.easeIn,
      ),
    );

    _headerSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _headerAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _headerAnimationController.forward();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _headerAnimationController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _filterMedia();
  }

  void _filterMedia() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      _filteredMedia.clear();

      if (query.isEmpty && _selectedCategory == "All") {
        _filteredMedia.addAll(_allMedia);
        return;
      }

      for (final media in _allMedia) {
        bool matchesCategory = _selectedCategory == "All" ||
            media.category.toLowerCase() == _selectedCategory.toLowerCase();

        bool matchesSearch = query.isEmpty ||
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

  Future<void> _loadMedia() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 300));
      final mediaList = await _mediaService.loadMedia();

      if (!mounted) return;

      setState(() {
        _allMedia.clear();
        _allMedia.addAll(mediaList);
        _filterMedia();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      debugPrint('Error loading media: $e');
    }
  }

  Future<void> _updateMediaCategory(VideoItem media, String newCategory) async {
    final success = await _mediaService.updateMediaCategory(media, newCategory);
    if (success) {
      await _loadMedia();
    }
  }

  Future<void> _renameMedia(VideoItem media) async {
    if (media.isLocked) {
      final authenticated = await _mediaService.authenticateUser(
        reason: 'Authenticate to rename locked media',
      );
      if (!authenticated) return;
    }

    if (!mounted) return;

    final TextEditingController renameController = TextEditingController(text: media.title);

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
                          color: LiquidColors.secondaryStart.withValues(alpha: 0.4),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.drive_file_rename_outline, color: Colors.white, size: 35),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Rename File',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    media.title,
                    style: TextStyle(
                      color: Colors.grey.shade400,
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
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Enter new name',
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        prefixIcon: Icon(Icons.title, color: LiquidColors.accentBlue, size: 20),
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
                                color: Colors.grey.shade700,
                                width: 1,
                              ),
                            ),
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
                          onPressed: () {
                            if (renameController.text.trim().isNotEmpty) {
                              Navigator.pop(dialogContext, renameController.text.trim());
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: LiquidColors.accentBlue,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                            shadowColor: LiquidColors.accentBlue.withValues(alpha: 0.4),
                          ),
                          child: const Text(
                            'Rename',
                            style: TextStyle(
                              color: Colors.white,
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

        debugPrint('Attempting to rename: ${media.title} to: $result');
        final success = await _mediaService.renameMedia(media, result);
        debugPrint('Rename result: $success');

        if (!mounted) return;
        setState(() => _isLoading = false);

        if (success) {
          await _loadMedia();
          if (widget.onVideosChanged != null) {
            widget.onVideosChanged!();
          }
          if (mounted) {
            FlushBarHelper.flushBarSuccessMessage('File renamed successfully', context);
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
        debugPrint('Error in rename: $e');
        if (mounted) {
          FlushBarHelper.flushBarErrorMessage('Error: ${e.toString()}', context);
        }
      }
    }
  }

  Future<void> _deleteMedia(VideoItem media) async {
    if (media.isLocked) {
      final authenticated = await _mediaService.authenticateUser(
        reason: 'Authenticate to delete locked media',
      );
      if (!authenticated) return;
    }

    if (!mounted) return;

    final currentContext = context;

    showDialog(
      context: currentContext,
      builder: (dialogContext) => DeleteDialog(
        title: media.title,
        onConfirm: () async {
          final success = await _mediaService.softDeleteMedia(media);
          if (!mounted) return;
          await _loadMedia();
          if (widget.onVideosChanged != null) {
            widget.onVideosChanged!();
          }
          FlushBarHelper.flushBarSuccessMessage('Moved to trash', currentContext);
          Navigator.pop(dialogContext);
        },
      ),
    );
  }

  void _showDownloadConfirmation(VideoItem media) async {
    if (media.isLocked) {
      final authenticated = await _mediaService.authenticateUser(
        reason: 'Authenticate to download locked media',
      );
      if (!authenticated) return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => DownloadDialog(
        title: media.title,
        path: media.path,
        onConfirm: () async {
          final success = await _mediaService.downloadFile(
            filePath: media.path,
            fileName: media.title,
          );
          if (!mounted) return;
          if (success) {
            FlushBarHelper.flushBarSuccessMessage('${media.title} downloaded successfully', context);
          } else {
            FlushBarHelper.flushBarErrorMessage('Download failed', context);
          }
        },
      ),
    );
  }

  Future<void> _onRefresh() async {
    try {
      if (!mounted) return;
      setState(() => _isLoading = true);
      await Future.delayed(const Duration(milliseconds: 800));
      await _loadMedia();
      if (!mounted) return;
      FlushBarHelper.flushBarSuccessMessage('Refreshed ${_filteredMedia.length} files', context);
    } catch (e) {
      if (!mounted) return;
      FlushBarHelper.flushBarErrorMessage('Refresh failed', context);
    }
  }

  Future<void> _toggleMediaLock(VideoItem media) async {
    if (media.isLocked) {
      final authenticated = await _mediaService.authenticateUser(
        reason: 'Authenticate to unlock media',
      );
      if (!authenticated) {
        if (!mounted) return;
        FlushBarHelper.flushBarErrorMessage('Authentication required to unlock', context);
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
      final authenticated = await _mediaService.authenticateUser();
      if (!authenticated) {
        if (!mounted) return;
        FlushBarHelper.flushBarErrorMessage('Authentication failed', context);
        return;
      }
    }

    if (!await File(media.path).exists()) {
      if (!mounted) return;
      FlushBarHelper.flushBarErrorMessage('File not found', context);
      return;
    }

    switch (media.type.toLowerCase()) {
      case 'video':
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoPlayerScreen(
              videoPath: media.path,
              videoTitle: media.title,
            ),
          ),
        ).then((_) => mounted ? _loadMedia() : null);
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
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  media.title,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              body: Center(
                child: InteractiveViewer(
                  child: Image.file(
                    File(media.path),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image, color: LiquidColors.error, size: 60),
                            const SizedBox(height: 16),
                            const Text('Unable to load image', style: TextStyle(color: Colors.white)),
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
            builder: (context) => AudioPlayerScreen(
              filePath: media.path,
              fileName: media.title,
            ),
          ),
        );
        break;

      case 'pdf':
      case 'document':
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PDFReaderScreen(
              filePath: media.path,
              fileName: media.title,
            ),
          ),
        );
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
                        color: LiquidColors.secondaryStart.withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.insert_drive_file_rounded, color: Colors.white, size: 40),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  media.title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'File Type: ${media.type.toUpperCase()}',
                  style: TextStyle(color: Colors.grey.shade400),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LiquidColors.accentBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Close', style: TextStyle(color: Colors.white)),
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
          actions: [

            TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 500),
              curve: Curves.elasticOut,
              builder: (context, double value, child) {
                return Transform.scale(
                  scale: value,
                  child: IconButton(
                    icon: Icon(
                      Icons.delete_forever,
                      color: Colors.white,
                      size: 30,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DeletedVideosScreen(
                            onVideosChanged: () => _loadMedia(),
                          ),
                        ),
                      );
                    },
                    tooltip: 'Recycle Bin',
                  ),
                );
              },
            ),
          ],
        ),
        body: Column(
          children: [
            _buildAnimatedHeader(),
            Expanded(
              child: _isLoading && _allMedia.isEmpty
                  ? _buildLoadingState()
                  : _filteredMedia.isEmpty
                  ? _buildEmptyState()
                  : _buildMediaListWithRefresh(),
            ),
          ],
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
    return LiquidContainer(
      gradient: LinearGradient(
        colors: [
          LiquidColors.backgroundLight.withValues(alpha: .9),
          LiquidColors.backgroundMid.withValues(alpha: .95),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(30),
        bottomRight: Radius.circular(30),
      ),
      boxShadow: [
        BoxShadow(
          color: LiquidColors.primaryStart.withValues(alpha: .3),
          blurRadius: 20,
          spreadRadius: 0,
          offset: const Offset(0, 10),
        ),
      ],
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSearchBar(),
          const SizedBox(height: 12),
          _buildCategoryFilter(),
          const SizedBox(height: 8),
          _buildFilterInfo(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, double value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  LiquidColors.backgroundDeep.withValues(alpha: .8),
                  LiquidColors.backgroundMid.withValues(alpha: .8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: LiquidColors.primaryStart.withValues(alpha: 0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: LiquidColors.primaryStart.withValues(alpha: 0.2),
                  blurRadius: 10,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: LiquidColors.accentBlue),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search media...',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    onPressed: () => _searchController.clear(),
                    icon: Icon(Icons.close, color: LiquidColors.error, size: 20),
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 45,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: MediaHelper.mediaCategories.length,
        itemBuilder: (context, index) {
          final category = MediaHelper.mediaCategories[index];
          final isSelected = _selectedCategory == category;
          return TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: 1),
            duration: Duration(milliseconds: 500 + (index * 50)),
            curve: Curves.elasticOut,
            builder: (context, double value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      category,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey.shade400,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = selected ? category : "All";
                        _filterMedia();
                      });
                    },
                    backgroundColor: LiquidColors.backgroundDeep,
                    selectedColor: LiquidColors.accentBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                      side: BorderSide(
                        color: isSelected
                            ? LiquidColors.accentBlue
                            : LiquidColors.backgroundLight,
                        width: 1,
                      ),
                    ),
                    elevation: isSelected ? 4 : 0,
                    shadowColor: LiquidColors.accentBlue.withValues(alpha: 0.3),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFilterInfo() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '${_filteredMedia.length} files found',
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 12,
            shadows: [
              Shadow(
                color: LiquidColors.primaryStart.withValues(alpha: 0.3),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        if (_selectedCategory != "All" || _searchController.text.isNotEmpty)
          TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            builder: (context, double value, child) {
              return Transform.scale(
                scale: value,
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedCategory = "All";
                      _searchController.clear();
                    });
                    _filterMedia();
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: LiquidColors.backgroundLight.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    'Clear filters',
                    style: TextStyle(
                      color: LiquidColors.accentBlue,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: LiquidColors.accentBlue,
      backgroundColor: LiquidColors.backgroundLight,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.8,
          child: Center(
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
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: LiquidColors.primaryGradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: LiquidColors.primaryStart.withValues(alpha: 0.4),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 30),
                const Text(
                  'Loading Media...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final bool hasFilters = _searchController.text.isNotEmpty || _selectedCategory != "All";

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: LiquidColors.accentBlue,
      backgroundColor: LiquidColors.backgroundLight,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.5,
          child: Center(
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
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              LiquidColors.backgroundLight,
                              LiquidColors.backgroundMid,
                              LiquidColors.backgroundDeep,
                            ],
                            center: Alignment.center,
                            radius: 0.8,
                          ),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: LiquidColors.primaryStart.withValues(alpha: 0.3),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: LiquidColors.primaryStart.withValues(alpha: 0.2),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            hasFilters ? Icons.search_off_rounded : Icons.library_music_outlined,
                            size: 60,
                            color: LiquidColors.primaryStart,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 30),
                Text(
                  hasFilters ? 'No Files Found' : 'No Files Yet',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  hasFilters
                      ? 'Try different search terms or categories'
                      : 'Upload your first file to get started',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 14,
                  ),
                ),
                if (hasFilters) const SizedBox(height: 25),
                if (hasFilters)
                  TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.elasticOut,
                    builder: (context, double value, child) {
                      return Transform.scale(
                        scale: value,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedCategory = "All";
                              _searchController.clear();
                            });
                            _filterMedia();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: LiquidColors.accentBlue,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 30,
                              vertical: 15,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 8,
                            shadowColor: LiquidColors.accentBlue.withValues(alpha: 0.4),
                          ),
                          child: const Text(
                            'Clear Filters',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
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
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.all(16),
        itemCount: _filteredMedia.length,
        itemBuilder: (context, index) {
          final media = _filteredMedia[index];
          return AnimatedMediaCard(
            media: media,
            categories: MediaHelper.mediaCategories,
            index: index,
            onTap: () => _openMedia(media),
            onCategorySelected: (category) => _updateMediaCategory(media, category),
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
