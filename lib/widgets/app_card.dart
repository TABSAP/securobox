import 'package:flutter/material.dart';

import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/widgets/app_spacing.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final double radius;
  final bool elevated;
  final Border? border;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.md),
    this.onTap,
    this.color,
    this.radius = AppRadius.lg,
    this.elevated = false,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? LiquidColors.backgroundLight.withValues(alpha: 0.55),
        borderRadius: br,
        border: border ?? Border.all(color: LiquidColors.cardBorder),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: LiquidColors.shadow,
                  blurRadius: 18,
                  spreadRadius: -6,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: child,
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: br,
        child: content,
      ),
    );
  }
}
