import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A cinematic, real-time "military-grade encryption in progress" animation
/// for the secure vault. Drop it into a dialog, an overlay, or a full screen
/// while files are being encrypted.
///
/// Pass [progress] (0..1) for a live percentage readout, or leave it null for
/// an indeterminate "ENCRYPTING" state.
class LiquidEncryptionAnimation extends StatefulWidget {
  final double? progress;
  final String title;
  final String subtitle;
  final double size;

  const LiquidEncryptionAnimation({
    super.key,
    this.progress,
    this.title = 'Securing your vault',
    this.subtitle = 'AES-256 · CTR · live encryption',
    this.size = 288,
  });

  @override
  State<LiquidEncryptionAnimation> createState() =>
      _LiquidEncryptionAnimationState();
}

class _LiquidEncryptionAnimationState extends State<LiquidEncryptionAnimation>
    with TickerProviderStateMixin {
  static const _cyan = Color(0xFF22D3EE);
  static const _ice = Color(0xFFE6FAFF);

  late final AnimationController _t;
  late final AnimationController _pulse;
  late final AnimationController _scan;

  late final List<_DataBlock> _blocks;
  late final List<_CodeColumn> _columns;
  late final List<_Beam> _beams;

  @override
  void initState() {
    super.initState();
    _t = AnimationController(vsync: this, duration: const Duration(seconds: 9))
      ..repeat();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1700))
      ..repeat(reverse: true);
    _scan = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600))
      ..repeat();

    final r = math.Random(11);
    _blocks = List.generate(22, (i) => _DataBlock.seed(r, i));
    _columns = List.generate(6, (i) => _CodeColumn.seed(r));
    _beams = List.generate(5, (i) => _Beam.seed(r));
  }

  @override
  void dispose() {
    _t.dispose();
    _pulse.dispose();
    _scan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasProgress = widget.progress != null;
    final pct = ((widget.progress ?? 0).clamp(0.0, 1.0) * 100).round();

    return RepaintBoundary(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: widget.size,
            height: widget.size,
            child: AnimatedBuilder(
              animation: Listenable.merge([_t, _pulse, _scan]),
              builder: (context, _) {
                final pulse = Curves.easeInOut.transform(_pulse.value);
                return CustomPaint(
                  isComplex: true,
                  willChange: true,
                  painter: _EncryptionPainter(
                    t: _t.value,
                    pulse: pulse,
                    scan: _scan.value,
                    progress: widget.progress,
                    blocks: _blocks,
                    columns: _columns,
                    beams: _beams,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                _cyan.withValues(alpha: 0.16),
                                Colors.black.withValues(alpha: 0.45),
                              ],
                              stops: const [0.0, 1.0],
                            ),
                            border: Border.all(
                              color: _ice.withValues(alpha: 0.55),
                              width: 1.1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _cyan.withValues(
                                    alpha: 0.30 + 0.30 * pulse),
                                blurRadius: 24 + 16 * pulse,
                                spreadRadius: 1 + 2 * pulse,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.lock_rounded,
                            color: Colors.white,
                            size: 36,
                            shadows: [
                              Shadow(
                                color: _cyan.withValues(alpha: 0.85),
                                blurRadius: 14,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (hasProgress)
                          Text(
                            '$pct%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              fontFeatures: [
                                ui.FontFeature.tabularFigures(),
                              ],
                              shadows: [
                                Shadow(color: _cyan, blurRadius: 16),
                              ],
                            ),
                          )
                        else
                          const Text(
                            'ENCRYPTING',
                            style: TextStyle(
                              color: _cyan,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 4.0,
                              shadows: [Shadow(color: _cyan, blurRadius: 12)],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _cyan.withValues(alpha: 0.72),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Particles / streams seed data (computed once, not per frame)
// ---------------------------------------------------------------------------

class _DataBlock {
  final double bx, by; // 0..1 base position
  final double sizePx;
  final double driftAngle;
  final double driftAmt;
  final double speed;
  final double rotSpeed;
  final double phase;
  final bool warm; // alternate accent

  const _DataBlock(this.bx, this.by, this.sizePx, this.driftAngle,
      this.driftAmt, this.speed, this.rotSpeed, this.phase, this.warm);

  factory _DataBlock.seed(math.Random r, int i) => _DataBlock(
        r.nextDouble(),
        r.nextDouble(),
        4.0 + r.nextDouble() * 7.0,
        r.nextDouble() * math.pi * 2,
        4.0 + r.nextDouble() * 16.0,
        0.4 + r.nextDouble() * 1.1,
        (r.nextBool() ? 1 : -1) * (0.3 + r.nextDouble() * 0.9),
        r.nextDouble(),
        i.isEven,
      );
}

class _CodeColumn {
  final double x; // 0..1
  final double speed;
  final double phase;
  final List<int> bits; // stable 0/1 sequence

  const _CodeColumn(this.x, this.speed, this.phase, this.bits);

  factory _CodeColumn.seed(math.Random r) => _CodeColumn(
        0.08 + r.nextDouble() * 0.84,
        0.55 + r.nextDouble() * 1.3,
        r.nextDouble(),
        List.generate(18, (_) => r.nextBool() ? 1 : 0),
      );
}

class _Beam {
  final double angle;
  final double speed;
  final double phase;

  const _Beam(this.angle, this.speed, this.phase);

  factory _Beam.seed(math.Random r) => _Beam(
        r.nextDouble() * math.pi * 2,
        0.5 + r.nextDouble() * 1.0,
        r.nextDouble(),
      );
}

// ---------------------------------------------------------------------------
// Painter
// ---------------------------------------------------------------------------

class _EncryptionPainter extends CustomPainter {
  final double t; // 0..1 master loop
  final double pulse; // 0..1 eased
  final double scan; // 0..1 loop
  final double? progress;
  final List<_DataBlock> blocks;
  final List<_CodeColumn> columns;
  final List<_Beam> beams;

  _EncryptionPainter({
    required this.t,
    required this.pulse,
    required this.scan,
    required this.progress,
    required this.blocks,
    required this.columns,
    required this.beams,
  });

  static const _cyan = Color(0xFF22D3EE);
  static const _blue = Color(0xFF3B82F6);
  static const _ice = Color(0xFFE6FAFF);
  static const _twoPi = math.pi * 2;

  static final TextPainter _ch0d = _mkChar('0', _cyan.withValues(alpha: 0.28));
  static final TextPainter _ch1d = _mkChar('1', _cyan.withValues(alpha: 0.28));
  static final TextPainter _ch0b = _mkChar('0', _ice.withValues(alpha: 0.85));
  static final TextPainter _ch1b = _mkChar('1', _ice.withValues(alpha: 0.85));

  static TextPainter _mkChar(String c, Color color) => TextPainter(
        text: TextSpan(
          text: c,
          style: TextStyle(
            color: color,
            fontSize: 11,
            height: 1.0,
            fontWeight: FontWeight.w700,
            fontFamily: 'monospace',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final half = math.min(size.width, size.height) / 2;

    canvas.clipRect(Offset.zero & size);

    // 1. Background vignette
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const RadialGradient(
          radius: 0.95,
          colors: [Color(0xFF0B1626), Color(0xFF030711)],
        ).createShader(Offset.zero & size),
    );

    _drawHexGrid(canvas, size, c, half);
    _drawCodeColumns(canvas, size);
    _drawScanWaves(canvas, c, half);
    _drawBeams(canvas, c, half);
    _drawDataBlocks(canvas, size, c);
    _drawRings(canvas, c, half);
    _drawHexReticle(canvas, c, half * 0.31);
    _drawCore(canvas, c, half);
    _drawCornerBrackets(canvas, size);
  }

  // ---- hex security grid with a scanning highlight ripple ----
  void _drawHexGrid(Canvas canvas, Size size, Offset c, double half) {
    final r = half * 0.135;
    final stepX = r * 1.5;
    final stepY = r * math.sqrt(3);
    final scanR = half * (0.12 + 0.95 * scan);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final fill = Paint();

    int col = -1;
    for (double x = -stepX; x < size.width + stepX; x += stepX) {
      col++;
      final yOff = col.isOdd ? stepY / 2 : 0.0;
      for (double y = -stepY + yOff; y < size.height + stepY; y += stepY) {
        final cell = Offset(x, y);
        final d = (cell - c).distance;
        if (d > half * 0.98) continue;
        final band =
            (1.0 - (d - scanR).abs() / (half * 0.16)).clamp(0.0, 1.0);
        final centerBoost =
            (1.0 - d / (half * 0.55)).clamp(0.0, 1.0) * 0.22;
        final a = (0.045 + 0.5 * band * band + centerBoost).clamp(0.0, 0.62);
        final path = _hexPath(cell, r * 0.92);
        stroke.color = _cyan.withValues(alpha: a);
        canvas.drawPath(path, stroke);
        if (band > 0.78) {
          fill.color = _cyan.withValues(alpha: 0.07 * band);
          canvas.drawPath(path, fill);
        }
      }
    }
  }

  Path _hexPath(Offset center, double r) {
    final p = Path();
    for (int i = 0; i < 6; i++) {
      final a = math.pi / 3 * i;
      final pt = Offset(center.dx + r * math.cos(a), center.dy + r * math.sin(a));
      if (i == 0) {
        p.moveTo(pt.dx, pt.dy);
      } else {
        p.lineTo(pt.dx, pt.dy);
      }
    }
    return p..close();
  }

  // ---- falling binary / code columns ----
  void _drawCodeColumns(Canvas canvas, Size size) {
    const lineH = 15.0;
    for (final c in columns) {
      final x = c.x * size.width;
      final headY =
          (((t * c.speed + c.phase) % 1.0) * (size.height + 80)) - 40;
      final shift = (headY / lineH).floor();
      final n = c.bits.length;
      for (int k = 0; k < n; k++) {
        final y = headY - k * lineH;
        if (y < -lineH || y > size.height) continue;
        final bit = c.bits[((k + shift) % n + n) % n];
        final near = k <= 1;
        final tp = bit == 1
            ? (near ? _ch1b : _ch1d)
            : (near ? _ch0b : _ch0d);
        tp.paint(canvas, Offset(x, y));
      }
    }
  }

  // ---- expanding AI scan waves ----
  void _drawScanWaves(Canvas canvas, Offset c, double half) {
    for (int i = 0; i < 2; i++) {
      final f = (scan + i * 0.5) % 1.0;
      final radius = half * (0.10 + 0.94 * f);
      final a = (1.0 - f) * 0.42;
      canvas.drawCircle(
        c,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4 + 2.0 * (1 - f)
          ..color = _cyan.withValues(alpha: a)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
      );
    }
  }

  // ---- secure data-transfer beams: files streaming into the vault ----
  void _drawBeams(Canvas canvas, Offset c, double half) {
    for (final b in beams) {
      final dir = Offset(math.cos(b.angle), math.sin(b.angle));
      final outer = c + dir * (half * 0.96);
      final inner = c + dir * (half * 0.215);
      canvas.drawLine(
        outer,
        inner,
        Paint()
          ..color = _cyan.withValues(alpha: 0.06)
          ..strokeWidth = 1.0,
      );
      final f = (t * b.speed + b.phase) % 1.0;
      final ef = Curves.easeIn.transform(f);
      final pkt = Offset.lerp(outer, inner, ef)!;
      final tail = Offset.lerp(outer, inner, (ef - 0.14).clamp(0.0, 1.0))!;
      final bright = (0.22 + 0.62 * ef).clamp(0.0, 1.0);
      canvas.drawLine(
        tail,
        pkt,
        Paint()
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..shader = ui.Gradient.linear(tail, pkt, [
            _cyan.withValues(alpha: 0.0),
            _ice.withValues(alpha: bright),
          ]),
      );
      canvas.drawCircle(
        pkt,
        2.4,
        Paint()
          ..color = _cyan.withValues(alpha: bright)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 + 3 * ef),
      );
      canvas.drawCircle(
          pkt, 1.3, Paint()..color = Colors.white.withValues(alpha: bright));
    }
  }

  // ---- drifting encrypted data blocks that disintegrate & reform ----
  void _drawDataBlocks(Canvas canvas, Size size, Offset c) {
    for (final b in blocks) {
      final phase = (t * b.speed + b.phase) % 1.0;
      final bob = math.sin(phase * _twoPi) * b.driftAmt;
      final pos = Offset(
        b.bx * size.width + math.cos(b.driftAngle) * bob,
        b.by * size.height + math.sin(b.driftAngle) * bob,
      );
      final diss = _smoothBump(phase, 0.58, 0.16); // 0..1, dissolve window
      final ang = t * _twoPi * b.rotSpeed + b.phase * _twoPi;
      final accent = b.warm ? _blue : _cyan;
      final aSolid = (b.warm ? 0.5 : 0.6) * (1.0 - diss);

      if (diss < 0.12) {
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(ang);
        final rect = Rect.fromCenter(
            center: Offset.zero, width: b.sizePx, height: b.sizePx);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(1.5)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = accent.withValues(alpha: aSolid),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.deflate(1.0), const Radius.circular(1.0)),
          Paint()..color = accent.withValues(alpha: aSolid * 0.22),
        );
        canvas.restore();
      } else {
        final spread = b.sizePx * (0.6 + 2.6 * diss);
        for (int k = 0; k < 5; k++) {
          final aa = ang + k * (math.pi * 2 / 5);
          final rr = spread *
              (0.25 + 0.75 * (((k * 7 + b.phase * 13) % 1.0)));
          final dp = pos + Offset(math.cos(aa) * rr, math.sin(aa) * rr);
          canvas.drawCircle(
            dp,
            1.1,
            Paint()
              ..color = accent.withValues(
                  alpha: (aSolid + 0.18 * (1 - diss)).clamp(0.0, 0.7)),
          );
        }
      }
    }
  }

  // ---- rotating energized rings (the holographic shield) ----
  void _drawRings(Canvas canvas, Offset c, double half) {
    const ringRadii = [0.305, 0.385, 0.46];
    const ringSpeeds = [1.0, -0.62, 0.34];
    const ringSegs = [16, 24, 32];
    const ringAlpha = [0.55, 0.4, 0.3];
    const ringGlow = [true, false, false];

    for (int ri = 0; ri < ringRadii.length; ri++) {
      final radius = half * ringRadii[ri];
      final rect = Rect.fromCircle(center: c, radius: radius);
      final segs = ringSegs[ri];
      final segArc = _twoPi / segs;
      final drawArc = segArc * 0.55;
      final rot = t * _twoPi * ringSpeeds[ri];
      final glow = ringGlow[ri];
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = glow ? 2.2 : 1.4
        ..strokeCap = StrokeCap.round;
      if (glow) {
        paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
      }
      for (int i = 0; i < segs; i++) {
        final wob = 0.65 + 0.35 * math.sin(i * 1.7 + t * _twoPi * 2);
        paint.color = (glow ? _ice : _cyan)
            .withValues(alpha: (ringAlpha[ri] * wob).clamp(0.0, 0.85));
        canvas.drawArc(rect, rot + i * segArc, drawArc, false, paint);
      }
    }
  }

  // ---- hexagonal targeting reticle around the core ----
  void _drawHexReticle(Canvas canvas, Offset c, double radius) {
    final rot = -t * _twoPi * 0.22;
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final a = rot + math.pi / 3 * i;
      final pt = Offset(c.dx + radius * math.cos(a), c.dy + radius * math.sin(a));
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = _cyan.withValues(alpha: 0.20),
    );
    final tick = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..color = _cyan.withValues(alpha: 0.6 + 0.25 * pulse);
    for (int i = 0; i < 6; i++) {
      final a = rot + math.pi / 3 * i;
      final v = Offset(c.dx + radius * math.cos(a), c.dy + radius * math.sin(a));
      final inn =
          Offset(c.dx + (radius - 7) * math.cos(a), c.dy + (radius - 7) * math.sin(a));
      canvas.drawLine(v, inn, tick);
    }
  }

  // ---- glowing metallic vault core + live encryption arc ----
  void _drawCore(Canvas canvas, Offset c, double half) {
    final coreR = half * 0.215;
    // outer bloom
    canvas.drawCircle(
      c,
      coreR * (1.7 + 0.25 * pulse),
      Paint()
        ..color = _cyan.withValues(alpha: 0.14 + 0.10 * pulse)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 24 + 14 * pulse),
    );
    // faint energized inner fill (kept dark so the lock icon stays readable)
    canvas.drawCircle(
      c,
      coreR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _cyan.withValues(alpha: 0.14 + 0.06 * pulse),
            _blue.withValues(alpha: 0.04),
            Colors.transparent,
          ],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: coreR)),
    );
    // bright containment rim
    canvas.drawCircle(
      c,
      coreR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = _ice.withValues(alpha: 0.55 + 0.25 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
    canvas.drawCircle(
      c,
      coreR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = _ice.withValues(alpha: 0.85),
    );

    // live encryption progress arc
    if (progress != null) {
      final pr = progress!.clamp(0.0, 1.0);
      final arcR = coreR + half * 0.05;
      final rect = Rect.fromCircle(center: c, radius: arcR);
      const start = -math.pi / 2;
      canvas.drawArc(
        rect,
        0,
        _twoPi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..color = _cyan.withValues(alpha: 0.10),
      );
      if (pr > 0) {
        final sweep = _twoPi * pr;
        canvas.drawArc(
          rect,
          start,
          sweep,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.0
            ..strokeCap = StrokeCap.round
            ..shader = SweepGradient(
              startAngle: start,
              endAngle: start + _twoPi,
              colors: const [_blue, _cyan, _ice, _cyan, _blue],
            ).createShader(rect)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0),
        );
        final ha = start + sweep;
        final hp = Offset(c.dx + arcR * math.cos(ha), c.dy + arcR * math.sin(ha));
        canvas.drawCircle(
          hp,
          3.6,
          Paint()
            ..color = _ice
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
        canvas.drawCircle(hp, 2.0, Paint()..color = Colors.white);
      }
    }
  }

  // ---- HUD corner brackets ----
  void _drawCornerBrackets(Canvas canvas, Size size) {
    const m = 14.0;
    const len = 22.0;
    final w = size.width, h = size.height;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = _cyan.withValues(alpha: 0.42 + 0.20 * pulse);

    canvas.drawLine(Offset(m, m + len), Offset(m, m), p);
    canvas.drawLine(Offset(m, m), Offset(m + len, m), p);
    canvas.drawLine(Offset(w - m - len, m), Offset(w - m, m), p);
    canvas.drawLine(Offset(w - m, m), Offset(w - m, m + len), p);
    canvas.drawLine(Offset(m, h - m - len), Offset(m, h - m), p);
    canvas.drawLine(Offset(m, h - m), Offset(m + len, h - m), p);
    canvas.drawLine(Offset(w - m - len, h - m), Offset(w - m, h - m), p);
    canvas.drawLine(Offset(w - m, h - m), Offset(w - m, h - m - len), p);
  }

  double _smoothBump(double x, double center, double width) {
    final d = (x - center).abs();
    if (d >= width) return 0.0;
    final n = 1.0 - d / width;
    return n * n * (3 - 2 * n);
  }

  @override
  bool shouldRepaint(_EncryptionPainter old) =>
      old.t != t ||
      old.pulse != pulse ||
      old.scan != scan ||
      old.progress != progress;
}
