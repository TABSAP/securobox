import 'dart:math';
import 'package:flutter/material.dart';
import 'package:video_player_app/utils/liquid_colors.dart';

class LiquidCircularProgress extends StatefulWidget {
  final double? value;
  final double size;
  final double strokeWidth;
  final List<Color>? colors;
  final Color? glowColor;
  final bool showWaveFill;
  final bool showPercentText;

  const LiquidCircularProgress({
    super.key,
    this.value,
    this.size = 72,
    this.strokeWidth = 6,
    this.colors,
    this.glowColor,
    this.showWaveFill = true,
    this.showPercentText = true,
  });

  @override
  State<LiquidCircularProgress> createState() =>
      _LiquidCircularProgressState();
}

class _LiquidCircularProgressState extends State<LiquidCircularProgress>
    with TickerProviderStateMixin {
  late final AnimationController _spin;
  late final AnimationController _wave;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    _wave = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _spin.dispose();
    _wave.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.colors ??
        const [
          LiquidColors.accentBlue,
          LiquidColors.accentPurple,
          LiquidColors.accentPink,
        ];
    final glow = widget.glowColor ?? palette.first;

    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: Listenable.merge([_spin, _wave, _pulse]),
          builder: (context, _) {
            return CustomPaint(
              painter: _LiquidCircularPainter(
                spin: _spin.value,
                wave: _wave.value,
                pulse: _pulse.value,
                progress: widget.value,
                colors: palette,
                glowColor: glow,
                strokeWidth: widget.strokeWidth,
                showWaveFill: widget.showWaveFill,
                showPercentText: widget.showPercentText,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LiquidCircularPainter extends CustomPainter {
  final double spin;
  final double wave;
  final double pulse;
  final double? progress;
  final List<Color> colors;
  final Color glowColor;
  final double strokeWidth;
  final bool showWaveFill;
  final bool showPercentText;

  _LiquidCircularPainter({
    required this.spin,
    required this.wave,
    required this.pulse,
    required this.progress,
    required this.colors,
    required this.glowColor,
    required this.strokeWidth,
    required this.showWaveFill,
    required this.showPercentText,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final shortest = size.shortestSide;
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = (shortest - strokeWidth) / 2;
    if (outerRadius <= 0) return;

    _paintHalo(canvas, center, outerRadius);
    _paintTrack(canvas, center, outerRadius);

    if (showWaveFill && shortest >= 40) {
      _paintWaveFill(canvas, center, outerRadius - strokeWidth - 2);
    }

    if (progress != null) {
      _paintProgressArc(canvas, center, outerRadius);
    } else {
      _paintIndeterminateDroplets(canvas, center, outerRadius);
    }

    if (progress != null && showPercentText && shortest >= 84) {
      _paintProgressText(canvas, center, shortest);
    }
  }

  void _paintHalo(Canvas canvas, Offset center, double radius) {
    final base = 0.16 + 0.12 * pulse;
    final paint = Paint()
      ..color = glowColor.withValues(alpha: base)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 + 8 * pulse);
    canvas.drawCircle(center, radius, paint);
  }

  void _paintTrack(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, paint);
  }

  void _paintWaveFill(Canvas canvas, Offset center, double innerRadius) {
    if (innerRadius <= 0) return;

    final progressValue = progress?.clamp(0.0, 1.0) ?? 0.5;
    final bob = progress == null ? 0.05 * sin(pulse * 2 * pi) : 0.0;
    final fillFraction = (progressValue + bob).clamp(0.0, 1.0);
    final waveY = center.dy + innerRadius - innerRadius * 2 * fillFraction;

    final clipRect = Rect.fromCircle(center: center, radius: innerRadius);

    canvas.save();
    canvas.clipPath(Path()..addOval(clipRect));

    _drawWave(
      canvas,
      center,
      innerRadius,
      waveY,
      freq: 2.0,
      phase: wave,
      amplitude: innerRadius * 0.07,
      color: colors.first.withValues(alpha: 0.50),
    );
    _drawWave(
      canvas,
      center,
      innerRadius,
      waveY + innerRadius * 0.05,
      freq: 1.4,
      phase: -wave * 1.3,
      amplitude: innerRadius * 0.05,
      color: colors.last.withValues(alpha: 0.32),
    );

    final highlight = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.10),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(
        center.dx - innerRadius,
        waveY,
        innerRadius * 2,
        innerRadius * 0.4,
      ));
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx - innerRadius,
        waveY,
        innerRadius * 2,
        innerRadius * 0.4,
      ),
      highlight,
    );

    canvas.restore();
  }

  void _drawWave(
    Canvas canvas,
    Offset center,
    double innerRadius,
    double baseY, {
    required double freq,
    required double phase,
    required double amplitude,
    required Color color,
  }) {
    final left = center.dx - innerRadius;
    final right = center.dx + innerRadius;
    final bottom = center.dy + innerRadius + 2;

    final phaseRad = phase * 2 * pi;
    final span = innerRadius * 2;

    final path = Path()..moveTo(left, baseY);
    for (double x = left; x <= right; x += 2) {
      final t = (x - left) / span;
      final y = baseY + amplitude * sin(t * freq * 2 * pi + phaseRad);
      path.lineTo(x, y);
    }
    path.lineTo(right, bottom);
    path.lineTo(left, bottom);
    path.close();

    canvas.drawPath(path, Paint()..color = color);
  }

  void _paintIndeterminateDroplets(
    Canvas canvas,
    Offset center,
    double radius,
  ) {
    final rect = Rect.fromCircle(center: center, radius: radius);

    const droplets = [
      _Droplet(speed: 1.0, sweepDeg: 90, lag: 0.0, alpha: 1.0, widthMul: 1.0),
      _Droplet(speed: 1.3, sweepDeg: 50, lag: 0.22, alpha: 0.65, widthMul: 0.75),
      _Droplet(speed: 0.7, sweepDeg: 24, lag: 0.45, alpha: 0.40, widthMul: 0.55),
    ];

    for (final d in droplets) {
      final start = (spin * d.speed - d.lag) * 2 * pi;
      final sweep = d.sweepDeg * pi / 180;

      final shader = SweepGradient(
        startAngle: start,
        endAngle: start + sweep,
        colors: [
          colors[0].withValues(alpha: 0.0),
          colors[0].withValues(alpha: d.alpha),
          colors[1 % colors.length].withValues(alpha: d.alpha),
          colors[2 % colors.length].withValues(alpha: d.alpha),
          colors[2 % colors.length].withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.18, 0.5, 0.82, 1.0],
      ).createShader(rect);

      final paint = Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * d.widthMul
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, start, sweep, false, paint);

      final headAngle = start + sweep;
      final headCenter = Offset(
        center.dx + radius * cos(headAngle),
        center.dy + radius * sin(headAngle),
      );
      final headSize = strokeWidth * d.widthMul * 0.55;
      canvas.drawCircle(
        headCenter,
        headSize + 2,
        Paint()
          ..color =
              colors[2 % colors.length].withValues(alpha: d.alpha * 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(
        headCenter,
        headSize,
        Paint()..color = Colors.white.withValues(alpha: 0.85 * d.alpha),
      );
    }
  }

  void _paintProgressArc(Canvas canvas, Offset center, double radius) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    final progressValue = progress!.clamp(0.0, 1.0);
    if (progressValue <= 0) return;

    const start = -pi / 2;
    final sweep = 2 * pi * progressValue;

    final shader = SweepGradient(
      startAngle: start,
      endAngle: start + 2 * pi,
      colors: [
        colors.first,
        ...colors.skip(1),
        colors.first,
      ],
    ).createShader(rect);

    final paint = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, start, sweep, false, paint);

    final headAngle = start + sweep;
    final headCenter = Offset(
      center.dx + radius * cos(headAngle),
      center.dy + radius * sin(headAngle),
    );
    canvas.drawCircle(
      headCenter,
      strokeWidth * 0.85,
      Paint()
        ..color = colors.last.withValues(alpha: 0.55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 + 2 * pulse),
    );
    canvas.drawCircle(
      headCenter,
      strokeWidth * 0.42,
      Paint()..color = Colors.white,
    );
  }

  void _paintProgressText(Canvas canvas, Offset center, double size) {
    final pct = (progress!.clamp(0.0, 1.0) * 100).round();
    final tp = TextPainter(
      text: TextSpan(
        text: '$pct%',
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.18,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(_LiquidCircularPainter old) =>
      old.spin != spin ||
      old.wave != wave ||
      old.pulse != pulse ||
      old.progress != progress;
}

class _Droplet {
  final double speed;
  final double sweepDeg;
  final double lag;
  final double alpha;
  final double widthMul;

  const _Droplet({
    required this.speed,
    required this.sweepDeg,
    required this.lag,
    required this.alpha,
    required this.widthMul,
  });
}
