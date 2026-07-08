import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:video_player_app/models/app_models.dart';
import 'package:video_player_app/notifications_screen/notifications_screen.dart';
import 'package:video_player_app/services/media_service.dart';
import 'package:video_player_app/utils/category_service.dart';
import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/utils/media_helper.dart';
import 'package:video_player_app/utils/notification_service.dart';
import 'package:video_player_app/utils/responsive.dart';
import 'package:video_player_app/views/screens/categories/category_management_screen.dart';
import 'package:video_player_app/views/screens/deleted_video_screen/deleted_video_screen.dart';
import 'package:video_player_app/views/screens/home_screen/home_screen.dart';
import 'package:video_player_app/views/screens/secure_camera/secure_camera_screen.dart';
import 'package:video_player_app/widgets/app_loader.dart';
import 'package:video_player_app/widgets/app_section_header.dart';
import 'package:video_player_app/widgets/app_spacing.dart';
import 'package:video_player_app/widgets/vault_thumbnail.dart';

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => HomeDashboardState();
}

class HomeDashboardState extends State<HomeDashboard> {
  final MediaService _mediaService = MediaService();
  final TextEditingController _searchController = TextEditingController();
  List<VideoItem> _all = const [];
  // Visible categories (defaults + custom) in the user's chosen order.
  List<CategoryInfo> _categories = const [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
    MediaService.revision.addListener(_onRevision);
    CategoryService.revision.addListener(_onRevision);
    _searchController.addListener(() {
      final q = _searchController.text.trim();
      if (q != _query) setState(() => _query = q);
    });
  }

  @override
  void dispose() {
    MediaService.revision.removeListener(_onRevision);
    CategoryService.revision.removeListener(_onRevision);
    _searchController.dispose();
    super.dispose();
  }

  void _onRevision() {
    if (mounted) _load();
  }

  Future<void> refresh() => _load();

  Future<void> _load() async {
    final media = await _mediaService.loadMedia();
    final cats = await CategoryService.instance.load();
    if (!mounted) return;
    setState(() {
      _all = media;
      _categories = cats.where((c) => !c.hidden).toList();
      _loading = false;
    });
  }

  int _countFor(CategoryInfo cat) {
    if (cat.type == 'favorite') {
      return _all.where((m) => m.isFavorite).length;
    }
    if (cat.isDefault && cat.type != null) {
      return _all.where((m) => m.type == cat.type).length;
    }
    final lower = cat.key.toLowerCase();
    return _all.where((m) => m.category.toLowerCase() == lower).length;
  }

