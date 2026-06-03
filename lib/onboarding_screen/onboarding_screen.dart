import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:video_player_app/main_screen.dart';
import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/utils/pin_crypto.dart';
import 'package:video_player_app/utils/session_manager.dart';
import 'package:video_player_app/security_settings/recovery_setup_screen.dart';
import 'package:video_player_app/app_lock_screen/widgets/liquid_lock_header.dart';
import 'package:video_player_app/app_lock_screen/widgets/liquid_pin_dots.dart';
import 'package:video_player_app/app_lock_screen/widgets/liquid_number_button.dart';
import 'package:video_player_app/app_lock_screen/widgets/liquid_action_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _Step {
  welcome,
  pickLength,
  setPin,
  confirmPin,
  recovery,
  biometric,
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  _Step _step = _Step.welcome;
  String _newPin = '';
  String _confirmPin = '';
  int _pinLength = 4;
  String? _error;
  bool _biometricAvailable = false;
  bool _enablingBiometric = false;

  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  late AnimationController _errorController;
  late Animation<double> _shakeAnimation;

  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();

    _errorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: -10.0, end: 10.0).animate(
      CurvedAnimation(parent: _errorController, curve: Curves.elasticIn),
    );

    _checkBiometricAvailability();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _errorController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final available = await _localAuth.getAvailableBiometrics();
      if (mounted) {
        setState(() {
          _biometricAvailable = canCheck && available.isNotEmpty;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _biometricAvailable = false);
    }
  }

  void _animateForward() {
    _ctrl.reset();
    _ctrl.forward();
  }

  void _onDigit(String d) {
    HapticFeedback.lightImpact();
    setState(() {
      _error = null;
      if (_step == _Step.setPin) {
        if (_newPin.length < _pinLength) _newPin += d;
        if (_newPin.length == _pinLength) _validatePinStrength();
      } else if (_step == _Step.confirmPin) {
        if (_confirmPin.length < _pinLength) _confirmPin += d;
        if (_confirmPin.length == _pinLength) _confirmAndSave();
      }
    });
  }

  void _onDelete() {
    HapticFeedback.selectionClick();
    setState(() {
      _error = null;
      if (_step == _Step.setPin && _newPin.isNotEmpty) {
        _newPin = _newPin.substring(0, _newPin.length - 1);
      }
      if (_step == _Step.confirmPin && _confirmPin.isNotEmpty) {
        _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
      }
    });
  }

  void _onBackStep() {
    HapticFeedback.selectionClick();
    setState(() {
      _error = null;
      if (_step == _Step.confirmPin) {
        _confirmPin = '';
        _newPin = '';
        _step = _Step.setPin;
      } else if (_step == _Step.setPin) {
        _newPin = '';
        _step = _Step.pickLength;
      }
    });
    _animateForward();
  }

  void _validatePinStrength() {
    final pin = _newPin;
    if (_isWeakPin(pin)) {
      setState(() {
        _error = 'PIN too weak — try something less obvious';
        _newPin = '';
      });
      return;
    }
    // Brief beat so the final dot visibly fills, then advance — kept short so
    // moving to the confirm step feels instant.
    Future.delayed(const Duration(milliseconds: 90), () {
      if (mounted) {
        setState(() => _step = _Step.confirmPin);
        _animateForward();
      }
    });
  }

  bool _isWeakPin(String pin) {
    if (RegExp(r'^(\d)\1+$').hasMatch(pin)) return true;
    final ascending = '0123456789';
    final descending = '9876543210';
    if (ascending.contains(pin) || descending.contains(pin)) return true;
    const knownBad = {
      '1234', '4321', '0000', '1111', '2222', '3333', '4444',
      '5555', '6666', '7777', '8888', '9999', '123456', '654321',
      '111111', '000000', '121212', '696969', '112233', '789456',
    };
    if (knownBad.contains(pin)) return true;
    return false;
  }

  Future<void> _confirmAndSave() async {
    if (_newPin != _confirmPin) {
      HapticFeedback.heavyImpact();
      _errorController.forward().then((_) {
        if (mounted) _errorController.reverse();
      });

      setState(() {
        _error = 'PINs do not match — try again';
        _newPin = '';
        _confirmPin = '';
        _step = _Step.setPin;
      });
      _animateForward();
      return;
    }

    final pin = _newPin;
    await PinCrypto.instance.setPin(pin);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('appLock', true);
    await prefs.setBool('hasOnboarded', true);

    HapticFeedback.mediumImpact();
    if (!mounted) return;

    setState(() => _step = _Step.recovery);
    _animateForward();
  }

  Future<void> _addRecoveryEmail() async {
    HapticFeedback.lightImpact();
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const RecoverySetupScreen()),
    );
    if (!mounted) return;
    if (saved == true) _afterRecovery();
  }

  void _skipRecovery() {
    HapticFeedback.lightImpact();
    _afterRecovery();
  }

  /// Moves past the recovery step into biometric setup (if available) or
  /// straight into the app.
  void _afterRecovery() {
    if (!mounted) return;
    if (_biometricAvailable) {
      setState(() => _step = _Step.biometric);
      _animateForward();
    } else {
      _goToApp();
    }
  }

  Future<void> _enableBiometric() async {
    if (_enablingBiometric) return;
    setState(() => _enablingBiometric = true);
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: 'Enable biometric unlock for SecuroBox',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      if (ok) {
        final prefs = await SharedPreferences.getInstance();
        final avail = await _localAuth.getAvailableBiometrics();
        final hasFace = avail.contains(BiometricType.face);
        final hasFingerprint = avail.contains(BiometricType.fingerprint);
        if (hasFace && !hasFingerprint) {
          await prefs.setBool('biometric_face', true);
        } else {
          await prefs.setBool('biometric', true);
          if (hasFace) await prefs.setBool('biometric_face', true);
        }
      }
    } catch (_) {}
    _goToApp();
  }

  void _skipBiometric() => _goToApp();

  void _goToApp() {
    if (!mounted) return;
    SessionManager.instance.markActive();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: LiquidColors.backgroundGradient),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: _buildStep(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case _Step.welcome:
        return _welcome();
      case _Step.pickLength:
        return _lengthPicker();
      case _Step.setPin:
      case _Step.confirmPin:
        return _pinEntryScreen();
      case _Step.recovery:
        return _recoveryPrompt();
      case _Step.biometric:
        return _biometricPrompt();
    }
  }

  // ============ WELCOME SCREEN ============
  Widget _welcome() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                gradient: LiquidColors.primaryGradient,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: LiquidColors.primaryStart.withValues(alpha: 0.4),
                    blurRadius: 30,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Icon(Icons.shield_rounded, color: Colors.white, size: 60),
            ),
            const SizedBox(height: 36),
            Text(
              'Welcome to SecuroBox',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: LiquidColors.textPrimary, letterSpacing: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'A private offline vault for your videos, photos, audio and documents. Files stay on your device — protected by a PIN you control.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: LiquidColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 36),
            _featureRow(Icons.lock_outline_rounded, 'AES-256 encryption for every file'),
            const SizedBox(height: 14),
            _featureRow(Icons.fingerprint_rounded, 'PIN + biometric unlock'),
            const SizedBox(height: 14),
            _featureRow(Icons.cloud_off_rounded, '100% offline — no cloud, no tracking'),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: LiquidColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: LiquidColors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, color: LiquidColors.warning, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Important — your PIN cannot be recovered. Lose it and your vault contents are permanently inaccessible. By design.',
                      style: TextStyle(color: LiquidColors.textSecondary, fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() => _step = _Step.pickLength);
                  _animateForward();
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  backgroundColor: LiquidColors.accentBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text('Get Started',
                
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _featureRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: LiquidColors.accentBlue.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: LiquidColors.accentBlue, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(child: Text(text, style: TextStyle(fontSize: 14, color: LiquidColors.textSecondary))),
      ],
    );
  }

  // ============ LENGTH PICKER ============
  Widget _lengthPicker() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Spacer(flex: 2),
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [LiquidColors.accentBlue, LiquidColors.primaryMid],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(Icons.pin_outlined, color: Colors.white, size: 50),
          ),
          const SizedBox(height: 28),
          Text('Choose Your PIN Length',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: LiquidColors.textPrimary)),
          const SizedBox(height: 10),
          Text('Longer PINs are exponentially harder to guess',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: LiquidColors.textSecondary)),
          const SizedBox(height: 32),
          _lengthOption(digits: 4, label: '4-digit PIN', sub: 'Quicker to type — 10,000 combinations'),
          const SizedBox(height: 12),
          _lengthOption(digits: 6, label: '6-digit PIN', sub: 'Recommended — 1,000,000 combinations', recommended: true),
          const Spacer(flex: 3),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                setState(() => _step = _Step.setPin);
                _animateForward();
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                backgroundColor: LiquidColors.accentBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text('Continue',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _lengthOption({required int digits, required String label, required String sub, bool recommended = false}) {
    final selected = _pinLength == digits;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _pinLength = digits);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? LiquidColors.accentBlue.withValues(alpha: 0.18) : LiquidColors.backgroundLight.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? LiquidColors.accentBlue : LiquidColors.textPrimary.withValues(alpha: 0.08),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: selected ? LiquidColors.accentBlue : LiquidColors.textTertiary, width: 2),
                color: selected ? LiquidColors.accentBlue : Colors.transparent,
              ),
              child: selected ? Icon(Icons.check, color: Colors.white, size: 16) : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(label, style: TextStyle(color: LiquidColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                      if (recommended) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: LiquidColors.success.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('BEST',
                              style: TextStyle(color: LiquidColors.success, fontSize: 10, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(sub, style: TextStyle(color: LiquidColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============ PIN ENTRY SCREEN (AppLockScreen Style) ============
  Widget _pinEntryScreen() {
    final isConfirm = _step == _Step.confirmPin;
    final entered = isConfirm ? _confirmPin : _newPin;
    final size = MediaQuery.of(context).size;

    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Container(
          width: size.width >= 600
              ? 500
              : (size.width > 420 ? 420 : double.infinity),
          padding: EdgeInsets.all(size.width >= 600 ? 36 : 28),
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
            border: Border.all(color: LiquidColors.accentBlue.withValues(alpha: .2), width: 1),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: .3), blurRadius: 30, spreadRadius: 5),
              BoxShadow(color: LiquidColors.accentBlue.withValues(alpha: .1), blurRadius: 20, spreadRadius: 2),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header (using same LiquidLockHeader as AppLockScreen)
              LiquidLockHeader(
                title: isConfirm ? 'Confirm PIN' : 'Create PIN',
                subtitle: isConfirm
                    ? 'Re-enter your $_pinLength-digit PIN'
                    : 'Choose a $_pinLength-digit secure PIN',
              ),

              const SizedBox(height: 32),

              // PIN Dots with shake animation (using LiquidPinDots)
              AnimatedBuilder(
                animation: _errorController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(_shakeAnimation.value, 0),
                    child: LiquidPinDots(
                      enteredLength: entered.length,
                      totalLength: _pinLength,
                      hasError: _error != null,
                    ),
                  );
                },
              ),

              const SizedBox(height: 32),

              // Error Message
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          LiquidColors.error.withValues(alpha: 0.15),
                          LiquidColors.error.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: LiquidColors.error.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: LiquidColors.error.withValues(alpha: 0.2),
                          ),
                          child: Icon(Icons.error_outline_rounded, color: LiquidColors.error, size: 16),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(_error!,
                              style: TextStyle(color: LiquidColors.error, fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ),

              _buildNumberPad(),
            ],
          ),
        ),
      ),
    );
  }

  // ============ NUMBER PAD (AppLockScreen Style) ============
  Widget _buildNumberPad() {
    return GridView.builder(
      shrinkWrap: true,
      itemCount: 12,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      itemBuilder: (context, index) {
        if (index == 9) {
          return LiquidActionButton(
            icon: Icons.arrow_back_rounded,
            color: LiquidColors.accentBlue,
            onPressed: _onBackStep,
          );
        }
        if (index == 10) {
          return LiquidNumberButton(
            number: '0',
            onPressed: () => _onDigit('0'),
          );
        }
        if (index == 11) {
          return LiquidActionButton(
            icon: Icons.backspace,
            color: LiquidColors.error,
            onPressed: _onDelete,
          );
        }
        return LiquidNumberButton(
          number: '${index + 1}',
          onPressed: () => _onDigit('${index + 1}'),
        );
      },
    );
  }

  // ============ RECOVERY EMAIL PROMPT ============
  Widget _recoveryPrompt() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 44),
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [LiquidColors.accentBlue, LiquidColors.primaryMid],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: LiquidColors.accentBlue.withValues(alpha: 0.4),
                    blurRadius: 30,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Icon(Icons.mark_email_read_rounded,
                  color: Colors.white, size: 56),
            ),
            const SizedBox(height: 32),
            Text(
              'Add a Recovery Email',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: LiquidColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Link an email address so you can reset your PIN if you ever '
              'forget it. SecuroBox creates a one-time recovery code for you '
              'to email to yourself — your files and email are never uploaded '
              'anywhere.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: LiquidColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: LiquidColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: LiquidColors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: LiquidColors.warning, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'If you don\'t add an email, a forgotten PIN cannot be '
                      'recovered — you may permanently lose access to your '
                      'vault and everything inside it.',
                      style: TextStyle(
                        color: LiquidColors.textSecondary,
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _addRecoveryEmail,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  backgroundColor: LiquidColors.accentBlue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text('Add Recovery Email',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _skipRecovery,
              child: Text('Skip — I understand the risk',
                  style: TextStyle(
                      color: LiquidColors.textSecondary, fontSize: 14)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ============ BIOMETRIC PROMPT ============
  Widget _biometricPrompt() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Spacer(flex: 2),
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [LiquidColors.accentPurple, LiquidColors.accentPink],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: LiquidColors.accentPurple.withValues(alpha: 0.4),
                  blurRadius: 30,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Icon(Icons.fingerprint_rounded, color: Colors.white, size: 60),
          ),
          const SizedBox(height: 32),
          Text('Enable Biometric Unlock?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: LiquidColors.textPrimary)),
          const SizedBox(height: 12),
          Text('Use Face ID or fingerprint instead of typing your PIN every time.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: LiquidColors.textSecondary, height: 1.5)),
          const Spacer(flex: 3),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _enablingBiometric ? null : _enableBiometric,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                backgroundColor: LiquidColors.accentPurple,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _enablingBiometric
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text('Enable Biometric',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _enablingBiometric ? null : _skipBiometric,
            child: Text('Maybe later', style: TextStyle(color: LiquidColors.textSecondary, fontSize: 14)),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}