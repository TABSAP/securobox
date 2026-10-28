import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/utils/responsive.dart';
import 'package:video_player_app/widgets/app_spacing.dart';
import 'package:video_player_app/widgets/liquid_glass_surface.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _lastUpdated = 'November 2025';
  static const _supportEmail = 'info@tabsap.com';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: LiquidColors.systemOverlayStyle,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: theme.colorScheme.onSurface,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Privacy Policy',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
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
                'Vault files and PINs stay on your device. SecuroBox has no '
                'accounts or vault cloud sync, and does not show ads. Here is '
                'how your privacy is handled.',
                style: TextStyle(
                  color: LiquidColors.textSecondary,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
              AppSpace.h8,
              LiquidGlassSurface(
                borderRadius: 22,
                blur: 12,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                child: Text(
                  'Last updated: $_lastUpdated',
                  style: TextStyle(
                    color: LiquidColors.textTertiary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              AppSpace.h32,
              _section(
                title: 'What we collect',
                body:
                    'SecuroBox does not upload vault files or PINs. The app '
                    'does not use advertising SDKs or show advertisements. '
                    'Network access occurs only when you explicitly request '
                    'an online action, such as downloading a URL you provide.',
              ),
              _section(
                title: 'How your files are stored',
                body:
                    'Every file you import is encrypted with AES-256-CTR '
                    'and stored in app-private storage that other apps '
                    'cannot read. The encryption key is generated on first '
                    'launch and held in the OS keychain (iOS) or '
                    'EncryptedSharedPreferences backed by Android Keystore. '
                    'Vault files are excluded from system backups. They stay '
                    'in app-private storage unless you explicitly export them.',
              ),
              _section(
                title: 'Your PIN',
                body:
                    'The PIN is hashed with PBKDF2-HMAC-SHA256 and a random salt. The PIN itself is never stored or transmitted. It controls access to the app but does not encrypt or wrap the vault key, which is stored separately in OS secure storage. If you forget it, locally stored recovery-question verifiers can let you choose a new PIN; your encrypted files remain on this device. Recovery answers are not synced or recoverable if you lose access to this device.',
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
                title: 'Children\'s privacy',
                body:
                    'SecuroBox is not designed for or directed at '
                    'children under 13. We do not knowingly collect children’s '
                    'personal information.',
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
      child: LiquidGlassSurface(
        borderRadius: AppRadius.lg,
        blur: 16,
        padding: const EdgeInsets.all(16),
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
          child: LiquidGlassSurface(
            borderRadius: AppRadius.lg,
            blur: 18,
            padding: const EdgeInsets.all(16),
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
