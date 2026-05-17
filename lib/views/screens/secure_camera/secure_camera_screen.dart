import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';

import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/utils/media_importer.dart';

/// Direct Secure Capture — take a photo or video, review it, and only commit
/// it to the encrypted vault when the user taps **Save**. A discarded capture
/// is wiped and never reaches the vault or the device gallery.
class SecureCameraScreen extends StatefulWidget {
  const SecureCameraScreen({super.key});

  @override
  State<SecureCameraScreen> createState() => _SecureCameraScreenState();
}

enum _CaptureMode { photo, video }

class _SecureCameraScreenState extends State<SecureCameraScreen>
    with WidgetsBindingObserver {
  static const Color _recColor = Color(0xFFE5484D);

  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  bool _initializing = true;
  bool _capturing = false;
  int _savedCount = 0;
  String? _error;

  // Transient red banner shown when a capture or save fails.
  String? _captureError;
  // Transient green confirmation shown on the camera after a successful save.
  bool _justSaved = false;

  _CaptureMode _mode = _CaptureMode.photo;
  bool _recording = false;
  bool _micGranted = false;
  Timer? _recordTimer;
  int _recordSeconds = 0;

  // Review state — the just-captured file, held only in temp. It is NOT in the
  // vault yet; it lands there only if the user taps Save, and is wiped if the
  // user discards it.
  String? _reviewPath;
  bool _reviewIsVideo = false;
  VideoPlayerController? _reviewVideo;
  bool _saving = false;

  bool get _reviewing => _reviewPath != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setup();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordTimer?.cancel();
    _reviewVideo?.dispose();
    _wipeReviewFile(_reviewPath);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (state == AppLifecycleState.inactive) {
      // Backgrounding tears down the camera — any in-progress recording is
      // lost, so reset the recording UI to a clean state.
      _recordTimer?.cancel();
      if (c != null) {
        if (mounted) {
          setState(() {
            _controller = null;
            _initializing = true;
            _recording = false;
            _recordSeconds = 0;
          });
        }
        c.dispose();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_controller == null && _cameras.isNotEmpty && _error == null) {
        _startController(_cameras[_cameraIndex]);
      }
    }
  }

  Future<void> _setup() async {
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        _fail('Camera permission is needed for Secure Capture.');
        return;
      }
      // Microphone is best-effort — video still records (silently) without it.
      try {
        final mic = await Permission.microphone.request();
        _micGranted = mic.isGranted;
      } catch (_) {
        _micGranted = false;
      }
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _fail('No camera was found on this device.');
        return;
      }
      _cameras = cameras;
      _cameraIndex = cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      if (_cameraIndex < 0) _cameraIndex = 0;
      await _startController(_cameras[_cameraIndex]);
    } catch (_) {
      _fail('Could not start the camera.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _initializing = false;
      _error = message;
    });
  }

  Future<void> _startController(CameraDescription camera) async {
    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: _micGranted,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await controller.initialize();
    } catch (_) {
      await controller.dispose();
      _fail('Could not start the camera.');
      return;
    }
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() {
      _controller = controller;
      _initializing = false;
      _error = null;
    });
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2 || _capturing || _recording) return;
    HapticFeedback.selectionClick();
    final old = _controller;
    setState(() {
      _controller = null;
      _initializing = true;
    });
    await old?.dispose();
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _startController(_cameras[_cameraIndex]);
  }

  void _onShutter() {
    if (_mode == _CaptureMode.photo) {
      _capturePhoto();
    } else {
      _toggleRecording();
    }
  }

  Future<void> _capturePhoto() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _capturing) return;
    setState(() {
      _capturing = true;
      _captureError = null;
    });
    HapticFeedback.mediumImpact();
    try {
      final shot = await c.takePicture();
      await _openReview(File(shot.path), isVideo: false);
    } catch (_) {
      _showCaptureError('Couldn\'t capture the photo. Please try again.');
    }
  }

  Future<void> _toggleRecording() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _capturing) return;
    if (_recording) {
      await _stopRecording(c);
    } else {
      await _startRecording(c);
    }
  }

  Future<void> _startRecording(CameraController c) async {
    try {
      await c.startVideoRecording();
      HapticFeedback.mediumImpact();
      if (!mounted) {
        await c.stopVideoRecording();
        return;
      }
      setState(() {
        _recording = true;
        _recordSeconds = 0;
        _captureError = null;
      });
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordSeconds++);
      });
    } catch (_) {
      if (mounted) setState(() => _recording = false);
      _showCaptureError('Couldn\'t start recording. Please try again.');
    }
  }

  Future<void> _stopRecording(CameraController c) async {
    _recordTimer?.cancel();
    HapticFeedback.mediumImpact();
    setState(() {
      _recording = false;
      _capturing = true;
    });
    try {
      final clip = await c.stopVideoRecording();
      await _openReview(File(clip.path), isVideo: true);
    } catch (_) {
      _showCaptureError('Couldn\'t finish the recording. Please try again.');
    }
  }

  /// Opens the review step on a freshly captured file. Nothing is saved here —
  /// the capture only lands in the vault when the user taps Save.
  Future<void> _openReview(File capture, {required bool isVideo}) async {
    VideoPlayerController? videoCtrl;
    if (isVideo) {
      videoCtrl = VideoPlayerController.file(capture);
      try {
        await videoCtrl.initialize();
        await videoCtrl.setLooping(true);
        await videoCtrl.setVolume(0);
        await videoCtrl.play();
      } catch (_) {
        await videoCtrl.dispose();
        videoCtrl = null;
      }
    }
    if (!mounted) {
      await videoCtrl?.dispose();
      _wipeReviewFile(capture.path);
      return;
    }
    setState(() {
      _capturing = false;
      _captureError = null;
      _reviewPath = capture.path;
      _reviewIsVideo = isVideo;
      _reviewVideo = videoCtrl;
    });
  }

  /// Commits the reviewed capture into the encrypted vault. This is the *only*
  /// path that saves a capture — it runs solely on a Save tap.
  Future<void> _saveCapture() async {
    final path = _reviewPath;
    if (path == null || _saving) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _saving = true;
      _captureError = null;
    });
    try {
      await MediaImporter.instance.importFiles(
        items: [PickedMedia(File(path))],
        category: _reviewIsVideo ? 'Videos' : 'Photos',
      );
      // importFiles may leave the source temp file behind — wipe any leftover.
      _wipeReviewFile(path);
      final video = _reviewVideo;
      if (!mounted) {
        await video?.dispose();
        return;
      }
      setState(() {
        _savedCount++;
        _saving = false;
        _reviewPath = null;
        _reviewVideo = null;
        _reviewIsVideo = false;
        _justSaved = true;
      });
      await video?.dispose();
      HapticFeedback.lightImpact();
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) setState(() => _justSaved = false);
      });
    } catch (_) {
      // Keep the review open so the user can retry Save or discard.
      if (mounted) {
        setState(() {
          _saving = false;
          _captureError = 'Couldn\'t save to your vault. Please try again.';
        });
        HapticFeedback.heavyImpact();
      }
    }
  }

  /// Discards the reviewed capture — the temp file is wiped and never saved.
  Future<void> _discardCapture() async {
    if (_saving) return;
    HapticFeedback.selectionClick();
    final path = _reviewPath;
    final video = _reviewVideo;
    setState(() {
      _reviewPath = null;
      _reviewVideo = null;
      _reviewIsVideo = false;
      _captureError = null;
    });
    await video?.dispose();
    _wipeReviewFile(path);
  }

  void _wipeReviewFile(String? path) {
    if (path == null) return;
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }

  void _showCaptureError(String message) {
    if (!mounted) return;
    setState(() {
      _capturing = false;
      _captureError = message;
    });
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 2800), () {
      if (mounted && _captureError == message) {
        setState(() => _captureError = null);
      }
    });
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _reviewing
            ? _reviewView()
            : _error != null
                ? _errorView()
                : (_initializing || _controller == null)
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : _cameraView(),
      ),
    );
  }

  // ── live camera ──────────────────────────────────────────────────────────

  Widget _cameraView() {
    return Stack(
      children: [
        Positioned.fill(child: _preview()),
        Positioned(top: 0, left: 0, right: 0, child: _scrim(top: true)),
        Positioned(bottom: 0, left: 0, right: 0, child: _scrim(top: false)),
        Positioned(top: 0, left: 0, right: 0, child: _topBar()),
        if (_recording)
          Positioned(
            top: 70,
            left: 0,
            right: 0,
            child: Center(child: _recordingPill()),
          )
        else if (_captureError != null)
          Positioned(
            top: 66,
            left: 24,
            right: 24,
            child: Center(child: _errorPill(_captureError!)),
          )
        else if (_justSaved)
          Positioned(
            top: 70,
            left: 0,
            right: 0,
            child: Center(child: _savedPill()),
          ),
        Positioned(bottom: 0, left: 0, right: 0, child: _bottomBar()),
      ],
    );
  }

  /// Full-bleed camera preview — scaled to cover the screen so there are no
  /// black letterbox bars, the way a native camera app looks.
  Widget _preview() {
    final c = _controller!;
    var scale =
        MediaQuery.of(context).size.aspectRatio * c.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;
    return ClipRect(
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.center,
        child: Center(child: CameraPreview(c)),
      ),
    );
  }

  /// A soft black gradient behind the top / bottom controls so they stay
  /// legible over a bright camera scene.
  Widget _scrim({required bool top}) {
    return IgnorePointer(
      child: Container(
        height: top ? 132 : 236,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: top ? Alignment.topCenter : Alignment.bottomCenter,
            end: top ? Alignment.bottomCenter : Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: top ? 0.55 : 0.62),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  Widget _recordingPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: _recColor,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatDuration(_recordSeconds),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _savedPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: LiquidColors.success.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, color: Colors.white, size: 14),
          SizedBox(width: 6),
          Text(
            'Saved to your vault',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorPill(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: _recColor.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          _circleButton(
            Icons.close_rounded,
            () => Navigator.of(context).pop(_savedCount),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_rounded,
                    color: LiquidColors.success, size: 13),
                const SizedBox(width: 6),
                const Text(
                  'SECURE CAPTURE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 0, 30, 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The Photo / Video switch hides while recording to keep focus on
          // the running clip.
          if (!_recording) ...[
            _modeToggle(),
            const SizedBox(height: 22),
          ] else
            const SizedBox(height: 51),
          Row(
            children: [
              SizedBox(
                width: 56,
                child: (_cameras.length > 1 && !_recording)
                    ? _circleButton(
                        Icons.flip_camera_ios_rounded, _flipCamera)
                    : null,
              ),
              const Spacer(),
              _shutterButton(),
              const Spacer(),
              SizedBox(
                width: 56,
                child: _savedCount > 0
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$_savedCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _modeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _modeChip('PHOTO', _CaptureMode.photo),
          _modeChip('VIDEO', _CaptureMode.video),
        ],
      ),
    );
  }

  Widget _modeChip(String label, _CaptureMode mode) {
    final active = _mode == mode;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: (active || _capturing)
          ? null
          : () {
              HapticFeedback.selectionClick();
              setState(() => _mode = mode);
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.black : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }

  Widget _shutterButton() {
    Widget inner;
    if (_capturing) {
      inner = const DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white54,
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(
            strokeWidth: 2.6,
            color: Colors.black,
          ),
        ),
      );
    } else if (_mode == _CaptureMode.photo) {
      inner = const DecoratedBox(
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white),
      );
    } else {
      // Video: a red disc that morphs to a rounded "stop" square while
      // recording.
      inner = AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        margin: EdgeInsets.all(_recording ? 16 : 0),
        decoration: BoxDecoration(
          color: _recColor,
          borderRadius: BorderRadius.circular(_recording ? 9 : 999),
        ),
      );
    }
    return GestureDetector(
      onTap: _onShutter,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: _recording ? _recColor : Colors.white,
            width: 4,
          ),
        ),
        padding: const EdgeInsets.all(6),
        child: inner,
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.5),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  // ── capture review ───────────────────────────────────────────────────────

  Widget _reviewView() {
    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 78, 20, 132),
            child: Center(child: _reviewMedia()),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                _circleButton(Icons.arrow_back_rounded, _discardCapture),
                const Spacer(),
                _reviewHeaderBadge(),
                const Spacer(),
                const SizedBox(width: 44),
              ],
            ),
          ),
        ),
        if (_captureError != null)
          Positioned(
            top: 64,
            left: 24,
            right: 24,
            child: Center(child: _errorPill(_captureError!)),
          ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
            child: Row(
              children: [
                Expanded(child: _reviewDiscardButton()),
                const SizedBox(width: 14),
                Expanded(flex: 2, child: _reviewSaveButton()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Neutral header making it explicit the capture is not in the vault yet.
  Widget _reviewHeaderBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: LiquidColors.warning.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline_rounded, color: Colors.white, size: 14),
          SizedBox(width: 6),
          Text(
            'Not saved yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewMedia() {
    final video = _reviewVideo;
    if (_reviewIsVideo && video != null && video.value.isInitialized) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: video.value.aspectRatio == 0
              ? 1
              : video.value.aspectRatio,
          child: VideoPlayer(video),
        ),
      );
    }
    if (_reviewIsVideo || _reviewPath == null) {
      return _mediaPlaceholder(
        icon: Icons.videocam_rounded,
        label: 'Video ready to save',
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Image.file(
        File(_reviewPath!),
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => _mediaPlaceholder(
          icon: Icons.image_rounded,
          label: 'Photo ready to save',
        ),
      ),
    );
  }

  Widget _mediaPlaceholder({required IconData icon, required String label}) {
    return Container(
      width: double.infinity,
      height: 260,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: 52),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewDiscardButton() {
    return GestureDetector(
      onTap: _saving ? null : _discardCapture,
      child: Opacity(
        opacity: _saving ? 0.5 : 1,
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.delete_outline_rounded,
                  color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text(
                'Discard',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reviewSaveButton() {
    return GestureDetector(
      onTap: _saving ? null : _saveCapture,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: LiquidColors.success,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: LiquidColors.success.withValues(alpha: 0.4),
              blurRadius: 16,
              spreadRadius: -3,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: _saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_rounded, color: Colors.white, size: 19),
                    SizedBox(width: 9),
                    Text(
                      'Save to vault',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.no_photography_rounded,
                color: Colors.white.withValues(alpha: 0.6), size: 56),
            const SizedBox(height: 18),
            Text(
              _error ?? 'Camera unavailable',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.of(context).pop(_savedCount),
              child: const Text(
                'Close',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
