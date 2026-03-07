import 'package:flutter/material.dart';
import '../../utils/liquid_colors.dart';


class LiquidLogo extends StatelessWidget {
  final Animation<double> animation;

  const LiquidLogo({
    super.key,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.elasticOut,
      builder: (context, double value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              gradient: LiquidColors.primaryGradient,
              borderRadius: BorderRadius.circular(35),
              boxShadow: [
                BoxShadow(
                  color: LiquidColors.primaryStart.withOpacity(0.5 * value),
                  blurRadius: 30,
                  spreadRadius: 10,
                  offset: const Offset(0, 15),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.3 * value),
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
                          Colors.white.withOpacity(0.4 * value),
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
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.elasticOut,
                    builder: (context, double iconValue, child) {
                      return Transform.scale(
                        scale: iconValue,
                        child: const Icon(
                          Icons.lock_outline,
                          size: 70,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}