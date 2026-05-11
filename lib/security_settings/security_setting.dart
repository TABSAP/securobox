import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player_app/download_screen/widgets/view.dart';
import 'package:video_player_app/security_settings/intrusion_log_screen.dart';
import 'package:video_player_app/security_settings/privacy_policy_screen.dart';
import 'package:video_player_app/security_settings/recovery_setup_screen.dart';
import 'package:video_player_app/security_settings/send_feedback_screen.dart';
import 'package:video_player_app/security_settings/widgets/view.dart';
import 'package:video_player_app/utils/disguise_service.dart';
import 'package:video_player_app/utils/import_settings.dart';
import 'package:video_player_app/utils/intrusion_service.dart';
import 'package:video_player_app/utils/pin_crypto.dart';
import 'package:video_player_app/utils/recovery_service.dart';
import 'package:video_player_app/utils/session_manager.dart';
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
  bool _intrusionEnabled = false;
  int _intrusionCount = 0;
  bool _deleteOriginals = false;
  String _currentDisguise = 'default';
  bool _recoveryEnabled = false;
  String? _recoveryEmail;
  bool _changingPin = false;
  bool _verifyingOldPin = false;
  final List<String> _oldPin = [];
  final List<String> _newPin = [];
  bool _confirmPinMode = false;
  final List<String> _confirmPin = [];
  int _pinLength = PinCrypto.defaultPinLength;

  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _biometricAvailable = false;
  List<BiometricType> _availableBiometrics = [];

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

  Future<void> _loadSecuritySettings() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final pinLen = await PinCrypto.instance.getPinLength();
      final intrusionEnabled = await IntrusionService.instance.isEnabled();
      final intrusionCount = await IntrusionService.instance.count();
      final deleteOriginals =
          await ImportSettings.instance.deleteOriginalsEnabled();
      final currentDisguise = await DisguiseService.instance.getCurrent();
      final recoveryEnabled = await RecoveryService.instance.isEnabled();
      final recoveryEmail =
          recoveryEnabled ? await RecoveryService.instance.getEmail() : null;
      if (!mounted) return;
      setState(() {
        _appLockEnabled = prefs.getBool('appLock') ?? false;
        _videoLockEnabled = prefs.getBool('videoLock') ?? false;
        _biometricEnabled = prefs.getBool('biometric') ?? false;
        _pinLength = pinLen;
        _intrusionEnabled = intrusionEnabled;
        _intrusionCount = intrusionCount;
        _deleteOriginals = deleteOriginals;
        _currentDisguise = currentDisguise;
        _recoveryEnabled = recoveryEnabled;
        _recoveryEmail = recoveryEmail;
      });
    } catch (e) {
      FlushBarHelper.flushBarErrorMessage('Failed to load security settings', context);
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
      if (mounted) {
        setState(() {
          _biometricAvailable = false;
          _biometricEnabled = false;
        });
      }
    }
  }


  Future<void> _toggleSetting(String setting, bool value) async {
    // Handle biometric enable
    if (setting == 'biometric' && value) {
      await _testAndEnableBiometric();
      return;
    }

    // 🔒 Handle biometric disable - require fingerprint/face verification
    if (setting == 'biometric' && !value) {
      await _verifyBiometricBeforeDisable('biometric');
      return;
    }

    // 🔒 Handle app lock disable - require fingerprint/face verification
    if (setting == 'appLock' && !value) {
      await _verifyBiometricBeforeDisable('appLock');
      return;
    }

    // 🔒 Handle video lock disable - require fingerprint/face verification
    if (setting == 'videoLock' && !value) {
      await _verifyBiometricBeforeDisable('videoLock');
      return;
    }

    // Handle app lock enable
    if (setting == 'appLock' && value) {
      final hasPin = await PinCrypto.instance.hasPin();
      if (!hasPin) {
        if (!mounted) return;
        FlushBarHelper.flushBarWarningMessage('Please set a PIN before enabling app lock', context);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _startPinChange();
        });
        return;
      }
    }

    // For enabling other settings (no verification needed)
    try {
      await _saveSetting(setting, value);
      await _loadSecuritySettings();
      if (!mounted) return;
      FlushBarHelper.flushBarSuccessMessage(value ? 'Security enabled' : 'Security disabled', context);
    } catch (e) {
      if (!mounted) return;
      FlushBarHelper.flushBarErrorMessage('Failed to update setting', context);
    }
  }

