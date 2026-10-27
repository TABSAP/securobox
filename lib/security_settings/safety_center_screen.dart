import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_app/models/app_models.dart';
import 'package:video_player_app/utils/vault_context.dart';
import 'package:video_player_app/utils/session_manager.dart';
import 'package:video_player_app/services/vault_backup_service.dart';
import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/utils/flush_bar_helper.dart';
import 'package:video_player_app/widgets/app_spacing.dart';
import 'package:video_player_app/widgets/liquid_glass_surface.dart';
import 'package:video_player_app/widgets/liquid_glass_button.dart';

class SafetyCenterScreen extends StatefulWidget {
  const SafetyCenterScreen({super.key});

  @override
  State<SafetyCenterScreen> createState() => _SafetyCenterScreenState();
}

class _SafetyCenterScreenState extends State<SafetyCenterScreen> {
  String get _lastBackupKey => VaultContext.instance.isDecoy
      ? 'vaultBackupLastAction_decoy'
      : 'vaultBackupLastAction';
  bool _busy = false;
  int _items = 0;
  int _missingFiles = 0;
  bool _refreshing = false;
  String _galleryAccess = 'Checking photo library access…';
  String _lastAction = 'No backup has been created on this device yet.';
  String? _statusError;

  @override
  void initState() {
    super.initState();
    _refreshCount();
  }

