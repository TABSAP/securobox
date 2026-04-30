import 'package:flutter/material.dart';
import 'package:video_player_app/onboarding_screen/onboarding_screen.dart';
import 'package:video_player_app/splash_screen/widgets/view.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin{

  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _titleAnimation;
  bool _hasNavigated = false;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startNavigationTimer();
  }

  @override
  void dispose() {
    _controller.dispose();
    _navigationTimer?.cancel();
    super.dispose();
  }

  void _initializeAnimations() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    _titleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutBack),
      ),
    );

    _controller.forward();
  }

  void _startNavigationTimer() {
    _navigationTimer?.cancel();
    _navigationTimer =
        Timer(const Duration(milliseconds: 3000), _navigateToNextScreen);
  }

  Future<void> _navigateToNextScreen() async {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final hasOnboarded = prefs.getBool('hasOnboarded') ?? false;
      final isLockEnabled = prefs.getBool('appLock') ?? false;

      if (!mounted) return;

      if (!hasOnboarded) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
      } else if (isLockEnabled) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AppLockScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
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
        child: Stack(
          children: [
            LiquidBackgroundIcons(
              screenWidth: screenWidth,
              screenHeight: screenHeight,
            ),
            Center(
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    LiquidLogo(animation: _titleAnimation),
                    const SizedBox(height: 50),
                    LiquidTitle(animation: _fadeAnimation),
                    const SizedBox(height: 50),
                    LiquidProgress(animation: _fadeAnimation),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Text(
                'Version 1.0.0',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
