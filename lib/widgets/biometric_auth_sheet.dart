import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:video_player_app/widgets/app_loader.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/utils/session_manager.dart';

enum BiometricAuthResult { authenticated, usePin, cancelled }

class BiometricAuthSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final String? localizedReason;
  final bool allowPinFallback;
  final String fallbackLabel;
  final IconData fallbackIcon;
  final void Function(BiometricAuthResult result)? onResult;

  const BiometricAuthSheet({
    super.key,
    this.title = 'Verify Your Identity',
    this.subtitle = 'Use Fingerprint or Face ID to continue',
    this.localizedReason,
    this.allowPinFallback = true,
    this.fallbackLabel = 'Use PIN instead',
    this.fallbackIcon = Icons.dialpad_rounded,
    this.onResult,
  });

  static Future<BiometricAuthResult?> show(
    BuildContext context, {
    String title = 'Verify Your Identity',
    String subtitle = 'Use Fingerprint or Face ID to continue',
    String? localizedReason,
    bool allowPinFallback = true,
    String fallbackLabel = 'Use PIN instead',
    IconData fallbackIcon = Icons.dialpad_rounded,
  }) {
    final navigator = Navigator.of(context);
    final completer = Completer<BiometricAuthResult?>();
    late final MaterialPageRoute<BiometricAuthResult> route;
    route = MaterialPageRoute<BiometricAuthResult>(
      fullscreenDialog: true,
      builder: (_) => BiometricAuthSheet(
        title: title,
        subtitle: subtitle,
        localizedReason: localizedReason,
        allowPinFallback: allowPinFallback,
        fallbackLabel: fallbackLabel,
        fallbackIcon: fallbackIcon,
        onResult: (result) {
          if (!completer.isCompleted) completer.complete(result);
          if (!route.isActive) return;
          if (route.isCurrent) {
            navigator.pop();
          } else {
            navigator.removeRoute(route);
          }
        },
      ),
    );
    navigator.push(route);
    return completer.future;
  }

  @override
  State<BiometricAuthSheet> createState() => _BiometricAuthSheetState();
}

enum _AuthPhase { idle, scanning, success, failed }

