import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_app/upload_screen/upload_screen.dart';
import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/utils/session_manager.dart';
import 'package:video_player_app/utils/theme_controller.dart';
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
    // Rebuild the whole shell (and therefore every tab) when the theme mode
    // changes, so screens that read LiquidColors directly pick up new colors.
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
                  HomeScreen(
                    key: _libraryKey,
                    onAddRequested: () => setState(() => _selectedIndex = 1),
                  ),
                  UploadScreen(onVideoUploaded: _onVideoUploaded),
                  DownloadScreen(),
                  SecuritySettingsScreen(),
                ],
              ),
              bottomNavigationBar: _LiquidNavBar(
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

/// Bottom navigation bar with a "liquid" glowing blob that morphs and glides
/// under the active tab — it stretches mid-glide like a droplet, then settles.
class _LiquidNavBar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  const _LiquidNavBar({
    required this.selectedIndex,
    required this.onTabSelected,
  });

  @override
  State<_LiquidNavBar> createState() => _LiquidNavBarState();
}

class _LiquidNavBarState extends State<_LiquidNavBar>
    with SingleTickerProviderStateMixin {
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

  static const double _barHeight = 56;
  static const double _blobW = 58;
  static const double _blobH = 42;

  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
    value: 1,
  );
  late int _prev = widget.selectedIndex;
  late int _curr = widget.selectedIndex;
  int? _pressed;

  @override
  void didUpdateWidget(covariant _LiquidNavBar old) {
    super.didUpdateWidget(old);
    if (old.selectedIndex != widget.selectedIndex) {
      _prev = old.selectedIndex;
      _curr = widget.selectedIndex;
      _slide.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  Widget build(BuildContext context) {
    final accent = LiquidColors.accentBlue;
    return Container(
      decoration: BoxDecoration(
        color: LiquidColors.surface.withValues(alpha: 0.97),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(26),
          topRight: Radius.circular(26),
        ),
        border: Border(top: BorderSide(color: LiquidColors.cardBorder)),
        boxShadow: [
          BoxShadow(
            color: LiquidColors.shadow,
            blurRadius: 22,
            spreadRadius: 1,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: SizedBox(
            height: _barHeight,
            child: LayoutBuilder(
              builder: (context, c) {
                final n = _navItems.length;
                final cell = c.maxWidth / n;
                double leftFor(int i) => i * cell + (cell - _blobW) / 2;

                return AnimatedBuilder(
                  animation: _slide,
                  builder: (context, _) {
                    final t = Curves.easeOutCubic.transform(_slide.value);
                    final blobLeft = _lerp(leftFor(_prev), leftFor(_curr), t);
                    // droplet stretch: peaks at mid-glide, then relaxes
                    final wave = math.sin(_slide.value * math.pi);
                    final bw = _blobW * (1 + wave * 0.5);
                    final bh = _blobH * (1 - wave * 0.18);

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: blobLeft - (bw - _blobW) / 2,
                          top: (_barHeight - bh) / 2,
                          width: bw,
                          height: bh,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(bh / 2),
                              gradient: RadialGradient(
                                colors: [
                                  accent.withValues(alpha: 0.32),
                                  accent.withValues(alpha: 0.10),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.30),
                                  blurRadius: 22,
                                  spreadRadius: -2,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Row(
                          children: List.generate(n, (i) {
                            final double sel;
                            if (i == _curr) {
                              sel = _prev == _curr ? 1.0 : t;
                            } else if (i == _prev) {
                              sel = 1.0 - t;
                            } else {
                              sel = 0.0;
                            }
                            final pressed = _pressed == i;
                            final iconScale =
                                _lerp(0.9, 1.12, sel) * (pressed ? 0.86 : 1.0);
                            final color = Color.lerp(
                              LiquidColors.textTertiary,
                              accent,
                              sel,
                            )!;
                            final item = _navItems[i];
                            return Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapDown: (_) => setState(() => _pressed = i),
                                onTapCancel: () =>
                                    setState(() => _pressed = null),
                                onTapUp: (_) => setState(() => _pressed = null),
                                onTap: () => widget.onTabSelected(i),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Transform.scale(
                                      scale: iconScale,
                                      child: Icon(
                                        sel > 0.5 ? item.activeIcon : item.icon,
                                        color: color,
                                        size: 23,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      item.label,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        height: 1.1,
                                        fontWeight: sel > 0.5
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: color,
                                        letterSpacing: 0.1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
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
