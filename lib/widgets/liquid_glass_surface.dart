import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:video_player_app/utils/theme_controller.dart';

/// Theme-aware frosted surface shared by the vault's interactive cards.
class LiquidGlassSurface extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final double blur;
  final Color? tintColor;
  final double tintOpacity;

  const LiquidGlassSurface({
    super.key,
    required this.child,
    this.borderRadius = 18,
    this.padding = EdgeInsets.zero,
    this.blur = 16,
    this.tintColor,
    this.tintOpacity = 0,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: ThemeController.instance.glassIntensityListenable,
      builder: (context, intensity, _) => _buildSurface(context, intensity),
    );
  }

  Widget _buildSurface(BuildContext context, double intensity) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final neutralTop = Colors.white.withValues(
      alpha: isDark ? 0.01 + (0.08 * intensity) : 0.12 + (0.60 * intensity),
    );
    final neutralBottom = theme.colorScheme.surface.withValues(
      alpha: isDark ? 0.12 + (0.46 * intensity) : 0.16 + (0.46 * intensity),
    );
    final tint = tintColor?.withValues(alpha: tintOpacity * intensity);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: isDark
                  ? 0.04 + (0.16 * intensity)
                  : 0.02 + (0.05 * intensity),
            ),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: blur * (0.08 + (0.92 * intensity)),
            sigmaY: blur * (0.08 + (0.92 * intensity)),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [?tint, neutralTop, neutralBottom],
              ),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: Colors.white.withValues(
                  alpha: isDark
                      ? 0.08 + (0.10 * intensity)
                      : 0.55 + (0.29 * intensity),
                ),
                width: 1,
              ),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}
