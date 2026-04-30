import 'package:flutter/material.dart';
import '../../utils/liquid_colors.dart';

class LiquidPinDots extends StatelessWidget {
  final int enteredLength;
  final bool hasError;

  const LiquidPinDots({
    super.key,
    required this.enteredLength,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        return TweenAnimationBuilder(
          tween: Tween<double>(begin: 0, end: 1),
          duration: Duration(milliseconds: 300 + (index * 50)),
          curve: Curves.elasticOut,
          builder: (context, double value, child) {
            return Transform.scale(
              scale: value,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 12),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: index < enteredLength
                        ? hasError
                        ? [LiquidColors.error, LiquidColors.error.withOpacity(0.5)]
                        : [LiquidColors.accentBlue, LiquidColors.primaryMid]
                        : [Colors.white24, Colors.white12],
                    center: Alignment.center,
                    radius: 0.8,
                  ),
                  boxShadow: index < enteredLength && !hasError
                      ? [
                    BoxShadow(
                      color: LiquidColors.accentBlue.withOpacity(0.5),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ]
                      : null,
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
