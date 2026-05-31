import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/utils/responsive.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _lastUpdated = 'November 2025';
  static const _supportEmail = 'info@tabsap.com';

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
          icon: Icon(Icons.arrow_back_rounded, color: LiquidColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [LiquidColors.success, LiquidColors.accentBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: LiquidColors.success.withValues(alpha: 0.35),
                    blurRadius: 12,
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.privacy_tip_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Privacy Policy',
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
            padding: EdgeInsets.fromLTRB(
              context.contentInset(phone: 20),
              16,
              context.contentInset(phone: 20),
              40,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroCard(),
                const SizedBox(height: 24),
                _section(
                  icon: Icons.do_not_disturb_alt_rounded,
                  iconColor: LiquidColors.success,
                  title: 'What we collect',
                  body:
                      'Nothing. SecuroBox has no server, no analytics SDK, '
                      'no advertising identifiers, and no telemetry. The app '
                      'works fully offline.',
                ),
                _section(
                  icon: Icons.lock_outline_rounded,
                  iconColor: LiquidColors.accentBlue,
                  title: 'How your files are stored',
                  body:
                      'Every file you import is encrypted with AES-256-CTR '
                      'and stored in app-private storage that other apps '
                      'cannot read. The encryption key is generated on first '
                      'launch and held in the OS keychain (iOS) or '
                      'EncryptedSharedPreferences backed by Android Keystore. '
                      'Cloud backup is disabled — your files never leave the '
                      'device.',
                ),
                _section(
                  icon: Icons.password_rounded,
                  iconColor: LiquidColors.accentPurple,
                  title: 'Your PIN',
                  body:
                      'Hashed with PBKDF2-HMAC-SHA256 (100,000 iterations) '
                      'and a random per-install salt. The PIN itself is never '
                      'stored, transmitted, or recoverable. If you forget '
                      'your PIN, your data cannot be recovered.',
                ),
                _section(
                  icon: Icons.tune_rounded,
                  iconColor: LiquidColors.warning,
                  title: 'Permissions we ask for',
                  body:
                      'Photos / Videos / Audio / Storage: only while you are '
                      'actively importing files.\n'
                      'Camera: only if you enable Break-in Detection.\n'
                      'Biometrics: only if you enable biometric unlock.\n'
                      'No other permissions are requested.',
                ),
                _section(
                  icon: Icons.public_off_rounded,
                  iconColor: LiquidColors.accentPink,
                  title: 'Third-party services',
                  body:
                      'None. SecuroBox does not integrate any analytics, '
                      'ads, crash reporting, or cloud sync provider. The app '
                      'connects to the network only when you explicitly '
                      'request it (for example, when downloading a URL you '
                      'paste yourself).',
                ),
                _section(
                  icon: Icons.child_care_rounded,
                  iconColor: LiquidColors.success,
                  title: 'Children\'s privacy',
                  body:
                      'SecuroBox is not designed for or directed at '
                      'children under 13. Because the app collects no data, '
                      'we cannot knowingly identify or contact any user.',
                ),
                _section(
                  icon: Icons.update_rounded,
                  iconColor: LiquidColors.accentBlue,
                  title: 'Changes to this policy',
                  body:
                      'If anything material changes, the "Last updated" date '
                      'at the top of this screen will change with the next '
                      'app update.',
                ),
                const SizedBox(height: 8),
                _contactCard(),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    'Last updated: $_lastUpdated',
                    style: TextStyle(
                      color: LiquidColors.textTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            LiquidColors.success.withValues(alpha: 0.16),
            LiquidColors.accentBlue.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: LiquidColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  LiquidColors.success.withValues(alpha: 0.3),
                  LiquidColors.success.withValues(alpha: 0.0),
                ],
              ),
            ),
            child: Icon(
              Icons.verified_user_rounded,
              color: LiquidColors.success,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your data stays on your device',
                  style: TextStyle(
                    color: LiquidColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'No servers. No accounts. No tracking.',
                  style: TextStyle(
                    color: LiquidColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String body,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: LiquidColors.textPrimary.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: LiquidColors.textPrimary.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: LiquidColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: TextStyle(
              color: LiquidColors.textSecondary,
              fontSize: 13,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactCard() {
    return Builder(
      builder: (context) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () async {
            HapticFeedback.lightImpact();
            final url = Uri.parse('mailto:$_supportEmail');
            if (await canLaunchUrl(url)) {
              await launchUrl(url);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  LiquidColors.accentBlue.withValues(alpha: 0.18),
                  LiquidColors.accentPurple.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: LiquidColors.accentBlue.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: LiquidColors.accentBlue.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.alternate_email_rounded,
                    color: LiquidColors.accentBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Questions about privacy?',
                        style: TextStyle(
                          color: LiquidColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        _supportEmail,
                        style: TextStyle(
                          color: LiquidColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: LiquidColors.textTertiary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
