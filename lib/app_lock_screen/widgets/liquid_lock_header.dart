import 'package:flutter/material.dart';
import 'package:video_player_app/widgets/liquid_glass_surface.dart';
import '../../utils/liquid_colors.dart';

class LiquidLockHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool neutralGlass;
  final bool brandGlass;
  final Color? iconColor;

  const LiquidLockHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.neutralGlass = false,
    this.brandGlass = false,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        TweenAnimationBuilder(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 800),
          curve: Curves.elasticOut,
          builder: (context, double value, child) {
            return Transform.scale(
              scale: value,
              child: neutralGlass || brandGlass
                  ? LiquidGlassSurface(
                      borderRadius: 35,
                      blur: 22,
                      tintColor: brandGlass ? LiquidColors.accentBlue : null,
                      tintOpacity: brandGlass ? 0.16 : 0,
                      child: SizedBox(
                        width: 120,
                        height: 120,
                        child: Center(
                          child: TweenAnimationBuilder(
                            tween: Tween<double>(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.elasticOut,
                            builder: (context, double scaleValue, child) =>
                                Transform.scale(
                                  scale: scaleValue,
                                  child: Icon(
                                    Icons.lock_outline_rounded,
                                    size: 64,
                                    color:
                                        iconColor ??
                                        (brandGlass
                                            ? LiquidColors.accentBlue
                                            : theme.colorScheme.onSurface),
                                  ),
                                ),
                          ),
                        ),
                      ),
                    )
                  : Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: LiquidColors.primaryGradient,
                        borderRadius: BorderRadius.circular(35),
                        boxShadow: [
                          BoxShadow(
                            color: LiquidColors.primaryStart.withValues(
                              alpha: 0.5,
                            ),
                            blurRadius: 30,
                            spreadRadius: 10,
                            offset: const Offset(0, 15),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 15,
                            spreadRadius: 3,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(35),
                                gradient: RadialGradient(
                                  colors: [
                                    LiquidColors.textPrimary.withValues(
                                      alpha: 0.4,
                                    ),
                                    Colors.transparent,
                                  ],
                                  radius: 0.7,
                                ),
                              ),
                            ),
                          ),
                          Center(
                            child: TweenAnimationBuilder(
                              tween: Tween<double>(begin: 0, end: 1),
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.elasticOut,
                              builder: (context, double scaleValue, child) =>
                                  Transform.scale(
                                    scale: scaleValue,
                                    child: const Icon(
                                      Icons.lock_outline,
                                      size: 70,
                                      color: Colors.white,
                                    ),
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
            );
          },
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: LiquidColors.textPrimary,
            shadows: [
              Shadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(color: LiquidColors.textSecondary, fontSize: 14),
        ),
      ],
    );
  }
}
