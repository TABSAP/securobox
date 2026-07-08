import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/utils/responsive.dart';
import 'package:video_player_app/widgets/app_spacing.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _lastUpdated = 'November 2025';
  static const _supportEmail = 'info@tabsap.com';

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
          'Privacy Policy',
          style: TextStyle(
            color: LiquidColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            context.contentInset(phone: 20),
            8,
            context.contentInset(phone: 20),
            40,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your data stays on your device. No servers, no accounts, no '
                'tracking. Here is exactly how SecuroBox handles your privacy.',
                style: TextStyle(
                  color: LiquidColors.textSecondary,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
              AppSpace.h8,
              Text(
                'Last updated: $_lastUpdated',
                style: TextStyle(
                  color: LiquidColors.textTertiary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              AppSpace.h32,
              _section(
                title: 'What we collect',
                body:
                    'Nothing. SecuroBox has no server, no analytics SDK, '
                    'no advertising identifiers, and no telemetry. The app '
                    'works fully offline.',
              ),
              _section(
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
                title: 'Your PIN',
                body:
                    'Hashed with PBKDF2-HMAC-SHA256 (100,000 iterations) '
                    'and a random per-install salt. The PIN itself is never '
                    'stored, transmitted, or recoverable. If you forget '
                    'your PIN, your data cannot be recovered.',
              ),
              _section(
                title: 'Permissions we ask for',
                body:
                    'Photos / Videos / Audio / Storage: only while you are '
                    'actively importing files.\n'
                    'Camera: only if you enable Break-in Detection.\n'
                    'Biometrics: only if you enable biometric unlock.\n'
                    'No other permissions are requested.',
              ),
              _section(
                title: 'Third-party services',
                body:
                    'None. SecuroBox does not integrate any analytics, '
                    'ads, crash reporting, or cloud sync provider. The app '
                    'connects to the network only when you explicitly '
                    'request it (for example, when downloading a URL you '
                    'paste yourself).',
              ),
              _section(
                title: 'Children\'s privacy',
                body:
                    'SecuroBox is not designed for or directed at '
                    'children under 13. Because the app collects no data, '
                    'we cannot knowingly identify or contact any user.',
              ),
              _section(
                title: 'Changes to this policy',
                body:
                    'If anything material changes, the "Last updated" date '
                    'at the top of this screen will change with the next '
                    'app update.',
                isLast: true,
              ),
              AppSpace.h24,
              _contactCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section({
    required String title,
    required String body,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: LiquidColors.textPrimary,
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
          AppSpace.h8,
          Text(
            body,
            style: TextStyle(
              color: LiquidColors.textSecondary,
              fontSize: 13.5,
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
          borderRadius: AppRadius.rLg,
          onTap: () async {
            HapticFeedback.lightImpact();
            final url = Uri.parse('mailto:$_supportEmail');
            if (await canLaunchUrl(url)) {
              await launchUrl(url);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: LiquidColors.backgroundLight.withValues(alpha: 0.55),
              borderRadius: AppRadius.rLg,
              border: Border.all(color: LiquidColors.cardBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: LiquidColors.textPrimary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    Icons.alternate_email_rounded,
                    color: LiquidColors.textSecondary,
                    size: 19,
                  ),
                ),
                AppSpace.w12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Questions about privacy?',
                        style: TextStyle(
                          color: LiquidColors.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      AppSpace.h4,
                      Text(
                        _supportEmail,
                        style: TextStyle(
                          color: LiquidColors.textSecondary,
                          fontSize: 12.5,
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