  Future<void> _refreshCount() async {
    if (_refreshing) return;
    if (mounted) setState(() => _refreshing = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final rows =
          prefs.getStringList(VaultContext.instance.libraryKey) ?? const [];
      final lastAction =
          prefs.getString(_lastBackupKey) ??
          'No backup has been created on this device yet.';
      var missing = 0;
      var activeCount = 0;
      for (final row in rows) {
        try {
          final item = VideoItem.fromStorageString(row);
          if (item.isDeleted) continue;
          activeCount++;
          if (!await File(item.path).exists()) missing++;
        } catch (_) {
          missing++;
        }
      }
      String access;
      try {
        final state = await PhotoManager.getPermissionState(
          requestOption: const PermissionRequestOption(),
        );
        access = state.isAuth
            ? 'Full photo and video access is allowed'
            : state.isLimited
            ? 'Gallery access is limited'
            : 'Gallery access is not allowed';
      } catch (_) {
        access = 'Could not read Gallery permission status';
      }
      if (mounted) {
        setState(() {
          _items = activeCount;
          _missingFiles = missing;
          _galleryAccess = access;
          _lastAction = lastAction;
          _statusError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _statusError =
              'Vault status could not be loaded. Tap refresh to try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<String?> _askPassphrase({required String title}) async {
    return showDialog<String>(
      context: context,
      builder: (_) => _PassphraseDialog(title: title),
    );
  }

  Future<void> _createBackup() async {
    final password = await _askPassphrase(title: 'Protect your backup');
    if (password == null || !mounted) return;
    final confirmation = await _askPassphrase(
      title: 'Confirm backup passphrase',
    );
    if (confirmation == null || !mounted) return;
    if (confirmation != password) {
      _message(
        'Passphrases did not match. Backup was not created.',
        error: true,
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final bytes = await VaultBackupService.instance.createBackup(password);
      if (!mounted) return;
      SessionManager.instance.beginTrustedInteraction();
      String? path;
      try {
        FocusManager.instance.primaryFocus?.unfocus();
        path = await FilePicker.platform.saveFile(
          dialogTitle: 'Save encrypted SecuroBox backup',
          fileName: 'securobox_backup.sbbackup',
          type: FileType.custom,
          allowedExtensions: const ['sbbackup'],
          bytes: bytes,
        );
        if (path == null) await SessionManager.instance.markActive();
      } finally {
        SessionManager.instance.endTrustedInteraction();
      }
      if (path == null) return;
      // Android/iOS document providers persist the bytes passed to saveFile.
      // Desktop providers return a path and require a direct write.
      if (!Platform.isAndroid && !Platform.isIOS) {
        await File(path).writeAsBytes(bytes, flush: true);
      }
      final stamp = DateTime.now().toLocal().toString().substring(0, 16);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastBackupKey, 'Last encrypted backup: $stamp');
      setState(() => _lastAction = 'Last encrypted backup: $stamp');
      _message('Encrypted backup created. Keep the passphrase separately.');
    } catch (_) {
      _message(
        'Backup could not be saved. Check available storage and try again. Your vault files were not changed.',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreBackup() async {
    setState(() => _busy = true);
    try {
      SessionManager.instance.beginTrustedInteraction();
      FilePickerResult? picked;
      try {
        FocusManager.instance.primaryFocus?.unfocus();
        picked = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['sbbackup'],
          withData: false,
        );
        if (picked == null || picked.files.isEmpty) {
          await SessionManager.instance.markActive();
        }
      } finally {
        SessionManager.instance.endTrustedInteraction();
      }
      if (picked == null || picked.files.isEmpty || !mounted) return;
      final selected = picked.files.single;
      if (selected.size > 130 * 1024 * 1024) {
        _message(
          'This backup is larger than the 130 MB import limit.',
          error: true,
        );
        return;
      }
      final path = selected.path;
      if (path == null) {
        _message(
          'The selected backup is not readable from this location. Copy it to Files and try again.',
          error: true,
        );
        return;
      }
      final bytes = await File(path).readAsBytes();
      if (!mounted) return;
      final password = await _askPassphrase(title: 'Unlock your backup');
      if (password == null || !mounted) return;
      final restored = await VaultBackupService.instance.restoreBackup(
        bytes,
        password,
      );
      final stamp = DateTime.now().toLocal().toString().substring(0, 16);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastBackupKey, 'Last restore: $stamp');
      await _refreshCount();
      if (!mounted) return;
      setState(() => _lastAction = 'Last restore: $stamp');
      _message('$restored items restored. Existing vault items were kept.');
    } on FormatException {
      _message(
        'Backup could not be verified. Check the passphrase or choose an intact SecuroBox backup. Nothing was restored.',
        error: true,
      );
    } on FileSystemException {
      _message(
        'The backup file could not be read. Check its location and try again. Your vault was not changed.',
        error: true,
      );
    } catch (_) {
      _message(
        'Restore could not be completed. Your existing vault files were kept; check storage and try again.',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    if (error) {
      FlushBarHelper.flushBarErrorMessage(text, context);
    } else {
      FlushBarHelper.flushBarSuccessMessage(text, context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        titleTextStyle: TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        title: const Text('Safety Center'),
        actions: [
          IconButton(
            tooltip: 'Refresh vault status',
            onPressed: _refreshing ? null : _refreshCount,
            icon: AnimatedRotation(
              turns: _refreshing ? 1 : 0,
              duration: const Duration(milliseconds: 500),
              child: const Icon(Icons.refresh_rounded),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(AppSpace.md),
            children: [
              _healthCard(),
              const SizedBox(height: AppSpace.lg),
              _sectionTitle(
                'BACKUP & RECOVERY',
                'Encrypted tools for moving or recovering your vault',
              ),
              const SizedBox(height: AppSpace.sm),
              _actionCard(
                icon: Icons.enhanced_encryption_rounded,
                title: 'Create encrypted backup',
                subtitle:
                    'Save a portable, passphrase-protected copy to Files, Drive, or iCloud Drive.',
                onTap: _busy ? null : _createBackup,
              ),
              const SizedBox(height: AppSpace.sm),
              _actionCard(
                icon: Icons.settings_backup_restore_rounded,
                title: 'Restore from backup',
                subtitle:
                    'Verify the backup first, then add its files to this vault.',
                onTap: _busy ? null : _restoreBackup,
              ),
              const SizedBox(height: AppSpace.md),
              _securityNote(),
            ],
          ),
          if (_busy)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black45,
                child: Center(
                  child: LiquidGlassSurface(
                    borderRadius: AppRadius.lg,
                    blur: 20,
                    padding: const EdgeInsets.all(AppSpace.md),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: LiquidColors.indigo),
                        const SizedBox(height: AppSpace.md),
                        Text(
                          'Preparing secure recovery…',
                          style: TextStyle(
                            color: LiquidColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusLine(IconData icon, String text) => Row(
    children: [
      Icon(icon, color: LiquidColors.success, size: 17),
      const SizedBox(width: AppSpace.sm),
      Expanded(
        child: Text(
          text,
          style: TextStyle(color: LiquidColors.textSecondary, fontSize: 13),
        ),
      ),
    ],
  );

  Widget _healthCard() => LiquidGlassSurface(
    borderRadius: AppRadius.lg,
    blur: 20,
    padding: const EdgeInsets.all(AppSpace.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: LiquidColors.success.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.verified_user_rounded,
                color: LiquidColors.success,
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vault health',
                    style: TextStyle(
                      color: LiquidColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _missingFiles == 0
                        ? 'Your local files are ready'
                        : 'Some files need attention',
                    style: TextStyle(
                      color: LiquidColors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color:
                    (_missingFiles == 0
                            ? LiquidColors.success
                            : LiquidColors.warning)
                        .withValues(alpha: .12),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _missingFiles == 0
                        ? Icons.check_circle_rounded
                        : Icons.error_rounded,
                    size: 14,
                    color: _missingFiles == 0
                        ? LiquidColors.success
                        : LiquidColors.warning,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _missingFiles == 0 ? 'Healthy' : 'Review',
                    style: TextStyle(
                      color: _missingFiles == 0
                          ? LiquidColors.success
                          : LiquidColors.warning,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.md),
        Container(height: 1, color: LiquidColors.divider),
        const SizedBox(height: AppSpace.md),
        Row(
          children: [
            Expanded(
              child: _healthMetric(
                Icons.photo_library_rounded,
                '$_items',
                'vault items',
              ),
            ),
            Container(width: 1, height: 38, color: LiquidColors.divider),
            Expanded(
              child: _healthMetric(
                Icons.warning_amber_rounded,
                '$_missingFiles',
                'missing files',
                alert: _missingFiles > 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.md),
        _statusLine(Icons.photo_library_outlined, _galleryAccess),
        const SizedBox(height: AppSpace.sm),
        _statusLine(Icons.lock_outline_rounded, 'Encrypted on this device'),
        const SizedBox(height: AppSpace.sm),
        _statusLine(Icons.history_rounded, _lastAction),
        if (_statusError != null) ...[
          const SizedBox(height: AppSpace.sm),
          Text(
            _statusError!,
            style: TextStyle(color: LiquidColors.error, fontSize: 12),
          ),
          TextButton.icon(
            onPressed: _refreshCount,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh status'),
          ),
        ],
      ],
    ),
  );

  Widget _healthMetric(
    IconData icon,
    String value,
    String label, {
    bool alert = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
    child: Row(
      children: [
        Icon(
          icon,
          color: alert ? LiquidColors.warning : LiquidColors.indigo,
          size: 19,
        ),
        const SizedBox(width: AppSpace.sm),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: LiquidColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: LiquidColors.textTertiary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _sectionTitle(String title, String subtitle) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: LiquidColors.textTertiary,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(color: LiquidColors.textSecondary, fontSize: 11),
        ),
      ],
    ),
  );

  Widget _securityNote() => LiquidGlassSurface(
    borderRadius: AppRadius.md,
    blur: 16,
    padding: const EdgeInsets.all(AppSpace.md),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.shield_outlined, color: LiquidColors.indigo, size: 20),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Text(
            'Your backup is encrypted before it is saved. SecuroBox never receives the file or passphrase. Keep the passphrase somewhere safe; it cannot be recovered. Media limit: 128 MB.',
            style: TextStyle(
              color: LiquidColors.textSecondary,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _actionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) => AnimatedOpacity(
    duration: const Duration(milliseconds: 180),
    opacity: onTap == null ? .55 : 1,
    child: LiquidGlassSurface(
      borderRadius: AppRadius.lg,
      blur: 18,
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.md),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: LiquidColors.textPrimary.withValues(alpha: .06),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, color: LiquidColors.textPrimary, size: 23),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: LiquidColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: LiquidColors.textSecondary,
                          fontSize: 11.5,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpace.xs),
                Icon(
                  Icons.chevron_right_rounded,
                  color: LiquidColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _PassphraseDialog extends StatefulWidget {
  const _PassphraseDialog({required this.title});
  final String title;

  @override
  State<_PassphraseDialog> createState() => _PassphraseDialogState();
}

class _PassphraseDialogState extends State<_PassphraseDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      child: LiquidGlassSurface(
        borderRadius: AppRadius.lg,
        blur: 22,
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpace.md),
              TextFormField(
                controller: _controller,
                obscureText: true,
                autofocus: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Backup passphrase',
                  helperText: 'Use at least 10 characters and keep it safe.',
                ),
                validator: (value) => (value ?? '').trim().length < 10
                    ? 'Enter at least 10 characters.'
                    : null,
              ),
              const SizedBox(height: AppSpace.md),
              Row(
                children: [
                  Expanded(
                    child: LiquidGlassButton(
                      label: 'Cancel',
                      onPressed: () => Navigator.pop(context),
                      height: 46,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LiquidGlassButton(
                      label: 'Continue',
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          Navigator.pop(context, _controller.text);
                        }
                      },
                      height: 46,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
