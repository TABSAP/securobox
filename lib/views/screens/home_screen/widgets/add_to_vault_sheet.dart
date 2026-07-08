import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:video_player_app/widgets/app_loader.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:photo_manager/photo_manager.dart';

import 'package:video_player_app/utils/app_rating.dart';
import 'package:video_player_app/utils/flush_bar_helper.dart';
import 'package:video_player_app/utils/responsive.dart';
import 'package:video_player_app/views/screens/secure_picker/secure_media_picker_screen.dart';
import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/utils/media_importer.dart';
import 'package:video_player_app/utils/notification_service.dart';
import 'package:video_player_app/utils/session_manager.dart';
import 'package:video_player_app/utils/vault_context.dart';

class AddToVaultSheet extends StatefulWidget {
  final Future<void> Function() onImported;

  /// When set (with [autoStart]), imports go straight into this category and
  /// the category grid is skipped.
  final String? initialCategory;

  /// When true, the sheet opens the picker immediately instead of showing the
  /// Quick Import grid. If [initialCategory] is null a smart (all-types) picker
  /// is used; otherwise the picker is filtered for that category.
  final bool autoStart;

  const AddToVaultSheet({
    super.key,
    required this.onImported,
    this.initialCategory,
    this.autoStart = false,
  });

  static Future<void> show(
    BuildContext context, {
    required Future<void> Function() onImported,
    String? initialCategory,
    bool autoStart = false,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => AddToVaultSheet(
        onImported: onImported,
        initialCategory: initialCategory,
        autoStart: autoStart,
      ),
    );
  }

  @override
  State<AddToVaultSheet> createState() => _AddToVaultSheetState();
}

class _AddToVaultSheetState extends State<AddToVaultSheet> {
  static const List<String> _builtInCategories = [
    'Videos',
    'Photos',
    'Audio',
    'Documents',
    'Others',
  ];

  final List<String> _customCategories = [];
  bool _loadingCustoms = true;
  bool _importing = false;
  final ValueNotifier<(int, int)> _progress = ValueNotifier((0, 0));

  String get _customKey => VaultContext.instance.customCategoriesKey;

