import 'package:flutter/material.dart';
import '../../utils/liquid_colors.dart';

class LiquidPinInput extends StatefulWidget {
  final bool confirmMode;
  final List<String> newPin;
  final List<String> confirmPin;
  final String? error;
  final Function(String) onNumberPressed;
  final VoidCallback onDelete;
  final VoidCallback onCancel;

  const LiquidPinInput({
    super.key,
    required this.confirmMode,
    required this.newPin,
    required this.confirmPin,
    this.error,
    required this.onNumberPressed,
    required this.onDelete,
    required this.onCancel,
  });

  @override
  State<LiquidPinInput> createState() => _LiquidPinInputState();
}

class _LiquidPinInputState extends State<LiquidPinInput>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            LiquidColors.backgroundLight.withOpacity(0.9),
            LiquidColors.backgroundMid.withOpacity(0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: LiquidColors.accentBlue.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: LiquidColors.accentBlue.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildPinIndicators(),
          if (widget.error != null) ...[
            const SizedBox(height: 16),
            _buildError(),
          ],
          const SizedBox(height: 30),
          _buildNumberPad(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          widget.confirmMode ? 'CONFIRM NEW PIN' : 'ENTER NEW PIN',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.confirmMode
              ? 'Enter the same 4-digit PIN again'
              : 'Create a new 4-digit security PIN',
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildPinIndicators() {
    return Column(
      children: [
        _buildPinIndicator(
          pin: widget.newPin,
          label: widget.confirmMode ? 'First PIN' : 'Entering PIN',
          color: LiquidColors.accentBlue,
        ),
        if (widget.confirmMode) ...[
          const SizedBox(height: 16),
          _buildPinIndicator(
            pin: widget.confirmPin,
            label: 'Confirm PIN',
            color: LiquidColors.success,
          ),
        ],
      ],
    );
  }

  Widget _buildPinIndicator({required List<String> pin, required String label, required Color color}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            return TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: 1),
              duration: Duration(milliseconds: 300 + (index * 50)),
              curve: Curves.elasticOut,
              builder: (context, double value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: index < pin.length
                            ? [color, color.withOpacity(0.5)]
                            : [Colors.grey.shade800, Colors.grey.shade900],
                        center: Alignment.center,
                        radius: 0.8,
                      ),
                      boxShadow: index < pin.length
                          ? [
                        BoxShadow(
                          color: color.withOpacity(0.5),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ]
                          : null,
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            LiquidColors.error.withOpacity(0.1),
            LiquidColors.error.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: LiquidColors.error.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: LiquidColors.error, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.error!,
              style: TextStyle(
                color: LiquidColors.error,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberPad() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        if (index == 9) {
          return _buildActionButton(
            icon: Icons.close_rounded,
            color: LiquidColors.error,
            onTap: widget.onCancel,
          );
        } else if (index == 10) {
          return _buildNumberButton('0');
        } else if (index == 11) {
          return _buildActionButton(
            icon: Icons.backspace_outlined,
            color: LiquidColors.warning,
            onTap: widget.onDelete,
          );
        } else {
          return _buildNumberButton('${index + 1}');
        }
      },
    );
  }

  Widget _buildNumberButton(String number) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (context, double value, child) {
        return Transform.scale(
          scale: value,
          child: GestureDetector(
            onTap: () => widget.onNumberPressed(number),
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    LiquidColors.backgroundLight.withOpacity(0.5),
                    LiquidColors.backgroundMid.withOpacity(0.5),
                  ],
                  center: Alignment.center,
                  radius: 0.8,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: LiquidColors.accentBlue.withOpacity(0.1),
                    blurRadius: 8,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  number,
                  style: const TextStyle(
                    fontSize: 28,
                    color: Colors.white,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (context, double value, child) {
        return Transform.scale(
          scale: value,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    color.withOpacity(0.2),
                    color.withOpacity(0.1),
                  ],
                  center: Alignment.center,
                  radius: 0.8,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: color.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 8,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: color,
                  size: 26,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}