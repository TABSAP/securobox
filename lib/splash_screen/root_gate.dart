import 'dart:async';

import 'package:flutter/material.dart';

import 'package:video_player_app/ads/ad_service.dart';
import 'package:video_player_app/splash_screen/splash_screen.dart';
import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/utils/startup_router.dart';

class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> with WidgetsBindingObserver {
  late final Future<Widget> _start = _resolve();
  bool _ready = false;
  bool _initialAdRequested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_ready && state == AppLifecycleState.resumed) {
      unawaited(AdService.instance.showAppOpenAd());
    }
  }

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
          return Scaffold(backgroundColor: LiquidColors.backgroundDeep);
        }
        _ready = true;
        if (!_initialAdRequested) {
          _initialAdRequested = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) unawaited(AdService.instance.showAppOpenAd());
          });
        }
        return child;
      },
    );
  }
}
