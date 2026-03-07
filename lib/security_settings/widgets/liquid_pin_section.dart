import 'package:flutter/material.dart';
import '../../utils/liquid_colors.dart';


class LiquidPinSection extends StatefulWidget {
  final List<String> currentPin;
  final bool isChanging;
  final bool showCurrentPin;
  final VoidCallback onStartChange;
  final VoidCallback onToggleShowPin;

  const LiquidPinSection({
    super.key,
    required this.currentPin,
    required this.isChanging,
    required this.showCurrentPin,
    required this.onStartChange,
    required this.onToggleShowPin,
  });

  @override
  State<LiquidPinSection> createState() => _LiquidPinSectionState();
}

class _LiquidPinSectionState extends State<LiquidPinSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDefaultPin = widget.currentPin.join() == '1234';

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Transform.scale(
          scale: isDefaultPin ? 1.0 + (_pulseController.value * 0.02) : 1.0,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  LiquidColors.backgroundLight.withOpacity(0.9),
                  LiquidColors.backgroundMid.withOpacity(0.95),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDefaultPin
                    ? LiquidColors.warning.withOpacity(0.3)
                    : LiquidColors.success.withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDefaultPin
                      ? LiquidColors.warning.withOpacity(0.2)
                      : LiquidColors.success.withOpacity(0.2),
                  blurRadius: 15,
                  spreadRadius: 0,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildPinIcon(isDefaultPin),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SECURITY PIN',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                          Text(
                            isDefaultPin
                                ? 'Change default PIN for better security'
                                : '4-digit security PIN configured',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDefaultPin
                                  ? LiquidColors.warning
                                  : LiquidColors.success,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildChangeButton(),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildPinStatus(isDefaultPin),
                    ),
                    _buildPinDisplay(),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPinIcon(bool isDefaultPin) {
    return Container(
      width: 45,
      height: 45,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: isDefaultPin
              ? [
            LiquidColors.warning.withOpacity(0.3),
            LiquidColors.warning.withOpacity(0.1),
          ]
              : [
            LiquidColors.success.withOpacity(0.3),
            LiquidColors.success.withOpacity(0.1),
          ],
          center: Alignment.center,
          radius: 0.8,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDefaultPin
              ? LiquidColors.warning.withOpacity(0.3)
              : LiquidColors.success.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Center(
        child: Icon(
          isDefaultPin ? Icons.warning_amber_rounded : Icons.pin_outlined,
          color: isDefaultPin ? LiquidColors.warning : LiquidColors.success,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildChangeButton() {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (context, double value, child) {
        return Transform.scale(
          scale: value,
          child: ElevatedButton(
            onPressed: widget.isChanging ? null : widget.onStartChange,
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.isChanging
                  ? Colors.grey.shade800
                  : LiquidColors.accentOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: widget.isChanging ? 0 : 8,
              shadowColor: LiquidColors.accentOrange.withOpacity(0.4),
            ),
            child: Text(
              widget.isChanging ? 'SETTING PIN...' : 'CHANGE PIN',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPinStatus(bool isDefaultPin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PIN Status:',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              isDefaultPin ? 'Weak' : 'Strong',
              style: TextStyle(
                fontSize: 14,
                color: isDefaultPin ? LiquidColors.warning : LiquidColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isDefaultPin ? Icons.warning_amber_rounded : Icons.verified_rounded,
              color: isDefaultPin ? LiquidColors.warning : LiquidColors.success,
              size: 16,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPinDisplay() {
    return GestureDetector(
      onTap: widget.onToggleShowPin,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              LiquidColors.backgroundLight.withOpacity(0.5),
              LiquidColors.backgroundMid.withOpacity(0.5),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            Text(
              widget.showCurrentPin ? widget.currentPin.join() : '••••',
              style: const TextStyle(
                fontSize: 18,
                color: Colors.white,
                letterSpacing: 4,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              widget.showCurrentPin
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              color: Colors.grey.shade400,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}