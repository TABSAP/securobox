import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../utils/face_recognition_service.dart';
import '../utils/liquid_colors.dart';

enum FaceScanMode { enroll, verify }

/// Camera screen that either enrolls the owner's face (averaging several
/// readings) or verifies a live face against the enrolled template.
///
/// Pops `true` on success (enrolled / recognized), `false` otherwise.
class FaceScanScreen extends StatefulWidget {
  final FaceScanMode mode;
  const FaceScanScreen({super.key, required this.mode});

  @override
  State<FaceScanScreen> createState() => _FaceScanScreenState();
}

class _FaceScanScreenState extends State<FaceScanScreen>
    with SingleTickerProviderStateMixin {
  static const int _maxVerifyAttempts = 12;
  static const Duration _tickInterval = Duration(milliseconds: 600);

  CameraController? _controller;
  Timer? _tickTimer;
  Timer? _overallTimeout;
  bool _busy = false;
  bool _finished = false;
  bool _initFailed = false;
  String _hint = 'Starting camera…';

  final List<List<double>> _samples = [];
  int _verifyAttempts = 0;
  int _verifyHits = 0; // consecutive matching frames during verification

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  bool get _isEnroll => widget.mode == FaceScanMode.enroll;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _overallTimeout?.cancel();
    _pulse.dispose();
    try {
      _controller?.dispose();
    } catch (_) {}
    FaceRecognitionService.instance.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        _failInit('Camera permission is required for Face Unlock.');
        return;
      }
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _failInit('No camera available on this device.');
        return;
      }
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _hint = _isEnroll
            ? 'Hold still and look at the camera'
            : 'Looking for your face…';
      });
      _tickTimer = Timer.periodic(_tickInterval, (_) => _tick());
      _overallTimeout = Timer(
        Duration(seconds: _isEnroll ? 38 : 16),
        _onTimeout,
      );
    } catch (_) {
      _failInit('Could not start the camera.');
    }
  }

  void _failInit(String message) {
    if (!mounted) return;
    setState(() {
      _initFailed = true;
      _hint = message;
    });
  }

  void _onTimeout() {
    if (_finished || !mounted) return;
    if (_isEnroll && _samples.length >= FaceRecognitionService.minEnrollSamples) {
      _completeEnrollment();
      return;
    }
    _finish(false,
        message: _isEnroll
            ? 'Couldn\'t read your face clearly. Use good lighting, keep your whole face in the circle, then try again.'
            : null);
  }

  void _forceCapture() {
    if (_busy || _finished) return;
    HapticFeedback.selectionClick();
    _tick();
  }

  Future<void> _tick() async {
    if (_busy || _finished || !mounted) return;
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    _busy = true;
    XFile? shot;
    try {
      shot = await controller.takePicture();
      final res =
          await FaceRecognitionService.instance.signatureFromImageFile(shot.path);
      if (_finished || !mounted) return;

      if (res.vector == null) {
        setState(() => _hint = res.error ?? 'Adjust your position.');
        return;
      }

      if (_isEnroll) {
        _samples.add(res.vector!);
        if (_samples.length >= FaceRecognitionService.enrollSamples) {
          await _completeEnrollment();
        } else {
          setState(() => _hint =
              'Captured ${_samples.length}/${FaceRecognitionService.enrollSamples} — hold still');
        }
      } else {
        final v =
            await FaceRecognitionService.instance.verifyVector(res.vector!);
        if (_finished || !mounted) return;
        if (v.matched) {
          _verifyHits++;
          if (_verifyHits >= FaceRecognitionService.verifyMatchesRequired) {
            HapticFeedback.mediumImpact();
            _finish(true);
            return;
          }
          setState(() => _hint = 'Almost there — hold steady…');
        } else {
          // A face was clearly detected but didn't match — reset the streak so
          // only the enrolled person's own face accumulates the matches.
          _verifyHits = 0;
          _verifyAttempts++;
          if (_verifyAttempts >= _maxVerifyAttempts) {
            _finish(false);
          } else {
            setState(() => _hint = 'Not recognized — keep looking at the camera');
          }
        }
      }
    } catch (_) {
      if (mounted && !_finished) {
        setState(() => _hint = 'Camera hiccup — trying again…');
      }
    } finally {
      if (shot != null) {
        try {
          await File(shot.path).delete();
        } catch (_) {}
      }
      _busy = false;
    }
  }

  Future<void> _completeEnrollment() async {
    if (_finished) return;
    _finished = true;
    _tickTimer?.cancel();
    _overallTimeout?.cancel();
    try {
      await FaceRecognitionService.instance.enroll(_samples);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      _finish(true, alreadyMarked: true);
    } catch (_) {
      // Readings weren't consistent enough for a reliable template — start over.
      _samples.clear();
      _verifyAttempts = 0;
      _verifyHits = 0;
      _finished = false;
      if (!mounted) return;
      setState(() =>
          _hint = 'Those readings didn\'t match each other — let\'s try again.');
      _tickTimer = Timer.periodic(_tickInterval, (_) => _tick());
      _overallTimeout = Timer(const Duration(seconds: 38), _onTimeout);
    }
  }

  void _finish(bool result, {String? message, bool alreadyMarked = false}) {
    if (_finished && !alreadyMarked) return;
    _finished = true;
    _tickTimer?.cancel();
    _overallTimeout?.cancel();
    if (!mounted) return;
    if (message != null) {
      setState(() => _hint = message);
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) Navigator.of(context).pop(result);
      });
    } else {
      Navigator.of(context).pop(result);
    }
  }

  void _cancel() {
    if (_finished) return;
    _finished = true;
    _tickTimer?.cancel();
    _overallTimeout?.cancel();
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;
    final accent = _isEnroll ? LiquidColors.accentPink : LiquidColors.accentBlue;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Camera viewport.
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isEnroll ? 'Set up Face Unlock' : 'Face Unlock',
                    style: TextStyle(
                      color: LiquidColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isEnroll
                        ? 'We\'ll take a few quick readings'
                        : 'Look at the camera to unlock',
                    style: TextStyle(color: LiquidColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 28),
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, child) {
                      final t = _pulse.value;
                      return Container(
                        width: 256,
                        height: 256,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: accent.withValues(alpha: 0.35 + 0.45 * t),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.18 + 0.22 * t),
                              blurRadius: 28 + 16 * t,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: child,
                      );
                    },
                    child: GestureDetector(
                      onTap: ready && !_initFailed ? _forceCapture : null,
                      child: ClipOval(
                        child: SizedBox(
                          width: 250,
                          height: 250,
                          child: _initFailed
                              ? Container(
                                  color: LiquidColors.backgroundLight,
                                  child: Icon(Icons.no_photography_rounded,
                                      color: LiquidColors.textTertiary, size: 56),
                                )
                              : ready
                                  ? FittedBox(
                                      fit: BoxFit.cover,
                                      child: SizedBox(
                                        width: controller
                                                .value.previewSize?.height ??
                                            480,
                                        height: controller
                                                .value.previewSize?.width ??
                                            640,
                                        child: CameraPreview(controller),
                                      ),
                                    )
                                  : Container(
                                      color: LiquidColors.backgroundLight,
                                      child: const Center(
                                        child: SizedBox(
                                          width: 28,
                                          height: 28,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2.5),
                                        ),
                                      ),
                                    ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (_isEnroll)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        FaceRecognitionService.enrollSamples,
                        (i) {
                          final filled = i < _samples.length;
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: filled
                                  ? LiquidColors.success
                                  : LiquidColors.textPrimary.withValues(alpha: 0.18),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _hint,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _initFailed
                            ? LiquidColors.warning
                            : LiquidColors.textSecondary,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                  if (ready && !_initFailed && !_finished) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Tap the circle to capture now',
                      style: TextStyle(
                        color: LiquidColors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 26),
                  if (_initFailed)
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text('Close',
                          style: TextStyle(color: LiquidColors.textPrimary)),
                    )
                  else
                    TextButton(
                      onPressed: _cancel,
                      child: Text(
                        _isEnroll ? 'Cancel' : 'Use PIN instead',
                        style: TextStyle(
                            color: LiquidColors.textSecondary,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),
            // Top-left close button.
            Positioned(
              top: 4,
              left: 4,
              child: IconButton(
                icon: Icon(Icons.close_rounded, color: LiquidColors.textPrimary),
                onPressed: _initFailed
                    ? () => Navigator.of(context).pop(false)
                    : _cancel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
