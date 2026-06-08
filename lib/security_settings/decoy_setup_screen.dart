import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player_app/app_lock_screen/widgets/liquid_action_button.dart';
import 'package:video_player_app/app_lock_screen/widgets/liquid_lock_header.dart';
import 'package:video_player_app/app_lock_screen/widgets/liquid_number_button.dart';
import 'package:video_player_app/app_lock_screen/widgets/liquid_pin_dots.dart';
import 'package:video_player_app/utils/decoy_service.dart';
import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/utils/pin_crypto.dart';

class DecoySetupScreen extends StatefulWidget {
  const DecoySetupScreen({super.key});

  @override
  State<DecoySetupScreen> createState() => _DecoySetupScreenState();
}

enum _Stage { loading, manage, pickLength, enter, confirm, verifyReal, done }

class _DecoySetupScreenState extends State<DecoySetupScreen>
    with SingleTickerProviderStateMixin {
  _Stage _stage = _Stage.loading;
  bool _hasFake = false;
  int _pinLength = PinCrypto.defaultPinLength;
  int _realPinLength = PinCrypto.defaultPinLength;
  String _newPin = '';
  String _confirmPin = '';
  String _realPin = '';
  String? _error;
  String _doneMessage = '';

  late final AnimationController _shakeCtrl;
  late final Animation<double> _shake;

  static const _knownBad = {
    '1234',
    '4321',
    '0000',
    '1111',
    '2222',
    '3333',
    '4444',
    '5555',
    '6666',
    '7777',
    '8888',
    '9999',
    '123456',
    '654321',
    '111111',
    '000000',
    '121212',
    '696969',
    '112233',
    '789456',
  };

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shake = Tween<double>(
      begin: -10,
      end: 10,
    ).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn));
    _load();
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final has = await DecoyService.instance.hasFakePin();
    final realLen = await PinCrypto.instance.getPinLength();
    if (!mounted) return;
    setState(() {
      _hasFake = has;
      _realPinLength = realLen;
      _stage = has ? _Stage.manage : _Stage.pickLength;
    });
  }

  void _shakeNow() {
    HapticFeedback.heavyImpact();
    _shakeCtrl.forward().then((_) => _shakeCtrl.reverse());
  }

  bool _isWeak(String pin) {
    if (RegExp(r'^(\d)\1+$').hasMatch(pin)) return true;
    if ('0123456789'.contains(pin) || '9876543210'.contains(pin)) return true;
    return _knownBad.contains(pin);
  }

  void _onDigit(String d) {
    HapticFeedback.lightImpact();
    setState(() {
      _error = null;
      switch (_stage) {
        case _Stage.enter:
          if (_newPin.length < _pinLength) _newPin += d;
          if (_newPin.length == _pinLength) {
            if (_isWeak(_newPin)) {
              _error = 'Choose a less obvious PIN';
              _newPin = '';
            } else {
              _stage = _Stage.confirm;
            }
          }
        case _Stage.confirm:
          if (_confirmPin.length < _pinLength) _confirmPin += d;
          if (_confirmPin.length == _pinLength) _finishSetup();
        case _Stage.verifyReal:
          if (_realPin.length < _realPinLength) _realPin += d;
          if (_realPin.length == _realPinLength) _finishDisable();
        default:
          break;
      }
    });
  }

  void _onDelete() {
    HapticFeedback.selectionClick();
    setState(() {
      _error = null;
      switch (_stage) {
        case _Stage.enter:
          if (_newPin.isNotEmpty) {
            _newPin = _newPin.substring(0, _newPin.length - 1);
          }
        case _Stage.confirm:
          if (_confirmPin.isNotEmpty) {
            _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
          }
        case _Stage.verifyReal:
          if (_realPin.isNotEmpty) {
            _realPin = _realPin.substring(0, _realPin.length - 1);
          }
        default:
          break;
      }
    });
  }

  Future<void> _finishSetup() async {
    if (_newPin != _confirmPin) {
      _shakeNow();
      setState(() {
        _error = 'PINs do not match';
        _newPin = '';
        _confirmPin = '';
        _stage = _Stage.enter;
      });
      return;
    }
    if (await PinCrypto.instance.verifyPin(_newPin)) {
      if (!mounted) return;
      _shakeNow();
      setState(() {
        _error = 'Decoy PIN must differ from your real PIN';
        _newPin = '';
        _confirmPin = '';
        _stage = _Stage.enter;
      });
      return;
    }
    await DecoyService.instance.setupFakePin(_newPin);
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _hasFake = true;
      _doneMessage =
          'Decoy mode is active. Entering this PIN at the lock screen opens a '
          'separate, harmless vault — your real files stay hidden and isolated.';
      _stage = _Stage.done;
    });
  }

  Future<void> _finishDisable() async {
    final ok = await PinCrypto.instance.verifyPin(_realPin);
    if (!mounted) return;
    if (!ok) {
      _shakeNow();
      setState(() {
        _error = 'Incorrect PIN';
        _realPin = '';
      });
      return;
    }
    await DecoyService.instance.clearFakePin(wipeDecoyVault: true);
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _hasFake = false;
      _doneMessage =
          'Decoy mode is off. The decoy vault and its PIN have been removed.';
      _stage = _Stage.done;
    });
  }

  void _startChange() {
    setState(() {
      _newPin = '';
      _confirmPin = '';
      _error = null;
      _stage = _Stage.pickLength;
    });
  }

  void _startDisable() {
    setState(() {
      _realPin = '';
      _error = null;
      _stage = _Stage.verifyReal;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LiquidColors.backgroundDeep,
      body: Container(
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
              _appBar(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: _body(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _appBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: LiquidColors.textPrimary,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 4),
          Text(
            'Decoy Mode',
            style: TextStyle(
              color: LiquidColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    switch (_stage) {
      case _Stage.loading:
        return SizedBox(
          height: 200,
          child: Center(
            child: CircularProgressIndicator(color: LiquidColors.accentBlue),
          ),
        );
      case _Stage.manage:
        return _manageBody();
      case _Stage.pickLength:
        return _lengthBody();
      case _Stage.enter:
      case _Stage.confirm:
      case _Stage.verifyReal:
        return _padBody();
      case _Stage.done:
        return _doneBody();
    }
  }

  Widget _explainerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            LiquidColors.accentPurple.withValues(alpha: 0.14),
            LiquidColors.accentBlue.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: LiquidColors.accentPurple.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.shield_outlined,
            color: LiquidColors.accentPurple,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'A decoy PIN opens a second, completely separate vault — its own '
              'encryption key, its own files, its own storage stats. Under pressure '
              'you can hand over the decoy PIN; your real encrypted vault stays '
              'invisible and untouched. Nothing in the app reveals decoy mode exists.',
              style: TextStyle(
                color: LiquidColors.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _manageBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        _explainerCard(),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: LiquidColors.success.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: LiquidColors.success.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: LiquidColors.success,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Decoy PIN is active.',
                  style: TextStyle(
                    color: LiquidColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _startChange,
            icon: const Icon(
              Icons.password_rounded,
              size: 18,
              color: Colors.white,
            ),
            label: const Text(
              'Change decoy PIN',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: LiquidColors.accentBlue,
              foregroundColor: LiquidColors.textPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 52,
          child: OutlinedButton.icon(
            onPressed: _startDisable,
            icon: Icon(
              Icons.lock_open_rounded,
              size: 18,
              color: LiquidColors.error,
            ),
            label: Text(
              'Disable decoy mode',
              style: TextStyle(color: LiquidColors.error),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: LiquidColors.error.withValues(alpha: 0.5),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Disabling requires your real PIN, and erases the decoy vault.',
          textAlign: TextAlign.center,
          style: TextStyle(color: LiquidColors.textTertiary, fontSize: 11),
        ),
      ],
    );
  }

  Widget _lengthBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        _explainerCard(),
        const SizedBox(height: 24),
        Text(
          'Choose decoy PIN length',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: LiquidColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        _lengthOption(4, '4-digit'),
        const SizedBox(height: 10),
        _lengthOption(6, '6-digit (recommended)'),
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: () => setState(() {
              _newPin = '';
              _confirmPin = '';
              _stage = _Stage.enter;
            }),
            style: ElevatedButton.styleFrom(
              backgroundColor: LiquidColors.accentBlue,
              foregroundColor: LiquidColors.textPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Continue',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _lengthOption(int digits, String label) {
    final selected = _pinLength == digits;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _pinLength = digits);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? LiquidColors.accentBlue.withValues(alpha: 0.16)
              : LiquidColors.textPrimary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? LiquidColors.accentBlue
                : LiquidColors.textPrimary.withValues(alpha: 0.08),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected
                  ? LiquidColors.accentBlue
                  : LiquidColors.textTertiary,
              size: 18,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? LiquidColors.textPrimary
                    : LiquidColors.textSecondary,
                fontSize: 15,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _padBody() {
    final isConfirm = _stage == _Stage.confirm;
    final isVerify = _stage == _Stage.verifyReal;
    final entered = isVerify ? _realPin : (isConfirm ? _confirmPin : _newPin);
    final total = isVerify ? _realPinLength : _pinLength;
    final title = isVerify
        ? 'Enter your real PIN'
        : (isConfirm ? 'Confirm decoy PIN' : 'Create decoy PIN');
    final subtitle = isVerify
        ? 'Required to disable decoy mode'
        : (isConfirm
              ? 'Re-enter the same $total-digit PIN'
              : 'Pick a $total-digit PIN you can share under pressure');

    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                LiquidColors.backgroundLight.withValues(alpha: .3),
                LiquidColors.backgroundMid.withValues(alpha: .4),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: LiquidColors.accentPurple.withValues(alpha: .2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .3),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LiquidLockHeader(title: title, subtitle: subtitle),
              const SizedBox(height: 28),
              AnimatedBuilder(
                animation: _shakeCtrl,
                builder: (context, _) => Transform.translate(
                  offset: Offset(_shake.value, 0),
                  child: LiquidPinDots(
                    enteredLength: entered.length,
                    totalLength: total,
                    hasError: _error != null,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: LiquidColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: LiquidColors.error.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: LiquidColors.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              GridView.builder(
                shrinkWrap: true,
                itemCount: 12,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.2,
                ),
                itemBuilder: (context, index) {
                  if (index == 9) {
                    return LiquidActionButton(
                      icon: Icons.arrow_back_rounded,
                      color: LiquidColors.accentBlue,
                      onPressed: () => setState(() {
                        _error = null;
                        if (isVerify) {
                          _stage = _Stage.manage;
                        } else if (isConfirm) {
                          _confirmPin = '';
                          _stage = _Stage.enter;
                        } else {
                          _newPin = '';
                          _stage = _Stage.pickLength;
                        }
                      }),
                    );
                  }
                  if (index == 10) {
                    return LiquidNumberButton(
                      number: '0',
                      onPressed: () => _onDigit('0'),
                    );
                  }
                  if (index == 11) {
                    return LiquidActionButton(
                      icon: Icons.backspace,
                      color: LiquidColors.error,
                      onPressed: _onDelete,
                    );
                  }
                  return LiquidNumberButton(
                    number: '${index + 1}',
                    onPressed: () => _onDigit('${index + 1}'),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _doneBody() {
    final ok = _hasFake;
    return Column(
      children: [
        const SizedBox(height: 36),
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: ok
                  ? [LiquidColors.success, LiquidColors.accentBlue]
                  : [LiquidColors.warning, LiquidColors.accentOrange],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: (ok ? LiquidColors.success : LiquidColors.warning)
                    .withValues(alpha: 0.4),
                blurRadius: 28,
                spreadRadius: 3,
              ),
            ],
          ),
          child: Icon(
            ok ? Icons.shield_rounded : Icons.lock_open_rounded,
            color: Colors.white,
            size: 44,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          ok ? 'Decoy mode enabled' : 'Decoy mode disabled',
          style: TextStyle(
            color: LiquidColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            _doneMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: LiquidColors.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: ok
                  ? LiquidColors.success
                  : LiquidColors.accentBlue,
              foregroundColor: LiquidColors.textPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Done',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
