import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:video_player_app/history_screen/history_screen.dart';
import 'package:video_player_app/security_settings/about_screen.dart';
import 'package:video_player_app/security_settings/security_setting.dart';
import 'package:video_player_app/security_settings/support_screen.dart';
import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/utils/responsive.dart';
import 'package:video_player_app/utils/theme_controller.dart';
import 'package:video_player_app/widgets/app_section_header.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController = AnimationController(
    duration: const Duration(milliseconds: 700),
    vsync: this,
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _animationController,
    curve: Curves.easeOut,
  );
  late final Animation<Offset> _slide =
      Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeOutCubic,
        ),
      );

  @override
  void initState() {
    super.initState();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [LiquidColors.accentBlue, LiquidColors.primaryMid],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.settings_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Settings',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: LiquidColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  Text(
                    'Personalise SecuroBox to your taste',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: LiquidColors.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
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
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                context.contentInset(phone: 16),
                0,
                context.contentInset(phone: 16),
                32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppSectionHeader(label: 'Appearance'),
                  const SizedBox(height: 10),
                  _appearanceCard(),
                  const SizedBox(height: 24),

                  const AppSectionHeader(label: 'Privacy & Data'),
                  const SizedBox(height: 10),
                  _groupCard([
                    _navRow(
                      icon: Icons.shield_rounded,
                      iconGradient: [
                        LiquidColors.accentBlue,
                        LiquidColors.primaryMid,
                      ],
                      title: 'Security',
                      subtitle:
                          'Locks, PIN, biometrics, recovery, decoy and more.',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SecuritySettingsScreen(),
                          ),
                        );
                      },
                    ),
                    _rowDivider(),
                    _navRow(
                      icon: Icons.history_rounded,
                      iconGradient: [
                        LiquidColors.accentOrange,
                        LiquidColors.accentPink,
                      ],
                      title: 'History',
                      subtitle:
                          'Files you saved out of the vault to the device.',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const HistoryScreen(),
                          ),
                        );
                      },
                    ),
                  ]),
                  const SizedBox(height: 24),

                  const AppSectionHeader(label: 'Information'),
                  const SizedBox(height: 10),
                  _groupCard([
                    _navRow(
                      icon: Icons.info_outline_rounded,
                      iconGradient: [
                        LiquidColors.accentPurple,
                        LiquidColors.accentPink,
                      ],
                      title: 'About SecuroBox',
                      subtitle: 'Version, what makes it secure, and credits.',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AboutScreen(),
                          ),
                        );
                      },
                    ),
                    _rowDivider(),
                    _navRow(
                      icon: Icons.help_outline_rounded,
                      iconGradient: [
                        LiquidColors.success,
                        LiquidColors.accentBlue,
                      ],
                      title: 'Help & Support',
                      subtitle: 'Send feedback, privacy policy, tips, and FAQs.',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SupportScreen(),
                          ),
                        );
                      },
                    ),
                  ]),
                  const SizedBox(height: 26),
                  _versionFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _appearanceCard() {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final current = ThemeController.instance.mode;
        return Container(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
          decoration: BoxDecoration(
            color: LiquidColors.backgroundLight.withValues(alpha: 0.6),
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
                  Expanded(
                    child: _themeOption(current, ThemeMode.system, 'System'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _themeOption(current, ThemeMode.light, 'Light'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _themeOption(current, ThemeMode.dark, 'Dark'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _themeHint(current),
            ],
          ),
        );
      },
    );
  }

  Widget _themeOption(ThemeMode current, ThemeMode mode, String label) {
    final selected = mode == current;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (selected) return;
        HapticFeedback.selectionClick();
        ThemeController.instance.setMode(mode);
      },
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 0.78,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: selected
                    ? LinearGradient(
                        colors: [
                          LiquidColors.accentBlue,
                          LiquidColors.accentPurple,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: selected
                    ? null
                    : LiquidColors.textPrimary.withValues(alpha: 0.08),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color:
                              LiquidColors.accentBlue.withValues(alpha: 0.35),
                          blurRadius: 16,
                          spreadRadius: -3,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: _themeMock(mode),
                  ),
                  if (selected)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: LiquidColors.accentBlue,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Icon(Icons.check_rounded,
                            size: 12, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            label,
            style: TextStyle(
              color: selected
                  ? LiquidColors.textPrimary
                  : LiquidColors.textSecondary,
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _themeMock(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return _miniScreen(Brightness.light);
      case ThemeMode.dark:
        return _miniScreen(Brightness.dark);
      case ThemeMode.system:
        return Stack(
          fit: StackFit.expand,
          children: [
            _miniScreen(Brightness.dark),
            ClipPath(
              clipper: _DiagonalClipper(),
              child: _miniScreen(Brightness.light),
            ),
          ],
        );
    }
  }

  Widget _miniScreen(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F1626) : const Color(0xFFEDF1F7);
    final surface = isDark ? const Color(0xFF1C2740) : Colors.white;
    final line = isDark ? const Color(0xFF35426A) : const Color(0xFFD6DEEA);
    return Container(
      color: bg,
      padding: const EdgeInsets.all(9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 7,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  LiquidColors.accentBlue,
                  LiquidColors.accentPurple,
                ],
              ),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 22,
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 7),
          _mockLine(line, 1.0),
          const SizedBox(height: 4),
          _mockLine(line, 0.72),
          const SizedBox(height: 4),
          _mockLine(line, 0.86),
        ],
      ),
    );
  }

  Widget _mockLine(Color color, double widthFactor) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: Container(
        height: 5,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }

  Widget _themeHint(ThemeMode mode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: LiquidColors.accentBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(_themeIcon(mode), size: 15, color: LiquidColors.accentBlue),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _themeBlurb(mode),
              style: TextStyle(
                color: LiquidColors.textSecondary,
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _themeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return Icons.light_mode_rounded;
      case ThemeMode.dark:
        return Icons.dark_mode_rounded;
      case ThemeMode.system:
        return Icons.brightness_auto_rounded;
    }
  }

  String _themeBlurb(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Bright background — easier to read in daylight.';
      case ThemeMode.dark:
        return 'Dim background — easier on the eyes at night.';
      case ThemeMode.system:
        return 'SecuroBox follows your phone’s light or dark setting.';
    }
  }

  Widget _groupCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: LiquidColors.backgroundLight.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: LiquidColors.cardBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(children: children),
      ),
    );
  }

  Widget _rowDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 66),
      child: Divider(
        height: 1,
        thickness: 1,
        color: LiquidColors.textPrimary.withValues(alpha: 0.05),
      ),
    );
  }

  Widget _navRow({
    required IconData icon,
    required List<Color> iconGradient,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: iconGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: LiquidColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: LiquidColors.textSecondary,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: LiquidColors.textTertiary,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _versionFooter() {
    return Center(
      child: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snap) {
          final v = snap.hasData
              ? '${snap.data!.version} (${snap.data!.buildNumber})'
              : '...';
          return Text(
            'SecuroBox · v$v',
            style: TextStyle(
              color: LiquidColors.textTertiary.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          );
        },
      ),
    );
  }
}

class _DiagonalClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..lineTo(size.width, 0)
    ..lineTo(0, size.height)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
