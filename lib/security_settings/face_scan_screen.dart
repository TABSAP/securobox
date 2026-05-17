import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../utils/face_recognition_service.dart';
import '../utils/liquid_colors.dart';

enum FaceScanMode { enroll, verify }

// Easypaisa-flavoured palette (shared visual language with BiometricAuthSheet).
const Color _kGreenDeep = Color(0xFF008A3D);
const Color _kGreen = Color(0xFF12B25C);
const Color _kGreenBright = Color(0xFF2BD976);
const Color _kRed = Color(0xFFE5484D);
const Color _kRedBright = Color(0xFFFF6B6B);

enum _Phase { scanning, success, failed }

/// Camera screen that either enrolls the owner's face (averaging several
/// readings) or verifies a live face against the enrolled template — styled to
/// match the app's premium fintech biometric flow (green gradient,
/// glassmorphism, glowing scan ring, scan-line sweep, success burst, error
/// shake, haptics).
///
/// Pops `true` on success (enrolled / recognized), `false` otherwise.
class FaceScanScreen extends StatefulWidget {
  final FaceScanMode mode;
  const FaceScanScreen({super.key, required this.mode});

  @override
  State<FaceScanScreen> createState() => _FaceScanScreenState();
}

class _FaceScanScreenState extends State<FaceScanScreen>
    with TickerProviderStateMixin {
  static const int _maxVerifyAttempts = 12;
  static const Duration _tickInterval = Duration(milliseconds: 600);

  CameraController? _controller;
  Timer? _tickTimer;
  Timer? _overallTimeout;
  bool _busy = false;
  bool _finished = false;
  bool _cameraReady = false;
  bool _initFailed = false;

  _Phase _phase = _Phase.scanning;
  String _hint = 'Starting camera…';
  String _failedReason = '';

  final List<List<double>> _samples = [];
  int _verifyAttempts = 0;
  int _verifyHits = 0; // consecutive matching frames during verification

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  )..repeat(reverse: true);
  late final AnimationController _ping = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  )..repeat();
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  late final AnimationController _success = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
  );
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  );

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
    _ping.dispose();
    _sweep.dispose();
    _success.dispose();
    _shake.dispose();
    try {
      _controller?.dispose();
    } catch (_) {}
    FaceRecognitionService.instance.dispose();
    super.dispose();
  }

  // ── camera / scan lifecycle ──────────────────────────────────────────────

  Future<void> _start() async {
    setState(() {
      _initFailed = false;
      _finished = false;
      _cameraReady = false;
      _phase = _Phase.scanning;
      _hint = 'Starting camera…';
      _samples.clear();
      _verifyAttempts = 0;
      _verifyHits = 0;
    });
    if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    if (!_ping.isAnimating) _ping.repeat();
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        _toFailed('Camera access is needed for Face Unlock.', initFailed: true);
        return;
      }
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _toFailed('No camera available on this device.', initFailed: true);
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
      try {
        await controller.initialize();
      } catch (_) {
        try {
          await controller.dispose();
        } catch (_) {}
        rethrow;
      }
      if (!mounted) {
        await controller.dispose();
        return;
      }
      final old = _controller;
      _controller = controller;
      if (old != null) {
        try {
          await old.dispose();
        } catch (_) {}
      }
      setState(() {
        _cameraReady = true;
        _hint = _isEnroll
            ? 'Hold still and look at the camera'
            : 'Looking for your face…';
      });
      _beginTicking(_isEnroll ? 38 : 16);
    } catch (_) {
      _toFailed('Couldn\'t start the camera.', initFailed: true);
    }
  }

  void _beginTicking(int timeoutSeconds) {
    _tickTimer?.cancel();
    _overallTimeout?.cancel();
    _sweep
      ..reset()
      ..repeat();
    _tickTimer = Timer.periodic(_tickInterval, (_) => _tick());
    _overallTimeout = Timer(Duration(seconds: timeoutSeconds), _onTimeout);
  }

  void _onTimeout() {
    if (_finished || !mounted) return;
    if (_isEnroll &&
        _samples.length >= FaceRecognitionService.minEnrollSamples) {
      _completeEnrollment();
      return;
    }
    _toFailed(
      _isEnroll
          ? 'Couldn\'t read your face clearly. Use good lighting and keep your whole face in the circle.'
          : 'We couldn\'t recognize you. Use your PIN, or try again.',
    );
  }

  void _forceCapture() {
    if (_busy || _finished || _phase != _Phase.scanning) return;
    HapticFeedback.selectionClick();
    _tick();
  }

  Future<void> _tick() async {
    if (_busy || _finished || !mounted || _phase != _Phase.scanning) return;
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    _busy = true;
    XFile? shot;
    try {
      shot = await controller.takePicture();
      final res = await FaceRecognitionService.instance.signatureFromImageFile(
        shot.path,
      );
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
          setState(
            () => _hint =
                'Captured ${_samples.length}/${FaceRecognitionService.enrollSamples} — hold still',
          );
        }
      } else {
        final v = await FaceRecognitionService.instance.verifyVector(
          res.vector!,
        );
        if (_finished || !mounted) return;
        if (v.matched) {
          _verifyHits++;
          if (_verifyHits >= FaceRecognitionService.verifyMatchesRequired) {
            _toSuccess();
            return;
          }
          setState(() => _hint = 'Almost there — hold steady…');
        } else {
          // A face was clearly detected but didn't match — reset the streak so
          // only the enrolled person's own face accumulates the matches.
          _verifyHits = 0;
          _verifyAttempts++;
          if (_verifyAttempts >= _maxVerifyAttempts) {
            _toFailed(
              'We couldn\'t recognize you. Use your PIN, or try again.',
            );
          } else {
            setState(
              () => _hint = 'Not recognized — keep looking at the camera',
            );
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
    _sweep.stop();
    try {
      await FaceRecognitionService.instance.enroll(_samples);
      if (!mounted) return;
      _toSuccess(alreadyFinished: true);
    } catch (_) {
      // Readings weren't consistent enough for a reliable template — start over.
      _samples.clear();
      _verifyAttempts = 0;
      _verifyHits = 0;
      _finished = false;
      if (!mounted) return;
      setState(
        () => _hint = 'Those readings didn\'t match — let\'s try once more.',
      );
      _beginTicking(38);
    }
  }

  void _toSuccess({bool alreadyFinished = false}) {
    if (_finished && !alreadyFinished) return;
    _finished = true;
    _tickTimer?.cancel();
    _overallTimeout?.cancel();
    _sweep.stop();
    _pulse.stop();
    _ping.stop();
    if (!mounted) return;
    setState(() {
      _phase = _Phase.success;
      _hint = _isEnroll ? 'Face Unlock is set up.' : 'Identity confirmed.';
    });
    _success.forward(from: 0);
    HapticFeedback.heavyImpact();
    Future<void>.delayed(
      const Duration(milliseconds: 160),
      () => HapticFeedback.lightImpact(),
    );
    Future<void>.delayed(const Duration(milliseconds: 840), () {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
    });
  }

  void _toFailed(String reason, {bool initFailed = false}) {
    if (_finished && !initFailed) return;
    _finished = true;
    _tickTimer?.cancel();
    _overallTimeout?.cancel();
    _sweep.stop();
    if (!mounted) return;
    setState(() {
      _phase = _Phase.failed;
      _initFailed = initFailed;
      _failedReason = reason;
      _hint = reason;
    });
    _shake.forward(from: 0);
    HapticFeedback.heavyImpact();
    Future<void>.delayed(
      const Duration(milliseconds: 130),
      () => HapticFeedback.heavyImpact(),
    );
  }

  void _retry() {
    HapticFeedback.selectionClick();
    if (_initFailed || !_cameraReady) {
      _start();
      return;
    }
    setState(() {
      _finished = false;
      _phase = _Phase.scanning;
      _samples.clear();
      _verifyAttempts = 0;
      _verifyHits = 0;
      _hint = _isEnroll
          ? 'Hold still and look at the camera'
          : 'Looking for your face…';
    });
    if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    if (!_ping.isAnimating) _ping.repeat();
    _beginTicking(_isEnroll ? 38 : 16);
  }

  void _close(bool result) {
    _finished = true;
    _tickTimer?.cancel();
    _overallTimeout?.cancel();
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop(result);
    }
  }

  // ── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final orb = (media.size.width - 96).clamp(180.0, 264.0);

    return Scaffold(
      backgroundColor: LiquidColors.backgroundDeep,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _kGreenDeep.withValues(alpha: 0.16),
              LiquidColors.backgroundDeep,
              LiquidColors.backgroundDeep,
            ],
            stops: const [0.0, 0.42, 1.0],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              LayoutBuilder(
                builder: (context, c) => SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: c.maxHeight),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _titleText(),
                            const SizedBox(height: 8),
                            _subtitleText(),
                            const SizedBox(height: 30),
                            _orbArea(orb),
                            const SizedBox(height: 26),
                            if (_isEnroll && _phase == _Phase.scanning) ...[
                              _enrollDots(),
                              const SizedBox(height: 16),
                            ],
                            _hintText(),
                            if (_phase == _Phase.scanning && _cameraReady) ...[
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
                            _stateButtons(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 2,
                left: 2,
                child: IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: LiquidColors.textPrimary,
                  ),
                  onPressed: () => _close(false),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color get _phaseColor => _phase == _Phase.failed ? _kRed : _kGreen;
  Color get _phaseColorBright =>
      _phase == _Phase.failed ? _kRedBright : _kGreenBright;

  Widget _titleText() {
    final String text;
    switch (_phase) {
      case _Phase.success:
        text = _isEnroll ? 'Face Unlock Ready' : 'Verified!';
        break;
      case _Phase.failed:
        text = _initFailed ? 'Camera Unavailable' : 'Not Recognized';
        break;
      case _Phase.scanning:
        text = _isEnroll ? 'Set up Face Unlock' : 'Face Unlock';
        break;
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: Text(
        text,
        key: ValueKey(text),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: LiquidColors.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _subtitleText() {
    final String text;
    switch (_phase) {
      case _Phase.success:
        text = _isEnroll
            ? 'You can unlock with your face from now on.'
            : 'Welcome back.';
        break;
      case _Phase.failed:
        text = _initFailed
            ? 'Grant camera access, then try again.'
            : 'Your face didn\'t match. Try again or use your PIN.';
        break;
      case _Phase.scanning:
        text = _isEnroll
            ? 'We\'ll take a few quick readings of your face.'
            : 'Look at the front camera to unlock.';
        break;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: Text(
          text,
          key: ValueKey(text),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: LiquidColors.textSecondary,
            fontSize: 13.5,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _hintText() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Text(
          _phase == _Phase.failed ? _failedReason : _hint,
          key: ValueKey(_phase == _Phase.failed ? _failedReason : _hint),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _phase == _Phase.failed ? _kRed : LiquidColors.textSecondary,
            fontSize: 13.5,
            height: 1.45,
            fontWeight: _phase == _Phase.failed
                ? FontWeight.w600
                : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _enrollDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(FaceRecognitionService.enrollSamples, (i) {
        final filled = i < _samples.length;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: filled ? 11 : 9,
          height: filled ? 11 : 9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled
                ? _kGreenBright
                : LiquidColors.textPrimary.withValues(alpha: 0.16),
            boxShadow: filled
                ? [
                    BoxShadow(
                      color: _kGreen.withValues(alpha: 0.5),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }

  // ── the camera "orb" ─────────────────────────────────────────────────────

  Widget _orbArea(double size) {
    final controller = _controller;
    return SizedBox(
      width: size * 1.55,
      height: size * 1.55,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulse, _ping, _success, _shake]),
        builder: (context, _) {
          final c = _phaseColor;
          final cBright = _phaseColorBright;
          final breathing = _phase == _Phase.scanning ? _pulse.value : 0.0;
          final scanGlow = (_phase == _Phase.scanning && _cameraReady)
              ? 1.0
              : 0.0;
          final successT = Curves.elasticOut.transform(
            _phase == _Phase.success ? _success.value : 0.0,
          );
          final shakeDx = _phase == _Phase.failed
              ? math.sin(_shake.value * math.pi * 4) * 12 * (1 - _shake.value)
              : 0.0;

          final glowAlpha =
              (0.28 +
                      0.14 * breathing +
                      0.18 * scanGlow +
                      0.18 * successT.clamp(0.0, 1.0))
                  .clamp(0.0, 0.65);
          final glowBlur = 34 + 16 * breathing + 24 * scanGlow + 20 * successT;
          final glowSpread =
              4 + 5 * breathing + 9 * scanGlow + 7 * successT.clamp(0.0, 1.0);

          return Transform.translate(
            offset: Offset(shakeDx, 0),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // expanding ping ripple while scanning
                if (_phase == _Phase.scanning && _cameraReady)
                  Opacity(
                    opacity: (1 - _ping.value) * 0.5,
                    child: Container(
                      width: size * (0.86 + _ping.value * 0.6),
                      height: size * (0.86 + _ping.value * 0.6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: c.withValues(alpha: 0.6),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                // success burst ring
                if (_phase == _Phase.success && successT < 1)
                  Opacity(
                    opacity: (1 - successT.clamp(0.0, 1.0)) * 0.85,
                    child: Container(
                      width: size * (0.86 + successT.clamp(0.0, 1.0) * 0.8),
                      height: size * (0.86 + successT.clamp(0.0, 1.0) * 0.8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: cBright.withValues(alpha: 0.7),
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                // soft halo
                Container(
                  width: size * 1.06,
                  height: size * 1.06,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        c.withValues(alpha: 0.14),
                        c.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
                // the camera circle
                Transform.scale(
                  scale: _phase == _Phase.success
                      ? (0.72 + 0.28 * successT.clamp(0.0, 1.0))
                      : 1.0,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: (_phase == _Phase.scanning ? cBright : c)
                            .withValues(alpha: 0.6 + 0.3 * scanGlow),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: c.withValues(alpha: glowAlpha),
                          blurRadius: glowBlur.toDouble(),
                          spreadRadius: glowSpread.toDouble(),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: GestureDetector(
                        onTap: (_phase == _Phase.scanning && _cameraReady)
                            ? _forceCapture
                            : null,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // preview / placeholder
                            if (_initFailed)
                              Container(
                                color: LiquidColors.backgroundLight,
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.no_photography_rounded,
                                  color: LiquidColors.textTertiary,
                                  size: 54,
                                ),
                              )
                            else if (_cameraReady && controller != null)
                              FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width:
                                      controller.value.previewSize?.height ??
                                      480,
                                  height:
                                      controller.value.previewSize?.width ??
                                      640,
                                  child: CameraPreview(controller),
                                ),
                              )
                            else
                              Container(
                                color: LiquidColors.backgroundLight,
                                alignment: Alignment.center,
                                child: const SizedBox(
                                  width: 30,
                                  height: 30,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.6,
                                    color: _kGreenBright,
                                  ),
                                ),
                              ),
                            // scanning sweep line
                            if (_phase == _Phase.scanning && _cameraReady)
                              AnimatedBuilder(
                                animation: _sweep,
                                builder: (context, _) {
                                  final t = _sweep.value;
                                  final p = t < 0.5 ? t * 2 : (1 - t) * 2;
                                  return Transform.translate(
                                    offset: Offset(0, (p - 0.5) * size * 0.92),
                                    child: Container(
                                      height: 4,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            _kGreenBright.withValues(
                                              alpha: 0.0,
                                            ),
                                            _kGreenBright.withValues(
                                              alpha: 0.95,
                                            ),
                                            _kGreenBright.withValues(
                                              alpha: 0.0,
                                            ),
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: _kGreenBright.withValues(
                                              alpha: 0.7,
                                            ),
                                            blurRadius: 10,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            // success / failed overlay
                            if (_phase == _Phase.success ||
                                (_phase == _Phase.failed && !_initFailed))
                              Container(
                                color: c.withValues(
                                  alpha: _phase == _Phase.success
                                      ? 0.45 * successT.clamp(0.0, 1.0)
                                      : 0.42,
                                ),
                                alignment: Alignment.center,
                                child: Transform.scale(
                                  scale: _phase == _Phase.success
                                      ? successT.clamp(0.0, 1.0)
                                      : 1.0,
                                  child: Icon(
                                    _phase == _Phase.success
                                        ? Icons.check_rounded
                                        : Icons.priority_high_rounded,
                                    color: Colors.white,
                                    size: size * 0.42,
                                  ),
                                ),
                              ),
                            // top-left sheen
                            IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    center: const Alignment(-0.6, -0.65),
                                    radius: 0.9,
                                    colors: [
                                      Colors.white.withValues(alpha: 0.18),
                                      Colors.white.withValues(alpha: 0.0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── state-specific buttons ───────────────────────────────────────────────

  Widget _stateButtons() {
    switch (_phase) {
      case _Phase.success:
        return const SizedBox(height: 6);

      case _Phase.scanning:
        return Column(
          children: [
            SizedBox(
              height: 4,
              width: 160,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: _cameraReady
                    ? LinearProgressIndicator(
                        backgroundColor: _kGreen.withValues(alpha: 0.15),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          _kGreenBright,
                        ),
                      )
                    : Container(color: _kGreen.withValues(alpha: 0.15)),
              ),
            ),
            const SizedBox(height: 18),
            _ghostButton(
              icon: Icons.close_rounded,
              label: 'Cancel',
              onTap: () => _close(false),
            ),
            if (!_isEnroll) ...[
              const SizedBox(height: 4),
              _textLink('Use PIN instead', onTap: () => _close(false)),
            ],
          ],
        );

      case _Phase.failed:
        return Column(
          children: [
            _primaryButton(
              icon: Icons.refresh_rounded,
              label: 'Try Again',
              onTap: _retry,
            ),
            const SizedBox(height: 10),
            if (!_isEnroll)
              Row(
                children: [
                  Expanded(
                    child: _textLink(
                      'Use PIN instead',
                      onTap: () => _close(false),
                    ),
                  ),
                  Expanded(
                    child: _textLink(
                      'Cancel',
                      onTap: () => _close(false),
                      muted: true,
                    ),
                  ),
                ],
              )
            else
              _textLink('Cancel', onTap: () => _close(false), muted: true),
          ],
        );
    }
  }

  // ── small button primitives (Easypaisa look) ────────────────────────────

  Widget _primaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return _PressableScale(
      onTap: onTap,
      borderRadius: 16,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_kGreenBright, _kGreenDeep],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _kGreen.withValues(alpha: 0.4),
              blurRadius: 18,
              spreadRadius: -3,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 19),
            const SizedBox(width: 9),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ghostButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return _PressableScale(
      onTap: onTap,
      borderRadius: 16,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: LiquidColors.textPrimary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: LiquidColors.cardBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: LiquidColors.textPrimary, size: 18),
            const SizedBox(width: 9),
            Text(
              label,
              style: TextStyle(
                color: LiquidColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _textLink(
    String label, {
    required VoidCallback onTap,
    bool muted = false,
  }) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 10),
        minimumSize: const Size(0, 36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: muted ? LiquidColors.textTertiary : _kGreen,
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double borderRadius;
  const _PressableScale({
    required this.child,
    required this.onTap,
    this.borderRadius = 12,
  });

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _down ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 110),
          child: widget.child,
        ),
      ),
    );
  }
}
