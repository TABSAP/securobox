import 'package:flutter/material.dart';
import '../../utils/liquid_colors.dart';
import '../../widgets/app_brand_icon.dart';

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
              borderRadius: BorderRadius.circular(35),
              boxShadow: [
                BoxShadow(
                  color: LiquidColors.primaryStart.withValues(alpha: 0.5 * value),
                  blurRadius: 30,
                  spreadRadius: 10,
                  offset: const Offset(0, 15),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3 * value),
                  blurRadius: 15,
                  spreadRadius: 3,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const AppBrandIcon(
              size: 140,
              radius: 35,
              showShadow: false,
            ),
          ),
        );
      },
    );
  }
}
