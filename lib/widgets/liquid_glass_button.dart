import 'package:flutter/material.dart';

import 'app_spacing.dart';
import 'liquid_glass_surface.dart';

class LiquidGlassButton extends StatelessWidget {
  const LiquidGlassButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 52,
    this.foregroundColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = foregroundColor ?? theme.colorScheme.onSurface;
    return Opacity(
      opacity: onPressed == null ? 0.52 : 1,
      child: LiquidGlassSurface(
        borderRadius: AppRadius.lg,
        blur: 18,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: AppRadius.rLg,
            child: SizedBox(
              height: height,
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: foreground, size: 19),
                    const SizedBox(width: 9),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
