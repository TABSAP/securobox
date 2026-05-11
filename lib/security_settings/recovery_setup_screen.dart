import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player_app/utils/flush_bar_helper.dart';
import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/utils/recovery_service.dart';

class RecoverySetupScreen extends StatefulWidget {
  const RecoverySetupScreen({super.key});

  @override
  State<RecoverySetupScreen> createState() => _RecoverySetupScreenState();
}

enum _Stage { collectEmail, showCode }

class _RecoverySetupScreenState extends State<RecoverySetupScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  _Stage _stage = _Stage.collectEmail;
  String _code = '';
  bool _emailSent = false;
  bool _saving = false;
  String? _saveError;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return 'Enter your email';
    final ok = RegExp(
      r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$',
    ).hasMatch(value);
    if (!ok) return 'That doesn\'t look like a valid email';
    return null;
  }

  void _proceedToCode() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    HapticFeedback.lightImpact();
    setState(() {
      _code = RecoveryService.instance.generateCode();
      _stage = _Stage.showCode;
    });
  }

  Future<void> _openEmailClient() async {
    HapticFeedback.lightImpact();
    final email = _emailController.text.trim();
    const subject = 'SecuroBox — Recovery Code';
    final body = _code;

    final uri = Uri(
      scheme: 'mailto',
      path: email,
      query: _encodeQuery({
        'subject': subject,
        'body': body,
      }),
    );

    try {
      if (await canLaunchUrl(uri) && await launchUrl(uri)) {
        if (!mounted) return;
        setState(() => _emailSent = true);
      } else {
        if (!mounted) return;
        await Clipboard.setData(ClipboardData(text: _code));
        if (!mounted) return;
        FlushBarHelper.flushBarInfoMessage(
          'No email app found — code copied to clipboard. Email it to yourself manually.',
          context,
        );
        setState(() => _emailSent = true);
      }
    } catch (e) {
      if (!mounted) return;
      FlushBarHelper.flushBarErrorMessage(
        'Could not open email app: ${e.toString()}',
        context,
      );
    }
  }

  String _encodeQuery(Map<String, String> params) {
    return params.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');
  }

  Future<void> _copyCode() async {
    HapticFeedback.lightImpact();
    await Clipboard.setData(ClipboardData(text: _code));
    if (!mounted) return;
    FlushBarHelper.flushBarSuccessMessage('Recovery code copied', context);
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await RecoveryService.instance.save(
        code: _code,
        email: _emailController.text.trim(),
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = 'Failed to save: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LiquidColors.backgroundDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [LiquidColors.backgroundDeep, LiquidColors.backgroundMid],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [LiquidColors.accentBlue, LiquidColors.accentPurple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Icon(
                  Icons.restore_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Set Up Recovery',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
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
          top: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: anim.drive(
                    Tween<Offset>(
                      begin: const Offset(0.04, 0),
                      end: Offset.zero,
                    ),
                  ),
                  child: child,
                ),
              ),
              child: _stage == _Stage.collectEmail
                  ? _buildEmailStage()
                  : _buildCodeStage(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailStage() {
    return Column(
      key: const ValueKey('email'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHero(
          icon: Icons.mark_email_read_outlined,
          title: 'Recover with email',
          subtitle:
              'We\'ll generate a one-time code and open your email app so you can send it to yourself. We never store the code or read your email.',
        ),
        const SizedBox(height: 24),
        _buildInfoCard(
          color: LiquidColors.accentBlue,
          icon: Icons.shield_outlined,
          title: 'How this works',
          bullets: const [
            'You\'ll see a recovery code on the next screen',
            'You email it to yourself from your own email app',
            'Only a hash of the code is stored on this device',
            'If you forget your PIN, paste the code from your email to reset it',
            'Your encrypted files are kept; only the PIN changes',
          ],
        ),
        const SizedBox(height: 18),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'YOUR EMAIL',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              TextFormField(
                controller: _emailController,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                enableSuggestions: false,
                validator: _validateEmail,
                cursorColor: LiquidColors.accentBlue,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'you@tabsap.com',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.04),
                  prefixIcon: Icon(
                    Icons.alternate_email_rounded,
                    color: Colors.grey.shade500,
                    size: 18,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: LiquidColors.accentBlue,
                      width: 1.4,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: LiquidColors.error),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: LiquidColors.error,
                      width: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _buildSecurityNote(),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _proceedToCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: LiquidColors.accentBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.arrow_forward_rounded, size: 18),
                SizedBox(width: 10),
                Text(
                  'Continue',
                  style: TextStyle(
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
    );
  }

  Widget _buildCodeStage() {
    return Column(
      key: const ValueKey('code'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHero(
          icon: Icons.vpn_key_rounded,
          title: 'Your recovery code',
          subtitle:
              'Email this to yourself now. Without this code you cannot recover your data.',
        ),
        const SizedBox(height: 22),
        _buildCodeCard(),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _copyCode,
                icon: Icon(
                  Icons.copy_rounded,
                  size: 16,
                  color: Colors.grey.shade300,
                ),
                label: Text(
                  'Copy',
                  style: TextStyle(
                    color: Colors.grey.shade300,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  side: BorderSide(color: Colors.grey.shade700),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _openEmailClient,
                icon: const Icon(Icons.mail_outline_rounded, size: 18),
                label: Text(
                  _emailSent ? 'Re-send email' : 'Email it to me',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: LiquidColors.accentBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _buildInfoCard(
          color: LiquidColors.warning,
          icon: Icons.warning_amber_rounded,
          title: 'Save it before you finish',
          bullets: [
            'Sending to ${RecoveryService.mask(_emailController.text.trim())}',
            'If you lose this code you can\'t recover from a forgotten PIN',
            'Without it, the only option will be to wipe the vault',
          ],
        ),
        if (_saveError != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: LiquidColors.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: LiquidColors.error.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: LiquidColors.error,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _saveError!,
                    style: TextStyle(
                      color: LiquidColors.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: (_emailSent && !_saving) ? _finish : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: LiquidColors.success,
              disabledBackgroundColor: LiquidColors.success.withValues(
                alpha: 0.3,
              ),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_saving)
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
                  _saving
                      ? 'Saving…'
                      : _emailSent
                      ? 'I\'ve saved the email'
                      : 'Email it first',
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
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
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
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            LiquidColors.accentBlue.withValues(alpha: 0.16),
            LiquidColors.accentPurple.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: LiquidColors.accentBlue.withValues(alpha: 0.4),
        ),
      ),
      child: Center(
        child: SelectableText(
          _code,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 4,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required Color color,
    required IconData icon,
    required String title,
    required List<String> bullets,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final b in bullets)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6, right: 8),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      b,
                      style: TextStyle(
                        color: Colors.grey.shade300,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSecurityNote() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 14,
            color: Colors.grey.shade500,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'With recovery enabled, anyone with both your phone and access to your email can reset the PIN. Skip this if your threat model includes someone who has both.',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
