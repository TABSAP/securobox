import 'package:flutter/material.dart';
import '../../utils/liquid_colors.dart';

class LiquidBackgroundIcons extends StatelessWidget {
  final double screenWidth;
  final double screenHeight;

  const LiquidBackgroundIcons({
    super.key,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [

        ...List.generate(6, (index) {
          final delay = index * 200;
          final isEven = index.isEven;
          final iconSize = isEven ? 80.0 : 60.0;
          final iconOpacity = isEven ? 0.1 : 0.08;

          return Positioned(
            top: screenHeight * (index * 0.15) % screenHeight,
            left: isEven
                ? screenWidth * 0.1
                : screenWidth * 0.8,
            child: TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: 1),
              duration: Duration(milliseconds: 1500 + delay),
              curve: Curves.easeInOut,
              builder: (context, double value, child) {
                return Opacity(
                  opacity: iconOpacity * value,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: Icon(
                      isEven ? Icons.lock_outline : Icons.security_rounded,
                      size: iconSize,
                      color: LiquidColors.primaryStart,
                    ),
                  ),
                );
              },
            ),
          );
        }),

        Positioned(
          top: screenHeight * 0.1,
          right: screenWidth * 0.2,
          child: TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 2000),
            curve: Curves.easeOut,
            builder: (context, double value, child) {
              return Transform.rotate(
                angle: value * 3.14,
                child: Opacity(
                  opacity: 0.1 * value,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: LiquidColors.primaryMid,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        Positioned(
          bottom: screenHeight * 0.15,
          left: screenWidth * 0.15,
          child: TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 2000),
            curve: Curves.easeOut,
            builder: (context, double value, child) {
              return Transform.rotate(
                angle: -value * 3.14,
                child: Opacity(
                  opacity: 0.1 * value,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: LiquidColors.accentPurple,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
