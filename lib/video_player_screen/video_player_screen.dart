import 'dart:io';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_app/utils/vault_crypto.dart';

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
  ChewieController? _chewieController;
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
    _chewieController?.dispose();
    super.dispose();
  }

  Future<void> _initializeVideoPlayer() async {
    _videoPlayerController = VideoPlayerController.file(File(widget.videoPath));

    try {
      await _videoPlayerController.initialize();

      if (mounted) {
        _chewieController = ChewieController(
          videoPlayerController: _videoPlayerController,
          autoPlay: true,
          looping: false,
          allowFullScreen: true,
          fullScreenByDefault: false,
          deviceOrientationsAfterFullScreen: [
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ],
          showControls: false,
          materialProgressColors: ChewieProgressColors(
            playedColor: const Color(0xFF4788FF),
            handleColor: const Color(0xFF4788FF),
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            bufferedColor: Colors.white.withValues(alpha: 0.1),
          ),
          placeholder: Container(
            color: const Color(0xFF0A0A1F),
            child: const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF4788FF),
              ),
            ),
          ),
          overlay: Container(),
          autoInitialize: true,
        );

        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e, st) {
      String fileInfo = 'File: ${widget.videoPath}';
      try {
        final f = File(widget.videoPath);
        if (await f.exists()) {
          final size = await f.length();
          final raf = await f.open();
          final head = await raf.read(16);
          await raf.close();
          final hex = head
              .map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join(' ');
          fileInfo = 'File: ${widget.videoPath}\nSize: $size bytes\nHead: $hex';
        } else {
          fileInfo = 'File: ${widget.videoPath}\n(file does not exist)';
        }
      } catch (_) {}
      final selfTest =
          'Crypto self-test: ${VaultCrypto.lastSelfTestResult ?? "not run"}';
      _errorDetail = '$e\n\n$fileInfo\n\n$selfTest\n\n$st';
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
    final currentPosition = _videoPlayerController.value.position;
    final newPosition = currentPosition + const Duration(seconds: 10);
    _videoPlayerController.seekTo(newPosition);
    _showSeekOverlay('+10s');
  }

  void _seekBackward() {
    final currentPosition = _videoPlayerController.value.position;
    final newPosition = currentPosition - const Duration(seconds: 10);
    _videoPlayerController.seekTo(newPosition);
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
            backgroundColor: const Color(0xFF1A1A3E),
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
                  const Text(
                    'Can\'t play this video',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'This file may be damaged or in a format that isn\'t '
                    'supported.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
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
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          _errorDetail ?? 'No additional details.',
                          style: const TextStyle(
                            color: Colors.white54,
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
                        color: Color(0xFF4788FF),
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
                        backgroundColor: const Color(0xFF4788FF),
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
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: _showOverlay ? 1.0 : 0.0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.7),
              Colors.transparent,
              Colors.transparent,
              Colors.black.withValues(alpha: 0.7),
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [

            Container(
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.of(context).padding.top + 10,
                20,
                10,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [

                  GestureDetector(
                    onTap: () {

                      if (_isFullScreen) {
                        SystemChrome.setPreferredOrientations([
                          DeviceOrientation.portraitUp,
                          DeviceOrientation.portraitDown,
                        ]);
                      }
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),

                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        widget.videoTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'speed') {
                        _showPlaybackSpeedDialog();
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'speed',
                        child: Row(
                          children: [
                            const Icon(Icons.speed, size: 20),
                            const SizedBox(width: 8),
                            Text('Playback Speed (${_playbackSpeed}x)'),
                          ],
                        ),
                      ),
                    ],
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.more_vert_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [

                    GestureDetector(
                      onTap: _seekBackward,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.replay_10_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),

                    GestureDetector(
                      onTap: _togglePlayPause,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4788FF),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF4788FF,
                              ).withValues(alpha: 0.35),
                              blurRadius: 22,
                              spreadRadius: -4,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ValueListenableBuilder<VideoPlayerValue>(
                          valueListenable: _videoPlayerController,
                          builder: (context, value, _) => Icon(
                            value.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                    ),

                    GestureDetector(
                      onTap: _seekForward,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.forward_10_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Container(
              padding: EdgeInsets.fromLTRB(
                20,
                10,
                20,
                MediaQuery.of(context).padding.bottom + 10,
              ),
              child: Column(
                children: [

                  VideoProgressIndicator(
                    _videoPlayerController,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      playedColor: Color(0xFF4788FF),
                      bufferedColor: Colors.white30,
                      backgroundColor: Colors.white24,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [

                      ValueListenableBuilder<VideoPlayerValue>(
                        valueListenable: _videoPlayerController,
                        builder: (context, value, _) => Text(
                          '${_formatDuration(value.position)}  /  '
                          '${_formatDuration(value.duration)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),

                      Row(
                        children: [

                          GestureDetector(
                            onTap: () => _showPlaybackSpeedDialog(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${_playbackSpeed}x',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          GestureDetector(
                            onTap: _toggleFullScreen,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(
                                _isFullScreen
                                    ? Icons.fullscreen_exit_rounded
                                    : Icons.fullscreen_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPlaybackSpeedDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A3E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Playback Speed',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.0,
              ),
              itemCount: _playbackSpeeds.length,
              itemBuilder: (context, index) {
                final speed = _playbackSpeeds[index];
                final isSelected = _playbackSpeed == speed;
                return GestureDetector(
                  onTap: () {
                    _changePlaybackSpeed(speed);
                    Navigator.pop(context);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF4788FF)
                          : const Color(0xFF141432),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF4788FF)
                            : Colors.white.withValues(alpha: 0.1),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${speed}x',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey.shade400,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
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
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  Widget _buildVideoPlayer() {
    if (!_isInitialized) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Color(0xFF4788FF),
              strokeWidth: 3,
            ),
            SizedBox(height: 20),
            Text(
              'Loading Video...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    final videoAspectRatio = _videoPlayerController.value.aspectRatio;
    final screenSize = MediaQuery.of(context).size;
    final screenAspectRatio = screenSize.width / screenSize.height;

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

          Center(
            child: AspectRatio(
              aspectRatio: videoAspectRatio > 0
                  ? videoAspectRatio
                  : screenAspectRatio,
              child: VideoPlayer(_videoPlayerController),
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
      backgroundColor: Colors.black,
      body: _buildVideoPlayerWithOrientationHandler(),
    );
  }

  Widget _buildVideoPlayerWithOrientationHandler() {
    return PopScope(
      onPopInvokedWithResult: (text, _)async{
        if (_isFullScreen) {
          await SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
          ]);
        }
        return ;
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

      return SafeArea(
        top: true,
        bottom: true,
        left: true,
        right: true,
        child: _buildVideoPlayer(),
      );
    }
  }
}
