import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player_app/security_settings/widgets/view.dart';
class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen>
    with SingleTickerProviderStateMixin {

  bool _appLockEnabled = false;
  bool _videoLockEnabled = false;
  bool _biometricEnabled = false;
  List<String> _appPin = ['1', '2', '3', '4'];
  bool _changingPin = false;
  final List<String> _newPin = [];
  bool _showCurrentPin = false;
  bool _confirmPinMode = false;
  final List<String> _confirmPin = [];

  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _biometricAvailable = false;
  List<BiometricType> _availableBiometrics = [];

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  bool _secureStorageAvailable = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();
  }

  Future<void> _checkSecureStorage() async {
    try {
      await _secureStorage.write(key: 'test_key', value: 'test_value');
      await _secureStorage.delete(key: 'test_key');
      setState(() => _secureStorageAvailable = true);
    } catch (e) {
      debugPrint('Secure storage not available: $e');
      setState(() => _secureStorageAvailable = false);
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
      _showSnackBar('Failed to load security settings', LiquidColors.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
    if (setting == 'biometric' && value) {
      await _testAndEnableBiometric();
      return;
    }

    if (setting == 'appLock' && value) {
      final isDefaultPin = _appPin.join() == '1234';
      if (isDefaultPin) {
        _showSnackBar(
          'Please change default PIN before enabling app lock',
          LiquidColors.warning,
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
        value ? LiquidColors.success : LiquidColors.warning,
      );
    } catch (e) {
      _showSnackBar('Failed to update setting', LiquidColors.error);
    }
  }

  Future<void> _saveSetting(String setting, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(setting, value);
  }

  Future<void> _testAndEnableBiometric() async {
    if (!_biometricAvailable) {
      _showSnackBar('Biometric authentication not available', LiquidColors.warning);
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
          setState(() => _biometricEnabled = true);
        }
        _showSnackBar('Biometric authentication enabled', LiquidColors.success);

        if (!_appLockEnabled) {
          await _saveSetting('appLock', true);
          if (mounted) setState(() => _appLockEnabled = true);
        }
      } else {
        _showSnackBar('Authentication cancelled', LiquidColors.warning);
      }
    } catch (e) {
      debugPrint('Biometric error: $e');
      _showSnackBar('Authentication failed. Please try again.', LiquidColors.error);
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
    HapticFeedback.lightImpact();
    setState(() {
      _pinError = null;
      if (!_confirmPinMode) {
        if (_newPin.length < 4) _newPin.add(number);
        if (_newPin.length == 4) _validateFirstPin();
      } else {
        if (_confirmPin.length < 4) _confirmPin.add(number);
        if (_confirmPin.length == 4) _validateAndSavePin();
      }
    });
  }

  void _validateFirstPin() {
    final enteredPin = _newPin.join();

    if (!_isPinStrong(enteredPin)) {
      setState(() {
        _pinError = 'Please choose a stronger PIN';
        _newPin.clear();
      });
      return;
    }

    setState(() => _confirmPinMode = true);
  }

  bool _isPinStrong(String pin) {
    final simplePins = ['0000', '1111', '1234', '4321', '2222', '3333', '4444'];
    if (simplePins.contains(pin)) return false;
    if (RegExp(r'^(\d)\1{3}$').hasMatch(pin)) return false;
    if (RegExp(r'^0123|1234|2345|3456|4567|5678|6789|9876|8765|7654|6543|5432|4321|3210$').hasMatch(pin)) return false;
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
      await prefs.setStringList('appPin', _newPin);

      if (_secureStorageAvailable) {
        try {
          await _secureStorage.write(key: 'secure_pin', value: newPin);
        } catch (e) {
          debugPrint('Secure storage backup failed: $e');
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

      _showSnackBar('PIN changed successfully', LiquidColors.success);

      final wasDefaultPin = _appPin.join() == '1234';
      if (wasDefaultPin && !_appLockEnabled) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await _saveSetting('appLock', true);
          if (mounted) setState(() => _appLockEnabled = true);
          _showSnackBar('App lock auto-enabled for security', LiquidColors.accentBlue);
        });
      }
    } catch (e) {
      debugPrint('Error saving PIN: $e');
      _showSnackBar('Failed to save PIN', LiquidColors.error);
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
        if (_newPin.isNotEmpty) _newPin.removeLast();
      } else {
        if (_confirmPin.isNotEmpty) _confirmPin.removeLast();
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
    _showSnackBar('PIN change cancelled', LiquidColors.warning);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildBiometricStatus() {
    if (!_biometricAvailable) {
      return Row(
        children: [
          Icon(Icons.info_outline_rounded, color: LiquidColors.warning, size: 14),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'Biometric not available on this device',
              style: TextStyle(fontSize: 11, color: LiquidColors.warning),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Icon(Icons.check_circle_rounded, color: LiquidColors.success, size: 14),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            '${_getBiometricTypeName()} available',
            style: TextStyle(fontSize: 11, color: LiquidColors.success),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                LiquidColors.backgroundDeep,
                LiquidColors.backgroundMid,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        title: TweenAnimationBuilder(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 600),
          curve: Curves.elasticOut,
          builder: (context, double value, child) {
            return Transform.scale(
              scale: value,
              child: Row(
                children: [
                  Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      gradient: LiquidColors.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: LiquidColors.primaryStart.withValues(alpha: .4),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.security_rounded, color: Colors.white, size: 24),
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
            );
          },
        ),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            ),
        ],
      ),
      body: Container(
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
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    LiquidSecurityCard(
                      icon: Icons.lock_outline_rounded,
                      title: 'App Lock',
                      subtitle: 'Require authentication to open the app',
                      value: _appLockEnabled,
                      gradient: [LiquidColors.accentBlue, LiquidColors.primaryMid],
                      index: 0,
                      onChanged: (value) => _toggleSetting('appLock', value),
                    ),

                    const SizedBox(height: 16),

                    LiquidSecurityCard(
                      icon: Icons.video_settings_outlined,
                      title: 'Video Lock',
                      subtitle: 'Lock individual videos with authentication',
                      value: _videoLockEnabled,
                      gradient: [LiquidColors.success, LiquidColors.accentBlue],
                      index: 1,
                      onChanged: (value) => _toggleSetting('videoLock', value),
                    ),

                    const SizedBox(height: 16),

                    LiquidSecurityCard(
                      icon: _getBiometricIcon(),
                      title: 'Biometric Authentication',
                      subtitle: 'Use ${_getBiometricTypeName().toLowerCase()} for authentication',
                      value: _biometricEnabled,
                      gradient: [LiquidColors.accentPurple, LiquidColors.accentPink],
                      index: 2,
                      onChanged: (value) => _toggleSetting('biometric', value),
                      statusWidget: _buildBiometricStatus(),
                    ),

                    if (_biometricAvailable && !_biometricEnabled) ...[
                      const SizedBox(height: 12),
                      TweenAnimationBuilder(
                        tween: Tween<double>(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.elasticOut,
                        builder: (context, double value, child) {
                          return Transform.scale(
                            scale: value,
                            child: Center(
                              child: ElevatedButton.icon(
                                onPressed: _testAndEnableBiometric,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: LiquidColors.accentPurple,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  elevation: 8,
                                  shadowColor: LiquidColors.accentPurple.withValues(alpha: .3),
                                ),
                                icon: const Icon(Icons.fingerprint_rounded, size: 20),
                                label: const Text(
                                  'Test & Enable Biometric',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],

                    const SizedBox(height: 32),

                    LiquidPinSection(
                      currentPin: _appPin,
                      isChanging: _changingPin,
                      showCurrentPin: _showCurrentPin,
                      onStartChange: _startPinChange,
                      onToggleShowPin: () {
                        setState(() => _showCurrentPin = !_showCurrentPin);
                      },
                    ),

                    const SizedBox(height: 24),

                    if (_changingPin) ...[
                      LiquidPinInput(
                        confirmMode: _confirmPinMode,
                        newPin: _newPin,
                        confirmPin: _confirmPin,
                        error: _pinError,
                        onNumberPressed: _onPinNumberPressed,
                        onDelete: _onPinDelete,
                        onCancel: _cancelPinChange,
                      ),
                      const SizedBox(height: 24),
                    ],

                    _buildSecurityInfoCard(),

                    const SizedBox(height: 24),

                    _buildSecurityTipsCard(),

                    const SizedBox(height: 24),

                    _buildAboutCard(),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAboutCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            LiquidColors.backgroundLight.withValues(alpha: .9),
            LiquidColors.backgroundMid.withValues(alpha: .95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
          width: 1,
        ),
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
                  gradient: LiquidColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(Icons.info_outline_rounded, color: Colors.white, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'ABOUT & SUPPORT',
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
          _aboutTile(
            icon: Icons.star_rounded,
            label: 'Rate Secure Player',
            sublabel: 'Leave a review on Google Play',
            color: LiquidColors.warning,
            onTap: () async {
              HapticFeedback.lightImpact();
              final url = Uri.parse('https://play.google.com/store/apps/details?id=com.tabsap.video_player');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
          ),
          const SizedBox(height: 8),
          _aboutTile(
            icon: Icons.mail_outline_rounded,
            label: 'Send Feedback',
            sublabel: 'hello@farhatullah.com',
            color: LiquidColors.accentBlue,
            onTap: () async {
              HapticFeedback.lightImpact();
              final url = Uri.parse(
                'mailto:hello@farhatullah.com?subject=Secure%20Player%20feedback',
              );
              if (await canLaunchUrl(url)) {
                await launchUrl(url);
              }
            },
          ),
          const SizedBox(height: 8),
          _aboutTile(
            icon: Icons.privacy_tip_outlined,
            label: 'Privacy Policy',
            sublabel: 'How we handle your data',
            color: LiquidColors.success,
            onTap: () async {
              HapticFeedback.lightImpact();
              final url = Uri.parse(
                'https://farhatullah777.github.io/secure-player-privacy/',
              );
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
          ),
          const SizedBox(height: 16),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snap) {
              final v = snap.hasData
                  ? '${snap.data!.version} (${snap.data!.buildNumber})'
                  : '...';
              return Center(
                child: Text(
                  'Secure Player v$v',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _aboutTile({
    required IconData icon,
    required String label,
    required String sublabel,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sublabel,
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey.shade600,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            LiquidColors.backgroundLight.withValues(alpha: .9),
            LiquidColors.backgroundMid.withValues(alpha: .95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: LiquidColors.accentBlue.withValues(alpha: .2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: LiquidColors.accentBlue.withValues(alpha: .1),
            blurRadius: 15,
            spreadRadius: 0,
            offset: const Offset(0, 8),
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
                  gradient: LiquidColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
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
                  LiquidColors.accentBlue.withValues(alpha: .1),
                  LiquidColors.accentBlue.withValues(alpha: .05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: LiquidColors.accentBlue.withValues(alpha: .3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_clock_rounded, color: LiquidColors.accentBlue, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'All security features work 100% offline',
                    style: TextStyle(color: LiquidColors.accentBlue, fontSize: 12),
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
            gradient: RadialGradient(
              colors: [LiquidColors.success, LiquidColors.success.withValues(alpha: .5)],
              center: Alignment.center,
              radius: 0.8,
            ),
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

  Widget _buildSecurityTipsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            LiquidColors.backgroundLight.withValues(alpha: .9),
            LiquidColors.backgroundMid.withValues(alpha: .95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: LiquidColors.warning.withValues(alpha: .2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: LiquidColors.warning.withValues(alpha: .1),
            blurRadius: 15,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, color: LiquidColors.warning, size: 24),
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
          _buildSecurityTip('Avoid using simple PINs like 1234, 0000, or repeating digits'),
          const SizedBox(height: 12),
          _buildSecurityTip('Enable biometric authentication for quick and secure access'),
          const SizedBox(height: 12),
          _buildSecurityTip('Video lock adds extra security to sensitive videos'),
          const SizedBox(height: 12),
          _buildSecurityTip('Change your PIN periodically for better security'),
          const SizedBox(height: 12),
          _buildSecurityTip('App lock prevents unauthorized access to your videos'),
        ],
      ),
    );
  }

  Widget _buildSecurityTip(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.chevron_right_rounded, color: LiquidColors.accentBlue, size: 20),
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
