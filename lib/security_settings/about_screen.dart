import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:video_player_app/security_settings/decoy_setup_screen.dart';
import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/widgets/app_brand_icon.dart';
import 'package:video_player_app/widgets/app_section_header.dart';
import 'package:video_player_app/widgets/app_spacing.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

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
          'About',
          style: TextStyle(
            color: LiquidColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(context),
            AppSpace.h32,
            const AppSectionHeader(label: 'What is SecuroBox'),
            _whatIsCard(),
            AppSpace.h24,
            const AppSectionHeader(label: 'How it keeps you safe'),
            _securityInfoCard(),
            AppSpace.h32,
            _rateButton(),
            AppSpace.h24,
            Center(
              child: Text(
                'Made with care for your privacy.',
                style: TextStyle(
                  color: LiquidColors.textTertiary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Column(
      children: [
        const AppBrandIcon(size: 72, radius: 18, showShadow: false),
        AppSpace.h16,
        Text(
          'SecuroBox',
          style: TextStyle(
            color: LiquidColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
        AppSpace.h4,
        Text(
          'Your private, offline vault.',
          style: TextStyle(
            color: LiquidColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        AppSpace.h12,
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
                  color: LiquidColors.textPrimary.withValues(alpha: 0.05),
                  borderRadius: AppRadius.rPill,
                  border: Border.all(color: LiquidColors.cardBorder),
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
    );
  }

  Widget _whatIsCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SecuroBox is a fully offline private vault for your videos, photos, '
            'audio files, and documents. Everything you import is encrypted on '
            'this device — no servers, no analytics, no cloud sync.',
            style: TextStyle(
              color: LiquidColors.textSecondary,
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
          AppSpace.h16,
          _factRow(
            Icons.wifi_off_rounded,
            'Works 100% offline',
            'Nothing ever leaves your phone.',
          ),
          AppSpace.h12,
          _factRow(
            Icons.do_not_disturb_on_outlined,
            'No account, no tracking',
            'You don\'t sign in. We don\'t see you.',
          ),
          AppSpace.h12,
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
    const points = <String>[
      'AES-256-CTR encryption for every file at rest',
      'PIN hashed with PBKDF2-HMAC-SHA256 (100,000 rounds)',
      'Hash and master key stored in the OS Keychain / Keystore',
      'Random UUID filenames — originals are never exposed',
      'Cloud backup disabled — files stay on this device',
      'Biometric verification via the OS BiometricPrompt',
      'Escalating cooldown after repeated wrong PINs',
      'No analytics, no trackers, no servers',
    ];
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < points.length; i++) ...[
            _featureRow(points[i]),
            if (i < points.length - 1) AppSpace.h12,
          ],
          AppSpace.h16,
          Row(
            children: [
              Icon(
                Icons.lock_clock_rounded,
                color: LiquidColors.textSecondary,
                size: 15,
              ),
              AppSpace.w8,
              Expanded(
                child: Text(
                  'Every security feature works without an internet connection.',
                  style: TextStyle(
                    color: LiquidColors.textTertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rateButton() {
    return Material(
      color: LiquidColors.indigo,
      borderRadius: AppRadius.rMd,
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
        borderRadius: AppRadius.rMd,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.star_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Rate SecuroBox',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LiquidColors.backgroundLight.withValues(alpha: 0.55),
        borderRadius: AppRadius.rLg,
        border: Border.all(color: LiquidColors.cardBorder),
      ),
      child: child,
    );
  }

  Widget _factRow(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: LiquidColors.textPrimary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(11),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: LiquidColors.textSecondary, size: 17),
        ),
        AppSpace.w12,
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
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              AppSpace.h4,
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
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            Icons.check_rounded,
            color: LiquidColors.textSecondary,
            size: 17,
          ),
        ),
        AppSpace.w8,
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
