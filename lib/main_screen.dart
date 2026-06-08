import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/utils/session_manager.dart';
import 'package:video_player_app/utils/theme_controller.dart';
import 'package:video_player_app/utils/vault_crypto.dart';
import 'package:video_player_app/security_settings/intrusion_log_screen.dart';
import 'package:video_player_app/utils/intrusion_service.dart';
import 'package:video_player_app/widgets/liquid_bottom_nav.dart';
import 'package:video_player_app/views/screens/home_screen/home_screen.dart';
import 'app_lock_screen/app_lock_screen.dart';
import 'settings/settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  final _libraryKey = GlobalKey<HomeScreenState>();
  final _intrusionKey = GlobalKey<IntrusionLogScreenState>();

  bool _wasPaused = false;
  bool _isShowingLockScreen = false;
  bool _showPrivacyShield = false;
  Timer? _inactivityTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SessionManager.instance.shouldLock.addListener(_onLockRequested);
    SessionManager.instance.markActive();
    _startInactivityTimer();
    unawaited(IntrusionService.instance.refreshCount());
    AppNav.tab.value = 0;
    AppNav.tab.addListener(_onTabRequested);
  }

  void _onTabRequested() {
    final i = AppNav.tab.value;
    if (!mounted || i == _selectedIndex) return;
    HapticFeedback.selectionClick();
    SessionManager.instance.markActive();
    setState(() => _selectedIndex = i);
    if (i == 1) _intrusionKey.currentState?.reload();
  }

  @override
  void dispose() {
    SessionManager.instance.shouldLock.removeListener(_onLockRequested);
    AppNav.tab.removeListener(_onTabRequested);
    WidgetsBinding.instance.removeObserver(this);
    _inactivityTimer?.cancel();
    super.dispose();
  }

  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      if (!mounted ||
          _isShowingLockScreen ||
          SessionManager.instance.inTrustedInteraction) {
        return;
      }
      if (await SessionManager.instance.hasInactivityElapsed()) {
        _showLockScreen();
      }
    });
  }

  void _onLockRequested() {
    if (SessionManager.instance.shouldLock.value &&
        mounted &&
        !_isShowingLockScreen) {
      SessionManager.instance.shouldLock.value = false;
      _showLockScreen();
    }
  }

  void _onUserActivity([_]) {
    if (!_isShowingLockScreen) {
      SessionManager.instance.markActive();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      setState(() => _showPrivacyShield = true);
    }

    if (state == AppLifecycleState.paused) {
      _wasPaused = true;
    }

    if (state == AppLifecycleState.resumed) {
      setState(() => _showPrivacyShield = false);
      _onResumed();
    }
  }

  Future<void> _onResumed() async {
    if (_isShowingLockScreen) return;

    if (SessionManager.instance.inTrustedInteraction) {
      _wasPaused = false;
      SessionManager.instance.markActive();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final lockEnabled = (prefs.getBool('appLock') ?? false) ||
        (prefs.getBool('biometric') ?? false) ||
        (prefs.getBool('biometric_face') ?? false);
    if (!lockEnabled) {
      _wasPaused = false;
      SessionManager.instance.markActive();
      return;
    }

    final autoLock = SessionManager.instance.autoLockSeconds;
    final mustLock = autoLock == 0 ||
        _wasPaused ||
        await SessionManager.instance.hasInactivityElapsed();

    _wasPaused = false;

    if (mustLock && mounted) {
      _showLockScreen();
    } else {
      SessionManager.instance.markActive();
    }
  }

  Future<void> _showLockScreen() async {
    if (!mounted || _isShowingLockScreen) return;
    final prefs = await SharedPreferences.getInstance();
    final lockEnabled = (prefs.getBool('appLock') ?? false) ||
        (prefs.getBool('biometric') ?? false) ||
        (prefs.getBool('biometric_face') ?? false);
    if (!lockEnabled) return;

    _isShowingLockScreen = true;
    unawaited(VaultCrypto.instance.wipeTempCache());
    if (!mounted) {
      _isShowingLockScreen = false;
      return;
    }
    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        fullscreenDialog: true,
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, _, _) => const AppLockScreen(isOverlay: true),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
    if (mounted) {
      _isShowingLockScreen = false;
      SessionManager.instance.markActive();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onUserActivity,
        onPointerMove: _onUserActivity,
        child: Stack(
          children: [
            Scaffold(
              backgroundColor: LiquidColors.backgroundDeep,
              body: IndexedStack(
                index: _selectedIndex,
                children: [
                  TickerMode(
                    enabled: _selectedIndex == 0,
                    child: HomeScreen(key: _libraryKey),
                  ),
                  TickerMode(
                    enabled: _selectedIndex == 1,
                    child: IntrusionLogScreen(key: _intrusionKey),
                  ),
                  TickerMode(
                    enabled: _selectedIndex == 2,
                    child: SettingsScreen(),
                  ),
                ],
              ),
              bottomNavigationBar: LiquidBottomNav(
                selectedIndex: _selectedIndex,
              ),
            ),
            if (_showPrivacyShield) const _PrivacyShield(),
          ],
        ),
      ),
    );
  }
}

class _PrivacyShield extends StatelessWidget {
  const _PrivacyShield();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: LiquidColors.backgroundDeep,
      child: Center(
        child: Container(
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
          child: Icon(Icons.shield_rounded, color: LiquidColors.textPrimary, size: 60),
        ),
      ),
    );
  }
}
