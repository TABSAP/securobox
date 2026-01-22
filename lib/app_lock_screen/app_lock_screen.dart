import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import '../main_screen.dart';

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen>
    with WidgetsBindingObserver {
  String _enteredPin = '';
  List<String> _correctPin = ['1', '2', '3', '4'];

  bool _isAppLocked = true;
  bool _biometricEnabled = false;
  bool _isAuthenticating = false;

  int _wrongPinCount = 0;
  bool _hidePinPad = false;

  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPreferences();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _isAppLocked = true;
    }

    if (state == AppLifecycleState.resumed && _isAppLocked) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AppLockScreen()),
      );
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _correctPin = prefs.getStringList('appPin') ?? ['1', '2', '3', '4'];
      _biometricEnabled = prefs.getBool('enableBiometric') ?? false;
    });
  }

  void _onNumberPressed(String number) {
    if (_enteredPin.length < 4 && !_hidePinPad) {
      setState(() => _enteredPin += number);
      if (_enteredPin.length == 4) _checkPin();
    }
  }

  void _onDeletePressed() {
    if (_enteredPin.isNotEmpty && !_hidePinPad) {
      setState(() {
        _enteredPin =
            _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  Future<void> _checkPin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPin = prefs.getStringList('appPin') ?? _correctPin;

    bool isCorrect = true;
    for (int i = 0; i < 4; i++) {
      if (_enteredPin[i] != savedPin[i]) {
        isCorrect = false;
        break;
      }
    }

    if (isCorrect && mounted) {
      _unlockApp();
    } else {
      setState(() {
        _enteredPin = '';
        _wrongPinCount++;
        if (_wrongPinCount >= 3) _hidePinPad = true;
      });
      _showErrorFeedback();
    }
  }

  void _unlockApp() {
    _wrongPinCount = 0;
    _hidePinPad = false;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainScreen()),
    );
  }

  void _showErrorFeedback() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Incorrect PIN'),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _useBiometric() async {
    setState(() => _isAuthenticating = true);

    try {
      final isSupported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;

      if (!isSupported || !canCheck) {
        _showMessage('Biometric not available');
        return;
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Unlock Secure Player',
        biometricOnly: true,
      );

      if (authenticated && mounted) _unlockApp();
    } catch (_) {
      _showMessage('Biometric error');
    } finally {
      setState(() => _isAuthenticating = false);
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      //backgroundColor: const Color(0xFF1A1A3E),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: const Color(0xFF1A1A3E),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                width: size.width > 420 ? 420 : double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .35),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .4),
                      blurRadius: 20,
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF4A6DE5),
                            Color(0xFF4788FF),
                            Color(0xFF5A9CFF),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4788FF).withValues(alpha: .5),
                            blurRadius: 25,
                            spreadRadius: 8,
                            offset: const Offset(0, 15),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: .2),
                            blurRadius: 10,
                            spreadRadius: 2,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30),
                                gradient: RadialGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: .3),
                                    Colors.transparent,
                                  ],
                                  radius: 0.7,
                                ),
                              ),
                            ),
                          ),
                          const Center(
                            child: Icon(
                              Icons.lock_outline,
                              size: 70,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Secure Video Player',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter your PIN to continue',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // PIN dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: index < _enteredPin.length
                                ? Colors.white
                                : Colors.white24,
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 24),

                    if (!_hidePinPad)
                      GridView.builder(
                        shrinkWrap: true,
                        itemCount: 12,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                        ),
                        itemBuilder: (context, index) {
                          if (index == 9) {
                            return _iconButton(
                              icon: Icons.fingerprint,
                              color: Colors.green,
                              onTap: _useBiometric,
                            );
                          }
                          if (index == 10) {
                            return _numberButton('0');
                          }
                          if (index == 11) {
                            return _iconButton(
                              icon: Icons.backspace,
                              color: Colors.red,
                              onTap: _onDeletePressed,
                            );
                          }
                          return _numberButton('${index + 1}');
                        },
                      ),

                    if (_hidePinPad)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Too many wrong attempts.\nUse biometric to unlock.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.redAccent, fontSize: 14),
                        ),
                      ),

                    if (_hidePinPad || _biometricEnabled)
                      TextButton(
                        onPressed:
                        _isAuthenticating ? null : _useBiometric,
                        child: const Text(
                          'Unlock with Biometric',
                          style: TextStyle(color: Colors.green),
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

  Widget _numberButton(String number) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _onNumberPressed(number),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        child: Text(
          number,
          style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w500,
              color: Colors.white),
        ),
      ),
    );
  }

  Widget _iconButton(
      {required IconData icon,
        required Color color,
        required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: color, size: 28),
      ),
    );
  }
}
