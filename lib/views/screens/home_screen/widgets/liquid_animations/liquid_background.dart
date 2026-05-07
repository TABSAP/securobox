import 'dart:math';
import 'package:flutter/material.dart';

import '../../../../../utils/liquid_colors.dart';

class LiquidBackground extends StatefulWidget {
  final Widget child;
  final bool animate;

  const LiquidBackground({
    super.key,
    required this.child,
    this.animate = true,
  });

  @override
  State<LiquidBackground> createState() => _LiquidBackgroundState();
}

class _LiquidBackgroundState extends State<LiquidBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 20),
      )..repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) {
      return Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              LiquidColors.backgroundDeep,
              LiquidColors.backgroundMid,
              LiquidColors.backgroundLight,
            ],
            center: Alignment.center,
            radius: 1.2,
          ),
        ),
        child: widget.child,
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                LiquidColors.backgroundDeep,
                LiquidColors.backgroundMid,
                LiquidColors.backgroundLight,
              ],
              center: Alignment(
                sin(_controller.value * 2 * pi) * 0.2,
                cos(_controller.value * 2 * pi) * 0.2,
              ),
              radius: 1.2 + sin(_controller.value * 2 * pi) * 0.2,
            ),
          ),
          child: widget.child,
        );
      },
    );
  }
}

class LiquidContainer extends StatelessWidget {
  final Widget child;
  final Gradient? gradient;
  final BorderRadius? borderRadius;
  final List<BoxShadow>? boxShadow;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final bool animate;

  const LiquidContainer({
    super.key,
    required this.child,
    this.gradient,
    this.borderRadius,
    this.boxShadow,
    this.padding,
    this.margin,
    this.onTap,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    final container = Container(
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(
        gradient: gradient ?? LiquidColors.cardGradient,
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        boxShadow: boxShadow ?? [
          BoxShadow(
            color: LiquidColors.primaryStart.withValues(alpha: 0.3),
            blurRadius: 15,
            spreadRadius: 0,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: container,
      );
    }

    return container;
  }
}
