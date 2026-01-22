import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen>
    with SingleTickerProviderStateMixin {
  // Security state
  bool _appLockEnabled = false;
  bool _videoLockEnabled = false;
  bool _biometricEnabled = false;
  List<String> _appPin = ['1', '2', '3', '4'];
  bool _changingPin = false;
  final List<String> _newPin = [];
  bool _showCurrentPin = false;
  bool _confirmPinMode = false;
  final List<String> _confirmPin = [];

  // Biometric
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _biometricAvailable = false;
  List<BiometricType> _availableBiometrics = [];

  // Secure storage for sensitive data
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  bool _secureStorageAvailable = true;

  // Animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  // Error states
  String? _pinError;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadSecuritySettings();
    _checkBiometricCapability();
    _checkSecureStorage();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _animationController.forward();
  }

  Future<void> _checkSecureStorage() async {
    try {
      // Test if secure storage is available
      await _secureStorage.write(key: 'test_key', value: 'test_value');
      await _secureStorage.delete(key: 'test_key');
      setState(() {
        _secureStorageAvailable = true;
      });
    } catch (e) {
      debugPrint('Secure storage not available: $e');
      setState(() {
        _secureStorageAvailable = false;
      });
    }
  }

  Future<void> _loadSecuritySettings() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedPin = prefs.getStringList('appPin');

      setState(() {
        _appLockEnabled = prefs.getBool('appLock') ?? false;
        _videoLockEnabled = prefs.getBool('videoLock') ?? false;
        _biometricEnabled = prefs.getBool('biometric') ?? false;
        _appPin = storedPin ?? ['1', '2', '3', '4'];
      });
    } catch (e) {
      debugPrint('Error loading settings: $e');
      _showSnackBar('Failed to load security settings', Colors.red);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkBiometricCapability() async {
    try {
      final bool canAuthenticate = await _localAuth.canCheckBiometrics;
      final List<BiometricType> availableBiometrics =
      await _localAuth.getAvailableBiometrics();

      if (mounted) {
        setState(() {
          _biometricAvailable = canAuthenticate && availableBiometrics.isNotEmpty;
          _availableBiometrics = availableBiometrics;

          // Auto-disable if not available
          if (!_biometricAvailable && _biometricEnabled) {
            _biometricEnabled = false;
            _saveSetting('biometric', false);
          }
        });
      }
    } catch (e) {
      debugPrint('Biometric check error: $e');
      if (mounted) {
        setState(() {
          _biometricAvailable = false;
          _biometricEnabled = false;
        });
      }
    }
  }

  Future<void> _toggleSetting(String setting, bool value) async {
    // For biometric, test authentication first
    if (setting == 'biometric' && value) {
      await _testAndEnableBiometric();
      return;
    }

    // For app lock, ensure PIN is not default
    if (setting == 'appLock' && value) {
      final isDefaultPin = _appPin.join() == '1234';
      if (isDefaultPin) {
        _showSnackBar(
          'Please change default PIN before enabling app lock',
          Colors.orange,
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _startPinChange();
        });
        return;
      }
    }

    try {
      await _saveSetting(setting, value);
      await _loadSecuritySettings();

      _showSnackBar(
        value ? 'Security enabled' : 'Security disabled',
        value ? const Color(0xFF00C853) : Colors.orange,
      );
    } catch (e) {
      _showSnackBar('Failed to update setting', Colors.red);
    }
  }

  Future<void> _saveSetting(String setting, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(setting, value);
  }

  Future<void> _testAndEnableBiometric() async {
    if (!_biometricAvailable) {
      _showSnackBar(
        'Biometric authentication not available',
        Colors.orange,
      );
      return;
    }

    try {
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Authenticate to enable biometric security',
        biometricOnly: true,
        sensitiveTransaction: true,
      );

      if (didAuthenticate) {
        await _saveSetting('biometric', true);
        if (mounted) {
          setState(() {
            _biometricEnabled = true;
          });
        }
        _showSnackBar(
          'Biometric authentication enabled',
          const Color(0xFF00C853),
        );

        // Also enable app lock for better security
        if (!_appLockEnabled) {
          await _saveSetting('appLock', true);
          if (mounted) {
            setState(() {
              _appLockEnabled = true;
            });
          }
        }
      } else {
        _showSnackBar('Authentication cancelled', Colors.orange);
      }
    } catch (e) {
      debugPrint('Biometric error: $e');
      _showSnackBar(
        'Authentication failed. Please try again.',
        Colors.red,
      );
    }
  }

  void _startPinChange() {
    setState(() {
      _changingPin = true;
      _confirmPinMode = false;
      _newPin.clear();
      _confirmPin.clear();
      _pinError = null;
    });
  }

  void _onPinNumberPressed(String number) {
    setState(() {
      _pinError = null;
      if (!_confirmPinMode) {
        if (_newPin.length < 4) {
          _newPin.add(number);
        }
        if (_newPin.length == 4) {
          _validateFirstPin();
        }
      } else {
        if (_confirmPin.length < 4) {
          _confirmPin.add(number);
        }
        if (_confirmPin.length == 4) {
          _validateAndSavePin();
        }
      }
    });
  }

  void _validateFirstPin() {
    final enteredPin = _newPin.join();

    // Validate PIN strength
    if (!_isPinStrong(enteredPin)) {
      setState(() {
        _pinError = 'Please choose a stronger PIN';
        _newPin.clear();
      });
      return;
    }

    // Move to confirmation mode
    setState(() {
      _confirmPinMode = true;
    });
  }

  bool _isPinStrong(String pin) {
    // Prevent simple PINs
    final simplePins = ['0000', '1111', '1234', '4321', '2222', '3333', '4444'];
    if (simplePins.contains(pin)) {
      return false;
    }

    // Prevent repeating digits
    if (RegExp(r'^(\d)\1{3}$').hasMatch(pin)) {
      return false;
    }

    // Prevent sequential digits
    if (RegExp(r'^0123|1234|2345|3456|4567|5678|6789|9876|8765|7654|6543|5432|4321|3210$').hasMatch(pin)) {
      return false;
    }

    return true;
  }

  Future<void> _validateAndSavePin() async {
    final newPin = _newPin.join();
    final confirmPin = _confirmPin.join();

    if (newPin != confirmPin) {
      setState(() {
        _pinError = 'PINs do not match';
        _newPin.clear();
        _confirmPin.clear();
        _confirmPinMode = false;
      });
      return;
    }

    // Check if same as current PIN
    if (newPin == _appPin.join()) {
      setState(() {
        _pinError = 'New PIN cannot be same as current PIN';
        _newPin.clear();
        _confirmPin.clear();
        _confirmPinMode = false;
      });
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      // Save to SharedPreferences (primary storage)
      await prefs.setStringList('appPin', _newPin);

      // Try to save to secure storage (backup)
      if (_secureStorageAvailable) {
        try {
          await _secureStorage.write(key: 'secure_pin', value: newPin);
        } catch (e) {
          debugPrint('Secure storage backup failed: $e');
          // Continue without secure storage
        }
      }

      if (mounted) {
        setState(() {
          _appPin = List.from(_newPin);
          _changingPin = false;
          _confirmPinMode = false;
          _newPin.clear();
          _confirmPin.clear();
        });
      }

      _showSnackBar('PIN changed successfully', const Color(0xFF00C853));

      // Auto-enable app lock if changing from default PIN
      final wasDefaultPin = _appPin.join() == '1234';
      if (wasDefaultPin && !_appLockEnabled) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await _saveSetting('appLock', true);
          if (mounted) {
            setState(() {
              _appLockEnabled = true;
            });
          }
          _showSnackBar('App lock auto-enabled for security', Colors.blue);
        });
      }
    } catch (e) {
      debugPrint('Error saving PIN: $e');
      _showSnackBar('Failed to save PIN', Colors.red);
      setState(() {
        _changingPin = false;
        _confirmPinMode = false;
        _newPin.clear();
        _confirmPin.clear();
      });
    }
  }

  void _onPinDelete() {
    setState(() {
      _pinError = null;
      if (!_confirmPinMode) {
        if (_newPin.isNotEmpty) {
          _newPin.removeLast();
        }
      } else {
        if (_confirmPin.isNotEmpty) {
          _confirmPin.removeLast();
        }
      }
    });
  }

  void _cancelPinChange() {
    setState(() {
      _changingPin = false;
      _confirmPinMode = false;
      _newPin.clear();
      _confirmPin.clear();
      _pinError = null;
    });
    _showSnackBar('PIN change cancelled', Colors.orange);
  }

  IconData _getBiometricIcon() {
    if (_availableBiometrics.contains(BiometricType.face)) {
      return Icons.face_retouching_natural;
    } else if (_availableBiometrics.contains(BiometricType.fingerprint)) {
      return Icons.fingerprint_rounded;
    } else if (_availableBiometrics.contains(BiometricType.iris)) {
      return Icons.remove_red_eye_rounded;
    }
    return Icons.fingerprint_rounded;
  }

  String _getBiometricTypeName() {
    if (_availableBiometrics.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (_availableBiometrics.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    } else if (_availableBiometrics.contains(BiometricType.iris)) {
      return 'Iris Scan';
    }
    return 'Biometric';
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildBiometricStatus() {
    if (!_biometricAvailable) {
      return Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Colors.orange, size: 14),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Biometric not available on this device',
                style: TextStyle(fontSize: 11, color: Colors.orange),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: const Color(0xFF00C853), size: 14),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '${_getBiometricTypeName()} available',
              style: TextStyle(fontSize: 11, color: const Color(0xFF00C853)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1A1A3E),
            const Color(0xFF141432),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: .1), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .2),
            blurRadius: 15,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2196F3), Color(0xFF21CBF3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2196F3).withValues(alpha: .3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.security_rounded, color: Colors.white, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'SECURITY INFORMATION',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSecurityFeature('256-bit AES encryption for all videos'),
          const SizedBox(height: 12),
          _buildSecurityFeature('Secure offline storage - no cloud uploads'),
          const SizedBox(height: 12),
          _buildSecurityFeature('Biometric authentication with hardware-level security'),
          const SizedBox(height: 12),
          _buildSecurityFeature('Automatic lock after 3 failed attempts'),
          const SizedBox(height: 12),
          _buildSecurityFeature('No data collection - privacy guaranteed'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.withValues(alpha: .1),
                  Colors.blue.withValues(alpha: .05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.withValues(alpha: .3)),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_clock_rounded, color: Colors.blue, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'All security features work 100% offline',
                    style: TextStyle(color: Colors.blue.shade300, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityFeature(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFF00C853),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Center(
            child: Icon(Icons.check, color: Colors.white, size: 12),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey.shade300, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildPinIndicator({required List<String> pin, required String label}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            return Container(
              width: 20,
              height: 20,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index < pin.length
                    ? const Color(0xFF4A6DE5)
                    : Colors.grey.shade800,
                boxShadow: index < pin.length
                    ? [
                  BoxShadow(
                    color: const Color(0xFF4A6DE5).withValues(alpha: .5),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
                    : null,
              ),
            );
          }),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4A6DE5), Color(0xFF4788FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4788FF).withValues(alpha: .4),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.security_rounded, color: Colors.white, size: 22),
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SECURITY SETTINGS',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    'Configure your security preferences',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0A0A1F),
              Color(0xFF141432),
              Color(0xFF1A1A3E),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SingleChildScrollView(
          child: AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Transform.translate(
                  offset: Offset(0, _slideAnimation.value),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // App Lock Card
                        _buildSecurityCard(
                          icon: Icons.lock_outline_rounded,
                          title: 'App Lock',
                          subtitle: 'Require authentication to open the app',
                          value: _appLockEnabled,
                          gradient: const [Color(0xFF4A6DE5), Color(0xFF4788FF)],
                          onChanged: (value) => _toggleSetting('appLock', value),
                        ),
                        const SizedBox(height: 16),

                        // Video Lock Card
                        _buildSecurityCard(
                          icon: Icons.video_settings_outlined,
                          title: 'Video Lock',
                          subtitle: 'Lock individual videos with authentication',
                          value: _videoLockEnabled,
                          gradient: const [Color(0xFF00C853), Color(0xFF64DD17)],
                          onChanged: (value) => _toggleSetting('videoLock', value),
                        ),
                        const SizedBox(height: 16),

                        // Biometric Card
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF9C27B0), Color(0xFFE91E63)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF9C27B0).withValues(alpha: .3),
                                blurRadius: 10,
                                spreadRadius: 1,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: .2),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: .3),
                                          width: 2,
                                        ),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          _getBiometricIcon(),
                                          color: Colors.white,
                                          size: 26,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Biometric Authentication',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Use ${_getBiometricTypeName().toLowerCase()} for authentication',
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: .8),
                                              fontSize: 12,
                                            ),
                                          ),
                                          _buildBiometricStatus(),
                                        ],
                                      ),
                                    ),
                                    Transform.scale(
                                      scale: 1.2,
                                      child: Switch.adaptive(
                                        value: _biometricEnabled,
                                        onChanged: _biometricAvailable
                                            ? (value) => _toggleSetting('biometric', value)
                                            : null,
                                        activeThumbColor: Colors.white,

                                        activeTrackColor: Colors.white.withValues(alpha: .5),
                                        inactiveThumbColor: Colors.grey.shade300,
                                        inactiveTrackColor: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_biometricAvailable && !_biometricEnabled)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: ElevatedButton.icon(
                                      onPressed: _testAndEnableBiometric,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: const Color(0xFF9C27B0),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 10,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        elevation: 2,
                                      ),
                                      icon: const Icon(Icons.fingerprint_rounded, size: 18),
                                      label: const Text(
                                        'Test & Enable',
                                        style: TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // PIN Section
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF1A1A3E),
                                const Color(0xFF141432),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: .1),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: .2),
                                blurRadius: 15,
                                spreadRadius: 1,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFFF9800).withValues(alpha: .3),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.pin_outlined, color: Colors.white, size: 22),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'SECURITY PIN',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                        Text(
                                          _appPin.join() == '1234'
                                              ? 'Change default PIN for better security'
                                              : '4-digit security PIN configured',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: _appPin.join() == '1234'
                                                ? Colors.orange
                                                : const Color(0xFF00C853),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        if (!_secureStorageAvailable)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4.0),
                                            child: Row(
                                              children: [
                                                Icon(Icons.warning_amber_rounded,
                                                    color: Colors.orange, size: 12),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'The default PIN is set to\n1234. For enhanced security,\nplease change it after\nfirst use',
                                                  style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.orange.shade300),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: _changingPin ? null : _startPinChange,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _changingPin
                                          ? Colors.grey.shade800
                                          : const Color(0xFFFF9800),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(9),
                                      ),
                                      elevation: 2,
                                    ),
                                    child: Text(
                                      _changingPin ? 'SETTING PIN...' : 'CHANGE PIN',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 10,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'PIN Status:',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text(
                                              _appPin.join() == '1234' ? 'Weak' : 'Strong',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: _appPin.join() == '1234'
                                                    ? Colors.orange
                                                    : const Color(0xFF00C853),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Icon(
                                              _appPin.join() == '1234'
                                                  ? Icons.warning_amber_rounded
                                                  : Icons.verified_rounded,
                                              color: _appPin.join() == '1234'
                                                  ? Colors.orange
                                                  : const Color(0xFF00C853),
                                              size: 16,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _showCurrentPin = !_showCurrentPin;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: .05),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: .1),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Text(
                                            _showCurrentPin ? _appPin.join() : '••••',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              color: Colors.white,
                                              letterSpacing: 4,
                                              fontWeight: FontWeight.w300,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Icon(
                                            _showCurrentPin
                                                ? Icons.visibility_off_rounded
                                                : Icons.visibility_rounded,
                                            color: Colors.grey.shade400,
                                            size: 16,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // PIN Input (When Changing)
                        if (_changingPin) ...[
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF1A1A3E),
                                  const Color(0xFF141432),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: .1),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: .2),
                                  blurRadius: 15,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Text(
                                  _confirmPinMode ? 'CONFIRM NEW PIN' : 'ENTER NEW PIN',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _confirmPinMode
                                      ? 'Enter the same 4-digit PIN again'
                                      : 'Create a new 4-digit security PIN',
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // PIN Indicators
                                Column(
                                  children: [
                                    _buildPinIndicator(
                                      pin: _newPin,
                                      label: _confirmPinMode ? 'First PIN' : 'Entering PIN',
                                    ),
                                    if (_confirmPinMode) ...[
                                      const SizedBox(height: 16),
                                      _buildPinIndicator(
                                        pin: _confirmPin,
                                        label: 'Confirm PIN',
                                      ),
                                    ],
                                  ],
                                ),

                                // Error message
                                if (_pinError != null) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: .1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.red.withValues(alpha: .3)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.error_outline_rounded,
                                            color: Colors.red, size: 16),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _pinError!,
                                            style: TextStyle(
                                              color: Colors.red.shade300,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 30),

                                // Number Pad
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    childAspectRatio: 1.5,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                  ),
                                  itemCount: 12,
                                  itemBuilder: (context, index) {
                                    if (index == 9) {
                                      return GestureDetector(
                                        onTap: _cancelPinChange,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.red.withValues(alpha: .2),
                                                Colors.red.withValues(alpha: .1),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: Colors.red.withValues(alpha: .3),
                                              width: 1,
                                            ),
                                          ),
                                          child: const Center(
                                            child: Icon(
                                              Icons.close_rounded,
                                              color: Colors.red,
                                              size: 26,
                                            ),
                                          ),
                                        ),
                                      );
                                    } else if (index == 10) {
                                      return GestureDetector(
                                        onTap: () => _onPinNumberPressed('0'),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: .05),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: Colors.white.withValues(alpha: .1),
                                              width: 1,
                                            ),
                                          ),
                                          child: const Center(
                                            child: Text(
                                              '0',
                                              style: TextStyle(
                                                fontSize: 26,
                                                color: Colors.white,
                                                fontWeight: FontWeight.w400,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    } else if (index == 11) {
                                      return GestureDetector(
                                        onTap: _onPinDelete,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.orange.withValues(alpha: .2),
                                                Colors.orange.withValues(alpha: .1),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: Colors.orange.withValues(alpha: .3),
                                              width: 1,
                                            ),
                                          ),
                                          child: const Center(
                                            child: Icon(
                                              Icons.backspace_outlined,
                                              color: Colors.orange,
                                              size: 26,
                                            ),
                                          ),
                                        ),
                                      );
                                    } else {
                                      return GestureDetector(
                                        onTap: () => _onPinNumberPressed('${index + 1}'),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: .05),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: Colors.white.withValues(alpha: .1),
                                              width: 1,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${index + 1}',
                                              style: const TextStyle(
                                                fontSize: 26,
                                                color: Colors.white,
                                                fontWeight: FontWeight.w400,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 32),

                        // Security Information
                        _buildSecurityInfoCard(),

                        const SizedBox(height: 40),

                        // Security Tips
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF1A1A3E),
                                const Color(0xFF141432),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: .1), width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: .2),
                                blurRadius: 15,
                                spreadRadius: 1,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.lightbulb_outline_rounded,
                                      color: Colors.yellow.shade400, size: 24),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'SECURITY TIPS',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildSecurityTip(
                                  'Avoid using simple PINs like 1234, 0000, or repeating digits'),
                              const SizedBox(height: 12),
                              _buildSecurityTip(
                                  'Enable biometric authentication for quick and secure access'),
                              const SizedBox(height: 12),
                              _buildSecurityTip(
                                  'Video lock adds extra security to sensitive videos'),
                              const SizedBox(height: 12),
                              _buildSecurityTip(
                                  'Change your PIN periodically for better security'),
                              const SizedBox(height: 12),
                              _buildSecurityTip(
                                  'App lock prevents unauthorized access to your videos'),
                            ],
                          ),
                        ),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required List<Color> gradient,
    required Function(bool) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withValues(alpha: .3),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: .3), width: 2),
              ),
              child: Center(child: Icon(icon, color: Colors.white, size: 26)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      )),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .8),
                        fontSize: 12,
                      )),
                ],
              ),
            ),
            Transform.scale(
              scale: 1.2,
              child: Switch.adaptive(
                value: value,
                onChanged: onChanged,
                activeColor: Colors.white,
                activeTrackColor: Colors.white.withValues(alpha: .5),
                inactiveThumbColor: Colors.grey.shade300,
                inactiveTrackColor: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityTip(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.chevron_right_rounded, color: Colors.blue.shade400, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey.shade300, fontSize: 13),
          ),
        ),
      ],
    );
  }
}