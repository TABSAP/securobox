import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:flutter/material.dart';
import 'package:video_player_app/widgets/liquid_glass_surface.dart';

class LiquidActionButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final bool isEnabled;
  final bool neutralGlass;
  final bool brandGlass;
  final Color? iconColor;

  const LiquidActionButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.isEnabled = true,
    this.neutralGlass = false,
    this.brandGlass = false,
    this.iconColor,
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
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.icon == Icons.fingerprint ? _pulseAnimation.value : 1.0,
          child: GestureDetector(
            onTap: widget.isEnabled ? widget.onPressed : null,
            child: widget.neutralGlass || widget.brandGlass
                ? LiquidGlassSurface(
                    borderRadius: 20,
                    blur: 16,
                    tintColor: widget.brandGlass ? widget.color : null,
                    tintOpacity: widget.brandGlass ? 0.15 : 0,
                    child: SizedBox.expand(
                      child: Icon(
                        widget.icon,
                        color:
                            widget.iconColor ??
                            (widget.brandGlass
                                ? widget.color.withValues(
                                    alpha: widget.isEnabled ? 0.96 : 0.42,
                                  )
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: widget.isEnabled ? 0.92 : 0.42,
                                  )),
                        size: 28,
                      ),
                    ),
                  )
                : Container(
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
                      color: widget.isEnabled
                          ? widget.color
                          : LiquidColors.textTertiary,
                      size: 28,
                    ),
                  ),
          ),
        );
      },
    );
  }
}
