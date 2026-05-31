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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LiquidColors.primaryGradient,
                borderRadius: BorderRadius.circular(13),
                boxShadow: [
                  BoxShadow(
                    color: LiquidColors.primaryStart.withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(
                Icons.settings_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
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
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: LiquidColors.textPrimary,
                      letterSpacing: 0.4,
                    ),
                  ),
                  Text(
                    'Personalise SecuroBox to your taste',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: LiquidColors.textTertiary,
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
                12,
                context.contentInset(phone: 16),
                32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  _sectionLabel('APP THEME'),
                  const SizedBox(height: 10),
                  _appearanceCard(),
                  const SizedBox(height: 26),

                  _sectionLabel('PRIVACY'),
                  const SizedBox(height: 10),
                  _navTile(
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
                  const SizedBox(height: 12),
                  _navTile(
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
                  const SizedBox(height: 26),

                  _sectionLabel('INFORMATION'),
                  const SizedBox(height: 10),
                  _navTile(
                    icon: Icons.info_outline_rounded,
                    iconGradient: [
                      LiquidColors.accentPurple,
                      LiquidColors.accentPink,
                    ],
                    title: 'About SecuroBox',
                    subtitle:
                        'Version, what makes it secure, and credits.',
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AboutScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _navTile(
                    icon: Icons.help_outline_rounded,
                    iconGradient: [
                      LiquidColors.success,
                      LiquidColors.accentBlue,
                    ],
                    title: 'Help & Support',
                    subtitle:
                        'Send feedback, privacy policy, tips, and FAQs.',
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SupportScreen(),
                        ),
                      );
                    },
                  ),
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

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: TextStyle(
          color: LiquidColors.textSecondary,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
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

  /// One selectable theme card, framed by a live miniature of the theme so
  /// the option previews exactly what tapping it does.
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

  /// A tiny mock of an app screen rendered in [brightness] — used inside the
  /// theme picker so each tile shows what the theme really looks like.
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

  Widget _navTile({
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
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: LiquidColors.backgroundLight.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: LiquidColors.textPrimary.withValues(alpha: 0.06),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: iconGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: iconGradient.first.withValues(alpha: 0.35),
                      blurRadius: 14,
                      spreadRadius: -2,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: LiquidColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 3),
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

/// Clips to the top-left triangle, so the System theme tile can show the
/// light mock diagonally over the dark one.
class _DiagonalClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..lineTo(size.width, 0)
    ..lineTo(0, size.height)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
