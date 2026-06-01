import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player_app/history_screen/widgets/view.dart';
import 'package:video_player_app/security_settings/decoy_setup_screen.dart';
import 'package:video_player_app/security_settings/face_scan_screen.dart';
import 'package:video_player_app/security_settings/intrusion_log_screen.dart';
import 'package:video_player_app/security_settings/recovery_setup_screen.dart';
import 'package:video_player_app/security_settings/widgets/view.dart';
import 'package:video_player_app/utils/decoy_service.dart';
import 'package:video_player_app/utils/responsive.dart';
import 'package:video_player_app/utils/disguise_service.dart';
import 'package:video_player_app/utils/face_recognition_service.dart';
import 'package:video_player_app/utils/import_settings.dart';
import 'package:video_player_app/utils/intrusion_service.dart';
import 'package:video_player_app/utils/network_guard.dart';
import 'package:video_player_app/utils/pin_crypto.dart';
import 'package:video_player_app/utils/recovery_service.dart';
import 'package:video_player_app/utils/session_manager.dart';
import 'package:video_player_app/widgets/liquid_bottom_nav.dart';
import 'package:video_player_app/widgets/pin_unlock_dialog.dart';

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
  bool _faceUnlockEnabled = false;
  bool _faceRecogEnrolled = false;
  bool _intrusionEnabled = false;
  bool _offlineIntegrityLock = false;
  int _intrusionCount = 0;
  bool _deleteOriginals = false;
  String _currentDisguise = 'default';
  bool _recoveryEnabled = false;
  String? _recoveryEmail;
  bool _decoyEnabled = false;
  bool _changingPin = false;
  bool _verifyingOldPin = false;
  final List<String> _oldPin = [];
  final List<String> _newPin = [];
  bool _confirmPinMode = false;
  final List<String> _confirmPin = [];
  
  int _pinLength = PinCrypto.defaultPinLength;
  int _newPinLength = PinCrypto.defaultPinLength;

  bool _choosingLength = false;

  bool _lengthSelectionFlow = false;

  final GlobalKey _pinFlowKey = GlobalKey();

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
 
    _pinLength = PinCrypto.instance.cachedPinLength;
    _newPinLength = _pinLength;
    _initAnimations();
    _loadSecuritySettings(initial: true);
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
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _animationController.forward();
  }

  Future<void> _loadSecuritySettings({bool initial = false}) async {
    if (initial) setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (initial) {
       
        try {
          final avail = await _localAuth.getAvailableBiometrics();
          if ((prefs.getBool('biometric') ?? false) &&
              avail.contains(BiometricType.face) &&
              !avail.contains(BiometricType.fingerprint)) {
            await prefs.setBool('biometric_face', true);
            await prefs.setBool('biometric', false);
          }
        } catch (_) {}
      
        await DisguiseService.instance.load();
      }


      final pinLenF = PinCrypto.instance.getPinLength();
      final intrusionEnabledF = IntrusionService.instance.isEnabled();
      final intrusionCountF = IntrusionService.instance.count();
      final deleteOriginalsF = ImportSettings.instance.deleteOriginalsEnabled();
      final recoveryEnabledF = RecoveryService.instance.isEnabled();
      final decoyEnabledF = DecoyService.instance.hasFakePin();
      final faceRecogEnrolledF = FaceRecognitionService.instance.isEnrolled();

      final pinLen = await pinLenF;
      final intrusionEnabled = await intrusionEnabledF;
      final intrusionCount = await intrusionCountF;
      final deleteOriginals = await deleteOriginalsF;
      final recoveryEnabled = await recoveryEnabledF;
      final recoveryEmail = recoveryEnabled
          ? await RecoveryService.instance.getEmail()
          : null;
      final decoyEnabled = await decoyEnabledF;
      final faceRecogEnrolled = await faceRecogEnrolledF;
      // Cached — no native PackageManager call on every settings change.
      final currentDisguise = DisguiseService.instance.currentKey;
      if (!mounted) return;
      setState(() {
        _appLockEnabled = prefs.getBool('appLock') ?? false;
        _videoLockEnabled = prefs.getBool('videoLock') ?? false;
        _biometricEnabled = prefs.getBool('biometric') ?? false;
        _faceUnlockEnabled = prefs.getBool('biometric_face') ?? false;
        _pinLength = pinLen;
        if (!_changingPin) _newPinLength = pinLen;
        _intrusionEnabled = intrusionEnabled;
        _offlineIntegrityLock = NetworkGuard.instance.enabled;
        _intrusionCount = intrusionCount;
        _deleteOriginals = deleteOriginals;
        _currentDisguise = currentDisguise;
        _recoveryEnabled = recoveryEnabled;
        _recoveryEmail = recoveryEmail;
        _decoyEnabled = decoyEnabled;
        _faceRecogEnrolled = faceRecogEnrolled;
      });
    } catch (e) {
      FlushBarHelper.flushBarErrorMessage(
        'Failed to load security settings',
        context,
      );
    } finally {
      if (initial && mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkBiometricCapability() async {
    try {
   
      final bool canCheck = await _localAuth.canCheckBiometrics;
      final bool supported = await _localAuth.isDeviceSupported();
      List<BiometricType> availableBiometrics = const <BiometricType>[];
      try {
        availableBiometrics = await _localAuth.getAvailableBiometrics();
      } catch (_) {}

      if (mounted) {
        setState(() {
          _biometricAvailable = canCheck || supported;
          _availableBiometrics = availableBiometrics;

          if (!_biometricAvailable && _biometricEnabled) {
            _biometricEnabled = false;
            _saveSetting('biometric', false);
          }
      
          if (availableBiometrics.isNotEmpty &&
              !availableBiometrics.contains(BiometricType.face) &&
              _faceUnlockEnabled) {
            _faceUnlockEnabled = false;
            _saveSetting('biometric_face', false);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _biometricAvailable = false;
          _biometricEnabled = false;
          _faceUnlockEnabled = false;
        });
      }
    }
  }

  bool get _faceAvailable => _availableBiometrics.contains(BiometricType.face);
  bool get _fingerprintAvailable =>
      _availableBiometrics.contains(BiometricType.fingerprint);


  static const Set<String> _lockSettings = {
    'appLock',
    'biometric',
    'biometric_face',
  };

  bool _wouldDisableAllLocks(String setting) {
    if (!_lockSettings.contains(setting)) return false;
    final remaining = <String, bool>{
      'appLock': _appLockEnabled,
      'biometric': _biometricEnabled,
      'biometric_face': _faceUnlockEnabled,
    };
    remaining[setting] = false;
    return !remaining.values.any((on) => on);
  }

  String _lockDisplayName(String setting) {
    switch (setting) {
      case 'appLock':
        return 'App Lock';
      case 'biometric':
        return 'Biometric Unlock';
      case 'biometric_face':
        return 'Face Unlock';
      default:
        return setting;
    }
  }

  Future<void> _toggleSetting(String setting, bool value) async {

    if (!value && _wouldDisableAllLocks(setting)) {
      HapticFeedback.heavyImpact();
      FlushBarHelper.flushBarWarningMessage(
        '${_lockDisplayName(setting)} is the only active lock. Enable another '
        'lock first to keep the vault protected.',
        context,
      );
      return;
    }


    if (setting == 'biometric' && value) {
      await _testAndEnableBiometric();
      return;
    }
    if (setting == 'biometric' && !value) {
      await _verifyBiometricBeforeDisable('biometric');
      return;
    }
    if (setting == 'biometric_face' && value) {
      await _testAndEnableBiometric(prefKey: 'biometric_face');
      return;
    }
    if (setting == 'biometric_face' && !value) {
      await _verifyBiometricBeforeDisable('biometric_face');
      return;
    }
    if (setting == 'appLock' && !value) {
      await _verifyBiometricBeforeDisable('appLock');
      return;
    }
    if (setting == 'videoLock' && !value) {
      await _verifyBiometricBeforeDisable('videoLock');
      return;
    }
    if (setting == 'appLock' && value) {
      final hasPin = await PinCrypto.instance.hasPin();
      if (!hasPin) {
        if (!mounted) return;
        FlushBarHelper.flushBarWarningMessage(
          'Please set a PIN before enabling app lock',
          context,
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _startPinChange();
        });
        return;
      }
    }
    try {
      await _saveSetting(setting, value);
      if (!mounted) return;
      setState(() {
        switch (setting) {
          case 'appLock':
            _appLockEnabled = value;
            break;
          case 'videoLock':
            _videoLockEnabled = value;
            break;
          case 'biometric':
            _biometricEnabled = value;
            break;
          case 'biometric_face':
            _faceUnlockEnabled = value;
            break;
        }
      });
      FlushBarHelper.flushBarSuccessMessage(
        value ? 'Security enabled' : 'Security disabled',
        context,
      );
    } catch (e) {
      if (!mounted) return;
      FlushBarHelper.flushBarErrorMessage('Failed to update setting', context);
    }
  }
  Future<void> _verifyBiometricBeforeDisable(String setting) async {
    // Get setting name for display
    final settingName = setting == 'appLock'
        ? 'App Lock'
        : setting == 'videoLock'
        ? 'Video Lock'
        : setting == 'biometric_face'
        ? 'Face Unlock'
        : 'Biometric Authentication';

    // Get setting icon
    final settingIcon = setting == 'appLock'
        ? Icons.lock_outline_rounded
        : setting == 'videoLock'
        ? Icons.video_settings_outlined
        : setting == 'biometric_face'
        ? Icons.face_retouching_natural
        : _getBiometricIcon();

    // Get gradient colors
    final gradientColors = setting == 'appLock'
        ? [LiquidColors.accentBlue, LiquidColors.primaryMid]
        : setting == 'videoLock'
        ? [LiquidColors.success, LiquidColors.accentBlue]
        : [LiquidColors.accentPurple, LiquidColors.accentPink];
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
                style: TextStyle(
                  color: LiquidColors.textPrimary,
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
                color: LiquidColors.textSecondary,
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
                      _biometricAvailable
                          ? _getBiometricIcon()
                          : Icons.lock_rounded,
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
                            color: LiquidColors.textSecondary,
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
              style: TextStyle(
                color: LiquidColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: LiquidColors.error,
              foregroundColor: LiquidColors.textPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 3,
              shadowColor: LiquidColors.error.withValues(alpha: 0.3),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _biometricAvailable
                      ? _getBiometricIcon()
                      : Icons.lock_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  _biometricAvailable
                      ? 'Verify & Disable'
                      : 'Enter PIN & Disable',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // User cancelled
    if (confirm != true || !mounted) return;

    // 1. Try biometric / Face ID first when the device supports it. If it
    //    fails or is cancelled we fall through to the PIN keypad dialog —
    //    EITHER biometric or the correct app PIN is enough to proceed.
    setState(() => _isLoading = true);
    bool verified = false;
    if (_biometricAvailable) {
      SessionManager.instance.beginTrustedInteraction();
      try {
        verified = await _localAuth.authenticate(
          localizedReason: 'Verify your identity to disable $settingName',
          biometricOnly: true,
          sensitiveTransaction: true,
          persistAcrossBackgrounding: true,
        );
      } on LocalAuthException {
        // Sensor unavailable / user cancelled / lockout — fall through to PIN.
      } catch (_) {
        // Defensive: any other failure → PIN fallback.
      } finally {
        SessionManager.instance.endTrustedInteraction();
      }
    }
    if (!mounted) return;
    setState(() => _isLoading = false);

    // 2. PIN fallback. Always offered when biometric didn't verify (whether
    //    because the device lacks biometrics, the user cancelled, the OS
    //    failed, or the user tapped through without authenticating).
    if (!verified) {
      verified = await PinUnlockDialog.show(
        context,
        title: 'Confirm with PIN',
        subtitle: 'Enter your app PIN to disable $settingName',
      );
      if (!mounted) return;
    }

    if (!verified) {
      FlushBarHelper.flushBarErrorMessage(
        'Verification failed. $settingName remains enabled.',
        context,
      );
      return;
    }

    // 3. Verified — disable just this setting. The other two locks (if any)
    //    stay on so the vault keeps a working lock layer.
    setState(() => _isLoading = true);
    try {
      await _saveSetting(setting, false);
      await _loadSecuritySettings();
      if (mounted) {
        FlushBarHelper.flushBarSuccessMessage(
          '$settingName disabled successfully',
          context,
        );
      }
    } catch (_) {
      if (mounted) {
        FlushBarHelper.flushBarErrorMessage(
          'Failed to disable $settingName',
          context,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============ ADD THIS HELPER METHOD ============

  /// Returns appropriate warning message based on the setting being disabled
  String _getDisableWarningMessage(String setting) {
    switch (setting) {
      case 'appLock':
        return 'Disabling App Lock removes the PIN prompt when the app opens. Biometric or Face Unlock (if enabled) will still gate access.';
      case 'videoLock':
        return 'Disabling video lock will remove individual video protection. All locked videos will become accessible without additional authentication.';
      case 'biometric':
        return 'Disabling biometric authentication means you will need to enter your PIN every time. This is less convenient but still secure.';
      case 'biometric_face':
        return 'Disabling Face Unlock means you will unlock with your PIN (or fingerprint, if enabled) instead.';
      default:
        return 'Are you sure you want to disable this security feature?';
    }
  }

  // ============ PROFESSIONAL BIOMETRIC ENABLE/DISABLE ============

  Future<void> _testAndEnableBiometric({String prefKey = 'biometric'}) async {
    if (!_biometricAvailable ||
        (prefKey == 'biometric_face' && !_faceAvailable)) {
      _showBiometricNotAvailableSheet();
      return;
    }

    final isFace = prefKey == 'biometric_face';

    // Show professional bottom sheet
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildBiometricEnableSheet(),
    );

    if (confirmed != true || !mounted) return;

    // Let the sheet's dismiss animation fully clear before raising the OS
    // biometric prompt — calling it mid-route-transition makes Android cancel
    // the prompt immediately, which looks like "it keeps failing".
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;

    final reason = isFace
        ? 'Authenticate to enable Face Unlock'
        : 'Authenticate to enable biometric security';

    bool didAuthenticate = false;
    try {
      didAuthenticate = await _authenticateOnce(reason);
    } on LocalAuthException catch (e) {
      if (!mounted) return;
      if (_isTransientAuthCode(e.code)) {
        // Sensor / UI momentarily unavailable — one quick warm-up retry.
        await Future<void>.delayed(const Duration(milliseconds: 700));
        if (!mounted) return;
        try {
          didAuthenticate = await _authenticateOnce(reason);
        } catch (_) {
          if (mounted) {
            _showErrorBottomSheet(_authErrorTitle(null), _authErrorBody(null));
          }
          return;
        }
      } else {
        _showErrorBottomSheet(_authErrorTitle(e.code), _authErrorBody(e.code));
        return;
      }
    } catch (e) {
      if (mounted) {
        _showErrorBottomSheet(_authErrorTitle(null), _authErrorBody(null));
      }
      return;
    }

    if (!mounted) return;
    if (didAuthenticate) {
      await _handleBiometricEnabled(prefKey: prefKey);
    } else {
      _showVerificationFailedSheet(prefKey: prefKey);
    }
  }

  Future<bool> _authenticateOnce(String reason) async {
    // OS biometric prompt round-trips through the background — flag it trusted
    // so resume doesn't auto-lock on top of it.
    SessionManager.instance.beginTrustedInteraction();
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        sensitiveTransaction: true,
        persistAcrossBackgrounding: true,
      );
    } finally {
      SessionManager.instance.endTrustedInteraction();
    }
  }

  bool _isTransientAuthCode(LocalAuthExceptionCode code) =>
      code == LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable ||
      code == LocalAuthExceptionCode.uiUnavailable ||
      code == LocalAuthExceptionCode.systemCanceled ||
      code == LocalAuthExceptionCode.authInProgress ||
      code == LocalAuthExceptionCode.timeout ||
      code == LocalAuthExceptionCode.deviceError ||
      code == LocalAuthExceptionCode.unknownError;

  String _authErrorTitle(LocalAuthExceptionCode? code) {
    switch (code) {
      case LocalAuthExceptionCode.noBiometricsEnrolled:
        return 'No biometric enrolled';
      case LocalAuthExceptionCode.noBiometricHardware:
        return 'Not supported';
      case LocalAuthExceptionCode.noCredentialsSet:
        return 'Screen lock required';
      case LocalAuthExceptionCode.temporaryLockout:
      case LocalAuthExceptionCode.biometricLockout:
        return 'Biometrics locked';
      case LocalAuthExceptionCode.userCanceled:
      case LocalAuthExceptionCode.userRequestedFallback:
        return 'Cancelled';
      default:
        return 'Couldn\'t verify';
    }
  }

  String _authErrorBody(LocalAuthExceptionCode? code) {
    switch (code) {
      case LocalAuthExceptionCode.noBiometricsEnrolled:
        return 'Enroll a fingerprint or face in your device settings, then try again.';
      case LocalAuthExceptionCode.noBiometricHardware:
        return 'This device doesn\'t have biometric hardware.';
      case LocalAuthExceptionCode.noCredentialsSet:
        return 'Set a screen lock (PIN, pattern or password) in your device settings to use biometrics.';
      case LocalAuthExceptionCode.temporaryLockout:
        return 'Too many attempts. Wait a moment, then try again.';
      case LocalAuthExceptionCode.biometricLockout:
        return 'Unlock your device with your screen lock first, then try again.';
      case LocalAuthExceptionCode.userCanceled:
      case LocalAuthExceptionCode.userRequestedFallback:
        return 'You cancelled the verification. Tap the toggle again to retry.';
      default:
        return 'Biometric verification isn\'t available right now. Please try again.';
    }
  }

  // ============ BIOMETRIC ENABLE BOTTOM SHEET ============
  Widget _buildBiometricEnableSheet() {
    return Container(
      decoration: BoxDecoration(
        color: LiquidColors.surface,
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
                color: LiquidColors.textPrimary.withValues(alpha: 0.2),
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
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: LiquidColors.textPrimary,
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
                color: LiquidColors.textSecondary,
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
                Expanded(
                  child: _securityBadge(
                    Icons.shield_rounded,
                    'Bank-grade',
                    'Security',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _securityBadge(
                    Icons.bolt_rounded,
                    'Instant',
                    'Unlock',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _securityBadge(
                    Icons.lock_rounded,
                    'Encrypted',
                    'Storage',
                  ),
                ),
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
                  foregroundColor: LiquidColors.textPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                  shadowColor: LiquidColors.accentPurple.withValues(alpha: 0.4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_getBiometricIcon(), size: 22, color: Colors.white),
                    const SizedBox(width: 10),
                    const Text(
                      'Enable Now',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: Colors.white,
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
                color: LiquidColors.textTertiary,
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
        color: LiquidColors.textPrimary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: LiquidColors.textPrimary.withValues(alpha: 0.06),
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
            style: TextStyle(
              color: LiquidColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: LiquidColors.textTertiary,
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
        decoration: BoxDecoration(
          color: LiquidColors.surface,
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
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: LiquidColors.textPrimary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: LiquidColors.warning.withValues(alpha: 0.15),
                border: Border.all(
                  color: LiquidColors.warning.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.fingerprint_rounded,
                color: LiquidColors.warning,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Biometric Not Available',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: LiquidColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Your device does not support biometric authentication or it has not been set up.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: LiquidColors.textSecondary,
                  height: 1.5,
                ),
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'OK',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: LiquidColors.textPrimary,
                    ),
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

  // ============ VERIFICATION FAILED SHEET ============
  void _showVerificationFailedSheet({String prefKey = 'biometric'}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: LiquidColors.surface,
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
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: LiquidColors.textPrimary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: LiquidColors.error.withValues(alpha: 0.15),
                border: Border.all(
                  color: LiquidColors.error.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.close_rounded,
                color: LiquidColors.error,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Verification Failed',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: LiquidColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'We couldn\'t verify your identity. Please try again.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: LiquidColors.textSecondary,
                  height: 1.5,
                ),
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
                        side: BorderSide(color: LiquidColors.textTertiary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: LiquidColors.textSecondary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _testAndEnableBiometric(prefKey: prefKey);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: LiquidColors.accentPurple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'Try Again',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: LiquidColors.textPrimary,
                        ),
                      ),
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
        decoration: BoxDecoration(
          color: LiquidColors.surface,
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
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: LiquidColors.textPrimary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: LiquidColors.error.withValues(alpha: 0.15),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                color: LiquidColors.error,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: LiquidColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: LiquidColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LiquidColors.accentBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'OK',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: LiquidColors.textPrimary,
                    ),
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

  // ============ HANDLE SUCCESS ============
  Future<void> _handleBiometricEnabled({String prefKey = 'biometric'}) async {
    await _saveSetting(prefKey, true);
    if (!mounted) return;

    setState(() {
      if (prefKey == 'biometric_face') {
        _faceUnlockEnabled = true;
      } else {
        _biometricEnabled = true;
      }
    });

    // Auto-enable app lock if not already enabled
    if (!_appLockEnabled) {
      await _saveSetting('appLock', true);
      if (mounted) setState(() => _appLockEnabled = true);
    }

    // Show success sheet
    if (!mounted) return;
    _showBiometricEnabledSuccessSheet(isFace: prefKey == 'biometric_face');
  }

  // ============ SUCCESS SHEET ============
  void _showBiometricEnabledSuccessSheet({bool isFace = false}) {
    final label = isFace ? 'Face Unlock' : _getBiometricTypeName();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: LiquidColors.surface,
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
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: LiquidColors.textPrimary.withValues(alpha: 0.2),
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
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [LiquidColors.success, LiquidColors.accentBlue],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: LiquidColors.success.withValues(alpha: 0.4),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              '$label Enabled!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: LiquidColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                isFace
                    ? 'You can now use your face to unlock the app.'
                    : 'You can now use your ${label.toLowerCase()} to unlock the app.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: LiquidColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LiquidColors.success,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                    shadowColor: LiquidColors.success.withValues(alpha: 0.4),
                  ),
                  child: Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
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
          FlushBarHelper.flushBarWarningMessage(
            'Camera permission required for break-in detection',
            context,
          );
        }
        return;
      }
    }
    await IntrusionService.instance.setEnabled(value);
    if (!mounted) return;
    setState(() => _intrusionEnabled = value);
    FlushBarHelper.flushBarSuccessMessage(
      value ? 'Break-in detection enabled' : 'Break-in detection disabled',
      context,
    );
  }

  Future<void> _toggleOfflineIntegrityLock(bool value) async {
    HapticFeedback.lightImpact();
    if (value) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: LiquidColors.backgroundLight,
          title: Text(
            'Enable Offline Integrity Lock?',
            style: TextStyle(color: LiquidColors.textPrimary),
          ),
          content: Text(
            'While this is on, the vault stays sealed whenever the device is '
            'online. The moment Wi-Fi or mobile data connects, the encryption '
            'session is revoked and the app locks.\n\n'
            'You will only be able to unlock the vault in Airplane Mode — with '
            'Wi-Fi and mobile data fully off.',
            style: TextStyle(color: LiquidColors.textSecondary, height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: TextStyle(color: LiquidColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Enable',
                style: TextStyle(color: LiquidColors.accentBlue),
              ),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await NetworkGuard.instance.setEnabled(value);
    if (!mounted) return;
    setState(() => _offlineIntegrityLock = value);
    FlushBarHelper.flushBarSuccessMessage(
      value
          ? 'Offline Integrity Lock enabled'
          : 'Offline Integrity Lock disabled',
      context,
    );
  }

  Widget _buildIntegrityLockCard() {
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
          color: LiquidColors.accentBlue.withValues(alpha: 0.25),
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
                child: Center(
                  child: Icon(
                    Icons.cloud_off_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'OFFLINE INTEGRITY LOCK',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: LiquidColors.textPrimary,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              Switch(
                value: _offlineIntegrityLock,
                onChanged: _toggleOfflineIntegrityLock,
                activeThumbColor: Colors.white,
                activeTrackColor: LiquidColors.accentBlue,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Keeps the vault sealed whenever the device is online. The instant '
            'Wi-Fi or mobile data connects, the encryption session is revoked '
            'and the app locks — so decrypted files are never exposed to a '
            'network.',
            style: TextStyle(
              fontSize: 12,
              color: LiquidColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'While this is on, the vault only opens in Airplane Mode.',
            style: TextStyle(
              fontSize: 11,
              color: LiquidColors.textTertiary,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 14),
          ValueListenableBuilder<bool>(
            valueListenable: NetworkGuard.instance.online,
            builder: (context, online, _) {
              final color = online
                  ? LiquidColors.warning
                  : LiquidColors.success;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    Icon(
                      online ? Icons.public_rounded : Icons.public_off_rounded,
                      size: 16,
                      color: color,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        online
                            ? 'Network detected — vault would be sealed'
                            : 'Offline — vault can be unlocked',
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _toggleDeleteOriginals(bool value) async {
    HapticFeedback.lightImpact();
    if (value && Platform.isIOS) {
      final status = await Permission.photos.request();
      if (!status.isGranted) {
        if (mounted) {
          FlushBarHelper.flushBarWarningMessage(
            'Photos permission required to remove originals from gallery',
            context,
          );
        }
        return;
      }
    }
    await ImportSettings.instance.setDeleteOriginalsEnabled(value);
    if (!mounted) return;
    setState(() => _deleteOriginals = value);
    FlushBarHelper.flushBarSuccessMessage(
      value
          ? 'Originals will be removed after each import'
          : 'Originals will stay on your device',
      context,
    );
  }

  Future<void> _openIntrusionLog() async {
    HapticFeedback.lightImpact();
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const IntrusionLogScreen()));
    if (mounted) {
      _loadSecuritySettings();
    }
  }

  /// Scrolls the in-flow PIN UI into view after the next frame, so the user
  /// always sees the verification keypad / length picker the moment it appears.
  void _ensurePinFlowVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _pinFlowKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          alignment: 0.1,
        );
      }
    });
  }

  /// Plain change-PIN flow: verify the current PIN, then set a new PIN of the
  /// SAME length. Used by the "Change PIN" button.
  void _startPinChange() {
    setState(() {
      _changingPin = true;
      _verifyingOldPin = true;
      _choosingLength = false;
      _lengthSelectionFlow = false;
      _confirmPinMode = false;
      _newPinLength = _pinLength;
      _oldPin.clear();
      _newPin.clear();
      _confirmPin.clear();
      _pinError = null;
    });
    _ensurePinFlowVisible();
  }

  /// Change-PIN-length flow: verify the current PIN first, then show the
  /// length picker, then set a new PIN of the chosen length. The recorded
  /// length is only persisted once the new PIN is saved, so cancelling at any
  /// point leaves the existing PIN (and its length) untouched.
  void _startPinLengthChange() {
    setState(() {
      _changingPin = true;
      _verifyingOldPin = true;
      _choosingLength = false;
      _lengthSelectionFlow = true;
      _confirmPinMode = false;
      _newPinLength = _pinLength;
      _oldPin.clear();
      _newPin.clear();
      _confirmPin.clear();
      _pinError = null;
    });
    _ensurePinFlowVisible();
  }

  /// Picks the new PIN length, then advances to new-PIN entry.
  void _selectNewPinLength(int digits) {
    HapticFeedback.selectionClick();
    setState(() {
      _newPinLength = digits;
      _choosingLength = false;
      _newPin.clear();
      _confirmPin.clear();
      _pinError = null;
    });
    _ensurePinFlowVisible();
  }

  void _onPinNumberPressed(String number) {
    HapticFeedback.lightImpact();
    setState(() {
      _pinError = null;
      if (_verifyingOldPin) {
        // Old PIN is verified at the CURRENT length.
        if (_oldPin.length < _pinLength) _oldPin.add(number);
        if (_oldPin.length == _pinLength) _validateOldPin();
      } else if (!_confirmPinMode) {
        // New + confirm use the TARGET length.
        if (_newPin.length < _newPinLength) _newPin.add(number);
        if (_newPin.length == _newPinLength) _validateFirstPin();
      } else {
        if (_confirmPin.length < _newPinLength) _confirmPin.add(number);
        if (_confirmPin.length == _newPinLength) _validateAndSavePin();
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
      // In a length-change flow the next step is picking the new length;
      // otherwise go straight to entering the new (same-length) PIN.
      _choosingLength = _lengthSelectionFlow;
    });
    _ensurePinFlowVisible();
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

      final lengthChanged = _pinLength != _newPinLength;
      if (mounted) {
        setState(() {
          _changingPin = false;
          _verifyingOldPin = false;
          _confirmPinMode = false;
          _choosingLength = false;
          _lengthSelectionFlow = false;
          // setPin() persisted the new length; reflect it in the live UI so the
          // PIN-length selector and any rebuilds show the new value.
          _pinLength = _newPinLength;
          _oldPin.clear();
          _newPin.clear();
          _confirmPin.clear();
        });
      }
      if (!mounted) return;
      FlushBarHelper.flushBarSuccessMessage(
        lengthChanged
            ? 'PIN updated to $_newPinLength digits'
            : 'PIN changed successfully',
        context,
      );

      if (!_appLockEnabled) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await _saveSetting('appLock', true);
          if (mounted) setState(() => _appLockEnabled = true);
          if (!mounted) return;
          FlushBarHelper.flushBarInfoMessage(
            'App lock auto-enabled for security',
            context,
          );
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
      _choosingLength = false;
      _lengthSelectionFlow = false;
      // Drop the pending target length — nothing was persisted, so the current
      // PIN (and its length) is untouched.
      _newPinLength = _pinLength;
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
          Icon(
            Icons.info_outline_rounded,
            color: LiquidColors.warning,
            size: 14,
          ),
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

  Widget _buildFaceStatus() {
    final bothEnrolled = _faceAvailable && _fingerprintAvailable;
    return Row(
      children: [
        Icon(
          bothEnrolled
              ? Icons.info_outline_rounded
              : Icons.check_circle_rounded,
          color: bothEnrolled ? LiquidColors.warning : LiquidColors.success,
          size: 14,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            bothEnrolled
                ? 'Uses your device unlock; fingerprint may still be offered by the system'
                : 'Face recognition available on this device',
            style: TextStyle(
              fontSize: 11,
              color: bothEnrolled ? LiquidColors.warning : LiquidColors.success,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: const LiquidBottomNav(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [LiquidColors.backgroundDeep, LiquidColors.backgroundMid],
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      gradient: LiquidColors.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: LiquidColors.primaryStart.withValues(
                            alpha: .4,
                          ),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.security_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Security',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: LiquidColors.textPrimary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'Keep your vault locked down',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: LiquidColors.textTertiary,
                          ),
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
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: LiquidColors.textPrimary,
                ),
              ),
            ),
          const SizedBox(width: 4),
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
                padding: EdgeInsets.fromLTRB(
                  context.contentInset(phone: 16),
                  16,
                  context.contentInset(phone: 16),
                  16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    _buildSecurityHeroCard(),
                    const SizedBox(height: 16),
                    _sectionHeader(
                      label: 'LOCKS',
                      icon: Icons.lock_rounded,
                      color: LiquidColors.accentBlue,
                      caption: 'Choose how the app unlocks.',
                    ),
                    const SizedBox(height: 12),
                    // App Lock is the master "show the lock screen" switch —
                    // always visible, whichever unlock method is in use.
                    LiquidSecurityCard(
                      icon: Icons.lock_outline_rounded,
                      title: 'App Lock',
                      subtitle: 'Require authentication to open the app',
                      value: _appLockEnabled,
                      gradient: [
                        LiquidColors.accentBlue,
                        LiquidColors.primaryMid,
                      ],
                      index: 0,
                      onChanged: (value) => _toggleSetting('appLock', value),
                    ),
                    const SizedBox(height: 14),
                    LiquidSecurityCard(
                      icon: Icons.video_settings_outlined,
                      title: 'Video Lock',
                      subtitle: 'Lock individual videos with authentication',
                      value: _videoLockEnabled,
                      gradient: [LiquidColors.success, LiquidColors.accentBlue],
                      index: 1,
                      onChanged: (value) => _toggleSetting('videoLock', value),
                    ),
                    // Fingerprint / generic biometric. Hidden on devices whose
                    // only biometric is face recognition — those get the
                    // dedicated Face Unlock card below instead.
                    if (!(_faceAvailable && !_fingerprintAvailable)) ...[
                      const SizedBox(height: 14),
                      LiquidSecurityCard(
                        icon: _fingerprintAvailable
                            ? Icons.fingerprint_rounded
                            : _getBiometricIcon(),
                        title: _fingerprintAvailable
                            ? 'Fingerprint Unlock'
                            : 'Biometric Authentication',
                        subtitle: _fingerprintAvailable
                            ? 'Use your fingerprint to unlock the app'
                            : 'Use ${_getBiometricTypeName().toLowerCase()} for authentication',
                        value: _biometricEnabled,
                        gradient: [
                          LiquidColors.accentPurple,
                          LiquidColors.accentPink,
                        ],
                        index: 2,
                        onChanged: (value) =>
                            _toggleSetting('biometric', value),
                        statusWidget: _buildBiometricStatus(),
                      ),
                    ],
                    if (_faceAvailable) ...[
                      const SizedBox(height: 14),
                      LiquidSecurityCard(
                        icon: Icons.face_retouching_natural,
                        title: 'Face Unlock',
                        subtitle: 'Use your face to unlock the app',
                        value: _faceUnlockEnabled,
                        gradient: [
                          LiquidColors.accentPink,
                          LiquidColors.accentPurple,
                        ],
                        index: 3,
                        onChanged: (value) =>
                            _toggleSetting('biometric_face', value),
                        statusWidget: _buildFaceStatus(),
                      ),
                    ],
                    const SizedBox(height: 28),

                    _sectionHeader(
                      label: 'IDENTITY & PIN',
                      icon: Icons.fingerprint_rounded,
                      color: LiquidColors.accentPurple,
                      caption: 'Enroll your face and manage your PIN.',
                    ),
                    const SizedBox(height: 12),
                    _buildFaceRecognitionCard(),
                    const SizedBox(height: 14),
                    LiquidPinSection(
                      isChanging: _changingPin,
                      onStartChange: _startPinChange,
                    ),
                    const SizedBox(height: 14),
                    // PIN-length control sits right next to "Change PIN" so its
                    // verify → pick-length → new-PIN flow appears directly below.
                    _buildPinLengthControl(),
                    if (_changingPin) ...[
                      const SizedBox(height: 14),
                      KeyedSubtree(
                        key: _pinFlowKey,
                        child: _choosingLength
                            ? _buildPinLengthSelector()
                            : LiquidPinInput(
                                verifyOldMode: _verifyingOldPin,
                                confirmMode: _confirmPinMode,
                                oldPin: _oldPin,
                                newPin: _newPin,
                                confirmPin: _confirmPin,
                                // Old-PIN stage uses the current length; the
                                // new/confirm stages use the target length.
                                totalLength: _verifyingOldPin
                                    ? _pinLength
                                    : _newPinLength,
                                error: _pinError,
                                onNumberPressed: _onPinNumberPressed,
                                onDelete: _onPinDelete,
                                onCancel: _cancelPinChange,
                              ),
                      ),
                    ],
                    const SizedBox(height: 28),

                    _sectionHeader(
                      label: 'SESSION & RECOVERY',
                      icon: Icons.timer_outlined,
                      color: LiquidColors.success,
                      caption: 'Auto-lock timing and add Email',
                    ),
                    const SizedBox(height: 12),
                    _buildSessionCard(),
                    const SizedBox(height: 14),
                    _buildRecoveryCard(),
                    const SizedBox(height: 28),

                    _sectionHeader(
                      label: 'PRIVACY & DEFENCE',
                      icon: Icons.shield_rounded,
                      color: LiquidColors.warning,
                      caption: 'Decoy mode and break-in alerts.',
                    ),
                    const SizedBox(height: 12),
                    _buildDecoyCard(),
                    const SizedBox(height: 14),
                    _buildIntrusionCard(),
                    const SizedBox(height: 14),
                    _buildIntegrityLockCard(),
                    const SizedBox(height: 28),

                    _sectionHeader(
                      label: 'IMPORT & DISGUISE',
                      icon: Icons.tune_rounded,
                      color: LiquidColors.accentBlue,
                      caption: 'Originals handling and home-screen disguise.',
                    ),
                    const SizedBox(height: 12),
                    _buildImportCard(),
                    const SizedBox(height: 14),
                    _buildDisguiseCard(),
                    const SizedBox(height: 28),

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
      FlushBarHelper.flushBarWarningMessage(
        'Disguise mode is Android-only for now',
        context,
      );
      return;
    }

    HapticFeedback.lightImpact();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: LiquidColors.backgroundLight,
        title: Text(
          'Switch to ${option.label}?',
          style: TextStyle(color: LiquidColors.textPrimary),
        ),
        content: Text(
          'Your home screen icon will change to "${option.label}". Some launchers may take a moment to update. The package name and Settings → Apps entry stay the same.',
          style: TextStyle(color: LiquidColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: LiquidColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Switch',
              style: TextStyle(color: LiquidColors.accentBlue),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final success = await DisguiseService.instance.set(option.key);
    if (!mounted) return;
    if (success) {
      setState(() => _currentDisguise = option.key);
      FlushBarHelper.flushBarSuccessMessage(
        'Icon switched to ${option.label}',
        context,
      );
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
                child: Center(
                  child: Icon(
                    Icons.face_retouching_natural,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'DISGUISE',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: LiquidColors.textPrimary,
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
              color: LiquidColors.textSecondary,
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
                  Icon(
                    Icons.info_outline_rounded,
                    color: LiquidColors.warning,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'A determined snooper can still find SecuroBox in Settings → Apps. This is a deterrent, not perfect hiding.',
                      style: TextStyle(
                        fontSize: 11,
                        color: LiquidColors.textSecondary,
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
                : LiquidColors.textPrimary.withValues(alpha: 0.06),
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
                      child: Icon(
                        Icons.image_not_supported_rounded,
                        color: LiquidColors.textTertiary,
                      ),
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
                color: selected
                    ? LiquidColors.textPrimary
                    : LiquidColors.textSecondary,
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
                child: Center(
                  child: Icon(
                    Icons.move_to_inbox_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'IMPORT',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: LiquidColors.textPrimary,
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
              color: LiquidColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'When enabled, files you import are removed from your device after they are encrypted into the vault.',
            style: TextStyle(
              fontSize: 12,
              color: LiquidColors.textSecondary,
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
                Icon(
                  Icons.info_outline_rounded,
                  color: LiquidColors.warning,
                  size: 14,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    Platform.isIOS
                        ? 'On iOS, photos and videos can only be removed via the system confirmation dialog after each import.'
                        : 'Some files (especially on Android 13+) may need to be removed manually because of OS storage rules.',
                    style: TextStyle(
                      fontSize: 11,
                      color: LiquidColors.textSecondary,
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

  Widget _buildDecoyCard() {
    final accent = _decoyEnabled
        ? LiquidColors.accentPurple
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
        border: Border.all(color: accent.withValues(alpha: 0.25), width: 1),
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
                    colors: _decoyEnabled
                        ? [LiquidColors.accentPurple, LiquidColors.accentPink]
                        : [LiquidColors.accentBlue, LiquidColors.accentPurple],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    Icons.theater_comedy_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'DECOY MODE',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: LiquidColors.textPrimary,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accent.withValues(alpha: 0.4)),
                ),
                child: Text(
                  _decoyEnabled ? 'ON' : 'OFF',
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
            _decoyEnabled
                ? 'A second, fully separate vault opens when you enter the decoy PIN at the lock screen. Your real files use a different key and stay hidden.'
                : 'Set a decoy PIN that opens a harmless-looking fake vault. Hand it over under pressure — your real encrypted vault never appears and stays cryptographically isolated.',
            style: TextStyle(
              fontSize: 12,
              color: LiquidColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _openDecoySetup,
              icon: Icon(
                _decoyEnabled
                    ? Icons.tune_rounded
                    : Icons.add_moderator_outlined,
                size: 18,
                color: Colors.white,
              ),
              label: Text(
                _decoyEnabled ? 'Manage decoy mode' : 'Set up decoy PIN',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: LiquidColors.textPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
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
                Icon(
                  Icons.info_outline_rounded,
                  color: LiquidColors.warning,
                  size: 14,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'The decoy PIN must differ from your real PIN. Opening the decoy vault silently captures a break-in photo and is logged.',
                    style: TextStyle(
                      fontSize: 11,
                      color: LiquidColors.textSecondary,
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

  Future<void> _openFaceEnroll() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const FaceScanScreen(mode: FaceScanMode.enroll),
      ),
    );
    if (!mounted) return;
    if (ok == true) {
      if (!_appLockEnabled) {
        await _saveSetting('appLock', true);
        if (mounted) setState(() => _appLockEnabled = true);
      }
      await _loadSecuritySettings();
      if (!mounted) return;
      FlushBarHelper.flushBarSuccessMessage('Face Unlock set up', context);
    }
  }

  Future<void> _disableFaceRecognition() async {
    HapticFeedback.lightImpact();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: LiquidColors.backgroundLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Turn off In-App Face Unlock?',
          style: TextStyle(
            color: LiquidColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          _biometricAvailable
              ? 'Your enrolled face data will be deleted from this device. '
                    'Verify with your ${_getBiometricTypeName().toLowerCase()} '
                    'or app PIN to turn it off.'
              : 'Your enrolled face data will be deleted from this device. '
                    'Enter your app PIN to turn it off.',
          style: TextStyle(color: LiquidColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: LiquidColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: LiquidColors.error,
              foregroundColor: LiquidColors.textPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Verify & turn off',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    // Identity gate — biometric first, app PIN as fallback. EITHER one is
    // enough, so Face Unlock can always be turned off even when biometrics
    // are unavailable, cancelled or fail.
    bool verified = false;
    if (_biometricAvailable) {
      SessionManager.instance.beginTrustedInteraction();
      try {
        verified = await _localAuth.authenticate(
          localizedReason: 'Verify your identity to turn off Face Unlock',
          biometricOnly: true,
          sensitiveTransaction: true,
          persistAcrossBackgrounding: true,
        );
      } on LocalAuthException {
        // Sensor unavailable / cancelled / lockout — fall through to PIN.
      } catch (_) {
        // Defensive: any other failure → PIN fallback.
      } finally {
        SessionManager.instance.endTrustedInteraction();
      }
    }
    if (!mounted) return;

    if (!verified) {
      verified = await PinUnlockDialog.show(
        context,
        title: 'Confirm with PIN',
        subtitle: 'Enter your app PIN to turn off In-App Face Unlock',
      );
      if (!mounted) return;
    }

    if (!verified) {
      FlushBarHelper.flushBarErrorMessage(
        'Verification failed — Face Unlock stays on.',
        context,
      );
      return;
    }

    await FaceRecognitionService.instance.clearEnrollment();
    await _loadSecuritySettings();
    if (!mounted) return;
    FlushBarHelper.flushBarSuccessMessage('Face Unlock turned off', context);
  }

  Widget _buildFaceRecognitionCard() {
    final enrolled = _faceRecogEnrolled;
    final accent = enrolled ? LiquidColors.success : LiquidColors.accentBlue;
    final iconGradient = enrolled
        ? [LiquidColors.success, LiquidColors.accentBlue]
        : [LiquidColors.accentBlue, LiquidColors.accentPurple];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            LiquidColors.backgroundLight.withValues(alpha: .9),
            LiquidColors.backgroundMid.withValues(alpha: .95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.28), width: 1),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.12),
            blurRadius: 24,
            spreadRadius: -6,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: iconGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: iconGradient.first.withValues(alpha: 0.4),
                      blurRadius: 14,
                      spreadRadius: -2,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.face_retouching_natural,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'In-App Face Unlock',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: LiquidColors.textPrimary,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Front-camera unlock · on-device',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: LiquidColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              _faceStatusPill(enrolled, accent),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            enrolled
                ? 'Tap "Scan Face" on the lock screen to unlock with your front camera. Your PIN still works any time.'
                : 'Unlock with your front camera instead of typing your PIN. Face matching runs entirely on this device.',
            style: TextStyle(
              fontSize: 12.5,
              color: LiquidColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _faceFeatureChip(Icons.memory_rounded, 'On-device AI'),
              const SizedBox(width: 8),
              _faceFeatureChip(Icons.cloud_off_rounded, 'Never uploaded'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: enrolled
                ? OutlinedButton.icon(
                    onPressed: _disableFaceRecognition,
                    icon: const Icon(Icons.lock_reset_rounded, size: 18),
                    label: const Text('Turn off Face Unlock'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: LiquidColors.error,
                      side: BorderSide(
                        color: LiquidColors.error.withValues(alpha: 0.5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  )
                : _faceSetupButton(),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: LiquidColors.warning.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: LiquidColors.warning.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: LiquidColors.warning,
                  size: 14,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Face Unlock is a convenience shortcut — weaker than your '
                    'PIN and can be fooled by a photo or look-alike. Your PIN '
                    'always works as a fallback.',
                    style: TextStyle(
                      fontSize: 11,
                      color: LiquidColors.textSecondary,
                      height: 1.45,
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

  /// Status pill for the Face Unlock card — a coloured dot plus a state label.
  Widget _faceStatusPill(bool enrolled, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
          ),
          const SizedBox(width: 6),
          Text(
            enrolled ? 'Active' : 'Not set up',
            style: TextStyle(
              color: accent,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  /// Small capability chip shown on the Face Unlock card.
  Widget _faceFeatureChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: LiquidColors.textPrimary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: LiquidColors.textPrimary.withValues(alpha: 0.07),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: LiquidColors.accentBlue),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: LiquidColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// Gradient call-to-action used when Face Unlock is not yet enrolled.
  Widget _faceSetupButton() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [LiquidColors.accentBlue, LiquidColors.accentPurple],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: LiquidColors.accentBlue.withValues(alpha: 0.35),
            blurRadius: 14,
            spreadRadius: -3,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _openFaceEnroll,
          borderRadius: BorderRadius.circular(14),
          child: const Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.face_retouching_natural,
                  size: 19,
                  color: Colors.white,
                ),
                SizedBox(width: 10),
                Text(
                  'Set up Face Unlock',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
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
                child: Center(
                  child: Icon(
                    Icons.camera_front_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'BREAK-IN DETECTION',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: LiquidColors.textPrimary,
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
              color: LiquidColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Note: iOS shows a green status-bar indicator while the camera is active.',
            style: TextStyle(
              fontSize: 11,
              color: LiquidColors.textTertiary,
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
                      child: Icon(
                        Icons.history_rounded,
                        color: LiquidColors.warning,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Intrusion Log',
                        style: TextStyle(
                          color: LiquidColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _intrusionCount > 0
                            ? LiquidColors.error.withValues(alpha: 0.2)
                            : LiquidColors.textTertiary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$_intrusionCount',
                        style: TextStyle(
                          color: _intrusionCount > 0
                              ? LiquidColors.error
                              : LiquidColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: LiquidColors.textTertiary,
                      size: 20,
                    ),
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

    // Re-issuing replaces the stored hash + email, so require the previously-
    // saved email first — otherwise anyone with momentary access to an unlocked
    // app could quietly rotate the recovery target.
    if (wasEnabled) {
      final verified = await _verifyRecoveryEmail();
      if (!verified || !mounted) return;
    }

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RecoverySetupScreen(
          lockedEmail: wasEnabled ? _recoveryEmail : null,
        ),
      ),
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

  Future<bool> _verifyRecoveryEmail() async {
    final storedEmail = (_recoveryEmail ?? '').trim();
    if (storedEmail.isEmpty) return true;

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
                    color: LiquidColors.accentBlue.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.autorenew_rounded,
                    color: LiquidColors.accentBlue,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Verify to re-issue',
                    style: TextStyle(
                      color: LiquidColors.textPrimary,
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
                  'Type the recovery email you used previously to prove it\'s '
                  'you. A new code will only be generated after this matches.',
                  style: TextStyle(
                    color: LiquidColors.textSecondary,
                    height: 1.5,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 6),
                  child: Text(
                    'Hint: ${RecoveryService.mask(storedEmail)}',
                    style: TextStyle(
                      color: LiquidColors.textTertiary,
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
                  cursorColor: LiquidColors.accentBlue,
                  style: TextStyle(
                    color: matches
                        ? LiquidColors.accentBlue
                        : LiquidColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'previous@gmail.com',
                    hintStyle: TextStyle(
                      color: LiquidColors.textTertiary,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: LiquidColors.textPrimary.withValues(alpha: 0.04),
                    prefixIcon: Icon(
                      Icons.alternate_email_rounded,
                      color: matches
                          ? LiquidColors.accentBlue
                          : LiquidColors.textTertiary,
                      size: 18,
                    ),
                    suffixIcon: matches
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: LiquidColors.accentBlue,
                            size: 18,
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: LiquidColors.textPrimary.withValues(alpha: 0.08),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: LiquidColors.textPrimary.withValues(alpha: 0.08),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: LiquidColors.accentBlue,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: LiquidColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: matches
                    ? () => Navigator.of(dialogContext).pop(true)
                    : null,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
                child: Text(
                  'Verify',
                  style: TextStyle(
                    color: matches
                        ? LiquidColors.accentBlue
                        : LiquidColors.textTertiary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (ok != true && mounted) {
      FlushBarHelper.flushBarErrorMessage(
        'Email didn\'t match — re-issue cancelled',
        context,
      );
    }
    return ok == true;
  }

  Future<void> _openDecoySetup() async {
    HapticFeedback.lightImpact();
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const DecoySetupScreen()));
    if (mounted) await _loadSecuritySettings();
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
                Expanded(
                  child: Text(
                    'Remove recovery?',
                    style: TextStyle(
                      color: LiquidColors.textPrimary,
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
                    color: LiquidColors.textSecondary,
                    height: 1.5,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
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
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 14,
                        color: LiquidColors.error,
                      ),
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
                      color: LiquidColors.textTertiary,
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
                    color: matches
                        ? LiquidColors.error
                        : LiquidColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'you@example.com',
                    hintStyle: TextStyle(
                      color: LiquidColors.textTertiary,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: LiquidColors.textPrimary.withValues(alpha: 0.04),
                    prefixIcon: Icon(
                      Icons.alternate_email_rounded,
                      color: matches
                          ? LiquidColors.error
                          : LiquidColors.textTertiary,
                      size: 18,
                    ),
                    suffixIcon: matches
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: LiquidColors.error,
                            size: 18,
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: LiquidColors.textPrimary.withValues(alpha: 0.08),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: LiquidColors.textPrimary.withValues(alpha: 0.08),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: LiquidColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: matches
                    ? () => Navigator.of(dialogContext).pop(true)
                    : null,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
                child: Text(
                  'Remove',
                  style: TextStyle(
                    color: matches
                        ? LiquidColors.error
                        : LiquidColors.textTertiary,
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
        border: Border.all(color: accent.withValues(alpha: 0.25), width: 1),
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
                        : [LiquidColors.accentBlue, LiquidColors.accentPurple],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    Icons.restore_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'ADD EMAIL',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: LiquidColors.textPrimary,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accent.withValues(alpha: 0.4)),
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
              color: LiquidColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          if (_recoveryEnabled) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: LiquidColors.backgroundDeep,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.alternate_email_rounded, color: accent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _recoveryEmail == null
                          ? 'unknown'
                          : RecoveryService.mask(_recoveryEmail!),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: LiquidColors.textPrimary,
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
                    icon: Icon(Icons.refresh_rounded, size: 16, color: accent),
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
                      side: BorderSide(color: accent.withValues(alpha: 0.4)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _confirmRemoveRecovery,
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: LiquidColors.error,
                    ),
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
                icon: const Icon(
                  Icons.add_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                label: const Text(
                  'Set up recovery',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: LiquidColors.accentBlue,
                  foregroundColor: LiquidColors.textPrimary,
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
                child: Center(
                  child: Icon(
                    Icons.timer_outlined,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'SESSION',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: LiquidColors.textPrimary,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Auto-lock when inactive',
            style: TextStyle(
              color: LiquidColors.textSecondary,
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
              style: TextStyle(color: LiquidColors.textPrimary, fontSize: 14),
              underline: const SizedBox(),
              icon: Icon(
                Icons.arrow_drop_down_rounded,
                color: LiquidColors.accentBlue,
              ),
              items: SessionManager.autoLockOptions.entries
                  .map(
                    (e) => DropdownMenuItem<int>(
                      value: e.key,
                      child: Text(e.value),
                    ),
                  )
                  .toList(),
              onChanged: (value) async {
                if (value == null) return;
                HapticFeedback.selectionClick();
                await SessionManager.instance.setAutoLockSeconds(value);
                if (mounted) setState(() {});
              },
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildPinLengthControl() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PIN length',
                style: TextStyle(
                  color: LiquidColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$_pinLength digits',
                style: TextStyle(
                  color: LiquidColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: _changingPin ? null : _onChangePinLengthTapped,
          child: Opacity(
            opacity: _changingPin ? 0.5 : 1.0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              decoration: BoxDecoration(
                color: LiquidColors.accentBlue.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: LiquidColors.accentBlue.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 16,
                    color: LiquidColors.accentBlue,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Change',
                    style: TextStyle(
                      color: LiquidColors.accentBlue,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _onChangePinLengthTapped() async {
    HapticFeedback.selectionClick();
    final hasPin = await PinCrypto.instance.hasPin();
    if (!mounted) return;
    if (!hasPin) {
      FlushBarHelper.flushBarWarningMessage(
        'Set a PIN first, then you can change its length.',
        context,
      );
      _startPinChange();
      return;
    }
    _startPinLengthChange();
  }
  Widget _buildPinLengthSelector() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            LiquidColors.backgroundLight.withValues(alpha: 0.9),
            LiquidColors.backgroundMid.withValues(alpha: 0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: LiquidColors.accentBlue.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: LiquidColors.accentBlue.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'CHOOSE PIN LENGTH',
            style: TextStyle(
              color: LiquidColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pick how many digits your new PIN will have',
            textAlign: TextAlign.center,
            style: TextStyle(color: LiquidColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              for (final len in PinCrypto.supportedPinLengths) ...[
                if (len != PinCrypto.supportedPinLengths.first)
                  const SizedBox(width: 14),
                Expanded(child: _lengthOptionTile(len)),
              ],
            ],
          ),
          const SizedBox(height: 18),
          TextButton(
            onPressed: _cancelPinChange,
            child: Text(
              'Cancel',
              style: TextStyle(
                color: LiquidColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lengthOptionTile(int digits) {
    final isCurrent = digits == _pinLength;
    return GestureDetector(
      onTap: () => _selectNewPinLength(digits),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              LiquidColors.accentBlue.withValues(alpha: 0.14),
              LiquidColors.accentPurple.withValues(alpha: 0.06),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: LiquidColors.accentBlue.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                digits,
                (_) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: LiquidColors.accentBlue,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '$digits digits',
              style: TextStyle(
                color: LiquidColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              isCurrent ? 'Current' : 'Tap to use',
              style: TextStyle(
                color: LiquidColors.textTertiary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityHeroCard() {
    final protections = <_Protection>[
      _Protection(
        'App Lock',
        _appLockEnabled,
        () => _toggleSetting('appLock', true),
      ),
      _Protection(
        'Biometric Unlock',
        _biometricEnabled,
        () => _toggleSetting('biometric', true),
      ),
    
      _Protection(
        'Face Unlock',
        _faceUnlockEnabled || _faceRecogEnrolled,
        _openFaceEnroll,
      ),
      _Protection('PIN Recovery', _recoveryEnabled, _openRecoverySetup),
      _Protection(
        'Intrusion Detection',
        _intrusionEnabled,
        () => _toggleIntrusion(true),
      ),
      _Protection('Decoy Mode', _decoyEnabled, _openDecoySetup),
    ];
    final active = protections.where((p) => p.on).length;
    final total = protections.length;
    final ratio = total == 0 ? 0.0 : active / total;
    final allGood = active == total;
    final isCritical = active == 0;
    final percent = (ratio * 100).round();

    final accent = isCritical
        ? LiquidColors.error
        : allGood
        ? LiquidColors.success
        : LiquidColors.accentBlue;
    final accentSoft = isCritical
        ? LiquidColors.error.withValues(alpha: 0.85)
        : allGood
        ? LiquidColors.success.withValues(alpha: 0.85)
        : LiquidColors.accentPurple;

    final headline = isCritical
        ? 'Your vault is unprotected'
        : allGood
        ? 'You’re fully protected'
        : 'You’re mostly protected';
    final subhead = isCritical
        ? 'Turn on at least one lock below to keep files safe.'
        : allGood
        ? 'Every protection is active. Nice work.'
        : '${total - active} more protection${total - active == 1 ? '' : 's'} available below.';

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            LiquidColors.backgroundLight.withValues(alpha: 0.72),
            LiquidColors.backgroundMid.withValues(alpha: 0.55),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.28), width: 1),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.14),
            blurRadius: 26,
            spreadRadius: -6,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _SecurityScoreRing(
                ratio: ratio,
                percent: percent,
                accent: accent,
                accentSoft: accentSoft,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headline,
                      style: TextStyle(
                        color: LiquidColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subhead,
                      style: TextStyle(
                        color: LiquidColors.textSecondary,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$active of $total active',
                        style: TextStyle(
                          color: accent,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!allGood && !isCritical) ...[
            const SizedBox(height: 16),
            Container(
              height: 1,
              color: LiquidColors.textPrimary.withValues(alpha: 0.05),
            ),
            const SizedBox(height: 14),
            Text(
              'Suggested next steps',
              style: TextStyle(
                color: LiquidColors.textTertiary,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final p in protections.where((p) => !p.on))
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: p.action,
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: LiquidColors.accentBlue.withValues(
                            alpha: 0.10,
                          ),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: LiquidColors.accentBlue.withValues(
                              alpha: 0.30,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_rounded,
                              size: 13,
                              color: LiquidColors.accentBlue,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              p.label,
                              style: TextStyle(
                                color: LiquidColors.accentBlue,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 14,
                              color: LiquidColors.accentBlue.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader({
    required String label,
    required IconData icon,
    required Color color,
    String? caption,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          if (caption != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 22),
              child: Text(
                caption,
                style: TextStyle(
                  color: LiquidColors.textTertiary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Protection {
  final String label;
  final bool on;
  final VoidCallback? action;
  const _Protection(this.label, this.on, [this.action]);
}

class _SecurityScoreRing extends StatelessWidget {
  final double ratio;
  final int percent;
  final Color accent;
  final Color accentSoft;

  const _SecurityScoreRing({
    required this.ratio,
    required this.percent,
    required this.accent,
    required this.accentSoft,
  });

  @override
  Widget build(BuildContext context) {
    const double size = 80;
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: ratio),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Soft accent glow behind the ring.
              Container(
                width: size - 14,
                height: size - 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.22),
                      blurRadius: 18,
                      spreadRadius: -4,
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: 1,
                  strokeWidth: 7,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    LiquidColors.textPrimary.withValues(alpha: 0.07),
                  ),
                ),
              ),
              ShaderMask(
                shaderCallback: (rect) => LinearGradient(
                  colors: [accent, accentSoft],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(rect),
                child: SizedBox(
                  width: size,
                  height: size,
                  child: CircularProgressIndicator(
                    value: value,
                    strokeWidth: 7,
                    strokeCap: StrokeCap.round,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                    backgroundColor: Colors.transparent,
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(value * 100).round()}',
                    style: TextStyle(
                      color: LiquidColors.textPrimary,
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'SCORE',
                    style: TextStyle(
                      color: accent,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
