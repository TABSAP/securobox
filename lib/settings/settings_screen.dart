import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:video_player_app/security_settings/about_screen.dart';
import 'package:video_player_app/security_settings/security_setting.dart';
import 'package:video_player_app/security_settings/safety_center_screen.dart';
import 'package:video_player_app/security_settings/auto_import_screen.dart';
import 'package:video_player_app/security_settings/private_locker_screen.dart';
import 'package:video_player_app/security_settings/support_screen.dart';
import 'package:video_player_app/utils/flush_bar_helper.dart';
import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/utils/responsive.dart';
import 'package:video_player_app/utils/theme_controller.dart';
import 'package:video_player_app/utils/vault_crypto.dart';
import 'package:video_player_app/widgets/app_section_header.dart';
import 'package:video_player_app/widgets/app_spacing.dart';
import 'package:video_player_app/widgets/liquid_glass_surface.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _vaultBytes = -1;
  int _cacheBytes = -1;

  @override
  void initState() {
    super.initState();
    _loadSizes();
  }

  Future<void> _loadSizes() async {
    final vault = await VaultCrypto.instance.currentVaultSize();
    final cache = await VaultCrypto.instance.appCacheSize();
    if (!mounted) return;
    setState(() {
      _vaultBytes = vault;
      _cacheBytes = cache;
    });
  }

  void _open(Widget screen) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _clearCache() async {
    HapticFeedback.lightImpact();
    await VaultCrypto.instance.wipeAppCache();
    await _loadSizes();
    if (!mounted) return;
    FlushBarHelper.flushBarSuccessMessage('Cache cleared', context);
  }

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
        systemOverlayStyle: theme.brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        titleSpacing: 20,
        title: Text(
          'Settings',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
      ),
      body: ColoredBox(
        color: theme.scaffoldBackgroundColor,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            context.contentInset(phone: 16),
            AppSpace.sm,
            context.contentInset(phone: 16),
            MediaQuery.paddingOf(context).bottom + 100,
          ),
          children: [
            _statusHeader(),
            const SizedBox(height: AppSpace.lg),

            const AppSectionHeader(label: 'Security & privacy'),
            const SizedBox(height: AppSpace.sm),
            _group([
              _tile(
                icon: Icons.shield_moon_rounded,
                color: LiquidColors.indigo,
                title: 'Private Locker',
                subtitle: 'A separate PIN-protected space for selected media',
                trailing: _chevron(),
                onTap: () => _open(const PrivateLockerScreen()),
              ),
              _divider(),
              _tile(
                icon: Icons.auto_awesome_motion_rounded,
                color: LiquidColors.accentPurple,
                title: 'Auto-import rules',
                subtitle: 'Review new photos and videos from selected albums',
                trailing: _chevron(),
                onTap: () => _open(const AutoImportScreen()),
              ),
              _divider(),
              _tile(
                icon: Icons.health_and_safety_rounded,
                color: LiquidColors.success,
                title: 'Safety Center',
                subtitle: 'Vault health and encrypted backup & recovery',
                trailing: _chevron(),
                onTap: () => _open(const SafetyCenterScreen()),
              ),
              _divider(),
              _tile(
                icon: Icons.shield_rounded,
                color: LiquidColors.accentBlue,
                title: 'Security',
                subtitle: 'Locks, PIN, biometrics, decoy & recovery',
                trailing: _chevron(),
                onTap: () => _open(const SecuritySettingsScreen()),
              ),
            ]),
            const SizedBox(height: AppSpace.lg),

            const AppSectionHeader(label: 'Storage'),
            const SizedBox(height: AppSpace.sm),
            _group([
              _tile(
                icon: Icons.pie_chart_rounded,
                color: LiquidColors.success,
                title: 'Storage used',
                subtitle: 'Encrypted files in this vault',
                trailing: _valueOnly(
                  _vaultBytes < 0 ? '—' : _fmtBytes(_vaultBytes),
                ),
              ),
              _divider(),
              _tile(
                icon: Icons.cleaning_services_rounded,
                color: LiquidColors.accentBlue,
                title: 'Clear cache',
                subtitle: _cacheBytes <= 0
                    ? 'Free up temporary space'
                    : '${_fmtBytes(_cacheBytes)} of temporary files',
                trailing: _chevron(),
                onTap: _clearCache,
              ),
            ]),
            const SizedBox(height: AppSpace.lg),

            const AppSectionHeader(label: 'Appearance'),
            const SizedBox(height: AppSpace.sm),
            _group([
              _tile(
                icon: _themeIcon(ThemeController.instance.mode),
                color: LiquidColors.indigo,
                title: 'Theme',
                subtitle: _themeSubtitle(ThemeController.instance.mode),
                trailing: _chevron(),
                onTap: _openThemeDialog,
              ),
              _divider(),
              _glassIntensityControl(),
            ]),
            const SizedBox(height: AppSpace.lg),

            const AppSectionHeader(label: 'About'),
            const SizedBox(height: AppSpace.sm),
            _group([
              _tile(
                icon: Icons.info_outline_rounded,
                color: LiquidColors.accentPurple,
                title: 'About SecuroBox',
                subtitle: 'Version, what makes it secure, and credits',
                trailing: _chevron(),
                onTap: () => _open(const AboutScreen()),
              ),
              _divider(),
              _tile(
                icon: Icons.help_outline_rounded,
                color: LiquidColors.success,
                title: 'Help & Support',
                subtitle: 'Feedback, privacy policy, tips and FAQs',
                trailing: _chevron(),
                onTap: () => _open(const SupportScreen()),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _statusHeader() {
    final theme = Theme.of(context);
    return LiquidGlassSurface(
      borderRadius: AppRadius.lg,
      blur: 20,
      padding: const EdgeInsets.all(AppSpace.md),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              Icons.shield_rounded,
              color: theme.colorScheme.onSurface,
              size: 26,
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SecuroBox Vault',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Encrypted · on this device',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: LiquidColors.success.withValues(alpha: 0.15),
                    borderRadius: AppRadius.rPill,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: LiquidColors.success,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Vault active',
                        style: TextStyle(
                          color: LiquidColors.success,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _group(List<Widget> children) {
    return LiquidGlassSurface(
      borderRadius: AppRadius.lg,
      blur: 18,
      padding: EdgeInsets.zero,
      child: Column(children: children),
    );
  }

  IconData _themeIcon(ThemeMode m) {
    switch (m) {
      case ThemeMode.light:
        return Icons.light_mode_rounded;
      case ThemeMode.dark:
        return Icons.dark_mode_rounded;
      case ThemeMode.system:
        return Icons.brightness_auto_rounded;
    }
  }

  String _themeSubtitle(ThemeMode m) => m == ThemeMode.system
      ? 'System default'
      : '${ThemeController.label(m)} mode';

  Widget _glassIntensityControl() {
    final theme = Theme.of(context);
    final controller = ThemeController.instance;
    return ValueListenableBuilder<double>(
      valueListenable: controller.glassIntensityListenable,
      builder: (context, intensity, _) {
        final level = intensity < 0.34
            ? 'Subtle'
            : intensity < 0.67
            ? 'Balanced'
            : 'Strong';
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.md - 2,
            14,
            AppSpace.md - 2,
            12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.06,
                      ),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      Icons.blur_on_rounded,
                      color: theme.colorScheme.onSurface,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Glass intensity',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Adjust frosted surfaces across the app',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.56,
                            ),
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    level,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.66,
                      ),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: theme.colorScheme.onSurface.withValues(
                    alpha: 0.72,
                  ),
                  inactiveTrackColor: theme.colorScheme.onSurface.withValues(
                    alpha: 0.14,
                  ),
                  thumbColor: theme.colorScheme.onSurface,
                  overlayColor: theme.colorScheme.onSurface.withValues(
                    alpha: 0.08,
                  ),
                  trackHeight: 3,
                ),
                child: Semantics(
                  label: 'Glass intensity',
                  value: '$level, ${(intensity * 100).round()} percent',
                  child: Slider(
                    value: intensity,
                    min: 0,
                    max: 1,
                    divisions: 10,
                    onChanged: controller.setGlassIntensity,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Low',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.52,
                        ),
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      'High',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.52,
                        ),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Opens a clean popup dialog to choose Light / Dark / System.
  Future<void> _openThemeDialog() async {
    HapticFeedback.selectionClick();
    const options = <(ThemeMode, String, String)>[
      (ThemeMode.light, 'Light', 'Always light'),
      (ThemeMode.dark, 'Dark', 'Always dark'),
      (ThemeMode.system, 'System default', 'Follow device setting'),
    ];
    final chosen = await showDialog<ThemeMode>(
      context: context,
      builder: (ctx) {
        final current = ThemeController.instance.mode;
        final theme = Theme.of(ctx);
        return Dialog(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          child: LiquidGlassSurface(
            borderRadius: AppRadius.lg,
            blur: 22,
            padding: const EdgeInsets.fromLTRB(8, 18, 8, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Theme',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                for (final o in options)
                  _themeDialogRow(ctx, o.$1, o.$2, o.$3, current),
              ],
            ),
          ),
        );
      },
    );
    if (chosen != null && chosen != ThemeController.instance.mode) {
      await ThemeController.instance.setMode(chosen);
      if (mounted) setState(() {});
    }
  }

  Widget _themeDialogRow(
    BuildContext ctx,
    ThemeMode mode,
    String title,
    String subtitle,
    ThemeMode current,
  ) {
    final selected = mode == current;
    final theme = Theme.of(ctx);
    return InkWell(
      onTap: () => Navigator.of(ctx).pop(mode),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Icon(
              _themeIcon(mode),
              size: 22,
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.62),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.56,
                      ),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(
                Icons.check_rounded,
                size: 20,
                color: theme.colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 66),
      child: Divider(
        height: 1,
        thickness: 1,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? titleColor,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.md - 2),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  // Neutral, theme-adaptive icon: dark in Light mode, light in
                  // Dark mode.
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: theme.colorScheme.onSurface, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: titleColor ?? theme.colorScheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.56,
                          ),
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing],
            ],
          ),
        ),
      ),
    );
  }

  Widget _chevron({Color? color}) {
    final theme = Theme.of(context);
    return Icon(
      Icons.chevron_right_rounded,
      color: color ?? theme.colorScheme.onSurface.withValues(alpha: 0.5),
      size: 22,
    );
  }

  Widget _valueOnly(String value) {
    final theme = Theme.of(context);
    return Text(
      value,
      style: TextStyle(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  String _fmtBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var i = 0;
    while (value >= 1024 && i < units.length - 1) {
      value /= 1024;
      i++;
    }
    return '${value.toStringAsFixed(value >= 10 || i == 0 ? 0 : 1)} ${units[i]}';
  }
}
