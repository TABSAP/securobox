import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player_app/models/app_models.dart';
import 'package:video_player_app/services/private_locker_service.dart';
import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/utils/media_opener.dart';
import 'package:video_player_app/utils/session_manager.dart';
import 'package:video_player_app/utils/flush_bar_helper.dart';
import 'package:video_player_app/views/screens/secure_picker/secure_media_picker_screen.dart';
import 'package:video_player_app/widgets/app_spacing.dart';
import 'package:video_player_app/widgets/liquid_glass_surface.dart';
import 'package:video_player_app/widgets/vault_thumbnail.dart';

class PrivateLockerScreen extends StatefulWidget {
  const PrivateLockerScreen({super.key});

  @override
  State<PrivateLockerScreen> createState() => _PrivateLockerScreenState();
}

class _PrivateLockerScreenState extends State<PrivateLockerScreen>
    with WidgetsBindingObserver {
  List<VideoItem> _items = const [];
  bool _loading = true;
  bool _enabled = false;
  bool _configured = false;
  bool _locked = true;
  bool _busy = false;
  bool _prompting = false;
  int _lockGeneration = 0;
  int _invalidRecords = 0;
  int _missingFiles = 0;
  String? _error;
  String? _feedback;
  Future<void> Function()? _feedbackRetry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lockGeneration++;
    unawaited(PrivateLockerService.instance.clearSessionPreviews(_items));
    _items = const [];
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      // iOS reports `inactive` while PHPicker is presented. Keep the locker
      // session alive for this trusted system interaction; otherwise the
      // picker can return to a screen that was just locked and cleared.
      if (mounted &&
          !_locked &&
          !SessionManager.instance.inTrustedInteraction) {
        _lock();
      }
    } else if (state == AppLifecycleState.resumed &&
        (ModalRoute.of(context)?.isCurrent ?? false) &&
        _enabled &&
        _configured &&
        !_busy) {
      _unlock();
    }
  }

  Future<void> _loadState() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final locker = PrivateLockerService.instance;
      final enabled = await locker.isEnabled();
      final configured = await locker.isConfigured();
      if (!mounted) return;
      setState(() {
        _enabled = enabled;
        _configured = configured;
        _loading = false;
      });
      if (enabled && configured) _unlock();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error =
              'Private Locker could not be opened. Check device storage and retry.';
        });
      }
    }
  }

  Future<String?> _askPin(
    String title,
    String subtitle, {
    String actionLabel = 'Continue',
  }) => showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _LockerPinDialog(
      title: title,
      subtitle: subtitle,
      actionLabel: actionLabel,
    ),
  );

  Future<void> _setup() async {
    if (_busy) return;
    try {
      final first = await _askPin(
        'Create locker PIN',
        'Choose a separate six-digit PIN for Private Locker.',
        actionLabel: 'Continue',
      );
      if (first == null || !mounted) return;
      final confirm = await _askPin(
        'Confirm locker PIN',
        'Enter the same six-digit PIN again.',
        actionLabel: 'Save PIN',
      );
      if (confirm == null || !mounted) return;
      if (first != confirm) {
        _reportFailure(
          'PINs did not match. Private Locker was not enabled.',
          retry: _setup,
        );
        return;
      }
      setState(() => _busy = true);
      await PrivateLockerService.instance.configure(first);
      if (!mounted) return;
      setState(() {
        _enabled = true;
        _configured = true;
        _locked = false;
        _feedback = null;
        _feedbackRetry = null;
      });
      await _loadItems();
      if (mounted) {
        _notice('Private Locker is ready. Your regular library is unchanged.');
      }
    } catch (_) {
      if (mounted) {
        _reportFailure(
          'Secure setup failed. Your existing vault and media were not changed.',
          retry: _setup,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unlock() async {
    if (_prompting || !_enabled || !_configured || !mounted) return;
    _prompting = true;
    try {
      final pin = await _askPin(
        'Unlock Private Locker',
        'Enter your six-digit locker PIN.',
        actionLabel: 'Unlock locker',
      );
      if (pin == null || !mounted) return;
      final verified = await PrivateLockerService.instance.verifyPin(pin);
      if (!mounted) return;
      if (!verified) {
        _reportFailure(
          'PIN not accepted. After five incorrect attempts, wait 30 seconds before trying again.',
          retry: _unlock,
        );
        return;
      }
      await _loadItems();
    } catch (_) {
      if (mounted) {
        _reportFailure(
          'Secure verification failed. The locker remains locked.',
          retry: _unlock,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _prompting = false);
      } else {
        _prompting = false;
      }
    }
  }

  Future<void> _loadItems() async {
    final generation = _lockGeneration;
    try {
      final items = await PrivateLockerService.instance.loadItems();
      if (mounted && generation == _lockGeneration) {
        setState(() {
          _items = items.items;
          _locked = false;
          _error = null;
          _invalidRecords = items.invalidRecords;
          _missingFiles = items.missingFiles;
          _feedback = null;
          _feedbackRetry = null;
        });
      }
    } catch (_) {
      if (mounted && generation == _lockGeneration) {
        setState(() {
          _items = const [];
          _error =
              'Locker media could not be loaded. Your encrypted files were not changed.';
        });
      }
    }
  }

  Future<void> _addMedia() async {
    if (_busy || _locked) return;
    setState(() => _busy = true);
    try {
      final assets = await SecureMediaPickerScreen.show(
        context,
        type: RequestType.common,
        title: 'Add to Private Locker',
      );
      if (assets == null || assets.isEmpty || !mounted) {
        await SessionManager.instance.markActive();
        return;
      }
      final sources = <File>[];
      var unreadable = 0;
      SessionManager.instance.beginTrustedInteraction();
      try {
        for (final asset in assets) {
          try {
            final file = await asset.file;
            if (file != null && await file.exists()) {
              sources.add(file);
            } else {
              unreadable++;
            }
          } catch (_) {
            unreadable++;
          }
        }
      } finally {
        SessionManager.instance.endTrustedInteraction();
      }
      if (sources.isEmpty) {
        _reportFailure(
          'Selected media could not be read. Choose local photo or video files and retry.',
          retry: _addMedia,
        );
        return;
      }
      final imported = await PrivateLockerService.instance.importFiles(sources);
      await _loadItems();
      if (mounted) {
        final skipped = imported.failed + unreadable;
        if (skipped > 0) {
          _reportFailure(
            '${imported.added} added; $skipped could not be imported. Gallery originals were kept. Select the failed media and retry.',
            retry: _addMedia,
          );
        } else {
          _clearFeedback();
          _notice(
            '${imported.added} added to Private Locker. Gallery originals were kept.',
          );
        }
      }
    } catch (_) {
      if (mounted) {
        _reportFailure(
          'Import could not be saved. Any incomplete encrypted files were rolled back; Gallery originals were kept.',
          retry: _addMedia,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _lock() {
    if (!mounted) return;
    _lockGeneration++;
    final previousItems = _items;
    setState(() {
      _locked = true;
      _items = const [];
    });
    unawaited(
      PrivateLockerService.instance.clearSessionPreviews(previousItems),
    );
  }

  void _notice(String message) {
    if (!mounted) return;
    FlushBarHelper.flushBarSuccessMessage(message, context);
  }

  void _reportFailure(String message, {Future<void> Function()? retry}) {
    if (!mounted) return;
    setState(() {
      _feedback = message;
      _feedbackRetry = retry;
    });
  }

  void _clearFeedback() {
    if (!mounted || _feedback == null) return;
    setState(() {
      _feedback = null;
      _feedbackRetry = null;
    });
  }

  Widget get _failureBanner {
    final retry = _feedbackRetry;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.md,
        AppSpace.sm,
        AppSpace.md,
        0,
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: LiquidGlassSurface(
          borderRadius: AppRadius.md,
          blur: 14,
          tintColor: LiquidColors.error,
          tintOpacity: 0.04,
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          child: Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: LiquidColors.error,
                size: 20,
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                  _feedback ?? '',
                  style: TextStyle(
                    color: LiquidColors.textPrimary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
              if (retry != null)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () {
                          _clearFeedback();
                          unawaited(retry());
                        },
                  child: const Text('Retry'),
                ),
              IconButton(
                tooltip: 'Dismiss message',
                onPressed: _clearFeedback,
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: LiquidColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget get _recordWarning {
    final missing = _missingFiles > 0;
    final count = _missingFiles + _invalidRecords;
    return LiquidGlassSurface(
      borderRadius: AppRadius.md,
      blur: 14,
      tintColor: LiquidColors.warning,
      tintOpacity: 0.04,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(
            missing ? Icons.folder_off_outlined : Icons.info_outline_rounded,
            color: LiquidColors.warning,
            size: 19,
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Text(
              '$count locker ${count == 1 ? 'item needs' : 'items need'} attention${missing ? ' because an encrypted file is missing' : ' because a record could not be verified'}. Other items are safe.',
              style: TextStyle(
                color: LiquidColors.textSecondary,
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Refresh locker',
            onPressed: _busy ? null : _loadItems,
            icon: Icon(Icons.refresh_rounded, color: LiquidColors.warning),
          ),
        ],
      ),
    );
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
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        title: Text(
          'Private Locker',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          if (!_loading && _enabled && _configured && !_locked)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: LiquidGlassSurface(
                borderRadius: 14,
                blur: 14,
                child: Material(
                  color: Colors.transparent,
                  child: IconButton(
                    tooltip: 'Lock now',
                    onPressed: _lock,
                    icon: Icon(
                      Icons.lock_rounded,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: ColoredBox(
        color: theme.scaffoldBackgroundColor,
        child: Column(
          children: [
            if (_feedback != null) _failureBanner,
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                child: _loading
                    ? Center(
                        key: const ValueKey('loading'),
                        child: CircularProgressIndicator(
                          color: theme.colorScheme.primary,
                        ),
                      )
                    : _error != null
                    ? _stateView(
                        key: const ValueKey('error'),
                        icon: Icons.error_outline_rounded,
                        title: 'Could not load locker',
                        body: _error!,
                        action: _glassActionButton(
                          icon: Icons.refresh_rounded,
                          label: 'Try again',
                          onPressed: _loadState,
                        ),
                      )
                    : !_enabled || !_configured
                    ? _setupView
                    : _locked
                    ? _lockedView
                    : _lockerContents,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glassActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    final theme = Theme.of(context);
    return LiquidGlassSurface(
      borderRadius: AppRadius.pill,
      blur: 18,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: AppRadius.rPill,
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: theme.colorScheme.primary, size: 19),
                const SizedBox(width: 9),
                Text(
                  label,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget get _setupView => _stateView(
    key: const ValueKey('setup'),
    icon: Icons.shield_moon_rounded,
    title: 'A private space for selected media',
    body:
        'Keep chosen photos and videos out of your regular SecuroBox library. Files are encrypted in a separate locker folder and protected by a dedicated PIN. Gallery originals are never deleted. Locker media is not included in regular vault backups, and this PIN cannot be recovered, so keep the PIN and another safe copy of your originals.',
    action: _glassActionButton(
      onPressed: _busy ? null : _setup,
      icon: Icons.lock_outline_rounded,
      label: 'Set up Private Locker',
    ),
  );

  Widget get _lockedView => _stateView(
    key: const ValueKey('locked'),
    icon: Icons.lock_rounded,
    title: 'Private Locker is locked',
    body:
        'Your private media stays encrypted and separate from the main library. Enter your locker PIN to continue.',
    action: _glassActionButton(
      onPressed: _prompting ? null : _unlock,
      icon: Icons.lock_open_rounded,
      label: 'Unlock locker',
    ),
  );

  Widget _stateView({
    required Key key,
    required IconData icon,
    required String title,
    required String body,
    required Widget action,
  }) => Center(
    key: key,
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: LiquidGlassSurface(
        borderRadius: AppRadius.lg,
        blur: 22,
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 34,
              ),
            ),
            const SizedBox(height: AppSpace.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.62),
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            SizedBox(width: double.infinity, child: action),
            if (_busy) ...[
              const SizedBox(height: AppSpace.md),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    ),
  );

  Widget get _lockerContents => Column(
    key: const ValueKey('contents'),
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.md,
          AppSpace.sm,
          AppSpace.md,
          AppSpace.md,
        ),
        child: _summaryCard,
      ),
      if (_invalidRecords > 0 || _missingFiles > 0)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.md,
            0,
            AppSpace.md,
            AppSpace.sm,
          ),
          child: _recordWarning,
        ),
      Expanded(
        child: _items.isEmpty
            ? _stateView(
                key: const ValueKey('empty'),
                icon: Icons.photo_library_outlined,
                title: 'Your locker is empty',
                body:
                    'Add photos and videos here. They will be encrypted and kept out of the regular library.',
                action: _glassActionButton(
                  onPressed: _busy ? null : _addMedia,
                  icon: Icons.add_photo_alternate_rounded,
                  label: 'Add media',
                ),
              )
            : GridView.builder(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.md,
                  0,
                  AppSpace.md,
                  AppSpace.md,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: AppSpace.sm,
                  mainAxisSpacing: AppSpace.sm,
                  childAspectRatio: .78,
                ),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return TweenAnimationBuilder<double>(
                    key: ValueKey(item.id),
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(
                      milliseconds: 220 + (index.clamp(0, 6) * 35),
                    ),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) => Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 10 * (1 - value)),
                        child: child,
                      ),
                    ),
                    child: LiquidGlassSurface(
                      borderRadius: AppRadius.md,
                      blur: 16,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => openVaultMedia(context, item),
                          borderRadius: AppRadius.rMd,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    VaultThumbnail(
                                      item: item,
                                      width: double.infinity,
                                      height: double.infinity,
                                      radius: 0,
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(
                                            alpha: .45,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.lock_rounded,
                                          color: Colors.white,
                                          size: 15,
                                        ),
                                      ),
                                    ),
                                    if (item.type == 'video')
                                      const Positioned(
                                        left: 8,
                                        bottom: 8,
                                        child: Icon(
                                          Icons.play_circle_fill_rounded,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.md,
            AppSpace.sm,
            AppSpace.md,
            AppSpace.md,
          ),
          child: SizedBox(
            width: double.infinity,
            child: _glassActionButton(
              onPressed: _busy ? null : _addMedia,
              icon: Icons.add_rounded,
              label: _busy ? 'Adding securely…' : 'Add photos or videos',
            ),
          ),
        ),
      ),
    ],
  );

  Widget get _summaryCard => LiquidGlassSurface(
    borderRadius: AppRadius.lg,
    blur: 18,
    padding: const EdgeInsets.all(AppSpace.md),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.shield_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Private and encrypted',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${_items.length} ${_items.length == 1 ? 'item' : 'items'} · separate from your library',
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.62),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _LockerPinDialog extends StatefulWidget {
  const _LockerPinDialog({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
  });
  final String title;
  final String subtitle;
  final String actionLabel;

  @override
  State<_LockerPinDialog> createState() => _LockerPinDialogState();
}

class _LockerPinDialogState extends State<_LockerPinDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.clear();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _controller.text.length == 6;
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: LiquidGlassSurface(
        borderRadius: AppRadius.lg,
        blur: 22,
        padding: const EdgeInsets.all(AppSpace.lg),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.07,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.lock_rounded,
                      color: theme.colorScheme.primary,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.md),
              Text(
                widget.subtitle,
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: AppSpace.md),
              TextField(
                controller: _controller,
                autofocus: true,
                obscureText: true,
                obscuringCharacter: '•',
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                textAlign: TextAlign.center,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 10,
                ),
                decoration: InputDecoration(
                  labelText: '6-digit PIN',
                  hintText: '••••••',
                  errorText: _error,
                  counterText: '',
                  isDense: true,
                  filled: true,
                  fillColor: theme.colorScheme.onSurface.withValues(
                    alpha: 0.035,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 17,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.12,
                      ),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.12,
                      ),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: theme.colorScheme.error),
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
              if (_error == null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.privacy_tip_outlined,
                      size: 15,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.55,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Separate from your main app PIN',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.55,
                          ),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpace.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _pinDialogButton(
                    context,
                    label: 'Cancel',
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 10),
                  _pinDialogButton(
                    context,
                    label: widget.actionLabel,
                    onPressed: canSubmit ? _submit : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pinDialogButton(
    BuildContext context, {
    required String label,
    required VoidCallback? onPressed,
  }) {
    final theme = Theme.of(context);
    return LiquidGlassSurface(
      borderRadius: 14,
      blur: 14,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 84, minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.82),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {
      if (_error != null) _error = null;
    });
  }

  void _submit() {
    final pin = _controller.text;
    if (pin.length != 6) {
      setState(() => _error = 'Enter all six digits.');
      HapticFeedback.selectionClick();
      return;
    }
    Navigator.pop(context, pin);
  }
}
