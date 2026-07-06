import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:video_player_app/models/app_models.dart';
import 'package:video_player_app/services/media_service.dart';
import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/utils/media_helper.dart';
import 'package:video_player_app/utils/responsive.dart';
import 'package:video_player_app/views/screens/deleted_video_screen/deleted_video_screen.dart';
import 'package:video_player_app/views/screens/home_screen/home_screen.dart';
import 'package:video_player_app/views/screens/home_screen/widgets/add_to_vault_sheet.dart';
import 'package:video_player_app/views/screens/home_screen/widgets/liquid_animations/liquid_background.dart';
import 'package:video_player_app/views/screens/secure_camera/secure_camera_screen.dart';
import 'package:video_player_app/widgets/app_empty_state.dart';
import 'package:video_player_app/widgets/app_section_header.dart';
import 'package:video_player_app/widgets/app_spacing.dart';

class _Cat {
  final String type;
  final String label;
  const _Cat(this.type, this.label);
}

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => HomeDashboardState();
}

class HomeDashboardState extends State<HomeDashboard> {
  static const List<_Cat> _cats = [
    _Cat('video', 'Videos'),
    _Cat('image', 'Images'),
    _Cat('audio', 'Audio'),
    _Cat('document', 'Documents'),
    _Cat('other', 'Files'),
  ];

  final MediaService _mediaService = MediaService();
  List<VideoItem> _all = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    MediaService.revision.addListener(_onRevision);
  }

  @override
  void dispose() {
    MediaService.revision.removeListener(_onRevision);
    super.dispose();
  }

  void _onRevision() {
    if (mounted) _load();
  }

  Future<void> refresh() => _load();

  Future<void> _load() async {
    final media = await _mediaService.loadMedia();
    if (!mounted) return;
    setState(() {
      _all = media;
      _loading = false;
    });
  }

  int _countFor(String type) => _all.where((m) => m.type == type).length;

  void _openCategory(String type) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HomeScreen(typeFilter: type)),
    );
  }

  void _openItem(VideoItem item) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HomeScreen(typeFilter: item.type, autoOpen: item),
      ),
    );
  }

  Future<void> _openAddSheet() async {
    HapticFeedback.lightImpact();
    await AddToVaultSheet.show(context, onImported: () async {});
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: LiquidColors.backgroundDeep,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
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
          _appBarAction(Icons.photo_camera_rounded, 'Secure Camera', _openSecureCamera),
          const SizedBox(width: 10),
          _appBarAction(Icons.delete_outline_rounded, 'Recycle Bin', _openRecycleBin),
          const SizedBox(width: 12),
        ],
      ),
      floatingActionButton: _fab(),
      body: LiquidBackground(child: _body()),
    );
  }

  Widget _body() {
    if (_loading) {
      return Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: LiquidColors.accentBlue,
          ),
        ),
      );
    }
    if (_all.isEmpty) {
      return AppEmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Your vault is empty',
        message:
            'Files you import are encrypted and stored only on this device — '
            'never in the cloud.',
        actionLabel: 'Add your first file',
        onAction: _openAddSheet,
      );
    }

    final recent = _all.take(8).toList();
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        context.contentInset(phone: 16),
        AppSpace.md,
        context.contentInset(phone: 16),
        AppSpace.xl + 40,
      ),
      children: [
        const AppSectionHeader(label: 'Categories'),
        const SizedBox(height: AppSpace.sm),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: AppSpace.sm + 2,
          crossAxisSpacing: AppSpace.sm + 2,
          childAspectRatio: 1.25,
          children: [for (final c in _cats) _categoryCard(c)],
        ),
        const SizedBox(height: AppSpace.lg),
        const AppSectionHeader(label: 'Recently added'),
        const SizedBox(height: AppSpace.sm),
        _recentGroup(recent),
      ],
    );
  }

  Widget _categoryCard(_Cat cat) {
    final count = _countFor(cat.type);
    final color = LiquidColors.getMediaColor(cat.type);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openCategory(cat.type),
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
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LiquidColors.getMediaGradient(cat.type),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.28),
                      blurRadius: 10,
                      spreadRadius: -3,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  MediaHelper.getMediaIcon(cat.type),
                  color: Colors.white,
                  size: 20,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    cat.label,
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

  Widget _recentGroup(List<VideoItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: LiquidColors.backgroundLight.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: LiquidColors.cardBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 66),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: LiquidColors.textPrimary.withValues(alpha: 0.05),
                  ),
                ),
              _recentTile(items[i]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _recentTile(VideoItem m) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openItem(m),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.sm + 2),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LiquidColors.getMediaGradient(m.type),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  MediaHelper.getMediaIcon(m.type),
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                      '${m.type.toUpperCase()}  ·  ${MediaHelper.formatDate(m.id)}',
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
              Icon(
                Icons.chevron_right_rounded,
                color: LiquidColors.textTertiary,
                size: 22,
              ),
            ],
          ),
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
                color: LiquidColors.textPrimary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: LiquidColors.textPrimary.withValues(alpha: 0.08),
                ),
              ),
              child: Icon(icon, color: LiquidColors.textPrimary, size: 20),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fab() {
    return GestureDetector(
      onTap: _openAddSheet,
      child: Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [LiquidColors.accentBlue, LiquidColors.accentPurple],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: LiquidColors.accentBlue.withValues(alpha: 0.4),
              blurRadius: 18,
              spreadRadius: -2,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}
