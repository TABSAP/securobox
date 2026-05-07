import 'package:flutter/material.dart';
import '../../utils/liquid_colors.dart';

class LiquidNumberButton extends StatefulWidget {
  final String number;
  final VoidCallback onPressed;

  const LiquidNumberButton({
    super.key,
    required this.number,
    required this.onPressed,
  });

  @override
  State<LiquidNumberButton> createState() => _LiquidNumberButtonState();
}

class _LiquidNumberButtonState extends State<LiquidNumberButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..forward();
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTapDown: (_) {
          _controller.reverse().then((_) => _controller.forward());
          widget.onPressed();
        },
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                LiquidColors.backgroundLight.withValues(alpha: 0.5),
                LiquidColors.backgroundMid.withValues(alpha: 0.5),
              ],
              center: Alignment.center,
              radius: 0.8,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: LiquidColors.accentBlue.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: LiquidColors.accentBlue.withValues(alpha: 0.2),
                blurRadius: 10,
                spreadRadius: 0,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Text(
            widget.number,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
