import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:video_player_app/security_settings/privacy_policy_screen.dart';
import 'package:video_player_app/security_settings/send_feedback_screen.dart';
import 'package:video_player_app/utils/app_rating.dart';
import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/utils/responsive.dart';
import 'package:video_player_app/widgets/app_section_header.dart';
import 'package:video_player_app/widgets/app_spacing.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LiquidColors.backgroundDeep,
      appBar: AppBar(
        backgroundColor: LiquidColors.backgroundDeep,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: LiquidColors.systemOverlayStyle,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: LiquidColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Help & Support',
          style: TextStyle(
            color: LiquidColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          context.contentInset(phone: 20),
          8,
          context.contentInset(phone: 20),
          40,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Send feedback, read our privacy policy, or skim the security '
              'tips below to get the most out of SecuroBox.',
              style: TextStyle(
                color: LiquidColors.textSecondary,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            AppSpace.h24,
            const AppSectionHeader(label: 'Get in touch'),
            _getInTouchCard(context),
            AppSpace.h24,
            const AppSectionHeader(label: 'Security tips'),
            _tipsCard(),
            AppSpace.h24,
            const AppSectionHeader(label: 'Quick answers'),
            _faqCard(),
          ],
        ),
      ),
    );
  }

  Widget _getInTouchCard(BuildContext context) {
    return _card(
      padding: const EdgeInsets.all(6),
      child: Column(
        children: [
          _actionTile(
            icon: Icons.mail_outline_rounded,
            label: 'Send Feedback',
            sublabel: 'Tell us what you think or report a bug.',
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SendFeedbackScreen()),
              );
            },
          ),
          _divider(),
          _actionTile(
            icon: Icons.star_outline_rounded,
            label: 'Rate SecuroBox',
            sublabel: 'Enjoying the app? Leave a rating on Google Play.',
            onTap: () {
              HapticFeedback.lightImpact();
              AppRating.rateNow();
            },
          ),
          _divider(),
          _actionTile(
            icon: Icons.privacy_tip_outlined,
            label: 'Privacy Policy',
            sublabel: 'See exactly how SecuroBox handles your data.',
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _tipsCard() {
    const tips = <String>[
      'Avoid simple PINs like 1234, 0000, or repeating digits.',
      'Enable biometric authentication for faster, secure access.',
      'Lock individual videos for extra protection on sensitive files.',
      'Change your PIN every few months for better security.',
      'Set up a Recovery Key so a forgotten PIN doesn\'t mean wiping the vault.',
    ];
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < tips.length; i++) ...[
            _tipRow(i + 1, tips[i]),
            if (i < tips.length - 1) AppSpace.h16,
          ],
        ],
      ),
    );
  }

  Widget _faqCard() {
    const items = <_Faq>[
      _Faq(
        q: 'Where are my files stored?',
        a: 'Only on this device. Imports are encrypted with AES-256-CTR and '
            'never sent to a server.',
      ),
      _Faq(
        q: 'What happens if I forget my PIN?',
        a: 'If you set up a Recovery Key, enter it on the Forgot PIN screen to '
            'reset your PIN. Without your Recovery Key, the only option is to '
            'wipe the vault.',
      ),
      _Faq(
        q: 'Does SecuroBox work without internet?',
        a: 'Yes — everything works fully offline. The app never makes network '
            'requests for security features.',
      ),
      _Faq(
        q: 'Can someone see my files if my phone is unlocked?',
        a: 'Enable App Lock, Biometric, or Face Unlock so SecuroBox always '
            'prompts for verification before opening.',
      ),
    ];
    return _card(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _FaqTile(item: items[i]),
            if (i < items.length - 1) _divider(),
          ],
        ],
      ),
    );
  }

  Widget _card({required Widget child, EdgeInsets? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LiquidColors.backgroundLight.withValues(alpha: 0.55),
        borderRadius: AppRadius.rLg,
        border: Border.all(color: LiquidColors.cardBorder),
      ),
      child: child,
    );
  }

  Widget _divider() {
    return Divider(height: 1, thickness: 1, color: LiquidColors.divider);
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    required String sublabel,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.rMd,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: LiquidColors.textPrimary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: LiquidColors.textSecondary, size: 19),
              ),
              AppSpace.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: LiquidColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    AppSpace.h4,
                    Text(
                      sublabel,
                      style: TextStyle(
                        color: LiquidColors.textTertiary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: LiquidColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tipRow(int index, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: LiquidColors.textPrimary.withValues(alpha: 0.06),
          ),
          alignment: Alignment.center,
          child: Text(
            '$index',
            style: TextStyle(
              color: LiquidColors.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        AppSpace.w12,
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              text,
              style: TextStyle(
                color: LiquidColors.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Faq {
  final String q;
  final String a;
  const _Faq({required this.q, required this.a});
}

class _FaqTile extends StatefulWidget {
  final _Faq item;
  const _FaqTile({required this.item});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _open = !_open);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.item.q,
                      style: TextStyle(
                        color: LiquidColors.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 180),
                    turns: _open ? 0.5 : 0.0,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: LiquidColors.textTertiary,
                      size: 22,
                    ),
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                child: _open
                    ? Padding(
                        padding: const EdgeInsets.only(top: 8, right: 28),
                        child: Text(
                          widget.item.a,
                          style: TextStyle(
                            color: LiquidColors.textSecondary,
                            fontSize: 12.5,
                            height: 1.5,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
