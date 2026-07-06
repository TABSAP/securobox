import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:video_player_app/security_settings/decoy_setup_screen.dart';
import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/widgets/app_brand_icon.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: LiquidColors.isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
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
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LiquidColors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.info_outline_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'About',
              style: TextStyle(
                color: LiquidColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
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
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _heroCard(context),
              const SizedBox(height: 20),
              _whatIsCard(),
              const SizedBox(height: 20),
              _securityInfoCard(),
              const SizedBox(height: 20),
              _rateCard(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            LiquidColors.accentBlue.withValues(alpha: 0.18),
            LiquidColors.accentPurple.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: LiquidColors.accentBlue.withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: LiquidColors.accentBlue.withValues(alpha: 0.18),
            blurRadius: 24,
            spreadRadius: -2,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          const AppBrandIcon(size: 88, radius: 22),
          const SizedBox(height: 18),
          Text(
            'SecuroBox',
            style: TextStyle(
              color: LiquidColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your private, offline vault.',
            style: TextStyle(
              color: LiquidColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snap) {
              final v = snap.hasData
                  ? '${snap.data!.version} (${snap.data!.buildNumber})'
                  : '...';
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPress: () {
                  HapticFeedback.heavyImpact();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const DecoySetupScreen(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: LiquidColors.textPrimary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: LiquidColors.textPrimary.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Text(
                    'Version $v',
                    style: TextStyle(
                      color: LiquidColors.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _whatIsCard() {
    return _sectionCard(
      icon: Icons.lock_outline_rounded,
      iconColor: LiquidColors.accentPurple,
      title: 'WHAT IS SECUROBOX?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SecuroBox is a fully offline private vault for your videos, photos, '
            'audio files, and documents. Everything you import is encrypted on '
            'this device — no servers, no analytics, no cloud sync.',
            style: TextStyle(
              color: LiquidColors.textSecondary,
              fontSize: 13,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 12),
          _factRow(
            Icons.wifi_off_rounded,
            'Works 100% offline',
            'Nothing ever leaves your phone.',
          ),
          const SizedBox(height: 10),
          _factRow(
            Icons.do_not_disturb_on_outlined,
            'No account, no tracking',
            'You don\'t sign in. We don\'t see you.',
          ),
          const SizedBox(height: 10),
          _factRow(
            Platform.isIOS ? Icons.phone_iphone_rounded : Icons.android_rounded,
            Platform.isIOS ? 'Built for iPhone' : 'Built for Android & iOS',
            Platform.isIOS
                ? 'Designed for everyday iPhones — requires iOS 15.5 or later.'
                : 'Designed for everyday phones — minimum Android 5.0.',
          ),
        ],
      ),
    );
  }

  Widget _securityInfoCard() {
    return _sectionCard(
      icon: Icons.shield_rounded,
      iconColor: LiquidColors.accentBlue,
      title: 'HOW IT KEEPS YOU SAFE',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _featureRow('AES-256-CTR encryption for every file at rest'),
          const SizedBox(height: 10),
          _featureRow('PIN hashed with PBKDF2-HMAC-SHA256 (100,000 rounds)'),
          const SizedBox(height: 10),
          _featureRow(
            'Hash and master key stored in the OS Keychain / Keystore',
          ),
          const SizedBox(height: 10),
          _featureRow('Random UUID filenames — originals are never exposed'),
          const SizedBox(height: 10),
          _featureRow('Cloud backup disabled — files stay on this device'),
          const SizedBox(height: 10),
          _featureRow('Biometric verification via the OS BiometricPrompt'),
          const SizedBox(height: 10),
          _featureRow('Escalating cooldown after repeated wrong PINs'),
          const SizedBox(height: 10),
          _featureRow('No analytics, no trackers, no servers'),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  LiquidColors.accentBlue.withValues(alpha: 0.12),
                  LiquidColors.accentBlue.withValues(alpha: 0.04),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: LiquidColors.accentBlue.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lock_clock_rounded,
                  color: LiquidColors.accentBlue,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Every security feature works without an internet connection.',
                    style: TextStyle(
                      color: LiquidColors.accentBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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

  Widget _rateCard() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          HapticFeedback.lightImpact();
          final url = Uri.parse(
            'https://play.google.com/store/apps/details?id=app.securobox.vault',
          );
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                LiquidColors.warning.withValues(alpha: 0.18),
                LiquidColors.warning.withValues(alpha: 0.06),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: LiquidColors.warning.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: LiquidColors.warning.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.star_rounded,
                  color: LiquidColors.warning,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enjoying SecuroBox?',
                      style: TextStyle(
                        color: LiquidColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Leave a quick review on Google Play.',
                      style: TextStyle(
                        color: LiquidColors.textSecondary,
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

  Widget _sectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            LiquidColors.backgroundLight.withValues(alpha: 0.9),
            LiquidColors.backgroundMid.withValues(alpha: 0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: LiquidColors.textPrimary.withValues(alpha: 0.06),
          width: 1,
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
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: LiquidColors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _factRow(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: LiquidColors.accentPurple.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: LiquidColors.accentPurple, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  title,
                  style: TextStyle(
                    color: LiquidColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
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
    );
  }

  Widget _featureRow(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                LiquidColors.success,
                LiquidColors.success.withValues(alpha: 0.6),
              ],
              center: Alignment.center,
              radius: 0.8,
            ),
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Center(
            child: Icon(Icons.check_rounded, color: Colors.white, size: 13),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: LiquidColors.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}
