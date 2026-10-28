import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:video_player_app/utils/liquid_colors.dart';

class AppLoader extends StatefulWidget {
  final double size;

  final Color? color;

  final String? label;

  const AppLoader({super.key, this.size = 48, this.color, this.label});

  static Widget centered({double size = 48, Color? color, String? label}) =>
      Center(
        child: AppLoader(size: size, color: color, label: label),
      );

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? LiquidColors.indigo;
    final dot = (widget.size / 5).clamp(5.0, 16.0);
    final gap = dot * 0.7;
    final travel = dot * 0.9;

    final dots = RepaintBoundary(
      child: SizedBox(
        height: dot + travel,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(3, (i) {
                final phase = (_controller.value - i * 0.18) % 1.0;
                final wave = phase < 0.6
                    ? math.sin(phase / 0.6 * math.pi)
                    : 0.0;
                return Padding(
                  padding: EdgeInsets.only(right: i == 2 ? 0 : gap),
                  child: Transform.translate(
                    offset: Offset(0, -travel * wave),
                    child: Container(
                      width: dot,
                      height: dot,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.35 + 0.65 * wave),
                        shape: BoxShape.circle,
                        boxShadow: wave > 0.5
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.35 * wave),
                                  blurRadius: 8,
                                  spreadRadius: -1,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );

    if (widget.label == null) return dots;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        dots,
        const SizedBox(height: 14),
        Text(
          widget.label!,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: LiquidColors.textSecondary,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
