import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:video_player_app/models/app_models.dart';
import 'package:video_player_app/notifications_screen/notification_preview_sheet.dart';
import 'package:video_player_app/services/media_service.dart';
import 'package:video_player_app/utils/app_rating.dart';
import 'package:video_player_app/utils/category_service.dart';
import 'package:video_player_app/utils/category_style.dart';
import 'package:video_player_app/utils/flush_bar_helper.dart';
import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/utils/media_helper.dart';
import 'package:video_player_app/utils/media_opener.dart';
import 'package:video_player_app/utils/media_importer.dart';
import 'package:video_player_app/utils/notification_service.dart';
import 'package:video_player_app/utils/responsive.dart';
import 'package:video_player_app/utils/session_manager.dart';
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
  /// The dashboard grid stays compact: only the first six categories (in the
  /// user's chosen order) are shown. The rest — including any custom categories
  /// they create — are reachable via "View all" / "Manage".
  static const int _dashboardCategoryLimit = 6;

  final MediaService _mediaService = MediaService();
  final TextEditingController _searchController = TextEditingController();
  List<VideoItem> _all = const [];
  // Visible categories (defaults + custom) in the user's chosen order.
  List<CategoryInfo> _categories = const [];
  bool _loading = true;
  String _query = '';
  // Items sitting in the Recycle Bin, shown as a badge on the bin icon.
  int _deletedCount = 0;

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
    // Same filter the Recycle Bin uses, so the badge always matches its list.
    final deleted = await _mediaService.getDeletedMedia();
    final deletedCount = deleted.where((m) => !m.isHidden).length;
    if (!mounted) return;
    setState(() {
      _all = media;
      _categories = cats.where((c) => !c.hidden).toList();
      _deletedCount = deletedCount;
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

  Future<void> _openItem(VideoItem item) async {
    HapticFeedback.selectionClick();
    // Open the viewer directly on top of the dashboard so Back returns here
    // (to Recently Added) instead of a filtered list the user never opened.
    await openVaultMedia(context, item, onChanged: _load);
  }

  void _openRecent() {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const HomeScreen(screenTitle: 'Recently Added'),
      ),
    );
  }

  Widget _seeAll(VoidCallback onTap, {String label = 'View all'}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: LiquidColors.indigo,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: LiquidColors.indigo,
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

  Future<void> _openRecycleBin() async {
    HapticFeedback.lightImpact();
    await Navigator.push(
      context,
      MaterialPageRoute(
        // Restoring or permanently deleting changes the bin count — reload so
        // the badge on the bin icon stays accurate.
        builder: (_) => DeletedVideosScreen(onVideosChanged: _load),
      ),
    );
    if (mounted) _load();
  }

  void _openNotifications() {
    HapticFeedback.lightImpact();
    NotificationPreviewSheet.show(context);
  }

  /// A small red count bubble, anchored to the top-right of an app-bar action.
  Widget _countBadge(int count) {
    return Positioned(
      right: 4,
      top: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
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
    );
  }

  Widget _recycleBinAction() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _appBarAction(
          Icons.delete_outline_rounded,
          'Recycle Bin',
          _openRecycleBin,
        ),
        if (_deletedCount > 0) _countBadge(_deletedCount),
      ],
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
            if (count > 0) _countBadge(count),
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
        systemOverlayStyle: LiquidColors.systemOverlayStyle,
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
          _recycleBinAction(),
          const SizedBox(width: 12),
        ],
      ),
      floatingActionButton: _importFab(),
      body: _body(),
    );
  }

  Widget _body() {
    final inset = context.contentInset(phone: 16);
    // The screen chrome renders immediately; a small loader fills the content
    // area while the library loads, so arriving here (e.g. straight after a
    // fingerprint/Face ID unlock) never looks like the app has frozen.
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(inset, 0, inset, AppSpace.sm),
          child: _searchBar(),
        ),
        Expanded(
          child: _loading
              ? const Center(child: AppLoader(size: 34))
              : _query.isNotEmpty
                  ? _searchResults(inset)
                  : _dashboardContent(inset),
        ),
      ],
    );
  }

  Widget _dashboardContent(double inset) {
    // Latest 10 only — a rolling FIFO window over the (newest-first) library,
    // so importing an 11th file pushes the oldest entry out of Recently Added.
    // This only trims the displayed list; the files stay stored in their
    // categories and are never deleted.
    final recent = _all.take(10).toList();
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(bottom: AppSpace.xl + 40),
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
        // Categories — the dashboard shows only the first six (in the user's
        // chosen order) to stay compact. Everything else, including custom
        // categories the user creates, lives behind "View all" / "Manage".
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
                  for (final c in _categories.take(_dashboardCategoryLimit))
                    _categoryCard(c),
                ],
              ),
              if (_categories.length > _dashboardCategoryLimit) ...[
                const SizedBox(height: AppSpace.sm),
                Center(
                  child: _seeAll(
                    _openManageCategories,
                    label: 'View all ${_categories.length} categories',
                  ),
                ),
              ],
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

  // FAB to import files: pick files → choose a category → save into it.
  Widget _importFab() {
    return FloatingActionButton.extended(
      onPressed: _importFlow,
      backgroundColor: LiquidColors.indigo,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.file_download_outlined),
      label: const Text(
        'Import',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }

  Future<void> _importFlow() async {
    HapticFeedback.lightImpact();
    // 1) Open the device file picker directly.
    final items = <PickedMedia>[];
    SessionManager.instance.beginTrustedInteraction();
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
        withData: false,
      );
      if (result == null) return;
      for (final pf in result.files) {
        final path = pf.path;
        if (path != null && await File(path).exists()) {
          items.add(PickedMedia(
            File(path),
            identifier: pf.identifier,
            originalName: pf.name,
            origin: 'file',
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        FlushBarHelper.flushBarErrorMessage('Couldn\'t read files: $e', context);
      }
      return;
    } finally {
      SessionManager.instance.endTrustedInteraction();
    }

    if (items.isEmpty || !mounted) return;

    // 2) Encrypt + import. Each file's category is auto-detected from its type
    // (video/image/document) — no manual picker.
    await _runImportInto(items, null);
  }

  Future<void> _runImportInto(List<PickedMedia> items, String? category) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: AppLoader(
          size: 56,
          label: 'Encrypting ${items.length} file${items.length == 1 ? '' : 's'}…',
        ),
      ),
    );
    SessionManager.instance.beginTrustedInteraction();
    ImportResult? res;
    try {
      res = await MediaImporter.instance.importFiles(
        items: items,
        category: category,
      );
    } catch (_) {
      // fall through to error handling below
    } finally {
      SessionManager.instance.endTrustedInteraction();
    }

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // dismiss loader
    await _load();
    if (!mounted) return;

    if (res != null && res.added > 0) {
      FlushBarHelper.flushBarSuccessMessage(
        '${res.added} file${res.added == 1 ? '' : 's'} added to ${category ?? 'your vault'}',
        context,
      );
      unawaited(NotificationService.instance.addEvent(
        title: 'Files added to your vault',
        body: '${res.added} file${res.added == 1 ? '' : 's'} were encrypted and added.',
        kind: 'info',
      ));
      AppRating.recordImportAndMaybeAsk();
    } else {
      FlushBarHelper.flushBarErrorMessage(
        'Nothing was imported',
        context,
      );
    }
  }

  Widget _categoryCard(CategoryInfo cat) {
    final count = _countFor(cat);
    final isDefault = cat.isDefault && cat.type != null;
    final color = CategoryStyle.forCategory(cat.name);
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
              // Minimal icon tile tinted with the category colour — a small,
              // consistent splash of colour that keeps the grid clean.
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isDefault
                      ? (cat.type == 'favorite'
                          ? Icons.favorite_rounded
                          : MediaHelper.getMediaIcon(cat.type!))
                      : Icons.folder_rounded,
                  color: color,
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
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: inset),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (_, i) => _recentCard(items[i]),
      ),
    );
  }

  // A compact rounded-square thumbnail — the real image/video frame (or a type
  // icon) with the file name beneath. No coloured ring.
  Widget _recentCard(VideoItem m) {
    const double size = 62;
    return GestureDetector(
      onTap: () => _openItem(m),
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            VaultThumbnail(
              item: m,
              width: size,
              height: size,
              radius: 14,
              iconSize: 24,
            ),
            const SizedBox(height: 7),
            Text(
              m.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: LiquidColors.textSecondary,
                fontSize: 10.5,
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
