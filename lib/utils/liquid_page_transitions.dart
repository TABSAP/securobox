import 'package:flutter/material.dart';

/// App-wide "liquid" page transition.
///
/// The incoming screen fades in while gently rising into place; the screen it
/// covers eases upward and dims so the navigation stack feels layered and
/// fluid. Wired through [PageTransitionsTheme] in the app theme, so every
/// [MaterialPageRoute] across the whole app picks it up automatically — and
/// the reverse plays on back-navigation.
class LiquidPageTransitionsBuilder extends PageTransitionsBuilder {
  const LiquidPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final incoming = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final outgoing = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return SlideTransition(
      // The covered page drifts up a touch as a new screen settles over it.
      position: Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(0, -0.03),
      ).animate(outgoing),
      child: FadeTransition(
        opacity: Tween<double>(begin: 1.0, end: 0.6).animate(outgoing),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.045),
            end: Offset.zero,
          ).animate(incoming),
          child: FadeTransition(opacity: incoming, child: child),
        ),
      ),
    );
  }
}

/// The liquid transition applied uniformly to every platform, so screen
/// changes feel identical across the app.
const PageTransitionsTheme liquidPageTransitionsTheme = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: LiquidPageTransitionsBuilder(),
    TargetPlatform.iOS: LiquidPageTransitionsBuilder(),
    TargetPlatform.macOS: LiquidPageTransitionsBuilder(),
    TargetPlatform.windows: LiquidPageTransitionsBuilder(),
    TargetPlatform.linux: LiquidPageTransitionsBuilder(),
    TargetPlatform.fuchsia: LiquidPageTransitionsBuilder(),
  },
);
