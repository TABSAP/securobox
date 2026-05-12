import 'package:flutter/material.dart';
import '../../utils/liquid_colors.dart';

class LiquidPinSection extends StatelessWidget {
  final bool isChanging;
  final VoidCallback onStartChange;

  const LiquidPinSection({
    super.key,
    required this.isChanging,
    required this.onStartChange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            LiquidColors.backgroundLight.withValues(alpha: 0.9),
            LiquidColors.backgroundMid.withValues(alpha: 0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: LiquidColors.success.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: LiquidColors.success.withValues(alpha: 0.15),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      LiquidColors.success.withValues(alpha: 0.3),
                      LiquidColors.success.withValues(alpha: 0.1),
                    ],
                    center: Alignment.center,
                    radius: 0.8,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: LiquidColors.success.withValues(alpha: 0.3),
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.pin_outlined,
                    color: LiquidColors.success,
                    size: 24,
                  ),
                ),
              ),
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
                        color: LiquidColors.textPrimary,
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Hashed and stored in secure keystore',
                      style: TextStyle(
                        fontSize: 12,
                        color: LiquidColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: isChanging ? null : onStartChange,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isChanging
                      ? LiquidColors.textTertiary
                      : LiquidColors.accentOrange,
                  foregroundColor: LiquidColors.textPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: isChanging ? 0 : 6,
                  shadowColor: LiquidColors.accentOrange.withValues(alpha: 0.4),
                ),
                child: Text(
                  isChanging ? 'SETTING…' : 'CHANGE PIN',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
