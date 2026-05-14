import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_app/app_lock_screen/widgets/liquid_action_button.dart';
import 'package:video_player_app/app_lock_screen/widgets/liquid_lock_header.dart';
import 'package:video_player_app/app_lock_screen/widgets/liquid_number_button.dart';
import 'package:video_player_app/app_lock_screen/widgets/liquid_pin_dots.dart';
import 'package:video_player_app/onboarding_screen/forgot_pin_screen.dart';
import 'package:video_player_app/security_settings/face_scan_screen.dart';
import 'package:video_player_app/utils/decoy_service.dart';
import 'package:video_player_app/utils/face_recognition_service.dart';
import 'package:video_player_app/utils/intrusion_service.dart';
import 'package:video_player_app/utils/pin_crypto.dart';
import 'package:video_player_app/utils/session_manager.dart';
import 'package:video_player_app/utils/vault_context.dart';
import 'package:video_player_app/utils/vault_crypto.dart';
import 'package:video_player_app/widgets/biometric_auth_sheet.dart';

import '../main_screen.dart';
import '../utils/liquid_colors.dart';

class AppLockScreen extends StatefulWidget {
  final bool isOverlay;
  const AppLockScreen({super.key, this.isOverlay = false});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen>
    with TickerProviderStateMixin {
  String _enteredPin = '';
  int _pinLength = PinCrypto.defaultPinLength;

  bool _biometricEnabled = false;
  bool _faceRecogEnrolled = false;
  bool _isAuthenticating = false;
  bool _hasError = false;
  // Banking-style flow: open on the biometric / face-scan stage, fall back to
  // the PIN keypad only if biometrics fail or the user taps "Use PIN".
  bool _showPin = false;

  Duration? _cooldownRemaining;
  // Separate, parallel cooldown that locks ONLY the biometric / face-scan path
  // after 3 failed attempts; the PIN keypad stays usable throughout.
  Duration? _bioCooldownRemaining;
  int _bioFailCount = 0;
  Timer? _cooldownTicker;

  late AnimationController _errorController;
  late Animation<double> _shakeAnimation;
  late final AnimationController _bioPulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  )..repeat(reverse: true);

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
    _bioPulse.dispose();
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
    final bioRemaining =
        await SessionManager.instance.getBiometricCooldownRemaining();
    final bioFails = await SessionManager.instance.getFailedBiometricAttempts();
    if (mounted) {
      setState(() {
        _cooldownRemaining = remaining;
        _bioCooldownRemaining = bioRemaining;
        _bioFailCount = bioFails;
      });
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final pinLen = await PinCrypto.instance.getPinLength();
    final faceEnrolled = await FaceRecognitionService.instance.isEnrolled();
    final bioCooldown =
        await SessionManager.instance.getBiometricCooldownRemaining();
    final bioFails = await SessionManager.instance.getFailedBiometricAttempts();
    if (!mounted) return;
    final bioEnabled =
        (prefs.getBool('biometric') ?? false) ||
        (prefs.getBool('biometric_face') ?? false);
    setState(() {
      _biometricEnabled = bioEnabled;
      _faceRecogEnrolled = faceEnrolled;
      _pinLength = pinLen;
      _bioCooldownRemaining = bioCooldown;
      _bioFailCount = bioFails;
      // Nothing to verify with → go straight to the PIN keypad.
      if (!bioEnabled && !faceEnrolled) _showPin = true;
    });

    if (_biometricEnabled &&
        mounted &&
        _cooldownRemaining == null &&
        !_bioLocked) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_showPin && !_bioLocked) _useBiometric();
      });
    }
  }

  bool get _padDisabled => _cooldownRemaining != null;
  bool get _bioLocked => _bioCooldownRemaining != null;

  /// Records one failed biometric / face-scan attempt; after the 3rd, the
  /// 60-second biometric cooldown kicks in (PIN keypad still works).
  Future<void> _recordBioFailure() async {
    final count = await SessionManager.instance.recordFailedBiometricAttempt();
    final remaining =
        await SessionManager.instance.getBiometricCooldownRemaining();
    if (!mounted) return;
    final justLocked = !_bioLocked && remaining != null;
    setState(() {
      _bioCooldownRemaining = remaining;
      _bioFailCount = count;
    });
    if (justLocked) HapticFeedback.heavyImpact();
  }

  /// Small "attempts before biometric lock" hint, shown once the user has at
  /// least one failed biometric / face-scan try and isn't already locked out.
  Widget _bioAttemptsBanner() {
    final left = SessionManager.bioCooldownThreshold - _bioFailCount;
    if (_bioLocked || _bioFailCount <= 0 || left <= 0) {
      return const SizedBox.shrink();
    }
    final msg = left == 1
        ? 'Last try before a 60s lock'
        : '$left of ${SessionManager.bioCooldownThreshold} biometric tries left';
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: LiquidColors.warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: LiquidColors.warning.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 15,
              color: LiquidColors.warning,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                msg,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                  color: LiquidColors.warning,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
    // 1. Real PIN → real vault.
    if (await PinCrypto.instance.verifyPin(_enteredPin)) {
      if (!mounted) return;
      VaultContext.instance.exitDecoy();
      _unlockApp();
      return;
    }

    // 2. Decoy PIN → completely separate fake vault. Silently log who's
    //    coercing access; the entry leaves a hidden audit trail.
    if (await DecoyService.instance.verifyFakePin(_enteredPin)) {
      if (!mounted) return;
      VaultContext.instance.enterDecoy();
      unawaited(VaultCrypto.instance.wipeAllTempCache());
      unawaited(IntrusionService.instance.captureSilently());
      unawaited(DecoyService.instance.recordDuressEntry());
      _unlockApp();
      return;
    }

    // 3. Wrong → cooldown + intruder capture.
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

  Future<void> _unlockApp() async {
    await SessionManager.instance.unlock();
    if (!mounted) return;
    final modeChanged = VaultContext.instance.modeChanged;
    VaultContext.instance.clearModeChanged();
    // If the vault mode flipped, the existing screen stack holds data from the
    // other namespace — tear it down and rebuild from scratch.
    if (widget.isOverlay && !modeChanged) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (_) => false,
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
            Icon(
              Icons.error_outline_rounded,
              color: LiquidColors.textPrimary,
              size: 20,
            ),
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
    if (_isAuthenticating || _bioLocked) return;
    setState(() => _isAuthenticating = true);
    try {
      final result = await BiometricAuthSheet.show(
        context,
        title: 'Verify Your Identity',
        subtitle: 'Use Fingerprint or Face ID to unlock SecuroBox',
        localizedReason: 'Unlock SecuroBox',
      );
      if (!mounted) return;
      if (result == BiometricAuthResult.authenticated) {
        // Biometric verifies the device owner → always the real vault.
        VaultContext.instance.exitDecoy();
        _unlockApp();
        return;
      }
      if (result == BiometricAuthResult.usePin) {
        // Deliberate switch to the keypad — not a failed attempt.
        HapticFeedback.selectionClick();
        setState(() => _showPin = true);
      }
      // The sheet records each failed attempt (and runs its own 60s countdown)
      // itself — just pull the latest cooldown / strike count into this screen.
      await _refreshCooldown();
    } finally {
      if (mounted) setState(() => _isAuthenticating = false);
    }
  }

  Future<void> _useFaceUnlock() async {
    if (_isAuthenticating || _padDisabled || _bioLocked) return;
    setState(() => _isAuthenticating = true);
    try {
      final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => const FaceScanScreen(mode: FaceScanMode.verify),
          fullscreenDialog: true,
        ),
      );
      if (!mounted) return;
      if (ok == true) {
        // Recognized the device owner → real vault.
        VaultContext.instance.exitDecoy();
        _unlockApp();
      } else {
        await _recordBioFailure();
      }
    } catch (_) {
      // Fall back to PIN silently.
    } finally {
      if (mounted) setState(() => _isAuthenticating = false);
    }
  }

  /// Two side-by-side unlock options: fingerprint (left) and face scan (right).
  /// Whichever isn't available is shown dimmed; in the wrong-PIN cooldown only
  /// the (strong) device biometric is offered — the in-app face scan is hidden.
  Widget _buildBiometricOptions() {
    final showFace = _faceRecogEnrolled && !_padDisabled && !_bioLocked;
    final fingerprintActive = (_biometricEnabled || _padDisabled) && !_bioLocked;
    // Nothing useful to offer.
    if (!fingerprintActive && !showFace && !_faceRecogEnrolled && !_bioLocked) {
      return const SizedBox.shrink();
    }

    final String? bioLockHint = _bioLocked
        ? 'Try again in ${_formatCooldown(_bioCooldownRemaining!)}'
        : null;

    final fpTile = _BioTile(
      icon: Icons.fingerprint_rounded,
      label: 'Fingerprint',
      accent: LiquidColors.accentBlue,
      busy: _isAuthenticating,
      onTap: (fingerprintActive && !_isAuthenticating) ? _useBiometric : null,
      disabledHint: bioLockHint ?? 'Enable in Settings',
    );
    final faceTile = _BioTile(
      icon: Icons.face_retouching_natural,
      label: 'Face Scan',
      accent: LiquidColors.accentPurple,
      onTap: (showFace && !_isAuthenticating) ? _useFaceUnlock : null,
      disabledHint: bioLockHint ??
          (_padDisabled
              ? 'Locked during cooldown'
              : (_faceRecogEnrolled ? null : 'Set up in Settings')),
    );

    // During the wrong-PIN cooldown only the device biometric makes sense; if
    // the biometric path itself is on its 60s cooldown, show that tile alone too.
    if (_padDisabled || _bioLocked) {
      return Center(child: SizedBox(width: 210, child: fpTile));
    }

    return Row(
      children: [
        Expanded(child: fpTile),
        const SizedBox(width: 12),
        Expanded(child: faceTile),
      ],
    );
  }

  /// The "biometric first" screen shown before the keypad: a big tappable
  /// biometric orb, then (if both are set up) a "Scan Face instead" link, then
  /// the "Use PIN instead" fallback button.
  /// Shown on the biometric stage once the 3-strike 60s cooldown is active:
  /// biometrics are temporarily off-limits, but the PIN keypad still works.
  Widget _bioLockedStage() {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 108,
          height: 108,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: LiquidColors.error.withValues(alpha: 0.14),
            border: Border.all(
              color: LiquidColors.error.withValues(alpha: 0.4),
              width: 1.4,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.lock_clock_rounded,
            color: LiquidColors.error,
            size: 48,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Biometric unlock locked',
          style: TextStyle(
            color: LiquidColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Too many failed attempts. Try Face ID or fingerprint again in '
          '${_formatCooldown(_bioCooldownRemaining!)} — or unlock with your PIN.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: LiquidColors.textSecondary,
            fontSize: 13.5,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () {
            HapticFeedback.selectionClick();
            setState(() => _showPin = true);
          },
          icon: Icon(
            Icons.dialpad_rounded,
            size: 18,
            color: LiquidColors.textPrimary,
          ),
          label: Text(
            'Use PIN instead',
            style: TextStyle(
              color: LiquidColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: LiquidColors.cardBorder),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBiometricStage() {
    if (_bioLocked) return _bioLockedStage();
    final faceOnly = !_biometricEnabled && _faceRecogEnrolled;
    final icon = faceOnly
        ? Icons.face_retouching_natural
        : Icons.fingerprint_rounded;
    final accent = faceOnly
        ? LiquidColors.accentPurple
        : LiquidColors.accentBlue;

    void primary() {
      if (_isAuthenticating) return;
      if (_biometricEnabled) {
        _useBiometric();
      } else if (_faceRecogEnrolled) {
        _useFaceUnlock();
      }
    }

    final String status = _isAuthenticating
        ? 'Authenticating…'
        : _padDisabled
        ? 'Biometrics still work during the cooldown — tap to unlock.'
        : 'Tap to unlock with your fingerprint or face.';

    return Column(
      children: [
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _bioPulse,
          builder: (context, _) {
            final t = _bioPulse.value;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _isAuthenticating ? null : primary,
              child: Container(
                width: 108,
                height: 108,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [accent, accent.withValues(alpha: 0.65)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.28 + 0.18 * t),
                      blurRadius: 30 + 16 * t,
                      spreadRadius: 3 + 5 * t,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: _isAuthenticating
                    ? const SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.6,
                          color: Colors.white,
                        ),
                      )
                    : Icon(icon, color: Colors.white, size: 48),
              ),
            );
          },
        ),
        const SizedBox(height: 22),
        Text(
          'Verify Your Identity',
          style: TextStyle(
            color: LiquidColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          status,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: LiquidColors.textSecondary,
            fontSize: 13.5,
            height: 1.5,
          ),
        ),
        _bioAttemptsBanner(),
        const SizedBox(height: 24),
        if (_biometricEnabled && _faceRecogEnrolled && !_padDisabled) ...[
          TextButton.icon(
            onPressed: _isAuthenticating ? null : _useFaceUnlock,
            icon: Icon(
              Icons.face_retouching_natural,
              size: 18,
              color: LiquidColors.accentPurple,
            ),
            label: Text(
              'Scan Face instead',
              style: TextStyle(
                color: LiquidColors.accentPurple,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 2),
        ],
        OutlinedButton.icon(
          onPressed: _isAuthenticating
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  setState(() => _showPin = true);
                },
          icon: Icon(
            Icons.dialpad_rounded,
            size: 18,
            color: LiquidColors.textPrimary,
          ),
          label: Text(
            'Use PIN instead',
            style: TextStyle(
              color: LiquidColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: LiquidColors.cardBorder),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
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
                    LiquidLockHeader(
                      title: 'SecuroBox',
                      subtitle: _showPin
                          ? 'Enter your PIN to continue'
                          : 'Verify your identity to unlock',
                    ),

                    if (_showPin) ...[
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
                            // if (index == 9) {
                            //   return LiquidActionButton(
                            //     icon: Icons.fingerprint,
                            //     color: LiquidColors.success,
                            //     onPressed: _useBiometric,
                            //     isEnabled:
                            //         _biometricEnabled && !_isAuthenticating,
                            //   );
                            // }
                            if (index == 9) {
                              return Container();
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
                                  color: LiquidColors.textSecondary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 20),

                      _buildBiometricOptions(),
                      _bioAttemptsBanner(),
                     ]
                     else ...[
                       const SizedBox(height: 26),
                      _buildBiometricStage(),
                     ],

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
                        color: LiquidColors.textSecondary,
                      ),
                      label: Text(
                        'Forgot PIN?',
                        style: TextStyle(
                          color: LiquidColors.textSecondary,
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

/// One of the two side-by-side unlock tiles on the lock screen.
class _BioTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback? onTap;
  final bool busy;
  final String? disabledHint;

  const _BioTile({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
    this.busy = false,
    this.disabledHint,
  });

  @override
  State<_BioTile> createState() => _BioTileState();
}

class _BioTileState extends State<_BioTile> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final accent = widget.accent;
    final fg = enabled ? accent : LiquidColors.textTertiary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              widget.onTap!();
            }
          : null,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            gradient: enabled
                ? LinearGradient(
                    colors: [
                      accent.withValues(alpha: 0.16),
                      accent.withValues(alpha: 0.06),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: enabled
                ? null
                : LiquidColors.textPrimary.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: enabled
                  ? accent.withValues(alpha: 0.4)
                  : LiquidColors.cardBorder,
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.18),
                      blurRadius: 16,
                      spreadRadius: -3,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (enabled ? accent : LiquidColors.textTertiary)
                      .withValues(alpha: 0.18),
                ),
                child: widget.busy
                    ? Padding(
                        padding: const EdgeInsets.all(11),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: fg,
                        ),
                      )
                    : Icon(widget.icon, color: fg, size: 23),
              ),
              const SizedBox(height: 9),
              Text(
                widget.label,
                style: TextStyle(
                  color: enabled ? LiquidColors.textPrimary : fg,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (!enabled && widget.disabledHint != null) ...[
                const SizedBox(height: 2),
                Text(
                  widget.disabledHint!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: LiquidColors.textTertiary,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