  @override
  void initState() {
    super.initState();
    _loadCustomCategories();
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoStartRun());
    }
  }

  // Direct-pick mode: open the (category-filtered) picker immediately, import
  // into the chosen category, then dismiss — no Quick Import grid.
  Future<void> _autoStartRun() async {
    try {
      if (widget.initialCategory != null) {
        await _importInto(widget.initialCategory!);
      } else {
        await _smartImport();
      }
    } finally {
      if (mounted) _dismissSheet();
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  Future<void> _loadCustomCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_customKey) ?? const <String>[];
      if (!mounted) return;
      setState(() {
        _customCategories
          ..clear()
          ..addAll(saved);
        _loadingCustoms = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingCustoms = false);
    }
  }

  Future<void> _persistCustomCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_customKey, List<String>.from(_customCategories));
    } catch (_) {}
  }

  FileType _fileTypeForCategory(String category) {
    switch (category) {
      case 'Videos':
        return FileType.video;
      case 'Photos':
        return FileType.image;
      case 'Audio':
        return FileType.audio;
      case 'Documents':
        return FileType.custom;
      default:
        return FileType.any;
    }
  }

  /// Allowed extensions for a custom-typed picker (Documents only). Returns
  /// null for every other category, which uses a broader [FileType].
  List<String>? _allowedExtensionsForCategory(String category) {
    if (category != 'Documents') return null;
    return MediaImporter.docExtensions
        .map((e) => e.replaceFirst('.', '').toLowerCase())
        .toList();
  }

  Future<void> _smartImport() async {
    HapticFeedback.lightImpact();
    await _importFromGallery(null, RequestType.all);
  }

  RequestType? _galleryRequestType(String category) {
    switch (category) {
      case 'Photos':
        return RequestType.image;
      case 'Videos':
        return RequestType.video;
      case 'Audio':
        return RequestType.audio;
      default:
        return null;
    }
  }

  Future<void> _importInto(String category) async {
    HapticFeedback.selectionClick();
    final galleryType = _galleryRequestType(category);
    if (galleryType != null) {
      await _importFromGallery(category, galleryType);
    } else {
      await _pickAndImport(
        category: category,
        type: _fileTypeForCategory(category),
        allowedExtensions: _allowedExtensionsForCategory(category),
      );
    }
  }

  Future<void> _importFromGallery(String? category, RequestType type) async {
    final assets = await SecureMediaPickerScreen.show(
      context,
      type: type,
      title: category == null ? 'Add to vault' : 'Add $category',
    );
    if (assets == null || assets.isEmpty || !mounted) return;

    final items = <PickedMedia>[];
    SessionManager.instance.beginTrustedInteraction();
    try {
      for (final a in assets) {
        final f = await a.file;
        if (f != null && await f.exists()) {
          final name = await a.titleAsync;
          items.add(PickedMedia(
            f,
            galleryAssetId: a.id,
            originalName: name.isNotEmpty ? name : a.title,
            origin: 'gallery',
            originAlbum: a.relativePath ?? '',
          ));
        }
      }
    } catch (_) {
    } finally {
      SessionManager.instance.endTrustedInteraction();
    }
    await _runImport(items, category);
  }

  void _dismissSheet() {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    final navigator = Navigator.of(context);
    if (route == null || !route.isActive) return;
    if (route.isCurrent) {
      navigator.pop();
    } else {
      navigator.removeRoute(route);
    }
  }

  Future<void> _pickAndImport({
    required String? category,
    required FileType type,
    List<String>? allowedExtensions,
    bool useStreamFallback = false,
  }) async {
    final items = <PickedMedia>[];
    SessionManager.instance.beginTrustedInteraction();
    try {
      final result = await FilePicker.platform.pickFiles(
        type: type,
        allowedExtensions: type == FileType.custom ? allowedExtensions : null,
        allowMultiple: true,
        withData: false,
        withReadStream: useStreamFallback,
      );
      if (result == null || result.files.isEmpty) return;

      for (final pf in result.files) {
        final path = pf.path;
        File? file;
        if (path != null && await File(path).exists()) {
          file = File(path);
        } else if (useStreamFallback) {
          file = await _materializePick(pf);
        }
        if (file != null) {
          items.add(PickedMedia(
            file,
            identifier: pf.identifier,
            originalName: pf.name,
            origin: 'file',
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        FlushBarHelper.flushBarErrorMessage('Import failed: $e', context);
      }
      return;
    } finally {
      SessionManager.instance.endTrustedInteraction();
    }
    await _runImport(items, category);
  }

  Future<void> _runImport(List<PickedMedia> items, String? category) async {
    if (items.isEmpty) {
      if (!mounted) return;
      FlushBarHelper.flushBarErrorMessage(
        'Couldn\'t read the selected files. Try again, or pick them from '
        'on-device storage.',
        context,
      );
      return;
    }

    if (!mounted) return;
    _progress.value = (0, items.length);
    setState(() => _importing = true);
    SessionManager.instance.beginTrustedInteraction();
    try {
      final import = await MediaImporter.instance.importFiles(
        items: items,
        category: category,
        onProgress: (done, total) => _progress.value = (done, total),
      );

      if (!mounted) return;
      setState(() => _importing = false);

      _dismissSheet();
      await widget.onImported();

      if (!mounted) return;
      final label = category ?? 'your vault';
      if (import.added == 0) {
        FlushBarHelper.flushBarErrorMessage(
          import.failed > 0
              ? 'Import failed — ${import.failed} file${import.failed == 1 ? '' : 's'} could not be encrypted. Your originals were left untouched.'
              : 'Nothing was imported.',
          context,
        );
        return;
      }
      final base = import.added == 1
          ? '1 file encrypted into $label'
          : '${import.added} files encrypted into $label';
      String msg = base;
      if (import.deleteOriginalsRequested && import.deletedOriginals > 0) {
        msg = '$base. ${import.deletedOriginals} original${import.deletedOriginals == 1 ? '' : 's'} hidden from gallery.';
      } else if (import.deleteOriginalsRequested && Platform.isIOS) {
        msg = '$base. iOS will confirm removal from Photos.';
      }
      if (import.failed > 0) {
        FlushBarHelper.flushBarErrorMessage(
          '$msg  ${import.failed} file${import.failed == 1 ? '' : 's'} could not be imported.',
          context,
        );
      } else {
        FlushBarHelper.flushBarSuccessMessage(msg, context);
      }

      if (import.added > 0) {
        unawaited(NotificationService.instance.addEvent(
          title: 'Files added to your vault',
          body:
              '${import.added} file${import.added == 1 ? '' : 's'} were encrypted and added.',
          kind: 'info',
        ));
        AppRating.recordImportAndMaybeAsk();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _importing = false);
      FlushBarHelper.flushBarErrorMessage('Import failed: $e', context);
    } finally {
      SessionManager.instance.endTrustedInteraction();
    }
  }

  Future<File?> _materializePick(PlatformFile pf) async {
    final stream = pf.readStream;
    if (stream == null) return null;
    try {
      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now().microsecondsSinceEpoch;
      final name = pf.name.isNotEmpty ? pf.name : 'pick_$stamp';
      final tmp = File(p.join(dir.path, 'pick_${stamp}_$name'));
      final sink = tmp.openWrite();
      await sink.addStream(stream);
      await sink.close();
      return tmp;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _promptCategoryName({
    required IconData icon,
    required String title,
    required String subtitle,
    required String confirmLabel,
    String initialValue = '',
    String? excludeName,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final formKey = GlobalKey<FormState>();
    final exclude = (excludeName ?? '').toLowerCase();
    String? validate(String? raw) {
      final name = (raw ?? '').trim();
      if (name.isEmpty) return 'Enter a name';
      if (name.length > 24) return 'Max 24 characters';
      if (!RegExp(r'^[A-Za-z0-9 _\-]+$').hasMatch(name)) {
        return 'Letters, numbers, spaces, _ and - only';
      }
      final lower = name.toLowerCase();
      final all = [..._builtInCategories, ..._customCategories]
          .map((c) => c.toLowerCase())
          .where((c) => c != exclude)
          .toSet();
      if (all.contains(lower)) return 'That category already exists';
      return null;
    }

    return showDialog<String>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: LiquidColors.backgroundLight,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: LiquidColors.accentBlue.withValues(alpha: 0.25),
            ),
          ),
          padding: const EdgeInsets.all(22),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        LiquidColors.accentBlue,
                        LiquidColors.accentPurple,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: TextStyle(
                    color: LiquidColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: LiquidColors.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 24,
                  validator: validate,
                  cursorColor: LiquidColors.accentBlue,
                  style: TextStyle(
                    color: LiquidColors.textPrimary,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. Recipes, Workouts, Receipts',
                    hintStyle: TextStyle(
                      color: LiquidColors.textTertiary,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: LiquidColors.textPrimary.withValues(alpha: 0.04),
                    counterStyle: TextStyle(
                      color: LiquidColors.textTertiary,
                      fontSize: 11,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: LiquidColors.textPrimary.withValues(alpha: 0.08),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: LiquidColors.accentBlue,
                        width: 1.4,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: LiquidColors.error),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: LiquidColors.textTertiary),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: LiquidColors.textSecondary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (formKey.currentState?.validate() ?? false) {
                            Navigator.of(dialogContext)
                                .pop(controller.text.trim());
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: LiquidColors.accentBlue,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          confirmLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addCustomCategory() async {
    HapticFeedback.lightImpact();
    final result = await _promptCategoryName(
      icon: Icons.create_new_folder_rounded,
      title: 'New category',
      subtitle: 'Pick a name for your custom vault folder.',
      confirmLabel: 'Create',
    );
    if (result == null || !mounted) return;
    setState(() => _customCategories.add(result));
    await _persistCustomCategories();
    if (!mounted) return;
    await _importInto(result);
  }

  Future<void> _showCategoryMenu(String name) async {
    HapticFeedback.selectionClick();
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: LiquidColors.backgroundLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).padding.bottom + 10,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: LiquidColors.textPrimary.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.folder_rounded,
                      size: 18, color: LiquidColors.accentBlue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: LiquidColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            _menuTile(
              icon: Icons.drive_file_rename_outline_rounded,
              color: LiquidColors.accentBlue,
              label: 'Rename category',
              onTap: () => Navigator.of(ctx).pop('rename'),
            ),
            _menuTile(
              icon: Icons.delete_outline_rounded,
              color: LiquidColors.error,
              label: 'Delete category',
              onTap: () => Navigator.of(ctx).pop('delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'rename') {
      await _renameCategory(name);
    } else if (action == 'delete') {
      await _deleteCategory(name);
    }
  }

  Widget _menuTile({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 19, color: color),
              ),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  color: LiquidColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _renameCategory(String oldName) async {
    final newName = await _promptCategoryName(
      icon: Icons.drive_file_rename_outline_rounded,
      title: 'Rename category',
      subtitle: 'Files already inside this folder move to the new name.',
      confirmLabel: 'Save',
      initialValue: oldName,
      excludeName: oldName,
    );
    if (newName == null || !mounted || newName == oldName) return;
    final idx = _customCategories.indexOf(oldName);
    if (idx == -1) return;
    setState(() => _customCategories[idx] = newName);
    await _persistCustomCategories();
    final moved =
        await MediaImporter.instance.moveCategoryItems(oldName, newName);
    await widget.onImported();
    if (!mounted) return;
    FlushBarHelper.flushBarSuccessMessage(
      moved > 0
          ? 'Renamed to "$newName" — $moved item${moved == 1 ? '' : 's'} moved'
          : 'Renamed to "$newName"',
      context,
    );
  }

  Future<void> _deleteCategory(String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: LiquidColors.backgroundLight,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: LiquidColors.error.withValues(alpha: 0.3),
            ),
          ),
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: LiquidColors.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.delete_outline_rounded,
                    color: LiquidColors.error, size: 28),
              ),
              const SizedBox(height: 14),
              Text(
                'Delete "$name"?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: LiquidColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'The category is removed. Any files still inside it stay '
                'safely in your vault and move to "Others" — nothing is '
                'deleted.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: LiquidColors.textSecondary,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: LiquidColors.textTertiary),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: LiquidColors.textSecondary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: LiquidColors.error,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Delete',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _customCategories.remove(name));
    await _persistCustomCategories();
    final moved =
        await MediaImporter.instance.moveCategoryItems(name, 'Others');
    await widget.onImported();
    if (!mounted) return;
    FlushBarHelper.flushBarSuccessMessage(
      moved > 0
          ? 'Category deleted — $moved item${moved == 1 ? '' : 's'} moved to Others'
          : 'Category deleted',
      context,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.85;
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: LiquidColors.backgroundLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: LiquidColors.textPrimary.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: LiquidColors.textPrimary.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 12),
            if (widget.autoStart)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                child: _importing
                    ? _importingBanner()
                    : const AppLoader(size: 46, label: 'Opening picker…'),
              )
            else ...[
              _header(),
              const SizedBox(height: 14),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    context.contentInset(maxContent: 620, phone: 18),
                    4,
                    context.contentInset(maxContent: 620, phone: 18),
                    24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_importing) _importingBanner(),
                      _smartImportCard(),
                      const SizedBox(height: 18),
                      _sectionLabel('YOUR CUSTOM CATEGORIES'),
                      const SizedBox(height: 10),
                      _categoryGrid(),
                      const SizedBox(height: 14),
                      _privacyNote(),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Add to vault',
                  style: TextStyle(
                    color: LiquidColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      Icons.lock_rounded,
                      size: 12,
                      color: LiquidColors.success,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Encrypted on this device — never uploaded',
                      style: TextStyle(
                        color: LiquidColors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Material(
            color: LiquidColors.textPrimary.withValues(alpha: 0.05),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _importing ? null : () => Navigator.of(context).pop(),
              child: Padding(
                padding: const EdgeInsets.all(9),
                child: Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: LiquidColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _importingBanner() {
    return ValueListenableBuilder<(int, int)>(
      valueListenable: _progress,
      builder: (context, value, _) {
        final done = value.$1;
        final total = value.$2;
        final progress = total == 0 ? 0.0 : done / total;
        return Container(
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          decoration: BoxDecoration(
            color: LiquidColors.accentBlue.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: LiquidColors.accentBlue.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppLoader(size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Encrypting $done of $total…',
                      style: TextStyle(
                        color: LiquidColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 5,
                  value: progress,
                  backgroundColor:
                      LiquidColors.textPrimary.withValues(alpha: 0.06),
                  valueColor: AlwaysStoppedAnimation(LiquidColors.accentBlue),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _smartImportCard() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _importing ? null : _smartImport,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                LiquidColors.accentBlue,
                LiquidColors.accentPurple,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: LiquidColors.accentBlue.withValues(alpha: 0.28),
                blurRadius: 16,
                spreadRadius: -4,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'Quick import',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Import photos, videos and audio from your gallery '
                      'into your encrypted vault. Use the Documents tile '
                      'for files.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        text,
        style: TextStyle(
          color: LiquidColors.textTertiary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _categoryGrid() {
    if (_loadingCustoms) {
      return SizedBox(
        height: 80,
        child: Center(
          child: AppLoader(),
        ),
      );
    }
    final customs = _customCategories;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: customs.length + 1,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: context.responsive(phone: 2, tablet: 3),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.6,
      ),
      itemBuilder: (context, index) {
        if (index == customs.length) {
          return _AddCategoryTile(
            onTap: _importing ? null : _addCustomCategory,
          );
        }
        final cat = customs[index];
        return _CategoryTile(
          label: cat,
          icon: _iconFor(cat),
          color: _colorFor(cat),
          isCustom: true,
          onTap: _importing ? null : () => _importInto(cat),
          onMenu: _importing ? null : () => _showCategoryMenu(cat),
        );
      },
    );
  }

  Widget _privacyNote() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: LiquidColors.textPrimary.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: LiquidColors.textPrimary.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.shield_outlined,
            color: LiquidColors.textTertiary,
            size: 14,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Photos, videos and audio you pick are removed from your gallery '
              'after encrypting (the system will ask you to confirm). They '
              'reappear only when you export from your vault.',
              style: TextStyle(
                color: LiquidColors.textSecondary,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String category) {
    switch (category) {
      case 'Videos':
        return Icons.video_library_rounded;
      case 'Photos':
        return Icons.photo_library_rounded;
      case 'Audio':
        return Icons.audiotrack_rounded;
      case 'Documents':
        return Icons.description_rounded;
      case 'Educational':
        return Icons.school_rounded;
      case 'Personal':
        return Icons.person_rounded;
      case 'Work':
        return Icons.work_rounded;
      case 'Sports':
        return Icons.sports_soccer_rounded;
      case 'Travel':
        return Icons.travel_explore_rounded;
      case 'Others':
        return Icons.folder_rounded;
      default:
        return Icons.folder_rounded;
    }
  }

  Color _colorFor(String category) {
    switch (category) {
      case 'Videos':
        return LiquidColors.accentBlue;
      case 'Photos':
        return LiquidColors.success;
      case 'Audio':
        return LiquidColors.accentPurple;
      case 'Documents':
        return LiquidColors.accentOrange;
      case 'Educational':
        return const Color(0xFF2196F3);
      case 'Personal':
        return const Color(0xFFE91E63);
      case 'Work':
        return const Color(0xFF795548);
      case 'Sports':
        return const Color(0xFF4CAF50);
      case 'Travel':
        return const Color(0xFF3F51B5);
      case 'Others':
        return LiquidColors.accentPink;
      default:
        return LiquidColors.accentPurple;
    }
  }
}

class _CategoryTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isCustom;
  final VoidCallback? onTap;
  final VoidCallback? onMenu;

  const _CategoryTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.isCustom,
    required this.onTap,
    this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: color.withValues(alpha: 0.12),
        highlightColor: color.withValues(alpha: 0.06),
        child: Opacity(
          opacity: disabled ? 0.55 : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: LiquidColors.textPrimary.withValues(alpha: 0.035),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: LiquidColors.textPrimary.withValues(alpha: 0.07),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: LiquidColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
                if (isCustom) ...[
                  const SizedBox(width: 2),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onMenu,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.more_vert_rounded,
                        size: 18,
                        color: LiquidColors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddCategoryTile extends StatelessWidget {
  final VoidCallback? onTap;
  const _AddCategoryTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Opacity(
          opacity: disabled ? 0.55 : 1,
          child: DottedBorderBox(
            color: LiquidColors.textPrimary.withValues(alpha: 0.18),
            radius: 16,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: LiquidColors.accentBlue.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: LiquidColors.accentBlue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Add custom',
                          style: TextStyle(
                            color: LiquidColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.1,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Your own folder',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: LiquidColors.textTertiary,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DottedBorderBox extends StatelessWidget {
  final Widget child;
  final Color color;
  final double radius;

  const DottedBorderBox({
    super.key,
    required this.child,
    required this.color,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(color: color, radius: radius),
      child: child,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final dashed = Path();
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        dashed.addPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          Offset.zero,
        );
        distance = next + dashSpace;
      }
    }
    canvas.drawPath(dashed, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
