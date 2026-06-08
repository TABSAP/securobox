import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';

import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/utils/session_manager.dart';

/// In-app gallery picker built on photo_manager.
///
/// Unlike the system file picker, this gives us the real [AssetEntity] (with its
/// id), so after a file is encrypted into the vault its original can be removed
/// from the gallery reliably — the whole point of "move into vault". Returns the
/// selected assets, or null if cancelled.
class SecureMediaPickerScreen extends StatefulWidget {
  final RequestType type;
  final String title;

  const SecureMediaPickerScreen({
    super.key,
    required this.type,
    required this.title,
  });

  static Future<List<AssetEntity>?> show(
    BuildContext context, {
    required RequestType type,
    required String title,
  }) {
    return Navigator.of(context).push<List<AssetEntity>>(
      MaterialPageRoute(
        builder: (_) => SecureMediaPickerScreen(type: type, title: title),
      ),
    );
  }

  @override
  State<SecureMediaPickerScreen> createState() =>
      _SecureMediaPickerScreenState();
}

class _SecureMediaPickerScreenState extends State<SecureMediaPickerScreen> {
  static const _pageSize = 60;

  final ScrollController _scroll = ScrollController();
  final List<AssetEntity> _assets = [];
  final List<AssetEntity> _selected = [];

  AssetPathEntity? _album;
  int _page = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _denied = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _init();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    // Picking sends us through the OS permission sheet — mark it trusted so the
    // app doesn't auto-lock and strand the picker behind the lock screen.
    SessionManager.instance.beginTrustedInteraction();
    try {
      final ps = await PhotoManager.requestPermissionExtend();
      if (!ps.hasAccess) {
        if (mounted) setState(() => _denied = true);
        return;
      }
      final albums = await PhotoManager.getAssetPathList(
        type: widget.type,
        hasAll: true,
      );
      if (albums.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      _album = albums.firstWhere((a) => a.isAll, orElse: () => albums.first);
      await _loadMore(initial: true);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    } finally {
      SessionManager.instance.endTrustedInteraction();
    }
  }

  void _onScroll() {
    if (_scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 600) {
      _loadMore();
    }
  }

  Future<void> _loadMore({bool initial = false}) async {
    if (_album == null || _loadingMore || (!_hasMore && !initial)) return;
    _loadingMore = true;
    try {
      final batch = await _album!.getAssetListPaged(page: _page, size: _pageSize);
      if (!mounted) return;
      setState(() {
        _assets.addAll(batch);
        _page++;
        _hasMore = batch.length == _pageSize;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    } finally {
      _loadingMore = false;
    }
  }

  void _toggle(AssetEntity asset) {
    HapticFeedback.selectionClick();
    setState(() {
      final i = _selected.indexWhere((a) => a.id == asset.id);
      if (i >= 0) {
        _selected.removeAt(i);
      } else {
        _selected.add(asset);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LiquidColors.backgroundDeep,
      appBar: AppBar(
        backgroundColor: LiquidColors.backgroundDeep,
        elevation: 0,
        title: Text(
          widget.title,
          style: TextStyle(
            color: LiquidColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: IconThemeData(color: LiquidColors.textPrimary),
      ),
      body: _buildBody(),
      bottomNavigationBar: _selected.isEmpty ? null : _buildAddBar(),
    );
  }

  Widget _buildBody() {
    if (_denied) return _buildDenied();
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: LiquidColors.accentBlue),
      );
    }
    if (_assets.isEmpty) {
      return Center(
        child: Text(
          'Nothing here yet',
          style: TextStyle(color: LiquidColors.textSecondary, fontSize: 15),
        ),
      );
    }
    return GridView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(3),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 3,
        mainAxisSpacing: 3,
      ),
      itemCount: _assets.length,
      itemBuilder: (context, index) => _tile(_assets[index]),
    );
  }

  Widget _tile(AssetEntity asset) {
    final selIndex = _selected.indexWhere((a) => a.id == asset.id);
    final selected = selIndex >= 0;
    return GestureDetector(
      onTap: () => _toggle(asset),
      child: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder<Uint8List?>(
            future: asset.thumbnailDataWithSize(
              const ThumbnailSize.square(220),
            ),
            builder: (context, snap) {
              if (snap.data == null) {
                return Container(color: LiquidColors.backgroundLight);
              }
              return Image.memory(snap.data!, fit: BoxFit.cover);
            },
          ),
          if (asset.type == AssetType.video || asset.type == AssetType.audio)
            Positioned(
              right: 4,
              bottom: 4,
              child: Icon(
                asset.type == AssetType.video
                    ? Icons.videocam_rounded
                    : Icons.music_note_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          if (selected)
            Container(color: LiquidColors.accentBlue.withValues(alpha: 0.35)),
          Positioned(
            top: 4,
            left: 4,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? LiquidColors.accentBlue
                    : Colors.black.withValues(alpha: 0.35),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: selected
                  ? Center(
                      child: Text(
                        '${selIndex + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(_selected),
            style: ElevatedButton.styleFrom(
              backgroundColor: LiquidColors.accentBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              'Add ${_selected.length} to vault',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_library_outlined,
              color: LiquidColors.textSecondary,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Media access needed',
              style: TextStyle(
                color: LiquidColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'To move photos and videos into your vault — and remove the '
              'originals from your gallery — SecuroBox needs access to your '
              'media. You can grant it in Settings.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: LiquidColors.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => PhotoManager.openSetting(),
              style: ElevatedButton.styleFrom(
                backgroundColor: LiquidColors.accentBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      ),
    );
  }
}
