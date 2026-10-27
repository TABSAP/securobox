import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_app/onboarding_screen/onboarding_screen.dart';
import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/utils/pin_crypto.dart';
import 'package:video_player_app/utils/recovery_questions_service.dart';
import 'package:video_player_app/utils/session_manager.dart';
import 'package:video_player_app/utils/vault_context.dart';
import 'package:video_player_app/widgets/app_loader.dart';
import 'package:video_player_app/widgets/liquid_glass_surface.dart';
import 'package:video_player_app/widgets/liquid_glass_button.dart';

class ForgotPinScreen extends StatefulWidget {
  const ForgotPinScreen({super.key});

  @override
  State<ForgotPinScreen> createState() => _ForgotPinScreenState();
}

class _ForgotPinScreenState extends State<ForgotPinScreen> {
  final _answers = List.generate(3, (_) => TextEditingController());
  List<RecoveryQuestion> _prompts = const [];
  bool _loading = true;
  bool _busy = false;
  bool _available = false;
  String? _error;
  Duration _lockout = Duration.zero;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadPrompts();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final controller in _answers) {
      controller.clear();
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPrompts() async {
    if (VaultContext.instance.isDecoy) {
      setState(() {
        _loading = false;
        _available = false;
        _error = 'PIN recovery is unavailable in this vault mode.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final configured = await RecoveryQuestionsService.instance.isEnabled();
      final prompts = configured
          ? await RecoveryQuestionsService.instance.getPrompts()
          : const <RecoveryQuestion>[];
      final remaining = configured
          ? await RecoveryQuestionsService.instance.lockoutRemaining()
          : Duration.zero;
      if (!mounted) return;
      setState(() {
        _available = prompts.length == 3;
        _prompts = prompts;
        _lockout = remaining;
        _loading = false;
      });
      _startLockoutTimer();
    } on Object {
      if (!mounted) return;
      setState(() {
        _available = false;
        _loading = false;
        _error =
            'Recovery information is unavailable or damaged. Your PIN was not changed.';
      });
    }
  }

  void _startLockoutTimer() {
    _timer?.cancel();
    if (_lockout <= Duration.zero) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _lockout -= const Duration(seconds: 1);
        if (_lockout <= Duration.zero) {
          _lockout = Duration.zero;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _verifyAndReset() async {
    if (_busy || !_available || _lockout > Duration.zero) return;
    FocusScope.of(context).unfocus();
    final answers = _answers.map((controller) => controller.text).toList();
    if (answers.any(
      (answer) => RecoveryQuestionsService.normalizeAnswer(answer).length < 3,
    )) {
      setState(() => _error = 'Answer all three questions before continuing.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final verified = await RecoveryQuestionsService.instance.verify(answers);
      if (!mounted) return;
      if (!verified) {
        HapticFeedback.heavyImpact();
        for (final controller in _answers) {
          controller.clear();
        }
        final remaining = await RecoveryQuestionsService.instance
            .lockoutRemaining();
        if (!mounted) return;
        setState(() {
          _busy = false;
          _lockout = remaining;
          _error = remaining > Duration.zero
              ? 'Too many attempts. Try again after the countdown.'
              : 'Those answers don’t match. Check them and try again.';
        });
        _startLockoutTimer();
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final hadCompletedOnboarding = prefs.getBool('hasOnboarded') ?? false;
      if (!await prefs.setBool('hasOnboarded', false)) {
        throw StateError('Could not start PIN setup.');
      }
      try {
        await PinCrypto.instance.clearPin();
      } catch (_) {
        if (hadCompletedOnboarding) {
          await prefs.setBool('hasOnboarded', true);
        }
        rethrow;
      }
      await SessionManager.instance.init();
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        (_) => false,
      );
    } on Object {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error =
            'PIN reset could not finish. Your encrypted files remain unchanged. Try again.';
      });
    } finally {
      if (mounted) {
        for (final controller in _answers) {
          controller.clear();
        }
      }
      answers.fillRange(0, answers.length, '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Forgot PIN',
          style: TextStyle(color: theme.colorScheme.onSurface),
        ),
        leading: IconButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          icon: Icon(
            Icons.arrow_back_rounded,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: AppLoader(size: 42, label: 'Loading recovery…'),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  _infoCard(),
                  const SizedBox(height: 18),
                  if (_available) ...[
                    for (var i = 0; i < _prompts.length; i++) _answerField(i),
                    if (_lockout > Duration.zero) _lockoutCard(),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      _errorCard(_error!),
                    ],
                    const SizedBox(height: 18),
                    LiquidGlassButton(
                      icon: Icons.lock_reset_rounded,
                      label: _busy
                          ? 'Verifying answers…'
                          : 'Verify and reset PIN',
                      onPressed: _busy || _lockout > Duration.zero
                          ? null
                          : _verifyAndReset,
                    ),
                  ] else
                    _unavailableCard(),
                  const SizedBox(height: 16),
                  LiquidGlassButton(
                    label: 'Cancel',
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _infoCard() => LiquidGlassSurface(
    borderRadius: 18,
    blur: 18,
    padding: const EdgeInsets.all(16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.shield_outlined, color: LiquidColors.textPrimary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Enter all three answers you chose during setup. After verification, you can choose a new PIN. Your encrypted media remains in place.',
            style: TextStyle(
              color: LiquidColors.textSecondary,
              height: 1.45,
              fontSize: 13,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _answerField(int index) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: LiquidGlassSurface(
      borderRadius: 16,
      blur: 16,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'QUESTION ${index + 1}',
            style: TextStyle(
              color: LiquidColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: .8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _prompts[index].prompt,
            style: TextStyle(
              color: LiquidColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _answers[index],
            enabled: !_busy && _lockout <= Duration.zero,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Your answer',
              filled: true,
              fillColor: Colors.transparent,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _lockoutCard() => _messageCard(
    icon: Icons.lock_clock_outlined,
    color: LiquidColors.warning,
    text: 'Try again in ${_lockout.inSeconds} seconds.',
  );

  Widget _unavailableCard() => _messageCard(
    icon: Icons.info_outline_rounded,
    color: LiquidColors.warning,
    text:
        _error ??
        'Recovery questions are not configured on this device. If you can unlock the app, set them up in Security settings. Your encrypted files have not been removed.',
  );

  Widget _errorCard(String message) => _messageCard(
    icon: Icons.error_outline_rounded,
    color: LiquidColors.error,
    text: message,
  );

  Widget _messageCard({
    required IconData icon,
    required Color color,
    required String text,
  }) => LiquidGlassSurface(
    borderRadius: 14,
    blur: 14,
    tintColor: color,
    tintOpacity: 0.08,
    padding: const EdgeInsets.all(14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 19),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: LiquidColors.textPrimary, height: 1.4),
          ),
        ),
      ],
    ),
  );
}
