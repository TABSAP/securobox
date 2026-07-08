import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:video_player_app/utils/liquid_colors.dart';

/// The app-wide loading animation: three indigo dots that rise and fade in a
/// staggered wave. Use this anywhere the app is *processing / waiting*
/// (importing, encrypting, saving, authenticating, loading a list…).
///
/// Do NOT use it when opening a file the user tapped — those should open
/// immediately without a loader.
///
/// Drop-in for the old `LiquidCircularProgress(size: …)` and bare
/// `CircularProgressIndicator` call sites: pass `size` for the footprint.
class AppLoader extends StatefulWidget {
  /// Overall footprint (width). Dot size and spacing derive from this so it can
  /// stand in for the old circular loaders that were sized 24–96.
  final double size;

  /// Dot color. Defaults to the indigo brand color.
  final Color? color;

  /// Optional caption shown beneath the dots.
  final String? label;

  const AppLoader({super.key, this.size = 48, this.color, this.label});

  /// Convenience: a centered loader, optionally with a caption.
  static Widget centered({double size = 48, Color? color, String? label}) =>
      Center(child: AppLoader(size: size, color: color, label: label));

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
                // Stagger each dot by a third of the cycle.
                final phase = (_controller.value - i * 0.18) % 1.0;
                // Ease up-and-down over the first ~60% of the cycle, rest low.
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
