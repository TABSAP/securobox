import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/widgets/liquid_glass_surface.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoPath;
  final String videoTitle;

  const VideoPlayerScreen({
    super.key,
    required this.videoPath,
    required this.videoTitle,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _videoPlayerController;
  bool _isInitialized = false;
  bool _isFullScreen = false;
  bool _showOverlay = true;
  double _playbackSpeed = 1.0;
  String? _errorDetail;

  final List<double> _playbackSpeeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    _videoPlayerController.dispose();
    super.dispose();
  }

  Future<void> _initializeVideoPlayer() async {
    _videoPlayerController = VideoPlayerController.file(File(widget.videoPath));

    try {
      await _videoPlayerController.initialize();

      if (!mounted) {
        _videoPlayerController.dispose();
        return;
      }

      await _videoPlayerController.setLooping(false);
      setState(() {
        _isInitialized = true;
      });

      // Start playback immediately — the UI renders a raw VideoPlayer with
      // custom controls, so the controller must be told to play directly.
      await _videoPlayerController.play();
      _hideOverlayAfterDelay();
    } catch (_) {
      _errorDetail =
          'Unable to play this file. It may be in an unsupported format.';
      if (mounted) {
        _showErrorDialog();
      }
    }
  }

  void _togglePlayPause() {
    if (_videoPlayerController.value.isPlaying) {
      _videoPlayerController.pause();
    } else {
      _videoPlayerController.play();
    }
    setState(() {
      _showOverlay = true;
    });
    _hideOverlayAfterDelay();
  }

  void _seekForward() {
    final value = _videoPlayerController.value;
    final target = value.position + const Duration(seconds: 10);
    _videoPlayerController.seekTo(
      target > value.duration ? value.duration : target,
    );
    _showSeekOverlay('+10s');
  }

  void _seekBackward() {
    final target =
        _videoPlayerController.value.position - const Duration(seconds: 10);
    _videoPlayerController.seekTo(target.isNegative ? Duration.zero : target);
    _showSeekOverlay('-10s');
  }

  void _changePlaybackSpeed(double speed) {
    setState(() {
      _playbackSpeed = speed;
      _videoPlayerController.setPlaybackSpeed(speed);
    });
    _showSpeedOverlay('${speed}x');
  }

  void _showSeekOverlay(String text) {
    setState(() {
      _showOverlay = true;
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _showOverlay = false;
        });
      }
    });
  }

  void _showSpeedOverlay(String text) {
    setState(() {
      _showOverlay = true;
    });

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          _showOverlay = false;
        });
      }
    });
  }

  void _showErrorDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        bool showDetails = false;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => Dialog(
            backgroundColor: LiquidColors.backgroundLight,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.videocam_off_rounded,
                      color: Colors.red,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Can\'t play this video',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: LiquidColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'This file may be damaged or in a format that isn\'t '
                    'supported.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: LiquidColors.textSecondary,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  if (showDetails) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 200),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: LiquidColors.textPrimary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          _errorDetail ?? 'No additional details.',
                          style: TextStyle(
                            color: LiquidColors.textTertiary,
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () =>
                        setDialogState(() => showDetails = !showDetails),
                    child: Text(
                      showDetails
                          ? 'Hide technical details'
                          : 'Show technical details',
                      style: const TextStyle(
                        color: Color(0xFF6366F1),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        if (mounted) Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _toggleFullScreen() {
    if (_isFullScreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }

    setState(() {
      _isFullScreen = !_isFullScreen;
      _showOverlay = true;
    });

    _hideOverlayAfterDelay();
  }

  void _hideOverlayAfterDelay() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _videoPlayerController.value.isPlaying) {
        setState(() {
          _showOverlay = false;
        });
      }
    });
  }

  Widget _buildCustomControls() {
    return IgnorePointer(
      ignoring: !_showOverlay,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
        opacity: _showOverlay ? 1 : 0,
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0, .22, .55, 1],
                      colors: [
                        Colors.black.withValues(alpha: .78),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withValues(alpha: .82),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 14,
              right: 14,
              child: Row(
                children: [
                  _playerIconButton(Icons.arrow_back_rounded, () {
                    if (_isFullScreen) {
                      SystemChrome.setPreferredOrientations([
                        DeviceOrientation.portraitUp,
                        DeviceOrientation.portraitDown,
                      ]);
                    }
                    Navigator.pop(context);
                  }, tooltip: 'Back'),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LiquidGlassSurface(
                      borderRadius: 18,
                      blur: 22,
                      tintColor: Colors.black,
                      tintOpacity: 0.12,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Text(
                        widget.videoTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  PopupMenuButton<String>(
                    tooltip: 'More video options',
                    onSelected: (value) {
                      if (value == 'speed') _showPlaybackSpeedDialog();
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'speed',
                        child: Row(
                          children: [
                            const Icon(Icons.speed_rounded, size: 20),
                            const SizedBox(width: 10),
                            Text('Playback speed · ${_playbackSpeed}x'),
                          ],
                        ),
                      ),
                    ],
                    child: _playerIconButton(
                      Icons.more_horiz_rounded,
                      null,
                      tooltip: 'More options',
                    ),
                  ),
                ],
              ),
            ),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _seekControl(
                    Icons.replay_10_rounded,
                    '−10 sec',
                    _seekBackward,
                  ),
                  const SizedBox(width: 24),
                  ValueListenableBuilder<VideoPlayerValue>(
                    valueListenable: _videoPlayerController,
                    builder: (context, value, _) => AnimatedScale(
                      scale: value.isPlaying ? .94 : 1,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutBack,
                      child: LiquidGlassSurface(
                        borderRadius: 50,
                        blur: 24,
                        tintColor: LiquidColors.accentBlue,
                        tintOpacity: 0.48,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _togglePlayPause,
                            child: SizedBox(
                              width: 74,
                              height: 74,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                transitionBuilder: (child, animation) =>
                                    ScaleTransition(
                                      scale: animation,
                                      child: child,
                                    ),
                                child: Icon(
                                  value.isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  key: ValueKey(value.isPlaying),
                                  color: Colors.white,
                                  size: 38,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  _seekControl(
                    Icons.forward_10_rounded,
                    '+10 sec',
                    _seekForward,
                  ),
                ],
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 12,
              child: LiquidGlassSurface(
                borderRadius: 22,
                blur: 24,
                tintColor: Colors.black,
                tintOpacity: 0.16,
                padding: const EdgeInsets.fromLTRB(16, 11, 12, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    VideoProgressIndicator(
                      _videoPlayerController,
                      allowScrubbing: true,
                      colors: const VideoProgressColors(
                        playedColor: Color(0xFF818CF8),
                        bufferedColor: Colors.white38,
                        backgroundColor: Colors.white24,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: ValueListenableBuilder<VideoPlayerValue>(
                            valueListenable: _videoPlayerController,
                            builder: (context, value, _) => Text(
                              '${_formatDuration(value.position)}  /  ${_formatDuration(value.duration)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                        ),
                        _playerPill(
                          Icons.speed_rounded,
                          '${_playbackSpeed}x',
                          _showPlaybackSpeedDialog,
                        ),
                        const SizedBox(width: 8),
                        _playerIconButton(
                          _isFullScreen
                              ? Icons.fullscreen_exit_rounded
                              : Icons.fullscreen_rounded,
                          _toggleFullScreen,
                          tooltip: _isFullScreen
                              ? 'Exit full screen'
                              : 'Full screen',
                          compact: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _playerIconButton(
    IconData icon,
    VoidCallback? onTap, {
    required String tooltip,
    bool compact = false,
  }) => Tooltip(
    message: tooltip,
    child: LiquidGlassSurface(
      borderRadius: compact ? 22 : 24,
      blur: 20,
      tintColor: Colors.black,
      tintOpacity: 0.12,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: compact ? 40 : 44,
            height: compact ? 40 : 44,
            child: Icon(icon, color: Colors.white, size: compact ? 21 : 23),
          ),
        ),
      ),
    ),
  );

  Widget _seekControl(IconData icon, String label, VoidCallback onTap) =>
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LiquidGlassSurface(
            borderRadius: 28,
            blur: 18,
            tintColor: Colors.black,
            tintOpacity: 0.1,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: SizedBox(
                  width: 54,
                  height: 54,
                  child: Icon(icon, color: Colors.white, size: 29),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .88),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );

  Widget _playerPill(IconData icon, String label, VoidCallback onTap) =>
      LiquidGlassSurface(
        borderRadius: 20,
        blur: 18,
        tintColor: Colors.black,
        tintOpacity: 0.1,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 15, color: Colors.white),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  void _showPlaybackSpeedDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      isScrollControlled: true,
      builder: (sheetContext) => LiquidGlassSurface(
        borderRadius: 26,
        blur: 24,
        padding: EdgeInsets.zero,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: LiquidColors.textTertiary.withValues(alpha: .45),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: LiquidColors.indigo.withValues(alpha: .13),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.speed_rounded,
                        color: LiquidColors.indigo,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Playback speed',
                            style: TextStyle(
                              color: LiquidColors.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Choose a comfortable pace',
                            style: TextStyle(
                              color: LiquidColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: LiquidColors.indigo.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        '${_playbackSpeed}x',
                        style: TextStyle(
                          color: LiquidColors.indigo,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.3,
                  ),
                  itemCount: _playbackSpeeds.length,
                  itemBuilder: (context, index) {
                    final speed = _playbackSpeeds[index];
                    final isSelected = _playbackSpeed == speed;
                    return LiquidGlassSurface(
                      borderRadius: 14,
                      blur: 14,
                      tintColor: isSelected ? LiquidColors.accentBlue : null,
                      tintOpacity: isSelected ? 0.22 : 0,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            _changePlaybackSpeed(speed);
                            Navigator.pop(sheetContext);
                          },
                          child: Center(
                            child: Text(
                              '${speed}x',
                              style: TextStyle(
                                color: isSelected
                                    ? LiquidColors.accentBlue
                                    : LiquidColors.textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
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

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0
        ? '$hours:$minutes:$seconds'
        : '$minutes:$seconds';
  }

  Widget _buildVideoPlayer() {
    if (!_isInitialized) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF6366F1), strokeWidth: 3),
            SizedBox(height: 20),
            Text(
              'Loading Video...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _showOverlay = !_showOverlay;
        });
        if (_showOverlay && _videoPlayerController.value.isPlaying) {
          _hideOverlayAfterDelay();
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: _videoPlayerController.value.size.width,
                height: _videoPlayerController.value.size.height,
                child: VideoPlayer(_videoPlayerController),
              ),
            ),
          ),

          _buildCustomControls(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Keep letterbox/system inset areas dark while the video fills the
      // player viewport, so no white bands flash around a portrait clip.
      backgroundColor: Colors.black,
      body: _buildVideoPlayerWithOrientationHandler(),
    );
  }

  Widget _buildVideoPlayerWithOrientationHandler() {
    return PopScope(
      onPopInvokedWithResult: (text, _) async {
        if (_isFullScreen) {
          await SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
          ]);
        }
        return;
      },
      child: OrientationBuilder(
        builder: (context, orientation) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _buildVideoPlayerContent(),
          );
        },
      ),
    );
  }

  Widget _buildVideoPlayerContent() {
    if (_isFullScreen) {
      return Stack(
        fit: StackFit.expand,
        children: [
          _buildVideoPlayer(),

          if (_showOverlay)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 10,
              child: GestureDetector(
                onTap: _toggleFullScreen,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.fullscreen_exit_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
        ],
      );
    } else {
      return _buildVideoPlayer();
    }
  }
}
