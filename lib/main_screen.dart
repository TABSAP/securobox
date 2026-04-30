import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_app/upload_screen/upload_screen.dart';
import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/utils/session_manager.dart';
import 'package:video_player_app/utils/vault_crypto.dart';
import 'package:video_player_app/views/screens/home_screen/home_screen.dart';
import 'app_lock_screen/app_lock_screen.dart';
import 'download_screen/download_screen.dart';
import 'security_settings/security_setting.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  final _libraryKey = GlobalKey<HomeScreenState>();

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
  }

  @override
  void dispose() {
    SessionManager.instance.shouldLock.removeListener(_onLockRequested);
    WidgetsBinding.instance.removeObserver(this);
    _inactivityTimer?.cancel();
    super.dispose();
  }

  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      if (!mounted || _isShowingLockScreen) return;
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

  void _onVideoUploaded() {
    setState(() {
      _selectedIndex = 0;
    });
    _libraryKey.currentState?.refreshVideos();
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

    final prefs = await SharedPreferences.getInstance();
    final lockEnabled = prefs.getBool('appLock') ?? false;
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
    final lockEnabled = prefs.getBool('appLock') ?? false;
    if (!lockEnabled) return;

    _isShowingLockScreen = true;
    await VaultCrypto.instance.wipeTempCache();
    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        fullscreenDialog: true,
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, __, ___) => const AppLockScreen(isOverlay: true),
        transitionsBuilder: (_, anim, __, child) =>
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
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onUserActivity,
      onPointerMove: _onUserActivity,
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: const Color(0xFF0A0A1F),
            body: IndexedStack(
              index: _selectedIndex,
              children: [
                HomeScreen(
                  key: _libraryKey,
                  onAddRequested: () => setState(() => _selectedIndex = 1),
                ),
                UploadScreen(onVideoUploaded: _onVideoUploaded),
                const DownloadScreen(),
                const SecuritySettingsScreen(),
              ],
            ),
            bottomNavigationBar: _ProfessionalNavigationBar(
              selectedIndex: _selectedIndex,
              onTabSelected: (index) {
                if (index != _selectedIndex) HapticFeedback.selectionClick();
                SessionManager.instance.markActive();
                setState(() => _selectedIndex = index);
              },
            ),
          ),
          if (_showPrivacyShield) const _PrivacyShield(),
        ],
      ),
    );
  }
}

class _PrivacyShield extends StatelessWidget {
  const _PrivacyShield();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0A0A1F),
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
          child: const Icon(Icons.shield_rounded, color: Colors.white, size: 60),
        ),
      ),
    );
  }
}

class _ProfessionalNavigationBar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  const _ProfessionalNavigationBar({
    required this.selectedIndex,
    required this.onTabSelected,
  });

  @override
  State<_ProfessionalNavigationBar> createState() =>
      _ProfessionalNavigationBarState();
}

class _ProfessionalNavigationBarState extends State<_ProfessionalNavigationBar> {

  static const List<NavigationItem> _navItems = [
    NavigationItem(
      icon: Icons.video_library_outlined,
      activeIcon: Icons.video_library_rounded,
      label: 'Library',
    ),
    NavigationItem(
      icon: Icons.add_circle_outline_rounded,
      activeIcon: Icons.add_circle_rounded,
      label: 'Add',
    ),
    NavigationItem(
      icon: Icons.history_outlined,
      activeIcon: Icons.history_rounded,
      label: 'History',
    ),
    NavigationItem(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings_rounded,
      label: 'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141432).withValues(alpha: .95),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .3),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_navItems.length, (index) {
            final item = _navItems[index];
            final isSelected = widget.selectedIndex == index;

            return _NavigationButton(
              item: item,
              isSelected: isSelected,
              onTap: () => widget.onTabSelected(index),
            );
          }),
        ),
      ),
    );
  }
}

class _NavigationButton extends StatelessWidget {
  final NavigationItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavigationButton({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isSelected
              ? const Color(0xFFFFFFFF).withValues(alpha: .20)
              : Colors.transparent,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return ScaleTransition(
                  scale: animation,
                  child: child,
                );
              },
              child: Icon(
                isSelected ? item.activeIcon : item.icon,
                key: ValueKey(isSelected ? 'active_${item.label}' : item.label),
                color: isSelected
                    ? const Color(0xFFFFFFFF)
                    : Colors.grey.withValues(alpha: .7),
                size: 24,
              ),
            ),
            const SizedBox(height: 4),

            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              transform: Matrix4.identity()
                ..
              scale(isSelected ? 1.0 : 0.9, isSelected ? 1.0 : 0.9),
              child: Text(
                item.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? const Color(0xFFFFFFFF)
                      : Colors.grey.withValues(alpha: .7),
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NavigationItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const NavigationItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
