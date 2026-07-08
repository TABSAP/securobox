import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:video_player_app/security_settings/about_screen.dart';
import 'package:video_player_app/security_settings/security_setting.dart';
import 'package:video_player_app/security_settings/support_screen.dart';
import 'package:video_player_app/utils/flush_bar_helper.dart';
import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/utils/responsive.dart';
import 'package:video_player_app/utils/theme_controller.dart';
import 'package:video_player_app/utils/vault_crypto.dart';
import 'package:video_player_app/widgets/app_card.dart';
import 'package:video_player_app/widgets/app_section_header.dart';
import 'package:video_player_app/widgets/app_spacing.dart';

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
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: LiquidColors.backgroundDeep,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: LiquidColors.systemOverlayStyle,
        titleSpacing: 20,
        title: Text(
          'Settings',
          style: TextStyle(
            color: LiquidColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
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
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            context.contentInset(phone: 16),
            AppSpace.sm,
            context.contentInset(phone: 16),
            AppSpace.xl,
          ),
          children: [
            _statusHeader(),
            const SizedBox(height: AppSpace.lg),

            const AppSectionHeader(label: 'Security & privacy'),
            const SizedBox(height: AppSpace.sm),
            _group([
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
    return AppCard(
      padding: const EdgeInsets.all(AppSpace.md),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [LiquidColors.accentBlue, LiquidColors.primaryMid],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: Colors.white,
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
                    color: LiquidColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Encrypted · on this device',
                  style: TextStyle(
                    color: LiquidColors.textSecondary,
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
    return AppCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: AppRadius.rLg,
        child: Column(children: children),
      ),
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

  String _themeSubtitle(ThemeMode m) =>
      m == ThemeMode.system ? 'System default' : '${ThemeController.label(m)} mode';

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
        return AlertDialog(
          title: const Text('Theme'),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final o in options)
                _themeDialogRow(ctx, o.$1, o.$2, o.$3, current),
            ],
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
    return InkWell(
      onTap: () => Navigator.of(ctx).pop(mode),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Icon(
              _themeIcon(mode),
              size: 22,
              color: selected ? LiquidColors.indigo : LiquidColors.textSecondary,
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
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: LiquidColors.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_rounded, size: 20, color: LiquidColors.indigo),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.only(left: 66),
      child: Divider(
        height: 1,
        thickness: 1,
        color: LiquidColors.textPrimary.withValues(alpha: 0.05),
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
                  color: LiquidColors.textPrimary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: LiquidColors.textPrimary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: titleColor ?? LiquidColors.textPrimary,
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
                          color: LiquidColors.textTertiary,
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
    return Icon(
      Icons.chevron_right_rounded,
      color: color ?? LiquidColors.textTertiary,
      size: 22,
    );
  }

  Widget _valueOnly(String value) {
    return Text(
      value,
      style: TextStyle(
        color: LiquidColors.textSecondary,
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
