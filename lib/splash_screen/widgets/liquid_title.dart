import 'package:flutter/material.dart';
import '../../utils/liquid_colors.dart';

class LiquidTitle extends StatelessWidget {
  final Animation<double> animation;

  const LiquidTitle({
    super.key,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: Column(
        children: [
          ShaderMask(
            shaderCallback: (bounds) {
              return LinearGradient(
                colors: [
                  Colors.white,
                  Colors.white.withValues(alpha: 0.7),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ).createShader(bounds);
            },
            child: Text(
              'SECURE',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 4.0,
                shadows: [
                  Shadow(
                    blurRadius: 15,
                    color: LiquidColors.primaryStart.withValues(alpha: 0.3),
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 5),
          ShaderMask(
            shaderCallback: (bounds) {
              return LiquidColors.primaryGradient.createShader(bounds);
            },
            child: Text(
              'PLAYER',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 4.0,
                shadows: [
                  Shadow(
                    blurRadius: 20,
                    color: LiquidColors.primaryStart.withValues(alpha: 0.5),
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
