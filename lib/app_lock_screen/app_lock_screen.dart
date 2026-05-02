import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:video_player_app/app_lock_screen/widgets/liquid_action_button.dart';
import 'package:video_player_app/app_lock_screen/widgets/liquid_lock_header.dart';
import 'package:video_player_app/app_lock_screen/widgets/liquid_number_button.dart';
import 'package:video_player_app/app_lock_screen/widgets/liquid_pin_dots.dart';
import 'package:video_player_app/utils/flush_bar_helper.dart';
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

      if (!isSupported || !canCheck) {
        FlushBarHelper.flushBarErrorMessage('Biometric not available', context);
        return;
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Unlock Secure Player',
        biometricOnly: true,

        sensitiveTransaction: true,
      );

      if (authenticated && mounted) {
        _unlockApp();
      }
    } catch (e) {
      FlushBarHelper.flushBarErrorMessage('Biometric error', context);
    } finally {
      if (mounted) setState(() => _isAuthenticating = false);
    }
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
                              isEnabled: _biometricEnabled && !_isAuthenticating,
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
                              onPressed: _isAuthenticating ? null : _useBiometric,
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
