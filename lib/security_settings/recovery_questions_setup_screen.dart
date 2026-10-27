import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/utils/recovery_questions_service.dart';
import 'package:video_player_app/widgets/app_loader.dart';
import 'package:video_player_app/widgets/liquid_glass_surface.dart';
import 'package:video_player_app/widgets/liquid_glass_button.dart';
import 'package:video_player_app/widgets/app_spacing.dart';

class RecoveryQuestionsSetupScreen extends StatefulWidget {
  const RecoveryQuestionsSetupScreen({super.key, this.requiredSetup = false});

  final bool requiredSetup;

  @override
  State<RecoveryQuestionsSetupScreen> createState() =>
      _RecoveryQuestionsSetupScreenState();
}

class _RecoveryQuestionsSetupScreenState
    extends State<RecoveryQuestionsSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _answers = List.generate(3, (_) => TextEditingController());
  final _selected = <String?>[null, null, null];
  final _obscured = <bool>[true, true, true];
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in _answers) {
      controller.clear();
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final ids = _selected.whereType<String>().toList(growable: false);
    final answers = _answers.map((controller) => controller.text).toList();
    final validation = RecoveryQuestionsService.validateAnswers(ids, answers);
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await RecoveryQuestionsService.instance.save(
        questionIds: ids,
        answers: answers,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error =
            'We couldn’t securely save your recovery questions. Check your device storage and try again.';
      });
    } finally {
      if (mounted) {
        for (final controller in _answers) {
          controller.clear();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: !widget.requiredSetup && !_saving,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.scaffoldBackgroundColor,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
          leading: widget.requiredSetup
              ? const SizedBox.shrink()
              : IconButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
          title: Text(
            widget.requiredSetup ? 'Set up recovery' : 'Recovery questions',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        body: SafeArea(
          child: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  _introCard(),
                  const SizedBox(height: 18),
                  Form(
                    key: _formKey,
                    child: Column(children: List.generate(3, _questionCard)),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    _errorBanner(_error!),
                  ],
                  const SizedBox(height: 18),
                  LiquidGlassButton(
                    onPressed: _saving ? null : _save,
                    icon: Icons.verified_user_rounded,
                    label: _saving
                        ? 'Securing answers…'
                        : 'Save recovery questions',
                    height: 54,
                  ),
                  if (!widget.requiredSetup)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpace.sm),
                      child: LiquidGlassButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context),
                        label: 'Cancel',
                        height: 44,
                      ),
                    ),
                ],
              ),
              if (_saving)
                Positioned.fill(
                  child: ColoredBox(
                    color: LiquidColors.scrim.withValues(alpha: .68),
                    child: const Center(
                      child: AppLoader(size: 46, label: 'Securing answers…'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _introCard() => LiquidGlassSurface(
    borderRadius: AppRadius.lg,
    blur: 20,
    padding: const EdgeInsets.all(16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.shield_outlined, color: LiquidColors.textPrimary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Choose three answers you can remember but others cannot guess. Security questions are easier to guess than a random recovery code, so use private, non-public answers. Only salted answer verifiers are stored on this device.',
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

  Widget _questionCard(int index) {
    final selectedId = _selected[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LiquidGlassSurface(
        borderRadius: AppRadius.lg,
        blur: 18,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'QUESTION ${index + 1}',
              style: TextStyle(
                color: LiquidColors.textSecondary,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: .8,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: selectedId,
              isExpanded: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: LiquidColors.textPrimary.withValues(alpha: .04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              hint: const Text('Select a question'),
              items: RecoveryQuestionsService.questions.map((question) {
                final usedElsewhere = _selected.asMap().entries.any(
                  (entry) => entry.key != index && entry.value == question.id,
                );
                return DropdownMenuItem<String>(
                  value: question.id,
                  enabled: !usedElsewhere,
                  child: Text(
                    question.prompt,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: _saving
                  ? null
                  : (value) => setState(() {
                      _selected[index] = value;
                      _error = null;
                    }),
              validator: (value) => value == null ? 'Select a question' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _answers[index],
              enabled: !_saving,
              obscureText: _obscured[index],
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 80,
              decoration: InputDecoration(
                labelText: 'Your answer',
                counterText: '',
                suffixIcon: IconButton(
                  tooltip: _obscured[index] ? 'Show answer' : 'Hide answer',
                  onPressed: () =>
                      setState(() => _obscured[index] = !_obscured[index]),
                  icon: Icon(
                    _obscured[index] ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
                filled: true,
                fillColor: LiquidColors.textPrimary.withValues(alpha: .04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) =>
                  RecoveryQuestionsService.normalizeAnswer(value ?? '').length <
                      3
                  ? 'Enter at least 3 characters'
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorBanner(String message) => LiquidGlassSurface(
    borderRadius: 12,
    blur: 14,
    tintColor: LiquidColors.error,
    tintOpacity: 0.08,
    padding: const EdgeInsets.all(12),
    child: Row(
      children: [
        Icon(Icons.error_outline, color: LiquidColors.error, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: TextStyle(color: LiquidColors.textPrimary),
          ),
        ),
      ],
    ),
  );
}
