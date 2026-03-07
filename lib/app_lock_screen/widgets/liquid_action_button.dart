import 'package:flutter/material.dart';


class LiquidActionButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final bool isEnabled;

  const LiquidActionButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.isEnabled = true,
  });

  @override
  State<LiquidActionButton> createState() => _LiquidActionButtonState();
}

class _LiquidActionButtonState extends State<LiquidActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.icon == Icons.fingerprint ? _pulseAnimation.value : 1.0,
          child: GestureDetector(
            onTap: widget.isEnabled ? widget.onPressed : null,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    widget.color.withValues(alpha: .2),
                    widget.color.withValues(alpha: .1),
                  ],
                  center: Alignment.center,
                  radius: 0.8,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.color.withValues(alpha: .3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: .2),
                    blurRadius: 10,
                    spreadRadius: 0,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(
                widget.icon,
                color: widget.isEnabled ? widget.color : Colors.grey.shade600,
                size: 28,
              ),
            ),
          ),
        );
      },
    );
  }
}