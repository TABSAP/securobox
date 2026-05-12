import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
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

enum _CodeStage { idle, entry }

class _ForgotPinScreenState extends State<ForgotPinScreen> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  bool _resetting = false;
  bool _sendingCode = false;
  String? _error;
  String? _codeError;
  String? _emailError;
  bool _recoveryEnabled = false;
  String? _recoveryEmail;
  String? _ephemeralCode;
  _CodeStage _codeStage = _CodeStage.idle;

  @override
  void initState() {
    super.initState();
    _codeController.addListener(() {
      if (_codeError != null) {
        setState(() => _codeError = null);
      }
    });
    _emailController.addListener(() {
      if (_emailError != null) {
        setState(() => _emailError = null);
      }
    });
    _loadRecoveryState();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadRecoveryState() async {
    try {
      final enabled = await RecoveryService.instance.isEnabled();
      final email = enabled ? await RecoveryService.instance.getEmail() : null;
      if (!mounted) return;
      setState(() {
        _recoveryEnabled = enabled;
        _recoveryEmail = email;
      });
    } catch (_) {}
  }

  String _normalizeCode(String code) =>
      code.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();

  String _encodeQuery(Map<String, String> params) {
    return params.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');
  }

  Future<void> _sendFreshCode({bool requireEmailMatch = false}) async {
    final email = (_recoveryEmail ?? '').trim();
    if (email.isEmpty || _sendingCode || _resetting) return;

    if (requireEmailMatch) {
      final entered = _emailController.text.trim();
      if (entered.isEmpty) {
        setState(() => _emailError = 'Enter your recovery email');
        HapticFeedback.heavyImpact();
        return;
      }
      if (entered.toLowerCase() != email.toLowerCase()) {
        setState(
          () =>
              _emailError = 'Email doesn\'t match the one set up for recovery.',
        );
        HapticFeedback.heavyImpact();
        return;
      }
    }

    HapticFeedback.lightImpact();
    setState(() {
      _sendingCode = true;
      _codeError = null;
      _emailError = null;
      _error = null;
    });

    final code = RecoveryService.instance.generateCode();
    const subject = 'SecuroBox — PIN Reset Code';

    final uri = Uri(
      scheme: 'mailto',
      path: email,
      query: _encodeQuery({'subject': subject, 'body': code}),
    );

    try {
      bool launched = false;
      if (await canLaunchUrl(uri)) {
        launched = await launchUrl(uri);
      }
      if (!mounted) return;

      if (!launched) {
        setState(() {
          _sendingCode = false;
          _error =
              'No email app found. Set up an email app on this device '
              'so the recovery code can be sent to $email, then try again.';
        });
        HapticFeedback.heavyImpact();
        return;
      }

      setState(() {
        _ephemeralCode = code;
        _codeStage = _CodeStage.entry;
        _sendingCode = false;
        _codeController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sendingCode = false;
        _error = 'Could not open email app: ${e.toString()}';
      });
    }
  }

  Future<void> _verifyCodeAndReset() async {
    if (_resetting || _ephemeralCode == null) return;

    final entered = _codeController.text.trim();
    if (entered.isEmpty) {
      setState(() => _codeError = 'Enter the code from your email');
      HapticFeedback.heavyImpact();
      return;
    }

    if (_normalizeCode(entered) != _normalizeCode(_ephemeralCode!)) {
      setState(() => _codeError = 'Code doesn\'t match. Check your email.');
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() {
      _resetting = true;
      _codeError = null;
      _error = null;
    });
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
                      _buildEmailGate(),
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
    final items = const [
      _LossItem(
        icon: Icons.video_library_rounded,
        text: 'All imported videos, photos, audio, and documents',
      ),
      _LossItem(
        icon: Icons.camera_front_rounded,
        text: 'Break-in selfies in the intrusion log',
      ),
      _LossItem(
        icon: Icons.history_rounded,
        text: 'Download history and recycle bin',
      ),
      _LossItem(
        icon: Icons.tune_rounded,
        text: 'Custom categories, disguise mode, and recovery email',
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

  Widget _buildEmailGate() {
    if (!_recoveryEnabled || (_recoveryEmail ?? '').trim().isEmpty) {
      return _buildNoRecoveryWarning();
    }
    if (_codeStage == _CodeStage.idle) {
      return _buildSendCodeStage();
    }
    return _buildEnterCodeStage();
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
                  'Recovery email not set up',
                  style: TextStyle(
                    color: LiquidColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'PIN reset requires a recovery email. To enable it, open Settings → PIN Recovery → Set up recovery, then come back here.',
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

  Widget _buildSendCodeStage() {
    final masked = RecoveryService.mask(_recoveryEmail!.trim());
    final hasEmailError = _emailError != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: LiquidColors.textPrimary.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: LiquidColors.textPrimary.withValues(alpha: 0.08),
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
                  Icons.outgoing_mail,
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
                      'Confirm your recovery email',
                      style: TextStyle(
                        color: LiquidColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Enter the email you set up for recovery. A one-time code will be sent there once it matches.',
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
            'RECOVERY EMAIL',
            style: TextStyle(
              color: LiquidColors.textSecondary,
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
          enabled: !_sendingCode && !_resetting,
          cursorColor: LiquidColors.accentBlue,
          style: TextStyle(
            color: LiquidColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: masked,
            hintStyle: TextStyle(
              color: LiquidColors.textTertiary,
              fontSize: 13,
              fontFamily: 'monospace',
            ),
            filled: true,
            fillColor: LiquidColors.textPrimary.withValues(alpha: 0.04),
            prefixIcon: Icon(
              Icons.alternate_email_rounded,
              color: hasEmailError
                  ? LiquidColors.error
                  : LiquidColors.textTertiary,
              size: 18,
            ),
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
                color: hasEmailError
                    ? LiquidColors.error
                    : LiquidColors.textPrimary.withValues(alpha: 0.08),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: hasEmailError
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
        if (hasEmailError) ...[
          const SizedBox(height: 8),
          _buildError(_emailError!),
        ],
        const SizedBox(height: 16),
        SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed: _sendingCode
                ? null
                : () => _sendFreshCode(requireEmailMatch: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: LiquidColors.accentBlue,
              disabledBackgroundColor: LiquidColors.accentBlue.withValues(
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
                if (_sendingCode)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: LiquidColors.textPrimary,
                    ),
                  )
                else
                  const Icon(
                    Icons.mail_outline_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                const SizedBox(width: 10),
                Text(
                  _sendingCode ? 'Opening email…' : 'Send recovery code',
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

  Widget _buildEnterCodeStage() {
    final masked = RecoveryService.mask(_recoveryEmail!.trim());
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
                  Icons.mark_email_read_outlined,
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
                      'Code sent',
                      style: TextStyle(
                        color: LiquidColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Open the email at $masked and paste the code below.',
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
            'RECOVERY CODE',
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
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: LiquidColors.textPrimary,
                    ),
                  )
                else
                  const Icon(Icons.lock_reset_rounded, size: 18),
                const SizedBox(width: 10),
                Text(
                  _resetting ? 'Resetting PIN…' : 'Verify & Reset PIN',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: TextButton(
            onPressed: (_resetting || _sendingCode) ? null : _sendFreshCode,
            child: Text(
              _sendingCode ? 'Sending…' : 'Re-send code',
              style: TextStyle(
                color: LiquidColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
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