// ============ ADD THIS NEW METHOD ============

  /// Requires biometric/fingerprint verification before disabling security features
  Future<void> _verifyBiometricBeforeDisable(String setting) async {
    // Get setting name for display
    final settingName = setting == 'appLock'
        ? 'App Lock'
        : setting == 'videoLock'
        ? 'Video Lock'
        : 'Biometric Authentication';

    // Get setting icon
    final settingIcon = setting == 'appLock'
        ? Icons.lock_outline_rounded
        : setting == 'videoLock'
        ? Icons.video_settings_outlined
        : _getBiometricIcon();

    // Get gradient colors
    final gradientColors = setting == 'appLock'
        ? [LiquidColors.accentBlue, LiquidColors.primaryMid]
        : setting == 'videoLock'
        ? [LiquidColors.success, LiquidColors.accentBlue]
        : [LiquidColors.accentPurple, LiquidColors.accentPink];

    // Show confirmation dialog first
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: LiquidColors.backgroundLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(settingIcon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Disable $settingName?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getDisableWarningMessage(setting),
              style: TextStyle(
                color: Colors.grey.shade300,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),

            // Biometric verification notice
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    LiquidColors.warning.withValues(alpha: 0.12),
                    LiquidColors.warning.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: LiquidColors.warning.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: LiquidColors.warning.withValues(alpha: 0.2),
                    ),
                    child: Icon(
                      _biometricAvailable ? _getBiometricIcon() : Icons.lock_rounded,
                      color: LiquidColors.warning,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _biometricAvailable
                              ? '${_getBiometricTypeName()} verification required'
                              : 'PIN verification required',
                          style: TextStyle(
                            color: LiquidColors.warning,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _biometricAvailable
                              ? 'Your ${_getBiometricTypeName().toLowerCase()} is needed to disable this security feature.'
                              : 'Your PIN is needed to disable this security feature.',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: LiquidColors.error,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 3,
              shadowColor: LiquidColors.error.withValues(alpha: 0.3),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _biometricAvailable ? _getBiometricIcon() : Icons.lock_rounded,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  _biometricAvailable ? 'Verify & Disable' : 'Enter PIN & Disable',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // User cancelled
    if (confirm != true || !mounted) return;

    // Show loading
    setState(() => _isLoading = true);

    try {
      bool verified = false;

      if (_biometricAvailable) {
        // Try biometric verification first
        verified = await _localAuth.authenticate(
          localizedReason: 'Verify your identity to disable $settingName',
          biometricOnly: true,
          sensitiveTransaction: true,
        );
      }

      if (!mounted) {
        setState(() => _isLoading = false);
        return;
      }

      if (verified) {
        // Successfully verified - disable the setting
        await _saveSetting(setting, false);

        // Also disable biometric if app lock is being disabled
        if (setting == 'appLock' && _biometricEnabled) {
          await _saveSetting('biometric', false);
        }

        await _loadSecuritySettings();

        if (mounted) {
          FlushBarHelper.flushBarSuccessMessage('$settingName disabled successfully', context);
        }
      } else {
        // Verification failed or cancelled
        if (mounted) {
          FlushBarHelper.flushBarErrorMessage('Verification failed. $settingName remains enabled.', context);
        }
      }
    } catch (e) {
      if (mounted) {
        FlushBarHelper.flushBarErrorMessage('Authentication error. $settingName remains enabled.', context);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }




// ============ ADD THIS HELPER METHOD ============

  /// Returns appropriate warning message based on the setting being disabled
  String _getDisableWarningMessage(String setting) {
    switch (setting) {
      case 'appLock':
        return 'Disabling app lock will remove the authentication requirement to open the app. Anyone with access to your device can view your vault contents.';
      case 'videoLock':
        return 'Disabling video lock will remove individual video protection. All locked videos will become accessible without additional authentication.';
      case 'biometric':
        return 'Disabling biometric authentication means you will need to enter your PIN every time. This is less convenient but still secure.';
      default:
        return 'Are you sure you want to disable this security feature?';
    }
  }

// ============ REPLACE YOUR EXISTING _testAndEnableBiometric METHOD ============

  // Future<void> _testAndEnableBiometric() async {
  //   if (!_biometricAvailable) {
  //     FlushBarHelper.flushBarWarningMessage('Biometric authentication not available', context);
  //     return;
  //   }
  //
  //   try {
  //     final bool didAuthenticate = await _localAuth.authenticate(
  //       localizedReason: 'Authenticate to enable biometric security',
  //       biometricOnly: true,
  //       sensitiveTransaction: true,
  //     );
  //
  //     if (didAuthenticate) {
  //       await _saveSetting('biometric', true);
  //       if (mounted) {
  //         setState(() => _biometricEnabled = true);
  //       }
  //       if (!mounted) return;
  //       FlushBarHelper.flushBarSuccessMessage('Biometric authentication enabled', context);
  //
  //       // Auto-enable app lock if not already enabled
  //       if (!_appLockEnabled) {
  //         await _saveSetting('appLock', true);
  //         if (mounted) setState(() => _appLockEnabled = true);
  //         if (!mounted) return;
  //         FlushBarHelper.flushBarInfoMessage('App lock auto-enabled for security', context);
  //       }
  //     } else {
  //       if (!mounted) return;
  //       FlushBarHelper.flushBarWarningMessage('Authentication cancelled', context);
  //     }
  //   } catch (e) {
  //     if (!mounted) return;
  //     FlushBarHelper.flushBarErrorMessage('Authentication failed. Please try again.', context);
  //   }
  // }

  // ============ PROFESSIONAL BIOMETRIC ENABLE/DISABLE ============

  Future<void> _testAndEnableBiometric() async {
    if (!_biometricAvailable) {
      _showBiometricNotAvailableSheet();
      return;
    }

    // Show professional bottom sheet
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildBiometricEnableSheet(),
    );

    if (confirmed != true || !mounted) return;

    // Show loading overlay
    _showLoadingOverlay('Verifying ${_getBiometricTypeName()}...');

    try {
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Authenticate to enable biometric security',
        biometricOnly: true,
        sensitiveTransaction: true,
      );

      // Dismiss loading
      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      if (didAuthenticate) {
        await _handleBiometricEnabled();
      } else {
        if (mounted) {
          _showVerificationFailedSheet();
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showErrorBottomSheet('Authentication failed', 'Please try again later');
      }
    }
  }

// ============ BIOMETRIC ENABLE BOTTOM SHEET ============
  Widget _buildBiometricEnableSheet() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1D2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Biometric Icon with Pulse Animation
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.8, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        LiquidColors.accentPurple,
                        LiquidColors.accentPink,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: LiquidColors.accentPurple.withValues(alpha: 0.4),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      _getBiometricIcon(),
                      color: Colors.white,
                      size: 44,
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // Title
          Text(
            'Enable ${_getBiometricTypeName()}',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),

          const SizedBox(height: 8),

          // Subtitle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Use your ${_getBiometricTypeName().toLowerCase()} instead of typing your PIN every time.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade400,
                height: 1.5,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Security badges
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(child: _securityBadge(Icons.shield_rounded, 'Bank-grade', 'Security')),
                const SizedBox(width: 12),
                Expanded(child: _securityBadge(Icons.bolt_rounded, 'Instant', 'Unlock')),
                const SizedBox(width: 12),
                Expanded(child: _securityBadge(Icons.lock_rounded, 'Encrypted', 'Storage')),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Enable button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: LiquidColors.accentPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                  shadowColor: LiquidColors.accentPurple.withValues(alpha: 0.4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_getBiometricIcon(), size: 22),
                    const SizedBox(width: 10),
                    const Text(
                      'Enable Now',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Cancel text button
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'Maybe Later',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

// ============ SECURITY BADGE ============
  Widget _securityBadge(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  LiquidColors.accentPurple.withValues(alpha: 0.3),
                  LiquidColors.accentPink.withValues(alpha: 0.1),
                ],
              ),
            ),
            child: Icon(icon, color: LiquidColors.accentPurple, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

// ============ BIOMETRIC NOT AVAILABLE SHEET ============
  void _showBiometricNotAvailableSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1D2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: LiquidColors.warning.withValues(alpha: 0.15),
                border: Border.all(
                  color: LiquidColors.warning.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Icon(Icons.fingerprint_rounded, color: LiquidColors.warning, size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              'Biometric Not Available',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Your device does not support biometric authentication or it has not been set up.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade400, height: 1.5),
              ),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LiquidColors.warning,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('OK', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

// ============ VERIFICATION FAILED SHEET ============
  void _showVerificationFailedSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1D2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: LiquidColors.error.withValues(alpha: 0.15),
                border: Border.all(
                  color: LiquidColors.error.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: const Icon(Icons.close_rounded, color: LiquidColors.error, size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              'Verification Failed',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'We couldn\'t verify your identity. Please try again.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade400, height: 1.5),
              ),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade700),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('Cancel', style: TextStyle(color: Colors.grey.shade400)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _testAndEnableBiometric();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: LiquidColors.accentPurple,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Try Again', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

// ============ ERROR BOTTOM SHEET ============
  void _showErrorBottomSheet(String title, String message) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1D2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Container(
              width: 70, height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: LiquidColors.error.withValues(alpha: 0.15),
              ),
              child: const Icon(Icons.error_outline_rounded, color: LiquidColors.error, size: 36),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(message, textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LiquidColors.accentBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('OK', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

// ============ LOADING OVERLAY ============
  void _showLoadingOverlay(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1D2E),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated fingerprint
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.9, end: 1.1),
                  duration: const Duration(milliseconds: 1000),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              LiquidColors.accentPurple.withValues(alpha: 0.3),
                              LiquidColors.accentPink.withValues(alpha: 0.1),
                            ],
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            _getBiometricIcon(),
                            color: LiquidColors.accentPurple,
                            size: 40,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                const SizedBox(
                  width: 24, height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: LiquidColors.accentPurple,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

// ============ HANDLE SUCCESS ============
  Future<void> _handleBiometricEnabled() async {
    await _saveSetting('biometric', true);
    if (!mounted) return;

    setState(() => _biometricEnabled = true);

    // Auto-enable app lock if not already enabled
    if (!_appLockEnabled) {
      await _saveSetting('appLock', true);
      if (mounted) setState(() => _appLockEnabled = true);
    }

    // Show success sheet
    if (!mounted) return;
    _showBiometricEnabledSuccessSheet();
  }

// ============ SUCCESS SHEET ============
  void _showBiometricEnabledSuccessSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1D2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Success checkmark
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    width: 90, height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          LiquidColors.success,
                          LiquidColors.accentBlue,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: LiquidColors.success.withValues(alpha: 0.4),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 50),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              '${_getBiometricTypeName()} Enabled!',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'You can now use your ${_getBiometricTypeName().toLowerCase()} to unlock the app.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade400, height: 1.5),
              ),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LiquidColors.success,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 8,
                    shadowColor: LiquidColors.success.withValues(alpha: 0.4),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
















  Future<void> _saveSetting(String setting, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(setting, value);
  }

  Future<void> _toggleIntrusion(bool value) async {
    HapticFeedback.lightImpact();
    if (value) {
      final granted = await IntrusionService.instance.requestCameraPermission();
      if (!granted) {
        if (mounted) {
          FlushBarHelper.flushBarWarningMessage('Camera permission required for break-in detection', context);
        }
        return;
      }
    }
    await IntrusionService.instance.setEnabled(value);
    if (!mounted) return;
    setState(() => _intrusionEnabled = value);
    FlushBarHelper.flushBarSuccessMessage( value
        ? 'Break-in detection enabled'
        : 'Break-in detection disabled', context);
  }

  Future<void> _toggleDeleteOriginals(bool value) async {
    HapticFeedback.lightImpact();
    if (value && Platform.isIOS) {
      final status = await Permission.photos.request();
      if (!status.isGranted) {
        if (mounted) {
          FlushBarHelper.flushBarWarningMessage('Photos permission required to remove originals from gallery', context);
        }
        return;
      }
    }
    await ImportSettings.instance.setDeleteOriginalsEnabled(value);
    if (!mounted) return;
    setState(() => _deleteOriginals = value);
    FlushBarHelper.flushBarSuccessMessage(value
        ? 'Originals will be removed after each import'
        : 'Originals will stay on your device', context);
  }

  Future<void> _openIntrusionLog() async {
    HapticFeedback.lightImpact();
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const IntrusionLogScreen()),
    );
    if (mounted) {
      _loadSecuritySettings();
    }
  }

  void _startPinChange() {
    setState(() {
      _changingPin = true;
      _verifyingOldPin = true;
      _confirmPinMode = false;
      _oldPin.clear();
      _newPin.clear();
      _confirmPin.clear();
      _pinError = null;
    });
  }

  void _onPinNumberPressed(String number) {
    HapticFeedback.lightImpact();
    setState(() {
      _pinError = null;
      if (_verifyingOldPin) {
        if (_oldPin.length < _pinLength) _oldPin.add(number);
        if (_oldPin.length == _pinLength) _validateOldPin();
      } else if (!_confirmPinMode) {
        if (_newPin.length < _pinLength) _newPin.add(number);
        if (_newPin.length == _pinLength) _validateFirstPin();
      } else {
        if (_confirmPin.length < _pinLength) _confirmPin.add(number);
        if (_confirmPin.length == _pinLength) _validateAndSavePin();
      }
    });
  }

  Future<void> _validateOldPin() async {
    final entered = _oldPin.join();
    final ok = await PinCrypto.instance.verifyPin(entered);
    if (!mounted) return;
    if (!ok) {
      HapticFeedback.heavyImpact();
      setState(() {
        _pinError = 'Incorrect current PIN';
        _oldPin.clear();
      });
      return;
    }
    setState(() {
      _verifyingOldPin = false;
      _pinError = null;
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
    if (RegExp(r'^(\d)\1+$').hasMatch(pin)) return false;
    const ascending = '0123456789';
    const descending = '9876543210';
    if (ascending.contains(pin) || descending.contains(pin)) return false;
    const knownBad = {
      '1234', '4321', '0000', '1111', '2222', '3333', '4444',
      '5555', '6666', '7777', '8888', '9999', '123456', '654321',
      '111111', '000000', '121212', '696969', '112233', '789456',
    };
    if (knownBad.contains(pin)) return false;
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

    final isSameAsCurrent = await PinCrypto.instance.verifyPin(newPin);
    if (isSameAsCurrent) {
      setState(() {
        _pinError = 'New PIN cannot be same as current PIN';
        _newPin.clear();
        _confirmPin.clear();
        _confirmPinMode = false;
      });
      return;
    }

    try {
      await PinCrypto.instance.setPin(newPin);

      if (mounted) {
        setState(() {
          _changingPin = false;
          _verifyingOldPin = false;
          _confirmPinMode = false;
          _oldPin.clear();
          _newPin.clear();
          _confirmPin.clear();
        });
      }
      if (!mounted) return;
      FlushBarHelper.flushBarSuccessMessage('PIN changed successfully', context);

      if (!_appLockEnabled) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await _saveSetting('appLock', true);
          if (mounted) setState(() => _appLockEnabled = true);
          if (!mounted) return;
          FlushBarHelper.flushBarInfoMessage('App lock auto-enabled for security', context);
        });
      }
    } catch (e) {
      if (!mounted) return;
      FlushBarHelper.flushBarErrorMessage('Failed to save PIN', context);
      setState(() {
        _changingPin = false;
        _verifyingOldPin = false;
        _confirmPinMode = false;
        _oldPin.clear();
        _newPin.clear();
        _confirmPin.clear();
      });
    }
  }

  void _onPinDelete() {
    setState(() {
      _pinError = null;
      if (_verifyingOldPin) {
        if (_oldPin.isNotEmpty) _oldPin.removeLast();
      } else if (!_confirmPinMode) {
        if (_newPin.isNotEmpty) _newPin.removeLast();
      } else {
        if (_confirmPin.isNotEmpty) _confirmPin.removeLast();
      }
    });
  }

  void _cancelPinChange() {
    setState(() {
      _changingPin = false;
      _verifyingOldPin = false;
      _confirmPinMode = false;
      _oldPin.clear();
      _newPin.clear();
      _confirmPin.clear();
      _pinError = null;
    });
    FlushBarHelper.flushBarWarningMessage('PIN change cancelled', context);
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

                    const SizedBox(height: 32),

                    LiquidPinSection(
                      isChanging: _changingPin,
                      onStartChange: _startPinChange,
                    ),

                    const SizedBox(height: 24),

                    if (_changingPin) ...[
                      LiquidPinInput(
                        verifyOldMode: _verifyingOldPin,
                        confirmMode: _confirmPinMode,
                        oldPin: _oldPin,
                        newPin: _newPin,
                        confirmPin: _confirmPin,
                        totalLength: _pinLength,
                        error: _pinError,
                        onNumberPressed: _onPinNumberPressed,
                        onDelete: _onPinDelete,
                        onCancel: _cancelPinChange,
                      ),
                      const SizedBox(height: 24),
                    ],

                    _buildSessionCard(),

                    const SizedBox(height: 24),

                    _buildRecoveryCard(),

                    const SizedBox(height: 24),

                    _buildIntrusionCard(),

                    const SizedBox(height: 24),

                    _buildImportCard(),

                    const SizedBox(height: 24),

                    _buildDisguiseCard(),

                    const SizedBox(height: 24),

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

  Future<void> _selectDisguise(DisguiseOption option) async {
    if (option.key == _currentDisguise) return;
    if (!DisguiseService.instance.isSupported) {
      FlushBarHelper.flushBarWarningMessage('Disguise mode is Android-only for now', context);
      return;
    }

    HapticFeedback.lightImpact();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: LiquidColors.backgroundLight,
        title: Text(
          'Switch to ${option.label}?',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          'Your home screen icon will change to "${option.label}". Some launchers may take a moment to update. The package name and Settings → Apps entry stay the same.',
          style: TextStyle(color: Colors.grey.shade300, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TextStyle(color: Colors.grey.shade400)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Switch',
                style: TextStyle(color: LiquidColors.accentBlue)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final success = await DisguiseService.instance.set(option.key);
    if (!mounted) return;
    if (success) {
      setState(() => _currentDisguise = option.key);
      FlushBarHelper.flushBarSuccessMessage('Icon switched to ${option.label}', context);
    } else {
      FlushBarHelper.flushBarErrorMessage('Failed to change icon', context);
    }
  }

  Widget _buildDisguiseCard() {
    final supported = DisguiseService.instance.isSupported;
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
          color: LiquidColors.accentPink.withValues(alpha: 0.25),
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
                  gradient: LinearGradient(
                    colors: [
                      LiquidColors.accentPink,
                      LiquidColors.accentPurple,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(Icons.face_retouching_natural,
                      color: Colors.white, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'DISGUISE',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            supported
                ? 'Hide the app behind a different home-screen icon and label.'
                : 'Disguise mode is Android-only for now. iOS support coming in a future update.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade400,
              height: 1.4,
            ),
          ),
          if (supported) ...[
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.85,
              children: DisguiseService.options
                  .map((o) => _disguiseTile(o))
                  .toList(),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: LiquidColors.warning.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: LiquidColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: LiquidColors.warning, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'A determined snooper can still find SecuroBox in Settings → Apps. This is a deterrent, not perfect hiding.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade300,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _disguiseTile(DisguiseOption option) {
    final selected = option.key == _currentDisguise;
    return GestureDetector(
      onTap: () => _selectDisguise(option),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected
              ? LiquidColors.accentPink.withValues(alpha: 0.18)
              : LiquidColors.backgroundDeep,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? LiquidColors.accentPink
                : Colors.white.withValues(alpha: 0.06),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    option.assetIcon,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: LiquidColors.backgroundLight,
                      child: const Icon(Icons.image_not_supported_rounded,
                          color: Colors.grey),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              option.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? Colors.white : Colors.grey.shade400,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportCard() {
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
          color: LiquidColors.accentPurple.withValues(alpha: 0.25),
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
                  gradient: LinearGradient(
                    colors: [
                      LiquidColors.accentPurple,
                      LiquidColors.accentPink,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(Icons.move_to_inbox_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'IMPORT',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              Switch(
                value: _deleteOriginals,
                onChanged: _toggleDeleteOriginals,
                activeThumbColor: Colors.white,
                activeTrackColor: LiquidColors.accentPurple,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Move originals into the vault',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'When enabled, files you import are removed from your device after they are encrypted into the vault.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade400,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: LiquidColors.warning.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: LiquidColors.warning.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    color: LiquidColors.warning, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    Platform.isIOS
                        ? 'On iOS, photos and videos can only be removed via the system confirmation dialog after each import.'
                        : 'Some files (especially on Android 13+) may need to be removed manually because of OS storage rules.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade300,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntrusionCard() {
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
          color: LiquidColors.warning.withValues(alpha: 0.25),
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
                  gradient: LinearGradient(
                    colors: [LiquidColors.warning, LiquidColors.error],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(Icons.camera_front_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'BREAK-IN DETECTION',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              Switch(
                value: _intrusionEnabled,
                onChanged: _toggleIntrusion,
                activeThumbColor: Colors.white,
                activeTrackColor: LiquidColors.warning,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Captures a front-camera photo on every wrong PIN attempt. Photos are encrypted and stored only inside this app.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade400,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Note: iOS shows a green status-bar indicator while the camera is active.',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _openIntrusionLog,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: LiquidColors.backgroundDeep,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: LiquidColors.warning.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: LiquidColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.history_rounded,
                          color: LiquidColors.warning, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Intrusion Log',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _intrusionCount > 0
                            ? LiquidColors.error.withValues(alpha: 0.2)
                            : Colors.grey.shade800,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$_intrusionCount',
                        style: TextStyle(
                          color: _intrusionCount > 0
                              ? LiquidColors.error
                              : Colors.grey.shade400,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right_rounded,
                        color: Colors.grey.shade600, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openRecoverySetup() async {
    HapticFeedback.lightImpact();
    final wasEnabled = _recoveryEnabled;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const RecoverySetupScreen()),
    );
    if (result == true && mounted) {
      await _loadSecuritySettings();
      if (!mounted) return;
      FlushBarHelper.flushBarSuccessMessage(
        wasEnabled ? 'Recovery code re-issued' : 'Recovery enabled',
        context,
      );
    }
  }

  Future<void> _confirmRemoveRecovery() async {
    HapticFeedback.lightImpact();
    final storedEmail = (_recoveryEmail ?? '').trim();
    if (storedEmail.isEmpty) {
      await RecoveryService.instance.clear();
      if (!mounted) return;
      await _loadSecuritySettings();
      return;
    }

    final controller = TextEditingController();
    final target = storedEmail.toLowerCase();

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final entered = controller.text.trim().toLowerCase();
          final matches = entered.isNotEmpty && entered == target;
          return AlertDialog(
            backgroundColor: LiquidColors.backgroundLight,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            title: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: LiquidColors.error.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.lock_open_rounded,
                    color: LiquidColors.error,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Remove recovery?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You\'ll no longer be able to reset your PIN with the email code. '
                  'If you forget your PIN, the only option will be to wipe the vault.',
                  style: TextStyle(
                    color: Colors.grey.shade300,
                    height: 1.5,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: LiquidColors.error.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: LiquidColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 14, color: LiquidColors.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Type your recovery email exactly to confirm.',
                          style: TextStyle(
                            color: LiquidColors.error,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 6),
                  child: Text(
                    'Hint: ${RecoveryService.mask(storedEmail)}',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                TextField(
                  controller: controller,
                  autofocus: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) => setDialogState(() {}),
                  cursorColor: LiquidColors.error,
                  style: TextStyle(
                    color: matches ? LiquidColors.error : Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'you@example.com',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.04),
                    prefixIcon: Icon(
                      Icons.alternate_email_rounded,
                      color: matches
                          ? LiquidColors.error
                          : Colors.grey.shade500,
                      size: 18,
                    ),
                    suffixIcon: matches
                        ? Icon(Icons.check_circle_rounded,
                            color: LiquidColors.error, size: 18)
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: matches
                            ? LiquidColors.error
                            : LiquidColors.accentBlue,
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: matches
                    ? () => Navigator.of(dialogContext).pop(true)
                    : null,
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                child: Text(
                  'Remove',
                  style: TextStyle(
                    color: matches
                        ? LiquidColors.error
                        : Colors.grey.shade600,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (ok != true || !mounted) return;
    await RecoveryService.instance.clear();
    if (!mounted) return;
    await _loadSecuritySettings();
    if (!mounted) return;
    FlushBarHelper.flushBarSuccessMessage('Recovery removed', context);
  }

  Widget _buildRecoveryCard() {
    final accent = _recoveryEnabled
        ? LiquidColors.success
        : LiquidColors.accentBlue;
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
          color: accent.withValues(alpha: 0.25),
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
                  gradient: LinearGradient(
                    colors: _recoveryEnabled
                        ? [LiquidColors.success, LiquidColors.accentBlue]
                        : [
                            LiquidColors.accentBlue,
                            LiquidColors.accentPurple,
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(Icons.restore_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'PIN RECOVERY',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  _recoveryEnabled ? 'ON' : 'OFF',
                  style: TextStyle(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _recoveryEnabled
                ? 'Use your emailed code to reset the PIN if you forget it. Vault contents stay encrypted and intact.'
                : 'Set up an email-based recovery code so a forgotten PIN doesn\'t mean wiping your vault.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade400,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          if (_recoveryEnabled) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: LiquidColors.backgroundDeep,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: accent.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.alternate_email_rounded,
                      color: accent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _recoveryEmail == null
                          ? 'unknown'
                          : RecoveryService.mask(_recoveryEmail!),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openRecoverySetup,
                    icon: Icon(Icons.refresh_rounded,
                        size: 16, color: accent),
                    label: Text(
                      'Re-issue code',
                      style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(
                        color: accent.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _confirmRemoveRecovery,
                    icon: Icon(Icons.delete_outline_rounded,
                        size: 16, color: LiquidColors.error),
                    label: Text(
                      'Remove',
                      style: TextStyle(
                        color: LiquidColors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(
                        color: LiquidColors.error.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openRecoverySetup,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(
                  'Set up recovery',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: LiquidColors.accentBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSessionCard() {
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
          color: LiquidColors.accentBlue.withValues(alpha: 0.2),
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
                  gradient: LinearGradient(
                    colors: [LiquidColors.accentBlue, LiquidColors.primaryMid],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(Icons.timer_outlined, color: Colors.white, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'SESSION',
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
          Text(
            'Auto-lock when inactive',
            style: TextStyle(
              color: Colors.grey.shade300,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: LiquidColors.backgroundDeep,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: LiquidColors.accentBlue.withValues(alpha: 0.3),
              ),
            ),
            child: DropdownButton<int>(
              value: SessionManager.instance.autoLockSeconds,
              isExpanded: true,
              dropdownColor: LiquidColors.backgroundLight,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              underline: const SizedBox(),
              icon: Icon(Icons.arrow_drop_down_rounded,
                  color: LiquidColors.accentBlue),
              items: SessionManager.autoLockOptions.entries
                  .map((e) => DropdownMenuItem<int>(
                        value: e.key,
                        child: Text(e.value),
                      ))
                  .toList(),
              onChanged: (value) async {
                if (value == null) return;
                HapticFeedback.selectionClick();
                await SessionManager.instance.setAutoLockSeconds(value);
                if (mounted) setState(() {});
              },
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'PIN length',
            style: TextStyle(
              color: Colors.grey.shade300,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _pinLengthChip(4)),
              const SizedBox(width: 10),
              Expanded(child: _pinLengthChip(6)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                SessionManager.instance.requestLock();
              },
              icon: Icon(Icons.lock_rounded,
                  color: LiquidColors.accentBlue, size: 18),
              label: Text(
                'Lock Now',
                style: TextStyle(
                  color: LiquidColors.accentBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(
                  color: LiquidColors.accentBlue.withValues(alpha: 0.6),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pinLengthChip(int digits) {
    final selected = _pinLength == digits;
    return GestureDetector(
      onTap: () async {
        if (selected) return;
        HapticFeedback.selectionClick();
        final hasPin = await PinCrypto.instance.hasPin();
        if (!mounted) return;
        if (hasPin) {
          final ok = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: LiquidColors.backgroundLight,
              title: const Text(
                'Change PIN length?',
                style: TextStyle(color: Colors.white),
              ),
              content: Text(
                'You will need to set a new $digits-digit PIN now. Continue?',
                style: TextStyle(color: Colors.grey.shade300),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey.shade400),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(
                    'Continue',
                    style: TextStyle(color: LiquidColors.accentBlue),
                  ),
                ),
              ],
            ),
          );
          if (ok != true) return;
        }
        await PinCrypto.instance.setPreferredPinLength(digits);
        if (!mounted) return;
        setState(() => _pinLength = digits);
        if (hasPin) {
          _startPinChange();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? LiquidColors.accentBlue.withValues(alpha: 0.18)
              : LiquidColors.backgroundDeep,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? LiquidColors.accentBlue
                : Colors.white.withValues(alpha: 0.08),
            width: selected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            '$digits digits',
            style: TextStyle(
              color: selected ? Colors.white : Colors.grey.shade400,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 14,
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
            label: 'Rate SecuroBox',
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
            sublabel: 'Tell us what you think',
            color: LiquidColors.accentBlue,
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SendFeedbackScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          _aboutTile(
            icon: Icons.privacy_tip_outlined,
            label: 'Privacy Policy',
            sublabel: 'How we handle your data',
            color: LiquidColors.success,
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PrivacyPolicyScreen(),
                ),
              );
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
                  'SecuroBox v$v',
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
          _buildSecurityFeature('AES-256-CTR encryption for every file at rest'),
          const SizedBox(height: 12),
          _buildSecurityFeature('PIN hashed with PBKDF2-HMAC-SHA256 (100k rounds)'),
          const SizedBox(height: 12),
          _buildSecurityFeature('Hash and master key in OS Keychain / Keystore'),
          const SizedBox(height: 12),
          _buildSecurityFeature('Random UUID filenames on disk — originals never exposed'),
          const SizedBox(height: 12),
          _buildSecurityFeature('Cloud backup disabled — files stay on device'),
          const SizedBox(height: 12),
          _buildSecurityFeature('Biometric authentication via OS BiometricPrompt'),
          const SizedBox(height: 12),
          _buildSecurityFeature('Escalating cooldown after wrong PIN attempts'),
          const SizedBox(height: 12),
          _buildSecurityFeature('No analytics, no trackers, no servers'),
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
