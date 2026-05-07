import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player_app/app_lock_screen/widgets/liquid_action_button.dart';
import 'package:video_player_app/app_lock_screen/widgets/liquid_number_button.dart';
import 'package:video_player_app/app_lock_screen/widgets/liquid_pin_dots.dart';
import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/utils/pin_crypto.dart';
import 'package:video_player_app/utils/recovery_service.dart';
import 'package:video_player_app/utils/session_manager.dart';

class RecoveryEntryScreen extends StatefulWidget {
  const RecoveryEntryScreen({super.key});

  @override
  State<RecoveryEntryScreen> createState() => _RecoveryEntryScreenState();
}

enum _Stage { code, pickLength, newPin, confirmPin, saving }

class _RecoveryEntryScreenState extends State<RecoveryEntryScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  _Stage _stage = _Stage.code;
  bool _verifying = false;
  String? _codeError;
  String? _pinError;
  int _pinLength = 4;
  String _newPin = '';
  String _confirmPin = '';

  static const _pinLengths = [4, 6];

  @override
  void initState() {
    super.initState();
    _emailController.addListener(() => setState(() {}));
    _codeController.addListener(() => setState(() {}));
    _loadPreferredPinLength();
  }

  Future<void> _loadPreferredPinLength() async {
    try {
      final stored = await PinCrypto.instance.getPinLength();
      if (mounted) setState(() => _pinLength = stored);
    } catch (_) {}
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    if (_verifying) return;
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    if (email.isEmpty || code.isEmpty) {
      setState(() => _codeError = 'Enter both your recovery email and code');
      return;
    }
    setState(() {
      _verifying = true;
      _codeError = null;
    });
    HapticFeedback.lightImpact();
    try {
      final ok = await RecoveryService.instance.verifyEmailAndCode(
        email: email,
        code: code,
      );
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _verifying = false;
          _codeError =
              'Email and code don\'t match what\'s on this device.';
        });
        HapticFeedback.heavyImpact();
        return;
      }
      setState(() {
        _verifying = false;
        _stage = _Stage.pickLength;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _codeError = 'Verification failed: ${e.toString()}';
      });
    }
  }

  void _selectLength(int length) {
    HapticFeedback.selectionClick();
    setState(() {
      _pinLength = length;
      _stage = _Stage.newPin;
      _newPin = '';
      _confirmPin = '';
      _pinError = null;
    });
  }

  void _onPinDigit(String digit) {
    HapticFeedback.lightImpact();
    setState(() {
      _pinError = null;
      if (_stage == _Stage.newPin) {
        if (_newPin.length < _pinLength) _newPin += digit;
        if (_newPin.length == _pinLength) {
          if (_isWeak(_newPin)) {
            _pinError = 'Please choose a stronger PIN';
            _newPin = '';
            return;
          }
          _stage = _Stage.confirmPin;
        }
      } else if (_stage == _Stage.confirmPin) {
        if (_confirmPin.length < _pinLength) _confirmPin += digit;
        if (_confirmPin.length == _pinLength) {
          if (_confirmPin != _newPin) {
            _pinError = 'PINs don\'t match — try again';
            _newPin = '';
            _confirmPin = '';
            _stage = _Stage.newPin;
            return;
          }
          _saveNewPin();
        }
      }
    });
  }

  void _onPinDelete() {
    HapticFeedback.selectionClick();
    setState(() {
      _pinError = null;
      if (_stage == _Stage.newPin && _newPin.isNotEmpty) {
        _newPin = _newPin.substring(0, _newPin.length - 1);
      } else if (_stage == _Stage.confirmPin && _confirmPin.isNotEmpty) {
        _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
      }
    });
  }

  bool _isWeak(String pin) {
    if (RegExp(r'^(\d)\1+$').hasMatch(pin)) return true;
    const ascending = '0123456789';
    const descending = '9876543210';
    if (ascending.contains(pin) || descending.contains(pin)) return true;
    const known = {
      '1234', '4321', '0000', '1111', '2222', '3333', '4444',
      '5555', '6666', '7777', '8888', '9999', '123456', '654321',
      '111111', '000000', '121212', '696969', '112233', '789456',
    };
    return known.contains(pin);
  }

  Future<void> _saveNewPin() async {
    setState(() => _stage = _Stage.saving);
    try {
      await PinCrypto.instance.setPin(_newPin);
      await SessionManager.instance.unlock();
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.newPin;
        _newPin = '';
        _confirmPin = '';
        _pinError = 'Failed to save: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LiquidColors.backgroundDeep,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              LiquidColors.backgroundDeep,
              LiquidColors.backgroundMid,
              LiquidColors.backgroundLight,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: anim.drive(Tween<Offset>(
                        begin: const Offset(0.04, 0),
                        end: Offset.zero,
                      )),
                      child: child,
                    ),
                  ),
                  child: _buildStage(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: _stage == _Stage.saving
                ? null
                : () => Navigator.of(context).pop(false),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          const SizedBox(width: 4),
          Text(
            _stage == _Stage.code ? 'Enter Recovery Code' : 'Set a New PIN',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStage() {
    switch (_stage) {
      case _Stage.code:
        return _buildCodeStage();
      case _Stage.pickLength:
        return _buildLengthStage();
      case _Stage.newPin:
      case _Stage.confirmPin:
        return _buildPinEntryStage();
      case _Stage.saving:
        return _buildSavingStage();
    }
  }

  Widget _buildCodeStage() {
    return SingleChildScrollView(
      key: const ValueKey('code'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHero(
            icon: Icons.vpn_key_rounded,
            title: 'Recover with email + code',
            subtitle:
                'Enter the email you used at setup and the 16-character code from that message.',
          ),
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'RECOVERY EMAIL',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ),
          TextField(
            controller: _emailController,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.emailAddress,
            cursorColor: LiquidColors.accentBlue,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: 'you@example.com',
              hintStyle: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              prefixIcon: Icon(
                Icons.alternate_email_rounded,
                color: Colors.grey.shade500,
                size: 18,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: LiquidColors.accentBlue, width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'RECOVERY CODE',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ),
          TextField(
            controller: _codeController,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            cursorColor: LiquidColors.accentBlue,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              hintText: 'XXXX-XXXX-XXXX-XXXX',
              hintStyle: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 3,
                fontFamily: 'monospace',
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: LiquidColors.accentBlue, width: 1.4),
              ),
            ),
            onSubmitted: (_) => _verifyCode(),
          ),
          if (_codeError != null) ...[
            const SizedBox(height: 10),
            _buildErrorPill(_codeError!),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Dashes and spaces are optional. The check is case-insensitive.',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _verifying ? null : _verifyCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: LiquidColors.accentBlue,
                disabledBackgroundColor:
                    LiquidColors.accentBlue.withValues(alpha: 0.3),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_verifying)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else
                    const Icon(Icons.check_rounded, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    _verifying ? 'Verifying…' : 'Verify code',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLengthStage() {
    return SingleChildScrollView(
      key: const ValueKey('length'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHero(
            icon: Icons.pin_rounded,
            title: 'Choose PIN length',
            subtitle:
                'Pick how long your new PIN should be. You can change this later in Settings.',
          ),
          const SizedBox(height: 28),
          for (final len in _pinLengths) ...[
            _buildLengthOption(len),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildLengthOption(int len) {
    final selected = _pinLength == len;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _selectLength(len),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: selected
                ? LiquidColors.accentBlue.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? LiquidColors.accentBlue
                  : Colors.white.withValues(alpha: 0.08),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected
                      ? LiquidColors.accentBlue.withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$len',
                  style: TextStyle(
                    color: selected
                        ? LiquidColors.accentBlue
                        : Colors.grey.shade400,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$len digits',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      len == 4
                          ? 'Quick to type, less entropy'
                          : 'Stronger, takes a moment longer',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.chevron_right_rounded,
                color: selected
                    ? LiquidColors.accentBlue
                    : Colors.grey.shade500,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinEntryStage() {
    final entered = _stage == _Stage.newPin ? _newPin : _confirmPin;
    return SingleChildScrollView(
      key: const ValueKey('pin'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildHero(
            icon: Icons.lock_outline_rounded,
            title: _stage == _Stage.newPin
                ? 'Enter new PIN'
                : 'Confirm new PIN',
            subtitle: _stage == _Stage.newPin
                ? 'Pick a $_pinLength-digit PIN you can remember.'
                : 'Type it again to make sure they match.',
          ),
          const SizedBox(height: 28),
          LiquidPinDots(
            enteredLength: entered.length,
            totalLength: _pinLength,
            hasError: _pinError != null,
          ),
          if (_pinError != null) ...[
            const SizedBox(height: 12),
            _buildErrorPill(_pinError!),
          ],
          const SizedBox(height: 28),
          GridView.builder(
            shrinkWrap: true,
            itemCount: 12,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1.3,
            ),
            itemBuilder: (context, index) {
              if (index == 9) {
                return const SizedBox.shrink();
              }
              if (index == 10) {
                return LiquidNumberButton(
                  number: '0',
                  onPressed: () => _onPinDigit('0'),
                );
              }
              if (index == 11) {
                return LiquidActionButton(
                  icon: Icons.backspace_outlined,
                  color: LiquidColors.error,
                  onPressed: _onPinDelete,
                );
              }
              final digit = '${index + 1}';
              return LiquidNumberButton(
                number: digit,
                onPressed: () => _onPinDigit(digit),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSavingStage() {
    return Center(
      key: const ValueKey('saving'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: LiquidColors.accentBlue,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Saving new PIN…',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  LiquidColors.accentBlue.withValues(alpha: 0.28),
                  LiquidColors.accentBlue.withValues(alpha: 0.0),
                ],
              ),
            ),
            child: Icon(icon, size: 36, color: LiquidColors.accentBlue),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorPill(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: LiquidColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: LiquidColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded,
              color: LiquidColors.error, size: 14),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              message,
              style: TextStyle(
                color: LiquidColors.error,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
