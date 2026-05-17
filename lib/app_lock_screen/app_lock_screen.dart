import 'dart:async';
import 'dart:math' as math;
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
import 'package:video_player_app/utils/network_guard.dart';
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
  bool _showPin = false;

  Duration? _cooldownRemaining;

  Duration? _bioCooldownRemaining;
  int _bioFailCount = 0;
  Timer? _cooldownTicker;

  late AnimationController _errorController;
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
      duration: const Duration(milliseconds: 500),
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
    final bioRemaining = await SessionManager.instance
        .getBiometricCooldownRemaining();
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
    final bioCooldown = await SessionManager.instance
        .getBiometricCooldownRemaining();
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
      // The bio stage rests when any biometric / face method exists;
      // otherwise the PIN keypad is the resting stage.
      if (!bioEnabled && !faceEnrolled) _showPin = true;
    });

    if (_cooldownRemaining == null &&
        mounted &&
        !NetworkGuard.instance.blockUnlock) {
      if (_biometricEnabled && !_bioLocked) {
        // Biometric / Face ID is triggered first on open; otherwise the
        // PIN keypad is already the resting stage.
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && !_showPin && !_bioLocked) _useBiometric();
        });
      }
    }
  }

  bool get _padDisabled => _cooldownRemaining != null;
  bool get _bioLocked => _bioCooldownRemaining != null;

  /// Records one failed biometric / face-scan attempt; after the 3rd, the
  /// 60-second biometric cooldown kicks in (PIN keypad still works).
  Future<void> _recordBioFailure() async {
    final count = await SessionManager.instance.recordFailedBiometricAttempt();
    final remaining = await SessionManager.instance
        .getBiometricCooldownRemaining();
    if (!mounted) return;
    final justLocked = !_bioLocked && remaining != null;
    setState(() {
      _bioCooldownRemaining = remaining;
      _bioFailCount = count;
    });
    if (justLocked) HapticFeedback.heavyImpact();
  }

  /// Inline "Incorrect PIN" feedback right under the dots. Lighter than the
  /// previous floating snackbar — the user keeps the context of their entry.
  Widget _wrongPinBanner() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: child),
      child: !_hasError
          ? const SizedBox.shrink(key: ValueKey('clean'))
          : Padding(
              key: const ValueKey('error'),
              padding: const EdgeInsets.only(top: 14),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: LiquidColors.error.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: LiquidColors.error.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 15,
                      color: LiquidColors.error,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Incorrect PIN — try again',
                      style: TextStyle(
                        color: LiquidColors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
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
          border: Border.all(
            color: LiquidColors.warning.withValues(alpha: 0.3),
          ),
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

  /// Shown whenever the Offline Integrity Lock is on and the device has a
  /// network path: the vault is sealed and no credential will open it until
  /// the user goes fully offline. Reacts live to connectivity changes.
  Widget _networkSealBanner() {
    return ValueListenableBuilder<bool>(
      valueListenable: NetworkGuard.instance.online,
      builder: (context, online, _) {
        if (!NetworkGuard.instance.enabled || !online) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: LiquidColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: LiquidColors.warning.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.wifi_off_rounded,
                  color: LiquidColors.warning,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vault sealed while online',
                        style: TextStyle(
                          color: LiquidColors.warning,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Offline Integrity Lock is on. Turn on Airplane Mode '
                        '(or disable Wi-Fi and mobile data) to unlock.',
                        style: TextStyle(
                          color: LiquidColors.textSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
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

    // 3. Wrong → cooldown. Capture a break-in photo only on the 3rd failed
    //    attempt — the first two misses are usually the owner mistyping, so
    //    capturing earlier would just photograph them.
    HapticFeedback.heavyImpact();
    final failedAttempts = await SessionManager.instance.recordFailedAttempt();
    if (failedAttempts == 3) {
      unawaited(IntrusionService.instance.captureSilently());
    }
    if (!mounted) return;
    setState(() {
      _enteredPin = '';
      _hasError = true;
    });
    _errorController.forward(from: 0);
    await _refreshCooldown();
  }

  Future<void> _unlockApp() async {
    // Offline Integrity Lock: even a correct credential cannot open the vault
    // while the device has a network path — decrypted content must never be
    // available during network exposure. The banner explains why.
    if (NetworkGuard.instance.blockUnlock) {
      HapticFeedback.heavyImpact();
      return;
    }
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
    final totalSeconds = d.inSeconds;
    if (totalSeconds < 60) {
      return '$totalSeconds second${totalSeconds == 1 ? '' : 's'}';
    }
    final m = d.inMinutes;
    final s = totalSeconds % 60;
    if (s == 0) return '$m minute${m == 1 ? '' : 's'}';
    return '${m}m ${s}s';
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
        // Deliberate switch away from biometric — not a failed attempt.
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
    final fingerprintActive =
        (_biometricEnabled || _padDisabled) && !_bioLocked;
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
      disabledHint:
          bioLockHint ??
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
          'Biometrics paused',
          style: TextStyle(
            color: LiquidColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Too many failed tries. You can try Face ID or fingerprint again in '
          '${_formatCooldown(_bioCooldownRemaining!)}, or unlock with your PIN below.',
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
        ? 'Checking your identity…'
        : _padDisabled
        ? 'Your PIN is locked for now — tap to unlock with biometrics.'
        : faceOnly
        ? 'Tap to unlock with Face ID.'
        : 'Tap to unlock with your fingerprint or face.';

    return Column(
      children: [
        const SizedBox(height: 8),
        // Isolated so the orb's 60fps pulse + glow blur repaints only itself,
        // not the rest of the lock card.
        RepaintBoundary(
          child: AnimatedBuilder(
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
        ),
        const SizedBox(height: 22),
        Text(
          'Welcome back',
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
                      LiquidColors.backgroundLight.withValues(alpha: .28),
                      LiquidColors.backgroundMid.withValues(alpha: .36),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: LiquidColors.accentBlue.withValues(alpha: .16),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: LiquidColors.accentBlue.withValues(alpha: .12),
                      blurRadius: 28,
                      spreadRadius: -4,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LiquidLockHeader(
                      title: 'SecuroBox',
                      subtitle: _showPin
                          ? 'Type your PIN to unlock the vault'
                          : 'Tap to unlock with your fingerprint or face',
                    ),

                    _networkSealBanner(),

                    // Smooth, professional swap between the biometric stage
                    // and the PIN keypad — a gentle crossfade + rise, with
                    // the card height easing between the two.
                    AnimatedSize(
                      duration: const Duration(milliseconds: 340),
                      curve: Curves.easeInOutCubic,
                      alignment: Alignment.topCenter,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.04),
                              end: Offset.zero,
                            ).animate(anim),
                            child: child,
                          ),
                        ),
                        child: _showPin
                            ? Column(
                                key: const ValueKey('pinStage'),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(height: 28),

                                  AnimatedBuilder(
                                    animation: _errorController,
                                    builder: (context, child) {
                                      // Damped horizontal shake: a few oscillations whose
                                      // amplitude decays to zero — settles instead of
                                      // swinging back like the old elastic tween.
                                      final v = _errorController.value;
                                      final dx =
                                          math.sin(v * math.pi * 6) *
                                          8 *
                                          (1 - v);
                                      return Transform.translate(
                                        offset: Offset(dx, 0),
                                        child: LiquidPinDots(
                                          enteredLength: _enteredPin.length,
                                          totalLength: _pinLength,
                                          hasError: _hasError,
                                        ),
                                      );
                                    },
                                  ),

                                  _wrongPinBanner(),

                                  const SizedBox(height: 24),

                                  if (!_padDisabled)
                                    GridView.builder(
                                      shrinkWrap: true,
                                      itemCount: 12,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
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
                                                _biometricEnabled &&
                                                !_isAuthenticating &&
                                                !_bioLocked,
                                          );
                                        }

                                        if (index == 10) {
                                          return LiquidNumberButton(
                                            number: '0',
                                            onPressed: () =>
                                                _onNumberPressed('0'),
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
                                          onPressed: () =>
                                              _onNumberPressed('${index + 1}'),
                                        );
                                      },
                                    ),

                                  if (_padDisabled)
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        gradient: RadialGradient(
                                          colors: [
                                            LiquidColors.error.withValues(
                                              alpha: .2,
                                            ),
                                            LiquidColors.error.withValues(
                                              alpha: .1,
                                            ),
                                          ],
                                          center: Alignment.center,
                                          radius: 0.8,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: LiquidColors.error.withValues(
                                            alpha: .3,
                                          ),
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
                                            'PIN locked for now',
                                            style: TextStyle(
                                              color: LiquidColors.error,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Too many wrong tries. Try again in ${_formatCooldown(_cooldownRemaining!)}.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: LiquidColors.textSecondary,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              height: 1.4,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'You can still unlock with biometrics.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: LiquidColors.textTertiary,
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                  const SizedBox(height: 16),

                                  // During PIN cooldown the keypad is hidden — give a
                                  // prominent biometric escape hatch instead of a link.
                                  if (_padDisabled) _buildBiometricOptions(),

                                  if (!_padDisabled &&
                                      _faceRecogEnrolled &&
                                      !_bioLocked &&
                                      !_isAuthenticating)
                                    TextButton.icon(
                                      onPressed: _useFaceUnlock,
                                      icon: Icon(
                                        Icons.face_retouching_natural,
                                        size: 18,
                                        color: LiquidColors.accentPurple,
                                      ),
                                      label: Text(
                                        'Use Face Scan instead',
                                        style: TextStyle(
                                          color: LiquidColors.accentPurple,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  _bioAttemptsBanner(),
                                ],
                              )
                            : Column(
                                key: const ValueKey('bioStage'),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(height: 26),
                                  _buildBiometricStage(),
                                ],
                              ),
                      ),
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
                        color: LiquidColors.textSecondary,
                      ),
                      label: Text(
                        'Forgot your PIN?',
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
