import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:video_player_app/app_lock_screen/widgets/liquid_action_button.dart';
import 'package:video_player_app/app_lock_screen/widgets/liquid_lock_header.dart';
import 'package:video_player_app/app_lock_screen/widgets/liquid_number_button.dart';
import 'package:video_player_app/app_lock_screen/widgets/liquid_pin_dots.dart';
import 'package:video_player_app/onboarding_screen/forgot_pin_screen.dart';
import 'package:video_player_app/utils/intrusion_service.dart';
import 'package:video_player_app/utils/pin_crypto.dart';
import 'package:video_player_app/utils/session_manager.dart';

import '../main_screen.dart';
import '../utils/liquid_colors.dart';

class AppLockScreen extends StatefulWidget {
  final bool isOverlay;
  const AppLockScreen({super.key, this.isOverlay = false});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen>
    with SingleTickerProviderStateMixin {
  String _enteredPin = '';
  int _pinLength = PinCrypto.defaultPinLength;

  bool _biometricEnabled = false;
  bool _isAuthenticating = false;
  bool _hasError = false;

  Duration? _cooldownRemaining;
  Timer? _cooldownTicker;

  late AnimationController _errorController;
  late Animation<double> _shakeAnimation;

  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _startCooldownTicker();

    _errorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(parent: _errorController, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _cooldownTicker?.cancel();
    _errorController.dispose();
    super.dispose();
  }

  void _startCooldownTicker() {
    _refreshCooldown();
    _cooldownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _refreshCooldown();
    });
  }

  Future<void> _refreshCooldown() async {
    final remaining = await SessionManager.instance.getCooldownRemaining();
    if (mounted) setState(() => _cooldownRemaining = remaining);
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final pinLen = await PinCrypto.instance.getPinLength();
    if (!mounted) return;
    setState(() {
      _biometricEnabled = prefs.getBool('biometric') ?? false;
      _pinLength = pinLen;
    });

    if (_biometricEnabled && mounted && _cooldownRemaining == null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _useBiometric();
      });
    }
  }

  bool get _padDisabled => _cooldownRemaining != null;

  void _onNumberPressed(String number) {
    if (_padDisabled) return;
    if (_enteredPin.length < _pinLength) {
      HapticFeedback.lightImpact();
      setState(() {
        _enteredPin += number;
        _hasError = false;
      });
      if (_enteredPin.length == _pinLength) _checkPin();
    }
  }

  void _onDeletePressed() {
    if (_padDisabled) return;
    if (_enteredPin.isNotEmpty) {
      HapticFeedback.selectionClick();
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _hasError = false;
      });
    }
  }

  Future<void> _checkPin() async {
    final isCorrect = await PinCrypto.instance.verifyPin(_enteredPin);

    if (isCorrect && mounted) {
      _unlockApp();
    } else {
      HapticFeedback.heavyImpact();
      await SessionManager.instance.recordFailedAttempt();
      unawaited(IntrusionService.instance.captureSilently());
      if (!mounted) return;
      setState(() {
        _enteredPin = '';
        _hasError = true;
      });
      _errorController.forward().then((_) => _errorController.reverse());
      await _refreshCooldown();
      _showErrorFeedback();
    }
  }

  Future<void> _unlockApp() async {
    await SessionManager.instance.unlock();
    if (!mounted) return;
    if (widget.isOverlay) {
      Navigator.of(context).pop();
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    }
  }

  String _formatCooldown(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  void _showErrorFeedback() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            const Text('Incorrect PIN'),
          ],
        ),
        backgroundColor: LiquidColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _useBiometric() async {
    if (_isAuthenticating) return;

    setState(() => _isAuthenticating = true);

    try {
      final isSupported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!mounted) return;

      if (!isSupported || !canCheck) {
        await _showAuthFailureDialog(
          title: 'Biometric Not Available',
          message:
              'This device doesn\'t support biometric authentication, or no biometrics have been enrolled in system settings.',
        );
        return;
      }

      final authenticated = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => _CustomAuthDialog(
          localAuth: _localAuth,
        ),
      );
      if (!mounted) return;

      if (authenticated == true) {
        _unlockApp();
      } else if (authenticated == false) {
        await _showAuthFailureDialog(
          title: 'Authentication Failed',
          message:
              'We couldn\'t verify your identity. Please try again or use your PIN.',
        );
      }
    } catch (_) {
      if (!mounted) return;
      await _showAuthFailureDialog(
        title: 'Authentication Error',
        message: 'Something went wrong. Please try again or use your PIN.',
      );
    } finally {
      if (mounted) setState(() => _isAuthenticating = false);
    }
  }

  Future<void> _showAuthFailureDialog({
    required String title,
    required String message,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1D2E),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: LiquidColors.error.withValues(alpha: 0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: LiquidColors.error.withValues(alpha: 0.2),
                blurRadius: 26,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: LiquidColors.error.withValues(alpha: 0.16),
                  border: Border.all(
                    color: LiquidColors.error.withValues(alpha: 0.4),
                    width: 1.4,
                  ),
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  color: LiquidColors.error,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LiquidColors.accentBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      fontSize: 14,
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
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              LiquidColors.backgroundDeep,
              LiquidColors.backgroundMid,
              LiquidColors.backgroundLight,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Container(
                width: size.width > 420 ? 420 : double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      LiquidColors.backgroundLight.withValues(alpha: .3),
                      LiquidColors.backgroundMid.withValues(alpha: .4),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: LiquidColors.accentBlue.withValues(alpha: .2),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .3),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                    BoxShadow(
                      color: LiquidColors.accentBlue.withValues(alpha: .1),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const LiquidLockHeader(
                      title: 'Secure Player',
                      subtitle: 'Enter your PIN to continue',
                    ),

                    const SizedBox(height: 32),

                    AnimatedBuilder(
                      animation: _errorController,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(_shakeAnimation.value, 0),
                          child: LiquidPinDots(
                            enteredLength: _enteredPin.length,
                            totalLength: _pinLength,
                            hasError: _hasError,
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 32),

                    if (!_padDisabled)
                      GridView.builder(
                        shrinkWrap: true,
                        itemCount: 12,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              childAspectRatio: 1.2,
                            ),
                        itemBuilder: (context, index) {
                          if (index == 9) {
                            return LiquidActionButton(
                              icon: Icons.fingerprint,
                              color: LiquidColors.success,
                              onPressed: _useBiometric,
                              isEnabled:
                                  _biometricEnabled && !_isAuthenticating,
                            );
                          }
                          if (index == 10) {
                            return LiquidNumberButton(
                              number: '0',
                              onPressed: () => _onNumberPressed('0'),
                            );
                          }
                          if (index == 11) {
                            return LiquidActionButton(
                              icon: Icons.backspace,
                              color: LiquidColors.error,
                              onPressed: _onDeletePressed,
                            );
                          }
                          return LiquidNumberButton(
                            number: '${index + 1}',
                            onPressed: () => _onNumberPressed('${index + 1}'),
                          );
                        },
                      ),

                    if (_padDisabled)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              LiquidColors.error.withValues(alpha: .2),
                              LiquidColors.error.withValues(alpha: .1),
                            ],
                            center: Alignment.center,
                            radius: 0.8,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: LiquidColors.error.withValues(alpha: .3),
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.lock_clock_rounded,
                              color: LiquidColors.error,
                              size: 40,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Too many wrong attempts',
                              style: TextStyle(
                                color: LiquidColors.error,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Try again in ${_formatCooldown(_cooldownRemaining!)}',
                              style: TextStyle(
                                color: Colors.grey.shade300,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 20),

                    if (_padDisabled || _biometricEnabled)
                      TweenAnimationBuilder(
                        tween: Tween<double>(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.elasticOut,
                        builder: (context, double value, child) {
                          return Transform.scale(
                            scale: value,
                            child: TextButton.icon(
                              onPressed: _isAuthenticating
                                  ? null
                                  : _useBiometric,
                              icon: _isAuthenticating
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: LiquidColors.success,
                                      ),
                                    )
                                  : Icon(
                                      Icons.fingerprint,
                                      color: LiquidColors.success,
                                      size: 24,
                                    ),
                              label: Text(
                                _isAuthenticating
                                    ? 'Authenticating...'
                                    : 'Unlock with Biometric',
                                style: TextStyle(
                                  color: LiquidColors.success,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                    const SizedBox(height: 8),

                    TextButton.icon(
                      onPressed: _isAuthenticating
                          ? null
                          : () {
                              HapticFeedback.lightImpact();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ForgotPinScreen(),
                                ),
                              );
                            },
                      icon: Icon(
                        Icons.help_outline_rounded,
                        size: 16,
                        color: Colors.grey.shade400,
                      ),
                      label: Text(
                        'Forgot PIN?',
                        style: TextStyle(
                          color: Colors.grey.shade300,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomAuthDialog extends StatefulWidget {
  final LocalAuthentication localAuth;

  const _CustomAuthDialog({required this.localAuth});

  @override
  State<_CustomAuthDialog> createState() => _CustomAuthDialogState();
}

class _CustomAuthDialogState extends State<_CustomAuthDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  bool _running = false;
  String _status = 'Place your finger on the sensor';
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _runAuth());
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _runAuth() async {
    if (_running) return;
    setState(() {
      _running = true;
      _failed = false;
      _status = 'Place your finger on the sensor';
    });
    try {
      final ok = await widget.localAuth.authenticate(
        localizedReason: 'Unlock Secure Player',
        biometricOnly: true,
        sensitiveTransaction: true,
      );
      if (!mounted) return;
      if (ok) {
        setState(() => _status = 'Verified');
        await Future.delayed(const Duration(milliseconds: 350));
        if (mounted) Navigator.of(context).pop(true);
      } else {
        setState(() {
          _running = false;
          _failed = true;
          _status = 'Authentication cancelled';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _running = false;
        _failed = true;
        _status = 'Couldn\'t verify. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _failed ? LiquidColors.error : LiquidColors.success;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D2E),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.25),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _running
                  ? _pulseAnimation
                  : const AlwaysStoppedAnimation(1.0),
              child: Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      accent.withValues(alpha: 0.35),
                      accent.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  _failed
                      ? Icons.error_outline_rounded
                      : Icons.fingerprint_rounded,
                  color: accent,
                  size: 46,
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Authenticate',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 6),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _status,
                key: ValueKey(_status),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _failed ? LiquidColors.error : Colors.grey.shade400,
                  fontSize: 13,
                  height: 1.4,
                  fontWeight:
                      _failed ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 22),
            if (_failed) ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _runAuth,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text(
                    'Try Again',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LiquidColors.accentBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: Text(
                'Use PIN instead',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
