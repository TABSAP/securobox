import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player_app/widgets/app_loader.dart';
import 'package:video_player_app/utils/flush_bar_helper.dart';
import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/utils/recovery_service.dart';

class RecoverySetupScreen extends StatefulWidget {
  final bool reissue;

  const RecoverySetupScreen({super.key, this.reissue = false});

  @override
  State<RecoverySetupScreen> createState() => _RecoverySetupScreenState();
}

class _RecoverySetupScreenState extends State<RecoverySetupScreen> {
  late final String _code;
  bool _codeSaved = false;
  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _code = RecoveryService.instance.generateCode();
  }

  Future<void> _copyCode() async {
    HapticFeedback.lightImpact();
    await Clipboard.setData(ClipboardData(text: _code));
    if (!mounted) return;
    setState(() => _codeSaved = true);
    FlushBarHelper.flushBarSuccessMessage(
      'Recovery Key copied — paste it somewhere safe',
      context,
    );
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await RecoveryService.instance.save(code: _code);
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
        backgroundColor: LiquidColors.backgroundDeep,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: LiquidColors.isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: LiquidColors.textPrimary),
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [LiquidColors.accentBlue, LiquidColors.accentPurple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.vpn_key_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              widget.reissue ? 'Re-issue Recovery Key' : 'Recovery Key',
              style: TextStyle(
                color: LiquidColors.textPrimary,
                fontSize: 18,
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
            child: _buildCodeStage(),
          ),
        ),
      ),
    );
  }

  Widget _buildCodeStage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHero(
          icon: Icons.vpn_key_rounded,
          title: 'Your Recovery Key',
          subtitle: widget.reissue
              ? 'A new key has been generated. Save it somewhere safe — the old key stops working as soon as you tap Done.'
              : 'Save this key somewhere safe. It is the only way to regain access if you forget your PIN. It can\'t be recovered for you.',
        ),
        const SizedBox(height: 22),
        _buildCodeCard(),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _copyCode,
            icon: Icon(
              Icons.copy_rounded,
              size: 16,
              color: LiquidColors.textSecondary,
            ),
            label: Text(
              'Copy',
              style: TextStyle(
                color: LiquidColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              side: BorderSide(color: LiquidColors.textTertiary),
            ),
          ),
        ),
        const SizedBox(height: 18),
        _buildInfoCard(
          color: LiquidColors.warning,
          icon: Icons.warning_amber_rounded,
          title: 'Save it before you finish',
          bullets: [
            'Copy the key and store it in a password manager or somewhere safe',
            'If you lose this key you can\'t recover from a forgotten PIN',
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
        const SizedBox(height: 22),
        CheckboxListTile(
          value: _codeSaved,
          onChanged: _saving
              ? null
              : (v) => setState(() => _codeSaved = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          activeColor: LiquidColors.indigo,
          checkColor: Colors.white,
          title: Text(
            'I have saved my Recovery Key',
            style: TextStyle(
              color: LiquidColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: (_codeSaved && !_saving) ? _finish : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: LiquidColors.success,
              disabledBackgroundColor: LiquidColors.success.withValues(
                alpha: 0.3,
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
                if (_saving)
                  AppLoader(size: 22, color: Colors.white)
                else
                  const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                const SizedBox(width: 10),
                Text(
                  _saving ? 'Saving…' : 'Done',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    color: Colors.white,
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
            style: TextStyle(
              color: LiquidColors.textPrimary,
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
              color: LiquidColors.textSecondary,
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
          style: TextStyle(
            color: LiquidColors.textPrimary,
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
                        color: LiquidColors.textSecondary,
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
}
