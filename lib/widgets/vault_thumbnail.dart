import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import 'package:video_player_app/models/app_models.dart';
import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/utils/media_helper.dart';
import 'package:video_player_app/utils/vault_crypto.dart';

/// A rounded media thumbnail for a vault item.
///
/// Images and videos that are not individually locked are decrypted to a temp
/// file (reusing [VaultCrypto.decryptToTemp]'s session cache, wiped on lock);
/// images show a real preview and videos show an extracted first-frame preview
/// (generated once per session and cached in memory). Audio, documents and any
/// locked item show a type-appropriate gradient icon, so a preview never leaks
/// a locked item's contents.
class VaultThumbnail extends StatefulWidget {
  final VideoItem item;
  final double width;
  final double height;
  final double radius;
  final double iconSize;

  const VaultThumbnail({
    super.key,
    required this.item,
    this.width = 54,
    this.height = 54,
    this.radius = 15,
    this.iconSize = 24,
  });

  @override
  State<VaultThumbnail> createState() => _VaultThumbnailState();
}

class _VaultThumbnailState extends State<VaultThumbnail> {
  // Generated video first-frame thumbnails, cached for the session so we only
  // decrypt + extract once per video (keyed by item id).
  static final Map<String, File> _videoThumbCache = {};

  File? _image;

  bool get _isImage => widget.item.type == 'image';
  bool get _isVideo => widget.item.type == 'video';
  bool get _canPreview => (_isImage || _isVideo) && !widget.item.isLocked;

  @override
  void initState() {
    super.initState();
    if (_canPreview) _load();
  }

  @override
  void didUpdateWidget(VaultThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.path != widget.item.path ||
        oldWidget.item.isLocked != widget.item.isLocked) {
      _image = null;
      if (_canPreview) _load();
    }
  }

  Future<void> _load() async {
    try {
      if (_isVideo) {
        await _loadVideoThumb();
        return;
      }
      // Image: decrypt the file and show it directly.
      final path = widget.item.encrypted
          ? await VaultCrypto.instance.decryptToTemp(widget.item.path)
          : widget.item.path;
      final file = File(path);
      if (!mounted) return;
      if (await file.exists()) {
        if (mounted) setState(() => _image = file);
      }
    } catch (_) {
      // Keep the fallback icon on any decrypt/read failure.
    }
  }

  Future<void> _loadVideoThumb() async {
    final cached = _videoThumbCache[widget.item.id];
    if (cached != null && await cached.exists()) {
      if (mounted) setState(() => _image = cached);
      return;
    }
    // Extract a first frame from the (decrypted) video into a temp jpeg.
    final videoPath = widget.item.encrypted
        ? await VaultCrypto.instance.decryptToTemp(widget.item.path)
        : widget.item.path;
    final tmpDir = await getTemporaryDirectory();
    final String? thumbPath = await VideoThumbnail.thumbnailFile(
      video: videoPath,
      thumbnailPath: tmpDir.path,
      imageFormat: ImageFormat.JPEG,
      maxWidth: 256,
      quality: 55,
    );
    if (thumbPath == null) return;
    final thumb = File(thumbPath);
    if (await thumb.exists()) {
      _videoThumbCache[widget.item.id] = thumb;
      if (mounted) setState(() => _image = thumb);
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.item.type;
    final accent = LiquidColors.getMediaColor(type);
    final radius = BorderRadius.circular(widget.radius);
    final dpr = MediaQuery.of(context).devicePixelRatio;

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.28),
            blurRadius: 10,
            spreadRadius: -3,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LiquidColors.getMediaGradient(type),
              ),
            ),
            if (_image != null)
              Image.file(
                _image!,
                fit: BoxFit.cover,
                cacheWidth: (widget.width * dpr).round(),
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => _iconLayer(type),
              )
            else
              _iconLayer(type),
            if (widget.item.isLocked)
              _badge(Icons.lock_rounded)
            else if (type == 'video')
              Center(child: _playBadge()),
          ],
        ),
      ),
    );
  }

  Widget _iconLayer(String type) {
    return Center(
      child: Icon(
        widget.item.isLocked
            ? Icons.lock_rounded
            : MediaHelper.getMediaIcon(type),
        color: Colors.white,
        size: widget.iconSize,
      ),
    );
  }

  Widget _playBadge() {
    final d = widget.iconSize + 10;
    return Container(
      width: d,
      height: d,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.play_arrow_rounded,
        color: Colors.white,
        size: widget.iconSize,
      ),
    );
  }

  Widget _badge(IconData icon) {
    return Positioned(
      right: 5,
      bottom: 5,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.42),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 11),
      ),
    );
  }
}
