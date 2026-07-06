import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:video_player_app/history_screen/history_screen.dart';
import 'package:video_player_app/onboarding_screen/onboarding_screen.dart';
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
    final cache = await VaultCrypto.instance.tempCacheSize();
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
    await VaultCrypto.instance.wipeAllTempCache();
    await _loadSizes();
    if (!mounted) return;
    FlushBarHelper.flushBarSuccessMessage('Cache cleared', context);
  }

  Future<void> _confirmWipe() async {
    HapticFeedback.heavyImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete all data?',
          style: TextStyle(color: LiquidColors.textPrimary),
        ),
        content: Text(
          'This permanently erases every file in your vault, your PIN, and all '
          'settings. This cannot be undone.',
          style: TextStyle(color: LiquidColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: LiquidColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete everything',
              style: TextStyle(
                color: LiquidColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await VaultCrypto.instance.resetAll();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (_) {}
    try {
      const storage = FlutterSecureStorage(
        aOptions: AndroidOptions(resetOnError: false),
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
      );
      await storage.deleteAll();
    } catch (_) {}

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        ThemeController.instance.effectiveBrightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: LiquidColors.backgroundDeep,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
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
              _divider(),
              _tile(
                icon: Icons.history_rounded,
                color: LiquidColors.accentOrange,
                title: 'History',
                subtitle: 'Files you exported out of the vault',
                trailing: _chevron(),
                onTap: () => _open(const HistoryScreen()),
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
                    ? 'No temporary files'
                    : '${_fmtBytes(_cacheBytes)} of temporary files',
                trailing: _chevron(),
                onTap: _cacheBytes <= 0 ? null : _clearCache,
              ),
            ]),
            const SizedBox(height: AppSpace.lg),

            const AppSectionHeader(label: 'Appearance'),
            const SizedBox(height: AppSpace.sm),
            _group([
              _tile(
                icon: isDark
                    ? Icons.dark_mode_rounded
                    : Icons.light_mode_rounded,
                color: LiquidColors.accentPurple,
                title: 'Dark mode',
                subtitle: 'Use the dark theme',
                trailing: Switch.adaptive(
                  value: isDark,
                  activeThumbColor: LiquidColors.accentBlue,
                  onChanged: (v) {
                    HapticFeedback.selectionClick();
                    ThemeController.instance.setMode(
                      v ? ThemeMode.dark : ThemeMode.light,
                    );
                  },
                ),
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
            const SizedBox(height: AppSpace.lg),

            const AppSectionHeader(label: 'Danger zone'),
            const SizedBox(height: AppSpace.sm),
            _group([
              _tile(
                icon: Icons.delete_forever_rounded,
                color: LiquidColors.error,
                title: 'Delete all data',
                subtitle: 'Permanently wipe the vault',
                titleColor: LiquidColors.error,
                trailing: _chevron(color: LiquidColors.error),
                onTap: _confirmWipe,
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
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: color, size: 20),
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
