import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/utils/recovery_questions_service.dart';
import 'package:video_player_app/widgets/app_loader.dart';

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
    return PopScope(
      canPop: !widget.requiredSetup && !_saving,
      child: Scaffold(
        backgroundColor: LiquidColors.backgroundDeep,
        appBar: AppBar(
          backgroundColor: LiquidColors.backgroundDeep,
          surfaceTintColor: Colors.transparent,
          leading: widget.requiredSetup
              ? const SizedBox.shrink()
              : IconButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: LiquidColors.textPrimary,
                  ),
                ),
          title: Text(
            widget.requiredSetup ? 'Set up recovery' : 'Recovery questions',
            style: TextStyle(
              color: LiquidColors.textPrimary,
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
                  SizedBox(
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.verified_user_rounded),
                      label: Text(
                        _saving
                            ? 'Securing answers…'
                            : 'Save recovery questions',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  if (!widget.requiredSetup)
                    TextButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: LiquidColors.textSecondary),
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

  Widget _introCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          LiquidColors.accentBlue.withValues(alpha: .15),
          LiquidColors.accentPurple.withValues(alpha: .08),
        ],
      ),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: LiquidColors.accentBlue.withValues(alpha: .28)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.shield_outlined, color: LiquidColors.accentBlue),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LiquidColors.textPrimary.withValues(alpha: .035),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: LiquidColors.textPrimary.withValues(alpha: .08),
        ),
      ),
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
                RecoveryQuestionsService.normalizeAnswer(value ?? '').length < 3
                ? 'Enter at least 3 characters'
                : null,
          ),
        ],
      ),
    );
  }

  Widget _errorBanner(String message) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: LiquidColors.error.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: LiquidColors.error.withValues(alpha: .35)),
    ),
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
