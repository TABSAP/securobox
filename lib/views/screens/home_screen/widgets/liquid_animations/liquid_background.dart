import 'dart:math';
import 'package:flutter/material.dart';

import '../../../../../utils/liquid_colors.dart';

class LiquidBackground extends StatefulWidget {
  final Widget child;
  final bool animate;

  const LiquidBackground({super.key, required this.child, this.animate = true});

  @override
  State<LiquidBackground> createState() => _LiquidBackgroundState();
}

class _LiquidBackgroundState extends State<LiquidBackground>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 26),
      )..repeat();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  BoxDecoration get _base => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        LiquidColors.backgroundDeep,
        LiquidColors.backgroundMid,
        LiquidColors.backgroundLight,
      ],
      stops: const [0.0, 0.55, 1.0],
    ),
  );

  Widget _glow(Color color, double size) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: 0.16), color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate || _controller == null) {
      return DecoratedBox(decoration: _base, child: widget.child);
    }

    return AnimatedBuilder(
      animation: _controller!,
      child: RepaintBoundary(child: widget.child),
      builder: (context, child) {
        final size = MediaQuery.of(context).size;
        final t = _controller!.value * 2 * pi;
        return DecoratedBox(
          decoration: _base,
          child: Stack(
            children: [
              Positioned(
                left: size.width * (0.1 + sin(t) * 0.12) - 150,
                top: size.height * (0.08 + cos(t) * 0.06) - 150,
                child: _glow(LiquidColors.accentBlue, 320),
              ),
              Positioned(
                right: size.width * (0.05 + cos(t) * 0.1) - 130,
                bottom: size.height * (0.12 + sin(t) * 0.05) - 130,
                child: _glow(LiquidColors.accentPurple, 300),
              ),
              child!,
            ],
          ),
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
        boxShadow:
            boxShadow ??
            [
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
      return GestureDetector(onTap: onTap, child: container);
    }
    return container;
  }
}
