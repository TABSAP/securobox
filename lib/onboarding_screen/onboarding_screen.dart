import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:video_player_app/main_screen.dart';
import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/utils/pin_crypto.dart';
import 'package:video_player_app/utils/session_manager.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _Step { welcome, setPin, confirmPin, biometric }

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  _Step _step = _Step.welcome;
  final List<String> _newPin = [];
  final List<String> _confirmPin = [];
  String? _error;
  bool _biometricAvailable = false;

  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  final _localAuth = LocalAuthentication();

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
    _checkBiometricAvailability();
  }

  @override
  void dispose() {
    _ctrl.dispose();
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
        if (_newPin.length < 4) _newPin.add(d);
        if (_newPin.length == 4) _validatePinStrength();
      } else if (_step == _Step.confirmPin) {
        if (_confirmPin.length < 4) _confirmPin.add(d);
        if (_confirmPin.length == 4) _confirmAndSave();
      }
    });
  }

  void _onDelete() {
    HapticFeedback.selectionClick();
    setState(() {
      _error = null;
      if (_step == _Step.setPin && _newPin.isNotEmpty) _newPin.removeLast();
      if (_step == _Step.confirmPin && _confirmPin.isNotEmpty) {
        _confirmPin.removeLast();
      }
    });
  }

  void _validatePinStrength() {
    final pin = _newPin.join();
    final weak = ['0000', '1111', '1234', '4321', '2222', '3333', '4444',
                  '5555', '6666', '7777', '8888', '9999'];
    if (weak.contains(pin) ||
        RegExp(r'^(\d)\1{3}$').hasMatch(pin) ||
        RegExp(r'^(0123|1234|2345|3456|4567|5678|6789|9876|8765|7654|6543|5432|4321|3210)$')
            .hasMatch(pin)) {
      setState(() {
        _error = 'PIN too weak — try something less obvious';
        _newPin.clear();
      });
      return;
    }
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() => _step = _Step.confirmPin);
        _animateForward();
      }
    });
  }

  Future<void> _confirmAndSave() async {
    if (_newPin.join() != _confirmPin.join()) {
      HapticFeedback.heavyImpact();
      setState(() {
        _error = 'PINs do not match — try again';
        _newPin.clear();
        _confirmPin.clear();
        _step = _Step.setPin;
      });
      _animateForward();
      return;
    }

    final pin = _newPin.join();
    await PinCrypto.instance.setPin(pin);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('appLock', true);
    await prefs.setBool('hasOnboarded', true);

    HapticFeedback.mediumImpact();
    if (!mounted) return;

    if (_biometricAvailable) {
      setState(() => _step = _Step.biometric);
      _animateForward();
    } else {
      _goToApp();
    }
  }

  Future<void> _enableBiometric() async {
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: 'Enable biometric unlock for Secure Player',
        biometricOnly: true,
      );
      if (ok) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('biometric', true);
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
      case _Step.setPin:
      case _Step.confirmPin:
        return _pinEntry();
      case _Step.biometric:
        return _biometricPrompt();
    }
  }

  Widget _welcome() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Spacer(flex: 2),
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
            child: const Icon(Icons.shield_rounded, color: Colors.white, size: 60),
          ),
          const SizedBox(height: 36),
          const Text(
            'Welcome to Secure Player',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'A private offline vault for your videos, photos, audio and documents. Files stay on your device — protected by a PIN you control.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade400,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 36),
          _featureRow(Icons.lock_outline_rounded, 'PIN-protected access'),
          const SizedBox(height: 14),
          _featureRow(Icons.fingerprint_rounded, 'Biometric unlock support'),
          const SizedBox(height: 14),
          _featureRow(Icons.cloud_off_rounded, '100% offline — no cloud, no tracking'),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Get Started',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
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
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade300),
          ),
        ),
      ],
    );
  }

  Widget _pinEntry() {
    final isConfirm = _step == _Step.confirmPin;
    final entered = isConfirm ? _confirmPin : _newPin;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Text(
            isConfirm ? 'Confirm Your PIN' : 'Create Your PIN',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isConfirm
                ? 'Enter the same 4-digit PIN to confirm'
                : 'Choose a 4-digit PIN to lock the app',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 36),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (i) {
              final filled = i < entered.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: filled
                      ? LiquidColors.accentBlue
                      : Colors.transparent,
                  border: Border.all(
                    color: _error != null
                        ? LiquidColors.error
                        : LiquidColors.accentBlue.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 18),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: LiquidColors.error, fontSize: 13),
            ),
          const Spacer(),
          _numberPad(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _numberPad() {
    Widget num(String d) => InkWell(
          onTap: () => _onDigit(d),
          borderRadius: BorderRadius.circular(40),
          child: Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: LiquidColors.backgroundLight.withValues(alpha: 0.6),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Text(
              d,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        );

    Widget gap() => const SizedBox(width: 72, height: 72);

    Widget del() => InkWell(
          onTap: _onDelete,
          borderRadius: BorderRadius.circular(40),
          child: Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            child: Icon(
              Icons.backspace_outlined,
              color: Colors.grey.shade400,
              size: 26,
            ),
          ),
        );

    Widget row(List<Widget> kids) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: kids,
          ),
        );

    return Column(
      children: [
        row([num('1'), num('2'), num('3')]),
        row([num('4'), num('5'), num('6')]),
        row([num('7'), num('8'), num('9')]),
        row([gap(), num('0'), del()]),
      ],
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
            child: const Icon(
              Icons.fingerprint_rounded,
              color: Colors.white,
              size: 60,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Enable Biometric Unlock?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Use Face ID or fingerprint instead of typing your PIN every time.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade400,
              height: 1.5,
            ),
          ),
          const Spacer(flex: 3),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _enableBiometric,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                backgroundColor: LiquidColors.accentPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Text(
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
            onPressed: _skipBiometric,
            child: Text(
              'Maybe later',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
