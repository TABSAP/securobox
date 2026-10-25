import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_player_app/models/app_models.dart';
import 'package:video_player_app/services/private_locker_service.dart';
import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/utils/media_opener.dart';
import 'package:video_player_app/widgets/app_card.dart';
import 'package:video_player_app/widgets/app_spacing.dart';
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
      if (mounted && !_locked) _lock();
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
    final staged = <File>[];
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.media,
        allowMultiple: true,
        withData: false,
        withReadStream: true,
        dialogTitle: 'Add photos and videos to Private Locker',
      );
      if (result == null || result.files.isEmpty || !mounted) return;
      final sources = <File>[];
      var unreadable = 0;
      final tempDir = await getTemporaryDirectory();
      for (final picked in result.files) {
        final path = picked.path;
        if (path != null && await File(path).exists()) {
          sources.add(File(path));
          continue;
        }
        final stream = picked.readStream;
        if (stream == null) {
          unreadable++;
          continue;
        }
        final safeName = p
            .basename(picked.name)
            .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
        final temp = File(
          p.join(
            tempDir.path,
            'locker_${DateTime.now().microsecondsSinceEpoch}_${staged.length}_$safeName',
          ),
        );
        staged.add(temp);
        final sink = temp.openWrite();
        try {
          await sink.addStream(stream);
          sources.add(temp);
        } catch (_) {
          unreadable++;
        } finally {
          await sink.close();
        }
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
      for (final file in staged) {
        try {
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: LiquidColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          decoration: BoxDecoration(
            color: LiquidColors.error.withValues(alpha: .09),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: LiquidColors.error.withValues(alpha: .3)),
          ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: LiquidColors.warning.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: LiquidColors.warning.withValues(alpha: .28)),
      ),
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
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: LiquidColors.backgroundDeep,
    appBar: AppBar(
      backgroundColor: LiquidColors.backgroundDeep,
      surfaceTintColor: Colors.transparent,
      title: const Text('Private Locker'),
      actions: [
        if (!_loading && _enabled && _configured && !_locked)
          IconButton(
            tooltip: 'Lock now',
            onPressed: _lock,
            icon: const Icon(Icons.lock_rounded),
          ),
      ],
    ),
    body: Column(
      children: [
        if (_feedback != null) _failureBanner,
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            child: _loading
                ? const Center(
                    key: ValueKey('loading'),
                    child: CircularProgressIndicator(),
                  )
                : _error != null
                ? _stateView(
                    key: const ValueKey('error'),
                    icon: Icons.error_outline_rounded,
                    title: 'Could not load locker',
                    body: _error!,
                    action: FilledButton.icon(
                      onPressed: _loadState,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try again'),
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
  );

  Widget get _setupView => _stateView(
    key: const ValueKey('setup'),
    icon: Icons.shield_moon_rounded,
    title: 'A private space for selected media',
    body:
        'Keep chosen photos and videos out of your regular SecuroBox library. Files are encrypted in a separate locker folder and protected by a dedicated PIN. Gallery originals are never deleted. Locker media is not included in regular vault backups, and this PIN cannot be recovered, so keep the PIN and another safe copy of your originals.',
    action: FilledButton.icon(
      onPressed: _busy ? null : _setup,
      icon: const Icon(Icons.lock_outline_rounded),
      label: const Text('Set up Private Locker'),
    ),
  );

  Widget get _lockedView => _stateView(
    key: const ValueKey('locked'),
    icon: Icons.lock_rounded,
    title: 'Private Locker is locked',
    body:
        'Your private media stays encrypted and separate from the main library. Enter your locker PIN to continue.',
    action: FilledButton.icon(
      onPressed: _prompting ? null : _unlock,
      icon: const Icon(Icons.lock_open_rounded),
      label: const Text('Unlock locker'),
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
      child: AppCard(
        elevated: true,
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: LiquidColors.indigo.withValues(alpha: .12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: LiquidColors.indigo, size: 34),
            ),
            const SizedBox(height: AppSpace.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: LiquidColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: LiquidColors.textSecondary,
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
                action: FilledButton.icon(
                  onPressed: _busy ? null : _addMedia,
                  icon: const Icon(Icons.add_photo_alternate_rounded),
                  label: const Text('Add media'),
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
                    child: GestureDetector(
                      onTap: () => openVaultMedia(context, item),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: Container(
                          decoration: BoxDecoration(
                            color: LiquidColors.backgroundLight,
                            border: Border.all(color: LiquidColors.cardBorder),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
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
                                    color: LiquidColors.textPrimary,
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
            child: FilledButton.icon(
              onPressed: _busy ? null : _addMedia,
              icon: const Icon(Icons.add_rounded),
              label: Text(_busy ? 'Adding securely…' : 'Add photos or videos'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ),
        ),
      ),
    ],
  );

  Widget get _summaryCard => Container(
    padding: const EdgeInsets.all(AppSpace.md),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          LiquidColors.indigo.withValues(alpha: .15),
          LiquidColors.backgroundLight,
        ],
      ),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(color: LiquidColors.indigo.withValues(alpha: .18)),
    ),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: LiquidColors.indigo.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.shield_rounded, color: LiquidColors.indigo),
        ),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Private and encrypted',
                style: TextStyle(
                  color: LiquidColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${_items.length} ${_items.length == 1 ? 'item' : 'items'} · separate from your library',
                style: TextStyle(
                  color: LiquidColors.textSecondary,
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
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [LiquidColors.accentBlue, LiquidColors.accentPurple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.lock_rounded,
              color: Colors.white,
              size: 21,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.subtitle,
              style: TextStyle(
                color: LiquidColors.textSecondary,
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
              style: const TextStyle(
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
                fillColor: LiquidColors.textPrimary.withValues(alpha: .035),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 17,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(
                    color: LiquidColors.accentBlue,
                    width: 1.6,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: LiquidColors.error),
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
                    color: LiquidColors.textTertiary,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Separate from your main app PIN',
                      style: TextStyle(
                        color: LiquidColors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: canSubmit ? _submit : null,
          child: Text(widget.actionLabel),
        ),
      ],
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
