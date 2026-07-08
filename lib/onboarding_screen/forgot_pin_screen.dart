import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:video_player_app/widgets/app_loader.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_app/onboarding_screen/onboarding_screen.dart';
import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/utils/pin_crypto.dart';
import 'package:video_player_app/utils/recovery_service.dart';
import 'package:video_player_app/utils/session_manager.dart';

class ForgotPinScreen extends StatefulWidget {
  const ForgotPinScreen({super.key});

  @override
  State<ForgotPinScreen> createState() => _ForgotPinScreenState();
}

class _ForgotPinScreenState extends State<ForgotPinScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _resetting = false;
  String? _error;
  String? _codeError;
  bool _recoveryEnabled = false;

  @override
  void initState() {
    super.initState();
    _codeController.addListener(_onCodeChanged);
    _loadRecoveryState();
  }

  @override
  void dispose() {
    _codeController.removeListener(_onCodeChanged);
    _codeController.dispose();
    super.dispose();
  }

  int _normalizedLength(String raw) =>
      raw.replaceAll(RegExp(r'[\s\-]'), '').length;

  void _onCodeChanged() {
    if (_codeError != null || _error != null) {
      setState(() {
        _codeError = null;
        _error = null;
      });
    }
    // Real-time verification: once a full-length key is entered, verify it.
    if (!_resetting && _normalizedLength(_codeController.text) >= 16) {
      _verifyCodeAndReset();
    }
  }

  Future<void> _loadRecoveryState() async {
    try {
      final enabled = await RecoveryService.instance.isEnabled();
      if (!mounted) return;
      setState(() => _recoveryEnabled = enabled);
    } catch (_) {}
  }

  Future<void> _verifyCodeAndReset() async {
    if (_resetting) return;

    final entered = _codeController.text.trim();
    if (entered.isEmpty) {
      setState(() => _codeError = 'Enter your Recovery Key');
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() {
      _resetting = true;
      _codeError = null;
      _error = null;
    });

    final ok = await RecoveryService.instance.verify(entered);
    if (!mounted) return;

    if (!ok) {
      HapticFeedback.heavyImpact();
      setState(() {
        _resetting = false;
        _codeError =
            'That Recovery Key doesn\'t match. Check the key you saved when you set up recovery.';
      });
      return;
    }

    HapticFeedback.heavyImpact();
    try {
      await PinCrypto.instance.clearPin();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('hasOnboarded');

      await SessionManager.instance.init();

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resetting = false;
        _error = 'Reset failed: ${e.toString()}';
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
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      _buildExplainer(),
                      const SizedBox(height: 22),
                      _buildLossList(),
                      const SizedBox(height: 22),
                      _buildKeyGate(),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        _buildError(_error!),
                      ],
                      const SizedBox(height: 24),
                      _buildCancelButton(),
                    ],
                  ),
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
            onPressed: _resetting ? null : () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.arrow_back_rounded,
              color: LiquidColors.textPrimary,
            ),
            tooltip: 'Back',
          ),
          const SizedBox(width: 4),
          Text(
            'Forgot PIN',
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

  Widget _buildExplainer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            LiquidColors.accentBlue.withValues(alpha: 0.14),
            LiquidColors.accentPurple.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: LiquidColors.accentBlue.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: LiquidColors.accentBlue, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your files are encrypted with a key kept in your device\'s secure storage, separate from your PIN. Resetting the PIN keeps every video, photo, audio file, and document exactly where it is — you\'ll just choose a new PIN to unlock the app.',
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

  Widget _buildLossList() {
    final items = [
      const _LossItem(
        icon: Icons.video_library_rounded,
        text: 'All imported videos, photos, audio, and documents',
      ),
      const _LossItem(
        icon: Icons.camera_front_rounded,
        text: 'Break-in selfies in the intrusion log',
      ),
      const _LossItem(
        icon: Icons.history_rounded,
        text: 'Download history and recycle bin',
      ),
      _LossItem(
        icon: Icons.tune_rounded,
        text: Platform.isAndroid
            ? 'Custom categories, disguise mode, and Recovery Key'
            : 'Custom categories and Recovery Key',
      ),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: LiquidColors.textPrimary.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: LiquidColors.textPrimary.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: 14,
                color: LiquidColors.success,
              ),
              const SizedBox(width: 6),
              Text(
                'WHAT STAYS INTACT',
                style: TextStyle(
                  color: LiquidColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < items.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: LiquidColors.success.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    items[i].icon,
                    size: 14,
                    color: LiquidColors.success,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      items[i].text,
                      style: TextStyle(
                        color: LiquidColors.textSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (i < items.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildKeyGate() {
    if (!_recoveryEnabled) {
      return _buildNoRecoveryWarning();
    }
    return _buildEnterKeyStage();
  }

  Widget _buildNoRecoveryWarning() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LiquidColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LiquidColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: LiquidColors.warning,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recovery Key not set up',
                  style: TextStyle(
                    color: LiquidColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'PIN reset requires your Recovery Key. Without it, the only option is to wipe the vault.',
                  style: TextStyle(
                    color: LiquidColors.textSecondary,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnterKeyStage() {
    final hasCodeError = _codeError != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                LiquidColors.accentBlue.withValues(alpha: 0.16),
                LiquidColors.accentPurple.withValues(alpha: 0.06),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: LiquidColors.accentBlue.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: LiquidColors.accentBlue.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.vpn_key_rounded,
                  color: LiquidColors.accentBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enter your Recovery Key',
                      style: TextStyle(
                        color: LiquidColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Type or paste the Recovery Key you saved when you set up recovery. It\'s verified as you enter it.',
                      style: TextStyle(
                        color: LiquidColors.textSecondary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'RECOVERY KEY',
            style: TextStyle(
              color: LiquidColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ),
        TextField(
          controller: _codeController,
          autofocus: true,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.characters,
          textAlign: TextAlign.center,
          cursorColor: LiquidColors.accentBlue,
          enabled: !_resetting,
          onSubmitted: (_) => _verifyCodeAndReset(),
          style: TextStyle(
            color: LiquidColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            fontFamily: 'monospace',
          ),
          decoration: InputDecoration(
            hintText: 'XXXX-XXXX-XXXX-XXXX',
            hintStyle: TextStyle(
              color: LiquidColors.textTertiary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              fontFamily: 'monospace',
            ),
            filled: true,
            fillColor: LiquidColors.textPrimary.withValues(alpha: 0.04),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: LiquidColors.textPrimary.withValues(alpha: 0.08),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: hasCodeError
                    ? LiquidColors.error
                    : LiquidColors.textPrimary.withValues(alpha: 0.08),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: hasCodeError
                    ? LiquidColors.error
                    : LiquidColors.accentBlue,
                width: 1.4,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: LiquidColors.textPrimary.withValues(alpha: 0.04),
              ),
            ),
          ),
        ),
        if (hasCodeError) ...[
          const SizedBox(height: 8),
          _buildError(_codeError!),
        ],
        const SizedBox(height: 16),
        SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed: _resetting ? null : _verifyCodeAndReset,
            style: ElevatedButton.styleFrom(
              backgroundColor: LiquidColors.success,
              disabledBackgroundColor: LiquidColors.success.withValues(
                alpha: 0.4,
              ),
              foregroundColor: LiquidColors.textPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_resetting)
                  AppLoader(size: 22, color: Colors.white)
                else
                  const Icon(
                    Icons.lock_reset_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                const SizedBox(width: 10),
                Text(
                  _resetting ? 'Resetting PIN…' : 'Reset PIN',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: LiquidColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LiquidColors.error.withValues(alpha: 0.4)),
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

  Widget _buildCancelButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: TextButton(
        onPressed: _resetting ? null : () => Navigator.of(context).pop(),
        child: Text(
          'Cancel',
          style: TextStyle(
            color: LiquidColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _LossItem {
  final IconData icon;
  final String text;

  const _LossItem({required this.icon, required this.text});
}
