import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/utils/pin_crypto.dart';

class PinUnlockDialog extends StatefulWidget {
  final int pinLength;
  final String title;
  final String subtitle;

  const PinUnlockDialog({
    super.key,
    required this.pinLength,
    this.title = 'Enter your PIN',
    this.subtitle = 'Confirm with your app PIN',
  });

  static Future<bool> show(
    BuildContext context, {
    String title = 'Enter your PIN',
    String subtitle = 'Confirm with your app PIN',
  }) async {
    if (!await PinCrypto.instance.hasPin()) return false;
    final pinLength = await PinCrypto.instance.getPinLength();
    if (!context.mounted) return false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => PinUnlockDialog(
        pinLength: pinLength,
        title: title,
        subtitle: subtitle,
      ),
    );
    return ok == true;
  }

  @override
  State<PinUnlockDialog> createState() => _PinUnlockDialogState();
}

class _PinUnlockDialogState extends State<PinUnlockDialog> {
  String _entered = '';
  bool _error = false;
  bool _checking = false;

  void _press(String digit) {
    if (_checking || _entered.length >= widget.pinLength) return;
    HapticFeedback.lightImpact();
    setState(() {
      _entered += digit;
      _error = false;
    });
    if (_entered.length == widget.pinLength) _verify();
  }

  void _backspace() {
    if (_checking || _entered.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _entered = _entered.substring(0, _entered.length - 1);
      _error = false;
    });
  }

  Future<void> _verify() async {
    setState(() => _checking = true);
    final ok = await PinCrypto.instance.verifyPin(_entered);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    HapticFeedback.heavyImpact();
    setState(() {
      _entered = '';
      _error = true;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          gradient: LiquidColors.cardGradient,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: LiquidColors.textPrimary.withValues(alpha: 0.06),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: LiquidColors.primaryGradient,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: LiquidColors.primaryStart.withValues(alpha: 0.4),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.lock_rounded, color: Colors.white, size: 30),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: LiquidColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _error ? 'Incorrect PIN — try again' : widget.subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: _error ? LiquidColors.error : LiquidColors.textTertiary,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.pinLength, (i) {
                  final filled = i < _entered.length;
                  final color = _error
                      ? LiquidColors.error
                      : LiquidColors.accentBlue;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? color : Colors.transparent,
                      border: Border.all(
                        color: filled ? color : LiquidColors.textTertiary,
                        width: 1.5,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 18),
              ..._keypadRows(),
              const SizedBox(height: 2),
              TextButton(
                onPressed: _checking
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: LiquidColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _keypadRows() {
    const layout = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '<'],
    ];
    return [
      for (final row in layout)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final k in row)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  child: SizedBox(
                    width: 58,
                    height: 50,
                    child: k.isEmpty ? null : _keyButton(k),
                  ),
                ),
            ],
          ),
        ),
    ];
  }

  Widget _keyButton(String k) {
    return Material(
      color: LiquidColors.textPrimary.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => k == '<' ? _backspace() : _press(k),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: LiquidColors.textPrimary.withValues(alpha: 0.08),
            ),
          ),
          child: k == '<'
              ? Icon(
                  Icons.backspace_outlined,
                  size: 20,
                  color: LiquidColors.textSecondary,
                )
              : Text(
                  k,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: LiquidColors.textPrimary,
                  ),
                ),
        ),
      ),
    );
  }
}
