import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:video_player_app/app_lock_screen/app_lock_screen.dart';
import 'package:video_player_app/main_screen.dart';
import 'package:video_player_app/onboarding_screen/onboarding_screen.dart';
import 'package:video_player_app/utils/liquid_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  late final Animation<double> _logoFade = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.0, 0.42, curve: Curves.easeOut),
  );
  late final Animation<double> _logoScale = Tween<double>(begin: 0.78, end: 1.0)
      .animate(CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
  ));
  late final Animation<double> _textFade = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.34, 0.82, curve: Curves.easeOut),
  );
  late final Animation<Offset> _textSlide =
      Tween<Offset>(begin: const Offset(0, 0.45), end: Offset.zero).animate(
    CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.34, 0.9, curve: Curves.easeOutCubic),
    ),
  );
  late final Animation<double> _bottomFade = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
  );

  bool _navigated = false;
  Timer? _navTimer;

  @override
  void initState() {
    super.initState();
    _intro.forward();
    _navTimer = Timer(const Duration(milliseconds: 2700), _goNext);
  }

  @override
  void dispose() {
    _intro.dispose();
    _glow.dispose();
    _navTimer?.cancel();
    super.dispose();
  }

  Future<void> _goNext() async {
    if (_navigated || !mounted) return;
    _navigated = true;
    Widget next = const MainScreen();
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasOnboarded = prefs.getBool('hasOnboarded') ?? false;
      final lockEnabled = prefs.getBool('appLock') ?? false;
      next = !hasOnboarded
          ? const OnboardingScreen()
          : (lockEnabled ? const AppLockScreen() : const MainScreen());
    } catch (_) {
      next = const MainScreen();
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, _, _) => next,
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LiquidColors.backgroundDeep,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              LiquidColors.accentBlue.withValues(alpha: 0.14),
              LiquidColors.backgroundDeep,
              LiquidColors.backgroundDeep,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // soft depth blobs
            Positioned(
              top: -120,
              left: -90,
              child: _blob(LiquidColors.accentBlue, 300),
            ),
            Positioned(
              bottom: -150,
              right: -110,
              child: _blob(LiquidColors.accentPurple, 340),
            ),
            // logo + wordmark
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeTransition(
                    opacity: _logoFade,
                    child: ScaleTransition(scale: _logoScale, child: _logo()),
                  ),
                  const SizedBox(height: 30),
                  FadeTransition(
                    opacity: _textFade,
                    child: SlideTransition(
                      position: _textSlide,
                      child: Column(
                        children: [
                          Text(
                            'SecuroBox',
                            style: TextStyle(
                              color: LiquidColors.textPrimary,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.6,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your private, offline vault',
                            style: TextStyle(
                              color: LiquidColors.textSecondary,
                              fontSize: 13.5,
                              letterSpacing: 0.4,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // bottom: loader + security badge + version
            Positioned(
              left: 0,
              right: 0,
              bottom: 34,
              child: FadeTransition(
                opacity: _bottomFade,
                child: Column(
                  children: [
                    SizedBox(
                      width: 92,
                      height: 3,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          backgroundColor:
                              LiquidColors.textPrimary.withValues(alpha: 0.10),
                          valueColor: AlwaysStoppedAnimation<Color>(
                              LiquidColors.accentBlue),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shield_rounded,
                            size: 13, color: LiquidColors.textTertiary),
                        const SizedBox(width: 6),
                        Text(
                          'AES-256 encrypted · 100% offline',
                          style: TextStyle(
                            color: LiquidColors.textTertiary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'v1.0.0',
                      style: TextStyle(
                        color: LiquidColors.textTertiary.withValues(alpha: 0.6),
                        fontSize: 10.5,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _logo() {
    return AnimatedBuilder(
      animation: _glow,
      builder: (context, child) {
        final g = _glow.value;
        return Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: LiquidColors.accentBlue.withValues(alpha: 0.22 + 0.16 * g),
                blurRadius: 38 + 16 * g,
                spreadRadius: 2 + 5 * g,
              ),
            ],
          ),
          child: child,
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Image.asset(
          'assets/splash/logo.png',
          width: 120,
          height: 120,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            decoration: BoxDecoration(
              gradient: LiquidColors.primaryGradient,
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Center(
              child: Icon(Icons.lock_rounded, color: Colors.white, size: 56),
            ),
          ),
        ),
      ),
    );
  }

  Widget _blob(Color color, double size) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [
            color.withValues(alpha: 0.12),
            color.withValues(alpha: 0.0),
          ]),
        ),
      ),
    );
  }
}