  void _openCategoryInfo(CategoryInfo cat) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) {
          if (cat.type == 'favorite') {
            // Smart category: filter by the favourite flag.
            return HomeScreen(initialCategory: 'Favorites', screenTitle: cat.name);
          }
          if (cat.isDefault && cat.type != null) {
            return HomeScreen(typeFilter: cat.type, screenTitle: cat.name);
          }
          return HomeScreen(initialCategory: cat.key, screenTitle: cat.name);
        },
      ),
    );
  }

  Future<void> _openManageCategories() async {
    HapticFeedback.lightImpact();
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CategoryManagementScreen()),
    );
    // Categories may have changed (rename/hide/reorder/delete) while managing.
    if (mounted) _load();
  }

  void _openItem(VideoItem item) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HomeScreen(typeFilter: item.type, autoOpen: item),
      ),
    );
  }

  void _openRecent() {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const HomeScreen(screenTitle: 'Recently Added'),
      ),
    );
  }

  Widget _seeAll(VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            children: [
              Text(
                'See all',
                style: TextStyle(
                  color: LiquidColors.accentBlue,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: LiquidColors.accentBlue,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }


  Future<void> _openSecureCamera() async {
    HapticFeedback.lightImpact();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SecureCameraScreen()),
    );
  }

  void _openRecycleBin() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DeletedVideosScreen(onVideosChanged: () {}),
      ),
    );
  }

  void _openNotifications() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }

  Widget _notificationsAction() {
    return ValueListenableBuilder<int>(
      valueListenable: NotificationService.instance.unreadCount,
      builder: (context, count, _) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            _appBarAction(
              Icons.notifications_none_rounded,
              'Notifications',
              _openNotifications,
            ),
            if (count > 0)
              Positioned(
                right: 4,
                top: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 16),
                  decoration: BoxDecoration(
                    color: LiquidColors.error,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: LiquidColors.backgroundDeep, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LiquidColors.backgroundDeep,
      appBar: AppBar(
        backgroundColor: LiquidColors.backgroundDeep,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        // Status-bar icons follow the theme (dark on white, light on black).
        systemOverlayStyle: LiquidColors.isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        titleSpacing: 20,
        title: Text(
          'Library',
          style: TextStyle(
            color: LiquidColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        actions: [
          _notificationsAction(),
          const SizedBox(width: 8),
          _appBarAction(Icons.photo_camera_rounded, 'Secure Camera', _openSecureCamera),
          const SizedBox(width: 8),
          _appBarAction(Icons.delete_outline_rounded, 'Recycle Bin', _openRecycleBin),
          const SizedBox(width: 12),
        ],
      ),
      floatingActionButton: _createCategoryFab(),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: AppLoader(size: 52));
    }

    final inset = context.contentInset(phone: 16);
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(inset, AppSpace.sm, inset, AppSpace.sm),
          child: _searchBar(),
        ),
        Expanded(
          child: _query.isNotEmpty
              ? _searchResults(inset)
              : _dashboardContent(inset),
        ),
      ],
    );
  }

  Widget _dashboardContent(double inset) {
    final recent = _all.take(8).toList();
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(top: AppSpace.xs, bottom: AppSpace.xl + 40),
      children: [
        // Recently added — a compact strip shown only when the vault has files.
        if (recent.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: inset),
            child: AppSectionHeader(
              label: 'Recently added',
              caption: 'Your latest additions',
              trailing: _seeAll(_openRecent),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          _recentCarousel(recent, inset),
          const SizedBox(height: AppSpace.lg),
        ],
        // Categories — built-in and custom shown together, the default view.
        Padding(
          padding: EdgeInsets.symmetric(horizontal: inset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSectionHeader(
                label: 'Categories',
                trailing: _manageButton(),
              ),
              const SizedBox(height: AppSpace.sm),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: AppSpace.sm + 2,
                crossAxisSpacing: AppSpace.sm + 2,
                childAspectRatio: 1.25,
                children: [
                  for (final c in _categories) _categoryCard(c),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _searchResults(double inset) {
    final q = _query.toLowerCase();
    final catCards = <Widget>[
      for (final c in _categories)
        if (c.name.toLowerCase().contains(q)) _categoryCard(c),
    ];
    final files = _all
        .where((m) =>
            m.title.toLowerCase().contains(q) ||
            m.category.toLowerCase().contains(q))
        .toList();

    if (catCards.isEmpty && files.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: inset),
          child: Text(
            'No matches for "$_query"',
            style: TextStyle(color: LiquidColors.textTertiary, fontSize: 14),
          ),
        ),
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(inset, AppSpace.xs, inset, AppSpace.xl + 40),
      children: [
        if (catCards.isNotEmpty) ...[
          const AppSectionHeader(label: 'Categories'),
          const SizedBox(height: AppSpace.sm),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: AppSpace.sm + 2,
            crossAxisSpacing: AppSpace.sm + 2,
            childAspectRatio: 1.25,
            children: catCards,
          ),
          const SizedBox(height: AppSpace.lg),
        ],
        if (files.isNotEmpty) ...[
          AppSectionHeader(label: 'Files (${files.length})'),
          const SizedBox(height: AppSpace.sm),
          for (final m in files) _fileResultRow(m),
        ],
      ],
    );
  }

  Widget _searchBar() {
    return TextField(
      controller: _searchController,
      style: TextStyle(color: LiquidColors.textPrimary, fontSize: 15),
      cursorColor: LiquidColors.indigo,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: LiquidColors.surfaceMuted,
        hintText: 'Search',
        hintStyle: TextStyle(color: LiquidColors.textTertiary, fontSize: 15),
        prefixIcon:
            Icon(Icons.search_rounded, color: LiquidColors.textTertiary, size: 20),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                icon: Icon(Icons.close_rounded,
                    color: LiquidColors.textTertiary, size: 20),
                onPressed: () {
                  _searchController.clear();
                  FocusScope.of(context).unfocus();
                },
              ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: LiquidColors.indigo, width: 1.4),
        ),
      ),
    );
  }

  Widget _fileResultRow(VideoItem m) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () => _openItem(m),
          child: Container(
            padding: const EdgeInsets.all(AppSpace.sm + 2),
            decoration: BoxDecoration(
              color: LiquidColors.backgroundLight.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: LiquidColors.cardBorder),
            ),
            child: Row(
              children: [
                VaultThumbnail(
                    item: m, width: 46, height: 46, radius: 12, iconSize: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        m.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: LiquidColors.textPrimary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${m.type.toUpperCase()}  ·  ${m.category}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: LiquidColors.textTertiary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: LiquidColors.textTertiary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _manageButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openManageCategories,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            children: [
              Icon(Icons.tune_rounded, color: LiquidColors.indigo, size: 16),
              const SizedBox(width: 4),
              Text(
                'Manage',
                style: TextStyle(
                  color: LiquidColors.indigo,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // FAB for quickly creating a new custom category.
  Widget _createCategoryFab() {
    return FloatingActionButton.extended(
      onPressed: _createCategory,
      backgroundColor: LiquidColors.indigo,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.create_new_folder_rounded),
      label: const Text(
        'New category',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }

  static const List<String> _reservedNames = ['all', 'favorites'];

  Future<void> _createCategory() async {
    HapticFeedback.lightImpact();
    final name = await _promptNewCategoryName();
    if (name == null || !mounted) return;
    await CategoryService.instance.addCustom(name);
    if (mounted) _load();
  }

  Future<String?> _promptNewCategoryName() {
    final controller = TextEditingController();
    String? error;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          void submit() {
            final name = controller.text.trim();
            final lower = name.toLowerCase();
            if (name.isEmpty) {
              setLocal(() => error = 'Enter a name');
              return;
            }
            if (name.length > 24) {
              setLocal(() => error = 'Max 24 characters');
              return;
            }
            if (!RegExp(r'^[A-Za-z0-9 _\-]+$').hasMatch(name)) {
              setLocal(() => error = 'Letters, numbers, spaces, _ and - only');
              return;
            }
            if (_reservedNames.contains(lower)) {
              setLocal(() => error = '"$name" is reserved');
              return;
            }
            final existing = {
              for (final c in _categories) ...[
                c.name.toLowerCase(),
                c.key.toLowerCase(),
              ],
            };
            if (existing.contains(lower)) {
              setLocal(() => error = 'That category already exists');
              return;
            }
            HapticFeedback.selectionClick();
            Navigator.of(ctx).pop(name);
          }

          return AlertDialog(
            title: const Text('New category'),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLength: 24,
              textCapitalization: TextCapitalization.words,
              cursorColor: LiquidColors.indigo,
              onSubmitted: (_) => submit(),
              decoration: InputDecoration(
                hintText: 'e.g. Travel, Work',
                errorText: error,
                counterText: '',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('Cancel',
                    style: TextStyle(color: LiquidColors.textSecondary)),
              ),
              TextButton(
                onPressed: submit,
                child: Text('Create',
                    style: TextStyle(
                        color: LiquidColors.indigo,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _categoryCard(CategoryInfo cat) {
    final count = _countFor(cat);
    final isDefault = cat.isDefault && cat.type != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openCategoryInfo(cat),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpace.sm + 2),
          decoration: BoxDecoration(
            color: LiquidColors.backgroundLight.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: LiquidColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (isDefault)
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LiquidColors.getMediaGradient(cat.type!),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: LiquidColors.getMediaColor(cat.type!)
                            .withValues(alpha: 0.28),
                        blurRadius: 10,
                        spreadRadius: -3,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    cat.type == 'favorite'
                        ? Icons.favorite_rounded
                        : MediaHelper.getMediaIcon(cat.type!),
                    color: Colors.white,
                    size: 20,
                  ),
                )
              else
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: LiquidColors.indigo.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.folder_rounded,
                    color: LiquidColors.indigo,
                    size: 20,
                  ),
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    cat.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: LiquidColors.textPrimary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$count ${count == 1 ? 'item' : 'items'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: LiquidColors.textTertiary,
                      fontSize: 11.5,
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

  Widget _recentCarousel(List<VideoItem> items, double inset) {
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: inset),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) => _recentCard(items[i]),
      ),
    );
  }

  // A circular thumbnail with a subtle indigo ring, a small media-type badge,
  // and the file name beneath — a cleaner, more professional recent item.
  Widget _recentCard(VideoItem m) {
    return GestureDetector(
      onTap: () => _openItem(m),
      child: SizedBox(
        width: 62,
        child: Column(
          children: [
            SizedBox(
              width: 58,
              height: 58,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: LiquidColors.cardBorder),
                    ),
                    child: ClipOval(
                      child: VaultThumbnail(
                        item: m,
                        width: 56,
                        height: 56,
                        radius: 56,
                        iconSize: 22,
                      ),
                    ),
                  ),
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: LiquidColors.indigo,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: LiquidColors.backgroundDeep,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        MediaHelper.getMediaIcon(m.type),
                        color: Colors.white,
                        size: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            Text(
              m.title,
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: LiquidColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _appBarAction(IconData icon, String tooltip, VoidCallback onTap) {
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
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: LiquidColors.textPrimary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: LiquidColors.textPrimary.withValues(alpha: 0.10),
                ),
              ),
              child: Icon(icon, color: LiquidColors.textPrimary, size: 20),
            ),
          ),
        ),
      ),
    );
  }

}
