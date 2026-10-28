import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_app/share_import/share_intake.dart';
import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/utils/session_manager.dart';
import 'package:video_player_app/utils/theme_controller.dart';
import 'package:video_player_app/utils/vault_crypto.dart';
import 'package:video_player_app/widgets/liquid_bottom_nav.dart';
import 'package:video_player_app/views/screens/home_screen/home_dashboard.dart';
import 'app_lock_screen/app_lock_screen.dart';
import 'settings/settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  final _libraryKey = GlobalKey<HomeDashboardState>();
  final _libraryNavigatorKey = GlobalKey<NavigatorState>();
  final _settingsNavigatorKey = GlobalKey<NavigatorState>();

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
    AppNav.tab.value = 0;
    AppNav.onTabSelected = _handleTabSelection;
    AppNav.tab.addListener(_onTabRequested);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ShareIntake.instance.markUnlocked();
    });
  }

  void _onTabRequested() {
    final i = AppNav.tab.value;
    if (_selectedIndex != i) {
      _handleTabSelection(i);
    }
  }

  void _handleTabSelection(int i) {
    if (!mounted || i < 0 || i >= 2) return;
    HapticFeedback.selectionClick();
    SessionManager.instance.markActive();

    if (_libraryNavigatorKey.currentState?.canPop() ?? false) {
      _libraryNavigatorKey.currentState?.popUntil((route) => route.isFirst);
    }
    if (_settingsNavigatorKey.currentState?.canPop() ?? false) {
      _settingsNavigatorKey.currentState?.popUntil((route) => route.isFirst);
    }

    if (_selectedIndex != i) {
      setState(() => _selectedIndex = i);
    }
    AppNav.tab.value = i;

    if (i == 0) {
      _libraryKey.currentState?.resetToTop();
      _libraryKey.currentState?.refresh();
    }
  }

  NavigatorState? _navigatorFor(int index) => index == 0
      ? _libraryNavigatorKey.currentState
      : _settingsNavigatorKey.currentState;

  void _handleSystemBack() {
    final navigator = _navigatorFor(_selectedIndex);
    if (navigator?.canPop() ?? false) {
      navigator!.pop();
    } else if (_selectedIndex != 0) {
      _handleTabSelection(0);
    } else if (Theme.of(context).platform == TargetPlatform.android) {
      SystemNavigator.pop();
    }
  }

  @override
  void dispose() {
    if (AppNav.onTabSelected == _handleTabSelection) {
      AppNav.onTabSelected = null;
    }
    ShareIntake.instance.markLocked();
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
    if (!SessionManager.instance.shouldLock.value ||
        !mounted ||
        _isShowingLockScreen) {
      return;
    }
    SessionManager.instance.shouldLock.value = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showLockScreen();
    });
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

      final backgrounded =
          state == AppLifecycleState.paused ||
          state == AppLifecycleState.hidden;
      if (backgrounded && !SessionManager.instance.inTrustedInteraction) {
        unawaited(VaultCrypto.instance.revokeSession());
      }
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
    final lockEnabled =
        (prefs.getBool('appLock') ?? false) ||
        (prefs.getBool('biometric') ?? false) ||
        (prefs.getBool('biometric_face') ?? false);
    if (!lockEnabled) {
      _wasPaused = false;
      SessionManager.instance.markActive();
      return;
    }

    final autoLock = SessionManager.instance.autoLockSeconds;
    final mustLock =
        autoLock == 0 ||
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
    _isShowingLockScreen = true;

    final prefs = await SharedPreferences.getInstance();
    final lockEnabled =
        (prefs.getBool('appLock') ?? false) ||
        (prefs.getBool('biometric') ?? false) ||
        (prefs.getBool('biometric_face') ?? false);
    if (!lockEnabled) {
      _isShowingLockScreen = false;
      return;
    }

    unawaited(VaultCrypto.instance.revokeSession());
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
    _isShowingLockScreen = false;
    if (mounted) SessionManager.instance.markActive();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onUserActivity,
        onPointerMove: _onUserActivity,
        child: PopScope<Object?>(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _handleSystemBack();
          },
          child: Stack(
            children: [
              Scaffold(
                backgroundColor: LiquidColors.backgroundDeep,
                extendBody: defaultTargetPlatform == TargetPlatform.iOS,
                body: IndexedStack(
                  index: _selectedIndex,
                  children: [
                    TickerMode(
                      enabled: _selectedIndex == 0,
                      child: Navigator(
                        key: _libraryNavigatorKey,
                        onGenerateRoute: (settings) => MaterialPageRoute<void>(
                          settings: settings,
                          builder: (_) => HomeDashboard(key: _libraryKey),
                        ),
                      ),
                    ),
                    TickerMode(
                      enabled: _selectedIndex == 1,
                      child: Navigator(
                        key: _settingsNavigatorKey,
                        onGenerateRoute: (settings) => MaterialPageRoute<void>(
                          settings: settings,
                          builder: (_) => const SettingsScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
                bottomNavigationBar: ValueListenableBuilder<bool>(
                  valueListenable: AppNav.bottomBarVisible,
                  builder: (context, visible, _) => Visibility(
                    visible: visible,
                    maintainState: true,
                    maintainAnimation: true,
                    child: LiquidBottomNav(
                      key: const ValueKey('main-bottom-nav'),
                      selectedIndex: _selectedIndex,
                    ),
                  ),
                ),
              ),
              if (_showPrivacyShield) const _PrivacyShield(),
            ],
          ),
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
          child: Icon(
            Icons.shield_rounded,
            color: LiquidColors.textPrimary,
            size: 60,
          ),
        ),
      ),
    );
  }
}
