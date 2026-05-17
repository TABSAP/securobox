import 'package:flutter/material.dart';

import 'package:video_player_app/utils/disguise_service.dart';
import 'package:video_player_app/utils/liquid_colors.dart';

/// Renders the app's brand icon, automatically reflecting the user's current
/// disguise choice. Listens to [DisguiseService] so changes propagate to every
/// surface (splash, onboarding, About hero, etc.) without a manual rebuild.
class AppBrandIcon extends StatelessWidget {
  final double size;
  final double radius;
  final BoxFit fit;
  final bool showShadow;

  const AppBrandIcon({
    super.key,
    this.size = 88,
    this.radius = 22,
    this.fit = BoxFit.cover,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DisguiseService.instance,
      builder: (context, _) {
        final option = DisguiseService.instance.currentOption;
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: showShadow
                ? [
                    BoxShadow(
                      color: LiquidColors.primaryStart.withValues(alpha: 0.35),
                      blurRadius: size * 0.25,
                      spreadRadius: 1,
                      offset: Offset(0, size * 0.08),
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Image.asset(
              option.assetIcon,
              width: size,
              height: size,
              fit: fit,
              errorBuilder: (_, _, _) => Container(
                decoration: BoxDecoration(
                  gradient: LiquidColors.primaryGradient,
                  borderRadius: BorderRadius.circular(radius),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.lock_rounded,
                  color: Colors.white,
                  size: size * 0.52,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
