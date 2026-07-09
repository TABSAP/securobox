import 'package:flutter/material.dart';

import 'package:video_player_app/splash_screen/splash_screen.dart';
import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/utils/startup_router.dart';

/// The app's root. On the very first launch it shows the branded
/// [SplashScreen]; on every launch after that it opens the appropriate screen
/// directly (onboarding, the lock screen, or the vault) with no splash.
///
/// The decision is a single local pref read, so the placeholder below is only
/// ever visible for a frame or two.
class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  // Held in state so a theme-driven rebuild of MyApp doesn't re-run the future.
  late final Future<Widget> _start = _resolve();

  Future<Widget> _resolve() async {
    if (await StartupRouter.shouldShowSplash()) return const SplashScreen();
    return StartupRouter.resolveStartScreen();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _start,
      builder: (context, snapshot) {
        final child = snapshot.data;
        if (child == null) {
          // Blank branded background — no spinner, no logo, no flash.
          return Scaffold(backgroundColor: LiquidColors.backgroundDeep);
        }
        return child;
      },
    );
  }
}