class _BiometricAuthSheetState extends State<BiometricAuthSheet>
    with TickerProviderStateMixin {
  final LocalAuthentication _auth = LocalAuthentication();

  _AuthPhase _phase = _AuthPhase.idle;
  bool _hasFace = false;
  bool _hasFingerprint = false;
  bool _preferFace = true;
  bool _bioReady = false;
  bool _introDone = false;
  bool _canAuthenticate = false;
  bool _retriedWarmup = false;
  String _errorMessage = '';
  bool _running = false;
  bool _resolved = false;
  Duration? _cooldownLeft;
  Timer? _cooldownTimer;

  late final AnimationController _entry = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );
  late final AnimationController _ping = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  );
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

  @override
  void initState() {
    super.initState();
    _entry.forward().then((_) {
      if (mounted) setState(() => _introDone = true);
    });
    _pulse.repeat(reverse: true);
    _ping.repeat();
    _init();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _entry.dispose();
    _pulse.dispose();
    _ping.dispose();
    _sweep.dispose();
    _success.dispose();
    _shake.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _detectBiometrics();
    if (!mounted) return;
    if (!_canAuthenticate) {
      _toFailed(
        'To unlock with biometrics, set a screen lock and enroll a '
        'fingerprint or face in your device settings.',
      );
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _authenticate();
    });
  }

  Future<void> _detectBiometrics() async {
    try {
      final supportedF = _auth.isDeviceSupported();
      final canCheckF = _auth.canCheckBiometrics;
      final listF = _auth.getAvailableBiometrics();
      final supported = await supportedF;
      final canCheck = await canCheckF;
      List<BiometricType> list = const <BiometricType>[];
      try {
        list = await listF;
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _canAuthenticate = supported || canCheck;
        final hasFace = list.contains(BiometricType.face);
        final hasFp =
            list.contains(BiometricType.fingerprint) ||
            (!hasFace && list.isNotEmpty) ||
            (!hasFace && _canAuthenticate);
        _hasFace = hasFace;
        _hasFingerprint = hasFp;
        _preferFace = hasFace;
        _bioReady = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _bioReady = true;
          _canAuthenticate = true;
          _hasFingerprint = true;
        });
      }
    }
  }

  bool get _showFaceIcon => _preferFace && _hasFace;

  IconData get _bioIcon =>
      _showFaceIcon ? Icons.face_retouching_natural : Icons.fingerprint_rounded;

  String get _methodName => _showFaceIcon ? 'Face ID' : 'Fingerprint';

  Future<void> _authenticate() async {
    if (_running) return;
    final cd = await SessionManager.instance.getBiometricCooldownRemaining();
    if (cd != null) {
      if (!mounted) return;
      _startCooldown(
        cd,
        _errorMessage.isEmpty ? 'Too many failed attempts.' : _errorMessage,
      );
      return;
    }
    if (!mounted) return;
    _running = true;
    setState(() {
      _phase = _AuthPhase.scanning;
      _cooldownLeft = null;
    });
    _sweep
      ..reset()
      ..repeat();
    HapticFeedback.lightImpact();
    SessionManager.instance.beginTrustedInteraction();
    try {
      final ok = await _auth.authenticate(
        localizedReason:
            widget.localizedReason ?? 'Verify your identity to continue',
        biometricOnly: true,
        sensitiveTransaction: true,
        persistAcrossBackgrounding: true,
      );
      if (!mounted) return;
      if (ok) {
        _toSuccess();
      } else {
        _toFailed('Verification was cancelled. Tap "Try Again" to retry.');
      }
    } on LocalAuthException catch (e) {
      if (!mounted) return;
      if (!_retriedWarmup && _isTransient(e.code)) {
        _retriedWarmup = true;
        Future<void>.delayed(const Duration(milliseconds: 700), () {
          if (mounted) _authenticate();
        });
        return;
      }
      final msg = _messageForCode(e.code);
      if (e.code == LocalAuthExceptionCode.temporaryLockout ||
          e.code == LocalAuthExceptionCode.biometricLockout) {
        await _registerFailure(msg);
      } else {
        _toFailed(msg);
      }
    } on PlatformException catch (_) {
      if (!mounted) return;
      if (!_retriedWarmup) {
        _retriedWarmup = true;
        Future<void>.delayed(const Duration(milliseconds: 700), () {
          if (mounted) _authenticate();
        });
        return;
      }
      _toFailed(
        'Biometric authentication isn\'t available right now. Tap "Try Again".',
      );
    } catch (_) {
      if (!mounted) return;
      _toFailed('Something went wrong. Tap "Try Again" to retry.');
    } finally {
      _running = false;
      SessionManager.instance.endTrustedInteraction();
    }
  }

  bool _isTransient(LocalAuthExceptionCode code) =>
      code == LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable ||
      code == LocalAuthExceptionCode.uiUnavailable ||
      code == LocalAuthExceptionCode.systemCanceled ||
      code == LocalAuthExceptionCode.authInProgress ||
      code == LocalAuthExceptionCode.timeout ||
      code == LocalAuthExceptionCode.deviceError ||
      code == LocalAuthExceptionCode.unknownError;

  Future<void> _registerFailure(String message) async {
    await SessionManager.instance.recordFailedBiometricAttempt();
    final remaining =
        await SessionManager.instance.getBiometricCooldownRemaining();
    if (!mounted) return;
    if (remaining != null) {
      _startCooldown(remaining, message);
    } else {
      _toFailed(message);
    }
  }

  void _startCooldown(Duration initial, String message) {
    _cooldownTimer?.cancel();
    _sweep.stop();
    _pulse.stop();
    _ping.stop();
    setState(() {
      _phase = _AuthPhase.failed;
      _errorMessage = message;
      _cooldownLeft = initial;
    });
    _shake.forward(from: 0);
    HapticFeedback.heavyImpact();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      final remaining =
          await SessionManager.instance.getBiometricCooldownRemaining();
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _cooldownLeft = remaining);
      if (remaining == null) t.cancel();
    });
  }

  String _formatCountdown(Duration d) {
    final total = (d.inMilliseconds / 1000).ceil().clamp(0, 599);
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _messageForCode(LocalAuthExceptionCode code) {
    switch (code) {
      case LocalAuthExceptionCode.userCanceled:
      case LocalAuthExceptionCode.userRequestedFallback:
        return 'Verification was cancelled. Tap "Try Again" to retry.';
      case LocalAuthExceptionCode.noCredentialsSet:
        return 'Set a screen lock on your device to use biometric unlock.';
      case LocalAuthExceptionCode.noBiometricsEnrolled:
        return 'No fingerprint or face is enrolled — add one in your device settings.';
      case LocalAuthExceptionCode.noBiometricHardware:
        return 'This device doesn\'t have biometric hardware.';
      case LocalAuthExceptionCode.temporaryLockout:
        return 'Too many attempts. Wait a moment, then try again.';
      case LocalAuthExceptionCode.biometricLockout:
        return 'Biometrics are locked. Unlock your device with your screen lock, then retry.';
      default:
        return 'Biometric authentication isn\'t available right now. Tap "Try Again".';
    }
  }

  void _toSuccess() {
    _sweep.stop();
    _pulse.stop();
    _ping.stop();
    setState(() => _phase = _AuthPhase.success);
    _success.forward(from: 0);
    HapticFeedback.heavyImpact();
    Future<void>.delayed(const Duration(milliseconds: 120), () {
      if (mounted) _close(BiometricAuthResult.authenticated);
    });
  }

  void _toFailed(String message) {
    _sweep.stop();
    _pulse.stop();
    _ping.stop();
    setState(() {
      _phase = _AuthPhase.failed;
      _errorMessage = message;
    });
    _shake.forward(from: 0);
    HapticFeedback.heavyImpact();
    Future<void>.delayed(
      const Duration(milliseconds: 130),
      () => HapticFeedback.heavyImpact(),
    );
  }

  void _retry() {
    if (_cooldownLeft != null) return;
    _cooldownTimer?.cancel();
    _retriedWarmup = false;
    setState(() {
      _phase = _AuthPhase.idle;
      _errorMessage = '';
      _cooldownLeft = null;
    });
    if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    if (!_ping.isAnimating) _ping.repeat();
    _authenticate();
  }

  void _switchMethod() {
    HapticFeedback.selectionClick();
    setState(() => _preferFace = !_preferFace);
    _retry();
  }

  void _close(BiometricAuthResult result) {
    if (_resolved) return;
    _resolved = true;
    widget.onResult?.call(result);
  }

  Color get _accent {
    switch (_phase) {
      case _AuthPhase.success:
        return LiquidColors.success;
      case _AuthPhase.failed:
        return LiquidColors.error;
      case _AuthPhase.idle:
      case _AuthPhase.scanning:
        return LiquidColors.accentBlue;
    }
  }

  List<Color> get _discGradient {
    switch (_phase) {
      case _AuthPhase.success:
        return [LiquidColors.success, LiquidColors.accentBlue];
      case _AuthPhase.failed:
        return [const Color(0xFFFF6B6B), LiquidColors.error];
      case _AuthPhase.idle:
      case _AuthPhase.scanning:
        return [LiquidColors.accentBlue, LiquidColors.accentPurple];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = LiquidColors.isDark;
    final size = MediaQuery.of(context).size;
    final double disc = (size.shortestSide * 0.36).clamp(124.0, 168.0).toDouble();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: PopScope<BiometricAuthResult?>(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _close(BiometricAuthResult.cancelled);
        },
        child: Scaffold(
          backgroundColor: LiquidColors.backgroundDeep,
          body: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: Align(
                    alignment: const Alignment(0, -0.35),
                    child: Container(
                      width: disc * 2.7,
                      height: disc * 2.7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            _accent.withValues(alpha: 0.18),
                            _accent.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    _topBar(),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 28,
                                ),
                                child: FadeTransition(
                                  opacity: CurvedAnimation(
                                    parent: _entry,
                                    curve: Curves.easeOut,
                                  ),
                                  child: SlideTransition(
                                    position:
                                        Tween<Offset>(
                                          begin: const Offset(0, 0.05),
                                          end: Offset.zero,
                                        ).animate(
                                          CurvedAnimation(
                                            parent: _entry,
                                            curve: Curves.easeOutCubic,
                                          ),
                                        ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const SizedBox(height: 12),
                                        _securityBadge(),
                                        const SizedBox(height: 40),
                                        _orb(disc),
                                        const SizedBox(height: 36),
                                        _titleText(),
                                        const SizedBox(height: 12),
                                        _subtitleText(),
                                        const SizedBox(height: 20),
                                        SizedBox(
                                          height: 34,
                                          child: Center(child: _statusChip()),
                                        ),
                                        const SizedBox(height: 12),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                      child: _actions(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            _Pressable(
              onTap: () => _close(BiometricAuthResult.cancelled),
              borderRadius: 24,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: LiquidColors.surfaceMuted,
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: LiquidColors.textPrimary,
                  size: 22,
                ),
              ),
            ),
            const Spacer(),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        LiquidColors.accentBlue,
                        LiquidColors.accentPurple,
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: Colors.white,
                    size: 13,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'SecuroBox',
                  style: TextStyle(
                    color: LiquidColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const Spacer(),
            const SizedBox(width: 44),
          ],
        ),
      ),
    );
  }

  Widget _securityBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: LiquidColors.accentBlue.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: LiquidColors.accentBlue.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.shield_rounded,
            size: 13,
            color: LiquidColors.accentBlue,
          ),
          const SizedBox(width: 7),
          Text(
            'SECURE VERIFICATION',
            style: TextStyle(
              color: LiquidColors.accentBlue,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _orb(double disc) {
    final reserved = disc + 64;

    return RepaintBoundary(
      child: SizedBox(
        width: reserved,
        height: reserved,
        child: AnimatedBuilder(
          animation: Listenable.merge([_pulse, _ping, _success, _shake]),
          builder: (context, _) {
            final isFailed = _phase == _AuthPhase.failed;
            final isIdle = _phase == _AuthPhase.idle;
            final isScanning = _phase == _AuthPhase.scanning;
            final isSuccess = _phase == _AuthPhase.success;

            final c = _accent;
            final breathing = isIdle ? _pulse.value : 0.0;
            final successT = Curves.elasticOut.transform(
              isSuccess ? _success.value : 0.0,
            );
            final shakeDx = isFailed
                ? math.sin(_shake.value * math.pi * 4) * 10 * (1 - _shake.value)
                : 0.0;
            final pingActive = isIdle || isScanning;
            final pingT = _ping.value;
            final burstT = successT.clamp(0.0, 1.0);

            return Transform.translate(
              offset: Offset(shakeDx, 0),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (pingActive)
                    Opacity(
                      opacity: (1 - pingT) * 0.35,
                      child: Container(
                        width: disc + 52 * pingT,
                        height: disc + 52 * pingT,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: c.withValues(alpha: 0.55),
                            width: 1.4,
                          ),
                        ),
                      ),
                    ),
                  if (isSuccess && burstT < 1)
                    Opacity(
                      opacity: (1 - burstT) * 0.7,
                      child: Container(
                        width: disc + 70 * burstT,
                        height: disc + 70 * burstT,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: c.withValues(alpha: 0.7),
                            width: 2.5,
                          ),
                        ),
                      ),
                    ),
                  Container(
                    width: disc + 24,
                    height: disc + 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.withValues(alpha: 0.06 + 0.04 * breathing),
                    ),
                  ),
                  Transform.scale(
                    scale: isSuccess
                        ? (0.82 + 0.18 * burstT)
                        : (1.0 + 0.025 * breathing),
                    child: Container(
                      width: disc,
                      height: disc,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: _discGradient,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: c.withValues(alpha: 0.34),
                            blurRadius: 28,
                            spreadRadius: -2,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    center: const Alignment(-0.45, -0.5),
                                    radius: 0.85,
                                    colors: [
                                      Colors.white.withValues(alpha: 0.22),
                                      Colors.white.withValues(alpha: 0.0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (isScanning)
                              AnimatedBuilder(
                                animation: _sweep,
                                builder: (context, _) {
                                  final t = _sweep.value;
                                  final p = t < 0.5 ? t * 2 : (1 - t) * 2;
                                  final y = (p - 0.5) * disc * 0.88;
                                  return Transform.translate(
                                    offset: Offset(0, y),
                                    child: Container(
                                      width: disc,
                                      height: 3,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.white.withValues(alpha: 0.0),
                                            Colors.white.withValues(alpha: 0.92),
                                            Colors.white.withValues(alpha: 0.0),
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.white.withValues(
                                              alpha: 0.6,
                                            ),
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            Icon(
                              _iconForPhase(),
                              color: Colors.white,
                              size: disc * 0.42,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  IconData _iconForPhase() {
    switch (_phase) {
      case _AuthPhase.success:
        return Icons.check_rounded;
      case _AuthPhase.failed:
        return _cooldownLeft != null
            ? Icons.lock_clock_rounded
            : Icons.priority_high_rounded;
      case _AuthPhase.scanning:
        return _bioIcon;
      case _AuthPhase.idle:
        return (!_bioReady || !_introDone)
            ? Icons.lock_outline_rounded
            : _bioIcon;
    }
  }

  Widget _titleText() {
    final String text;
    switch (_phase) {
      case _AuthPhase.success:
        text = 'Verified';
        break;
      case _AuthPhase.failed:
        text = _cooldownLeft != null
            ? 'Too Many Attempts'
            : 'Verification Failed';
        break;
      case _AuthPhase.scanning:
        text = 'Verifying…';
        break;
      case _AuthPhase.idle:
        text = widget.title;
        break;
    }
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: LiquidColors.textPrimary,
        fontSize: 24,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        height: 1.15,
      ),
    );
  }

  Widget _subtitleText() {
    final String text;
    final isFailed = _phase == _AuthPhase.failed;
    switch (_phase) {
      case _AuthPhase.success:
        text = 'Your identity has been confirmed.';
        break;
      case _AuthPhase.failed:
        text = _errorMessage;
        break;
      case _AuthPhase.scanning:
        text = 'Authenticating with $_methodName…';
        break;
      case _AuthPhase.idle:
        text = (!_bioReady)
            ? 'Preparing secure authentication…'
            : widget.subtitle;
        break;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isFailed ? LiquidColors.error : LiquidColors.textSecondary,
          fontSize: 14,
          height: 1.5,
          fontWeight: isFailed ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
    );
  }

  Widget _statusChip() {
    switch (_phase) {
      case _AuthPhase.scanning:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: LiquidColors.accentBlue.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: LiquidColors.accentBlue.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppLoader(size: 20),
              const SizedBox(width: 9),
              Text(
                'SCANNING…',
                style: TextStyle(
                  color: LiquidColors.accentBlue,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        );
      case _AuthPhase.idle:
        if (!_bioReady || !_introDone) return const SizedBox.shrink();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _showFaceIcon
                  ? Icons.face_retouching_natural
                  : Icons.fingerprint_rounded,
              size: 16,
              color: LiquidColors.textTertiary,
            ),
            const SizedBox(width: 7),
            Text(
              _showFaceIcon
                  ? 'Look at the camera to verify'
                  : 'Touch the fingerprint sensor',
              style: TextStyle(
                color: LiquidColors.textTertiary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        );
      case _AuthPhase.failed:
      case _AuthPhase.success:
        return const SizedBox.shrink();
    }
  }

  Widget _actions() {
    switch (_phase) {
      case _AuthPhase.success:
        return const SizedBox(height: 4);

      case _AuthPhase.scanning:
      case _AuthPhase.idle:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.allowPinFallback) ...[
              _primaryButton(
                icon: widget.fallbackIcon,
                label: widget.fallbackLabel,
                onTap: () => _close(BiometricAuthResult.usePin),
              ),
              const SizedBox(height: 10),
            ],
            _secondaryButton(
              icon: Icons.close_rounded,
              label: 'Cancel',
              onTap: () => _close(BiometricAuthResult.cancelled),
            ),
          ],
        );

      case _AuthPhase.failed:
        final coolingDown = _cooldownLeft != null;
        final canSwitch = _hasFace && _hasFingerprint;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (coolingDown) ...[
              _countdownCard(_cooldownLeft!),
              const SizedBox(height: 14),
              if (widget.allowPinFallback) ...[
                _primaryButton(
                  icon: widget.fallbackIcon,
                  label: widget.fallbackLabel,
                  onTap: () => _close(BiometricAuthResult.usePin),
                ),
                const SizedBox(height: 10),
              ],
              _secondaryButton(
                icon: Icons.close_rounded,
                label: 'Cancel',
                onTap: () => _close(BiometricAuthResult.cancelled),
              ),
            ] else ...[
              _primaryButton(
                icon: Icons.refresh_rounded,
                label: 'Try Again',
                onTap: _retry,
              ),
              const SizedBox(height: 10),
              if (canSwitch) ...[
                _secondaryButton(
                  icon: _showFaceIcon
                      ? Icons.fingerprint_rounded
                      : Icons.face_retouching_natural,
                  label: 'Use ${_showFaceIcon ? 'Fingerprint' : 'Face ID'}',
                  onTap: _switchMethod,
                ),
                const SizedBox(height: 10),
              ],
              if (widget.allowPinFallback) ...[
                _secondaryButton(
                  icon: widget.fallbackIcon,
                  label: widget.fallbackLabel,
                  onTap: () => _close(BiometricAuthResult.usePin),
                ),
                const SizedBox(height: 6),
              ],
              _textLink(
                'Cancel',
                onTap: () => _close(BiometricAuthResult.cancelled),
              ),
            ],
          ],
        );
    }
  }

  Widget _countdownCard(Duration left) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: BoxDecoration(
        color: LiquidColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: LiquidColors.error.withValues(alpha: 0.22),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_clock_rounded,
                size: 15,
                color: LiquidColors.error,
              ),
              const SizedBox(width: 6),
              Text(
                'BIOMETRICS LOCKED',
                style: TextStyle(
                  color: LiquidColors.error,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _formatCountdown(left),
            style: TextStyle(
              color: LiquidColors.error,
              fontSize: 40,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              height: 1.0,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Use your PIN, or wait for the timer.',
            style: TextStyle(
              color: LiquidColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return _Pressable(
      onTap: onTap,
      borderRadius: 16,
      child: Container(
        width: double.infinity,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [LiquidColors.accentBlue, LiquidColors.accentPurple],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: LiquidColors.accentBlue.withValues(alpha: 0.35),
              blurRadius: 16,
              spreadRadius: -2,
              offset: const Offset(0, 8),
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

  Widget _secondaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return _Pressable(
      onTap: onTap,
      borderRadius: 16,
      child: Container(
        width: double.infinity,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: LiquidColors.surfaceMuted,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: LiquidColors.cardBorder, width: 1.2),
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

  Widget _textLink(String label, {required VoidCallback onTap}) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: LiquidColors.textTertiary,
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double borderRadius;
  const _Pressable({
    required this.child,
    required this.onTap,
    this.borderRadius = 12,
  });

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
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
