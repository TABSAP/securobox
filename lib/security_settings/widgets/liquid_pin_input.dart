import 'package:flutter/material.dart';
import 'package:video_player_app/widgets/liquid_glass_surface.dart';
import '../../utils/liquid_colors.dart';

class LiquidPinInput extends StatefulWidget {
  final bool confirmMode;
  final bool verifyOldMode;
  final List<String> newPin;
  final List<String> confirmPin;
  final List<String> oldPin;
  final int totalLength;
  final String? error;
  final Function(String) onNumberPressed;
  final VoidCallback onDelete;
  final VoidCallback onCancel;

  const LiquidPinInput({
    super.key,
    required this.confirmMode,
    required this.newPin,
    required this.confirmPin,
    this.verifyOldMode = false,
    this.oldPin = const [],
    this.totalLength = 4,
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
    return LiquidGlassSurface(
      borderRadius: 24,
      blur: 20,
      tintColor: LiquidColors.accentBlue,
      tintOpacity: 0.06,
      padding: const EdgeInsets.all(24),
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
    final String title;
    final String subtitle;
    if (widget.verifyOldMode) {
      title = 'ENTER CURRENT PIN';
      subtitle =
          'Verify your existing ${widget.totalLength}-digit PIN to continue';
    } else if (widget.confirmMode) {
      title = 'CONFIRM NEW PIN';
      subtitle = 'Enter the same ${widget.totalLength}-digit PIN again';
    } else {
      title = 'ENTER NEW PIN';
      subtitle = 'Create a new ${widget.totalLength}-digit security PIN';
    }
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            color: LiquidColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(color: LiquidColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildPinIndicators() {
    if (widget.verifyOldMode) {
      return _buildPinIndicator(pin: widget.oldPin, label: 'Current PIN');
    }
    return Column(
      children: [
        _buildPinIndicator(
          pin: widget.newPin,
          label: widget.confirmMode ? 'First PIN' : 'Entering PIN',
        ),
        if (widget.confirmMode) ...[
          const SizedBox(height: 16),
          _buildPinIndicator(pin: widget.confirmPin, label: 'Confirm PIN'),
        ],
      ],
    );
  }

  Widget _buildPinIndicator({
    required List<String> pin,
    required String label,
  }) {
    final spacing = widget.totalLength == 6 ? 6.0 : 12.0;
    final size = widget.totalLength == 6 ? 18.0 : 24.0;
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: LiquidColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.totalLength, (index) {
            return TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: 1),
              duration: Duration(milliseconds: 300 + (index * 50)),
              curve: Curves.elasticOut,
              builder: (context, double value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    width: size,
                    height: size,
                    margin: EdgeInsets.symmetric(horizontal: spacing),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: index < pin.length
                            ? [
                                LiquidColors.accentBlue,
                                LiquidColors.accentBlue.withValues(alpha: .56),
                              ]
                            : [
                                LiquidColors.textTertiary.withValues(
                                  alpha: .42,
                                ),
                                LiquidColors.textTertiary.withValues(
                                  alpha: .28,
                                ),
                              ],
                        center: Alignment.center,
                        radius: 0.8,
                      ),
                      boxShadow: null,
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
            LiquidColors.error.withValues(alpha: 0.1),
            LiquidColors.error.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LiquidColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: LiquidColors.error,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.error!,
              style: TextStyle(color: LiquidColors.error, fontSize: 12),
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
            onTap: widget.onCancel,
          );
        } else if (index == 10) {
          return _buildNumberButton('0');
        } else if (index == 11) {
          return _buildActionButton(
            icon: Icons.backspace_outlined,
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
            child: LiquidGlassSurface(
              borderRadius: 16,
              blur: 14,
              tintColor: LiquidColors.accentBlue,
              tintOpacity: 0.12,
              child: Center(
                child: Text(
                  number,
                  style: TextStyle(
                    fontSize: 28,
                    color: LiquidColors.textPrimary,
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
            child: LiquidGlassSurface(
              borderRadius: 16,
              blur: 14,
              tintColor: LiquidColors.accentBlue,
              tintOpacity: 0.12,
              child: Center(
                child: Icon(icon, color: LiquidColors.accentBlue, size: 26),
              ),
            ),
          ),
        );
      },
    );
  }
}
