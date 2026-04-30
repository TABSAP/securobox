import 'package:flutter/material.dart';
import '../../utils/liquid_colors.dart';

class LiquidProgressIndicator extends StatefulWidget {
  final double progress;
  final Color color;
  final String category;
  final bool isDownloading;

  const LiquidProgressIndicator({
    super.key,
    required this.progress,
    required this.color,
    required this.category,
    this.isDownloading = false,
  });

  @override
  State<LiquidProgressIndicator> createState() => _LiquidProgressIndicatorState();
}

class _LiquidProgressIndicatorState extends State<LiquidProgressIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: TweenAnimationBuilder(
                  tween: Tween<double>(begin: 0, end: widget.progress),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (context, double value, child) {
                    return CustomPaint(
                      painter: LiquidProgressPainter(
                        progress: value,
                        color: widget.color,
                      ),
                      child: Container(),
                    );
                  },
                ),
              ),
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Column(
                      children: [
                        Text(
                          '${(widget.progress * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            shadows: [
                              Shadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          widget.isDownloading ? 'DOWNLOADING' : 'UPLOADING',
                          style: TextStyle(
                            color: widget.color,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  LiquidColors.backgroundLight.withOpacity(0.9),
                  LiquidColors.backgroundMid.withOpacity(0.95),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: widget.color.withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withOpacity(0.2),
                  blurRadius: 15,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.folder_rounded,
                  size: 16,
                  color: widget.color,
                ),
                const SizedBox(width: 8),
                Text(
                  'To: ${widget.category}',
                  style: TextStyle(
                    color: widget.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            widget.isDownloading
                ? 'Downloading file from URL...'
                : 'Processing files...',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class LiquidProgressPainter extends CustomPainter {
  final double progress;
  final Color color;

  LiquidProgressPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..color = color.withOpacity(0.2);

    canvas.drawCircle(center, radius, paint);

    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [color, color.withOpacity(0.5), color],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -90 * (3.14159 / 180),
      360 * (3.14159 / 180) * progress,
      false,
      progressPaint,
    );

    final liquidPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withOpacity(0.1);

    final path = Path();
    final liquidHeight = size.height * (1 - progress);

    for (double i = 0; i <= size.width; i++) {
      if (i == 0) {
        path.moveTo(i, size.height);
      } else {
        path.lineTo(i, liquidHeight + 10 * (i / size.width) * (progress * 2));
      }
    }
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, liquidPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
