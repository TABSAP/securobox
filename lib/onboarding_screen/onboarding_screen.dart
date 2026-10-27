import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player_app/widgets/app_loader.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:video_player_app/main_screen.dart';
import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/utils/pin_crypto.dart';
import 'package:video_player_app/utils/session_manager.dart';
import 'package:video_player_app/security_settings/recovery_questions_setup_screen.dart';
import 'package:video_player_app/app_lock_screen/widgets/liquid_lock_header.dart';
import 'package:video_player_app/app_lock_screen/widgets/liquid_pin_dots.dart';
import 'package:video_player_app/app_lock_screen/widgets/liquid_number_button.dart';
import 'package:video_player_app/app_lock_screen/widgets/liquid_action_button.dart';
import 'package:video_player_app/widgets/liquid_glass_surface.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _Step { welcome, pickLength, setPin, confirmPin, biometric }

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  _Step _step = _Step.welcome;
  String _newPin = '';
  String _confirmPin = '';
  int _pinLength = 6;
  String? _error;
  bool _biometricAvailable = false;
  bool _enablingBiometric = false;
  bool _saving = false;

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
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
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
      '1234',
      '4321',
      '0000',
      '1111',
      '2222',
      '3333',
      '4444',
      '5555',
      '6666',
      '7777',
      '8888',
      '9999',
      '123456',
      '654321',
      '111111',
      '000000',
      '121212',
      '696969',
      '112233',
      '789456',
    };
    if (knownBad.contains(pin)) return true;
    return false;
  }

  Future<void> _confirmAndSave() async {
    // Guard against re-entry from rapid taps while the PIN is being saved.
    if (_saving) return;

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

    // PIN hashing and recovery setup run off the UI thread. Guard against
    // rapid taps while secure storage is being updated.
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final pin = _newPin;
      await PinCrypto.instance.setPin(pin);
      _newPin = '';
      _confirmPin = '';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('appLock', true);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      final configured = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) =>
              const RecoveryQuestionsSetupScreen(requiredSetup: true),
        ),
      );
      if (!mounted) return;
      if (configured != true) {
        setState(() {
          _saving = false;
          _error = 'Set up recovery questions to finish securing your vault.';
        });
        return;
      }
      await prefs.setBool('hasOnboarded', true);
      if (!mounted) return;
      setState(() => _saving = false);
      await _afterRecovery();
    } catch (_) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _saving = false;
        _error = 'Something went wrong — please try again';
        _newPin = '';
        _confirmPin = '';
        _step = _Step.setPin;
      });
      _animateForward();
    }
  }

  Future<void> _afterRecovery() async {
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
        // Onboarding explicitly offers device biometrics, not a modality.
        await prefs.setBool('biometric', true);
        await prefs.setBool('biometric_face', false);
      }
    } catch (_) {}
    _goToApp();
  }

  void _skipBiometric() => _goToApp();

  void _goToApp() {
    if (!mounted) return;
    SessionManager.instance.markActive();
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const MainScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: LiquidColors.backgroundGradient),
        child: SafeArea(
          child: Stack(
            children: [
              FadeTransition(
                opacity: _fade,
                child: SlideTransition(position: _slide, child: _buildStep()),
              ),
              if (_saving)
                Positioned.fill(
                  child: Container(
                    color: LiquidColors.scrim,
                    alignment: Alignment.center,
                    child: const AppLoader(
                      size: 56,
                      label: 'Securing your vault…',
                    ),
                  ),
                ),
            ],
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
      case _Step.biometric:
        return _biometricPrompt();
    }
  }

  Widget _welcome() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    SizedBox(
                      width: 104,
                      height: 104,
                      child: LiquidGlassSurface(
                        borderRadius: 26,
                        blur: 22,
                        tintColor: LiquidColors.accentBlue,
                        tintOpacity: 0.12,
                        child: Icon(
                          Icons.shield_rounded,
                          color: LiquidColors.accentBlue,
                          size: 54,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Welcome to SecuroBox',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                        color: LiquidColors.textPrimary,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'A private offline vault for your videos, photos, audio and documents. Files stay on your device — protected by a PIN you control.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14.5,
                        color: LiquidColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),
                    LiquidGlassSurface(
                      borderRadius: 20,
                      blur: 18,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _featureRow(
                            Icons.lock_outline_rounded,
                            'AES-256 encryption for every file',
                          ),
                          const SizedBox(height: 14),
                          _featureRow(
                            Icons.fingerprint_rounded,
                            'PIN + biometric unlock',
                          ),
                          const SizedBox(height: 14),
                          _featureRow(
                            Icons.cloud_off_rounded,
                            '100% offline — no cloud, no tracking',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    LiquidGlassSurface(
                      borderRadius: 16,
                      blur: 16,
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: LiquidColors.accentBlue,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Set recovery questions after choosing your PIN. They let you reset a forgotten PIN on this device; choose answers others cannot easily guess.',
                              style: TextStyle(
                                color: LiquidColors.textSecondary,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: _brandButton(
                        label: 'Get Started',
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          setState(() => _step = _Step.pickLength);
                          _animateForward();
                        },
                        height: 58,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _featureRow(IconData icon, String text) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 40,
          height: 40,
          child: LiquidGlassSurface(
            borderRadius: 12,
            blur: 12,
            tintColor: LiquidColors.accentBlue,
            tintOpacity: 0.12,
            child: Icon(icon, color: LiquidColors.accentBlue, size: 20),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
            ),
          ),
        ),
      ],
    );
  }

  Widget _lengthPicker() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Spacer(flex: 2),
          SizedBox(
            width: 90,
            height: 90,
            child: LiquidGlassSurface(
              borderRadius: 24,
              blur: 20,
              tintColor: LiquidColors.accentBlue,
              tintOpacity: 0.12,
              child: Icon(
                Icons.pin_outlined,
                color: LiquidColors.accentBlue,
                size: 46,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Set a Strong PIN',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: LiquidColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Choose your PIN length — longer is stronger',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: LiquidColors.textSecondary),
          ),
          const SizedBox(height: 32),
          _lengthOption(
            digits: 6,
            label: '6-digit PIN',
            sub: '1,000,000 combinations — recommended for a vault',
            recommended: true,
          ),
          const SizedBox(height: 14),
          _lengthOption(
            digits: 4,
            label: '4-digit PIN',
            sub: '10,000 combinations — quick to enter',
          ),
          const Spacer(flex: 3),
          SizedBox(
            width: double.infinity,
            child: _brandButton(
              label: 'Continue',
              height: 58,
              onPressed: () {
                HapticFeedback.lightImpact();
                setState(() => _step = _Step.setPin);
                _animateForward();
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _brandButton({
    required String label,
    required VoidCallback onPressed,
    double height = 58,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LiquidColors.primaryGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(
            color: LiquidColors.accentBlue.withValues(alpha: 0.24),
            blurRadius: 20,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onPressed,
          child: SizedBox(
            height: height,
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _lengthOption({
    required int digits,
    required String label,
    required String sub,
    bool recommended = false,
  }) {
    final selected = _pinLength == digits;
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _pinLength = digits);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? LiquidColors.accentBlue.withValues(alpha: 0.82)
                : theme.colorScheme.onSurface.withValues(alpha: 0.10),
            width: selected ? 1.8 : 1,
          ),
        ),
        child: LiquidGlassSurface(
          borderRadius: 16,
          blur: 18,
          tintColor: selected ? LiquidColors.accentBlue : null,
          tintOpacity: selected ? 0.12 : 0,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? LiquidColors.accentBlue
                        : theme.colorScheme.onSurface.withValues(alpha: 0.42),
                    width: 2,
                  ),
                  color: selected
                      ? LiquidColors.accentBlue
                      : Colors.transparent,
                ),
                child: selected
                    ? Icon(Icons.check, color: Colors.white, size: 16)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (recommended) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: LiquidColors.accentBlue.withValues(
                                alpha: 0.16,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'BEST',
                              style: TextStyle(
                                color: LiquidColors.accentBlue,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.65,
                        ),
                        fontSize: 12,
                      ),
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

  Widget _pinEntryScreen() {
    final isConfirm = _step == _Step.confirmPin;
    final entered = isConfirm ? _confirmPin : _newPin;
    final size = MediaQuery.of(context).size;

    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: size.width >= 600 ? 500 : 420),
          child: LiquidGlassSurface(
            borderRadius: 32,
            blur: 24,
            tintColor: LiquidColors.accentBlue,
            tintOpacity: 0.035,
            padding: EdgeInsets.all(size.width >= 600 ? 36 : 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LiquidLockHeader(
                  title: isConfirm ? 'Confirm PIN' : 'Create PIN',
                  subtitle: isConfirm
                      ? 'Re-enter your $_pinLength-digit PIN'
                      : 'Choose a $_pinLength-digit secure PIN',
                ),

                const SizedBox(height: 32),

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

                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
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
                        border: Border.all(
                          color: LiquidColors.error.withValues(alpha: 0.4),
                        ),
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
                            child: Icon(
                              Icons.error_outline_rounded,
                              color: LiquidColors.error,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: LiquidColors.error,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
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
      ),
    );
  }

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
            brandGlass: true,
          );
        }
        if (index == 10) {
          return LiquidNumberButton(
            number: '0',
            onPressed: () => _onDigit('0'),
            brandGlass: true,
          );
        }
        if (index == 11) {
          return LiquidActionButton(
            icon: Icons.backspace,
            color: LiquidColors.error,
            onPressed: _onDelete,
            brandGlass: true,
          );
        }
        return LiquidNumberButton(
          number: '${index + 1}',
          onPressed: () => _onDigit('${index + 1}'),
          brandGlass: true,
        );
      },
    );
  }

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
            child: Icon(
              Icons.fingerprint_rounded,
              color: Colors.white,
              size: 60,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Enable Biometric Unlock?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: LiquidColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Use Face ID or fingerprint instead of typing your PIN every time.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: LiquidColors.textSecondary,
              height: 1.5,
            ),
          ),
          const Spacer(flex: 3),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _enablingBiometric ? null : _enableBiometric,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                backgroundColor: LiquidColors.accentPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _enablingBiometric
                  ? const AppLoader(size: 22, color: Colors.white)
                  : Text(
                      'Enable Biometric',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _enablingBiometric ? null : _skipBiometric,
            child: Text(
              'Maybe later',
              style: TextStyle(color: LiquidColors.textSecondary, fontSize: 14),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
