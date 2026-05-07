import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:video_player_app/download_screen/widgets/view.dart';
import 'package:video_player_app/utils/import_settings.dart';
import 'package:video_player_app/utils/title_helper.dart';
import 'package:video_player_app/utils/vault_crypto.dart';
import '../upload_screen/widgets/view.dart';

class UploadScreen extends StatefulWidget {
  final VoidCallback? onVideoUploaded;

  const UploadScreen({super.key, this.onVideoUploaded});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedCategory;
  final List<File> _selectedFiles = [];
  bool _isUploading = false;
  double _uploadProgress = 0;
  final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  static const String _customCategoriesPrefKey = 'customCategories';

  static const List<String> _builtInCategories = [
    "Videos",
    "Photos",
    "Audio",
    "Documents",
    "Educational",
    "Personal",
    "Work",
    "Sports",
    "Travel",
    "Others",
  ];

  final List<String> _customCategories = [];

  List<String> get videoCategories =>
      [..._builtInCategories, ..._customCategories];

  bool _isBuiltIn(String category) =>
      _builtInCategories.contains(category);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _animationController.forward();
    _loadCustomCategories();
  }

  Future<void> _loadCustomCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_customCategoriesPrefKey) ?? [];
      if (!mounted) return;
      setState(() {
        _customCategories
          ..clear()
          ..addAll(saved);
      });
    } catch (_) {}
  }

  Future<void> _persistCustomCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _customCategoriesPrefKey,
        List<String>.from(_customCategories),
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    if (_selectedCategory == null) return;
    final category = _selectedCategory!;
    try {
      if (Platform.isAndroid) {
        final granted = await _requestAndroidPermissionFor(category);
        if (!granted) return;
      } else if (Platform.isIOS) {
        final status = await Permission.photos.request();
        if (!status.isGranted) {
          if (!mounted) return;
          FlushBarHelper.flushBarErrorMessage(
            'Permission required to access files',
            context,
          );
          return;
        }
      }

      final fileType = _fileTypeForCategory(category);
      final allowedExtensions = _allowedExtensionsForCategory(category);

      final result = await FilePicker.platform.pickFiles(
        type: fileType,
        allowMultiple: true,
        withData: false,
        withReadStream: false,
        allowedExtensions: fileType == FileType.custom
            ? allowedExtensions
            : null,
      );

      if (result != null && result.files.isNotEmpty) {
        final accepted = <File>[];
        final rejected = <String>[];
        for (final platformFile in result.files) {
          if (platformFile.path == null) continue;
          if (_isAcceptedForCategory(platformFile.path!, category)) {
            accepted.add(File(platformFile.path!));
          } else {
            rejected.add(platformFile.name);
          }
        }
        setState(() => _selectedFiles.addAll(accepted));
        if (!mounted) return;
        if (accepted.isNotEmpty) {
          FlushBarHelper.flushBarSuccessMessage(
            '${accepted.length} file(s) added',
            context,
          );
        }
        if (rejected.isNotEmpty) {
          FlushBarHelper.flushBarWarningMessage(
            '${rejected.length} file(s) skipped — not allowed in "$category".',
            context,
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      FlushBarHelper.flushBarErrorMessage('Error: ${e.toString()}', context);
    }
  }

  Future<bool> _requestAndroidPermissionFor(String category) async {
    final androidInfo = await _deviceInfoPlugin.androidInfo;
    final sdkInt = androidInfo.version.sdkInt;

    PermissionStatus status;
    switch (category) {
      case "Videos":
        status = sdkInt >= 33
            ? await Permission.videos.request()
            : await Permission.storage.request();
        break;
      case "Photos":
        status = sdkInt >= 33
            ? await Permission.photos.request()
            : await Permission.storage.request();
        break;
      case "Audio":
        status = sdkInt >= 33
            ? await Permission.audio.request()
            : await Permission.storage.request();
        break;
      case "Documents":
      case "Others":
        if (sdkInt >= 33) return true;
        status = await Permission.storage.request();
        break;
      default:
        status = sdkInt >= 33
            ? await Permission.photos.request()
            : await Permission.storage.request();
    }

    if (status.isPermanentlyDenied) {
      _showPermissionSettingsDialog();
      return false;
    }
    if (!status.isGranted) {
      if (!mounted) return false;
      FlushBarHelper.flushBarErrorMessage(
        'Permission required to access $category files',
        context,
      );
      return false;
    }
    return true;
  }

  FileType _fileTypeForCategory(String category) {
    switch (category) {
      case "Videos":
        return FileType.video;
      case "Photos":
        return FileType.image;
      case "Audio":
        return FileType.audio;
      case "Others":
        return FileType.any;
      default:
        return FileType.custom;
    }
  }

  static const _videoExts = [
    'mp4',
    'mov',
    'avi',
    'mkv',
    'wmv',
    'flv',
    'm4v',
    'webm',
    '3gp',
    'mpg',
    'mpeg',
  ];
  static const _imageExts = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'bmp',
    'webp',
    'heic',
    'tiff',
  ];
  static const _audioExts = [
    'mp3',
    'wav',
    'aac',
    'flac',
    'ogg',
    'm4a',
    'wma',
    'aiff',
    'alac',
    'opus',
  ];
  static const _docExts = [
    'pdf',
    'doc',
    'docx',
    'txt',
    'ppt',
    'pptx',
    'xls',
    'xlsx',
    'rtf',
    'csv',
  ];

  List<String>? _allowedExtensionsForCategory(String category) {
    switch (category) {
      case "Videos":
      case "Photos":
      case "Audio":
      case "Others":
        return null;
      case "Documents":
        return _docExts;
      case "Educational":
      case "Personal":
        return [..._videoExts, ..._imageExts, ..._audioExts, ..._docExts];
      case "Work":
        return [..._docExts, ..._imageExts];
      case "Sports":
      case "Travel":
        return [..._videoExts, ..._imageExts];
      default:
        return [..._videoExts, ..._imageExts, ..._docExts];
    }
  }

  bool _isAcceptedForCategory(String path, String category) {
    final ext = p.extension(path).toLowerCase().replaceFirst('.', '');
    if (ext.isEmpty) return category == "Others";
    final allowed = _allowedExtensionsForCategory(category);
    if (allowed == null) {
      switch (category) {
        case "Videos":
          return _videoExts.contains(ext);
        case "Photos":
          return _imageExts.contains(ext);
        case "Audio":
          return _audioExts.contains(ext);
        case "Others":
          return true;
      }
      return true;
    }
    return allowed.contains(ext);
  }

  String _getFileTypeFromExtension(String path) {
    final ext = p.extension(path).toLowerCase();
    if (const {
      '.mp4',
      '.avi',
      '.mov',
      '.wmv',
      '.mkv',
      '.flv',
      '.m4v',
      '.mpg',
      '.mpeg',
      '.3gp',
      '.webm',
    }.contains(ext)) {
      return 'video';
    } else if (const {
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.bmp',
      '.webp',
      '.tiff',
      '.svg',
      '.ico',
      '.heic',
    }.contains(ext)) {
      return 'image';
    } else if (const {
      '.mp3',
      '.wav',
      '.aac',
      '.flac',
      '.ogg',
      '.m4a',
      '.wma',
      '.aiff',
      '.alac',
      '.opus',
      '.mid',
      '.midi',
      '.amr',
      '.ape',
      '.ra',
      '.rm',
      '.mka',
      '.m4b',
      '.m4p',
      '.ac3',
      '.dts',
    }.contains(ext)) {
      return 'audio';
    } else if (const {
      '.pdf',
      '.doc',
      '.docx',
      '.txt',
      '.ppt',
      '.pptx',
      '.xls',
      '.xlsx',
      '.rtf',
      '.odt',
      '.ods',
      '.odp',
      '.csv',
      '.xml',
      '.html',
      '.htm',
      '.epub',
      '.mobi',
      '.tex',
      '.md',
    }.contains(ext)) {
      return 'document';
    }
    return 'other';
  }

  Future<void> _showPermissionSettingsDialog() async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: LiquidColors.cardGradient,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: LiquidColors.warning.withValues(alpha: .3),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: LiquidColors.warning.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: LiquidColors.warning.withValues(alpha: .3),
                    ),
                  ),
                  child: Icon(
                    Icons.lock_outline_rounded,
                    size: 32,
                    color: LiquidColors.warning,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Permission Required',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Access was permanently denied. Enable it from the system settings to continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade400,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: BorderSide(color: Colors.grey.shade700),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.grey.shade300,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          openAppSettings();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: LiquidColors.accentBlue,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Open Settings',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
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

  Future<void> _uploadFiles() async {
    if (_selectedFiles.isEmpty || _selectedCategory == null) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final videoList = prefs.getStringList('videoLibrary') ?? [];
      final deleteOriginals = await ImportSettings.instance
          .deleteOriginalsEnabled();

      int fileCount = 0;
      int deletedOriginals = 0;
      final isMediaCategory = const {
        'Videos',
        'Photos',
        'Audio',
      }.contains(_selectedCategory);

      for (int i = 0; i < _selectedFiles.length; i++) {
        final file = _selectedFiles[i];
        final timestamp = DateTime.now().millisecondsSinceEpoch + i;
        final originalName = TitleHelper.prettyTitleFromFilename(file.path);

        try {
          final encryptedPath = await VaultCrypto.instance.importEncrypted(
            file,
          );

          String fileType = "other";
          if (_selectedCategory == "Videos") {
            fileType = "video";
          } else if (_selectedCategory == "Photos") {
            fileType = "image";
          } else if (_selectedCategory == "Audio") {
            fileType = "audio";
          } else if (_selectedCategory == "Documents") {
            fileType = "document";
          } else {
            fileType = _getFileTypeFromExtension(file.path);
          }

          videoList.add(
            '$timestamp|$originalName|$encryptedPath|$fileType|false|$_selectedCategory|false||true',
          );
          fileCount++;

          if (deleteOriginals) {
            final removed = await ImportSettings.instance.deleteOriginal(file);
            if (removed) deletedOriginals++;
          }

          if (mounted) {
            setState(() {
              _uploadProgress = (i + 1) / _selectedFiles.length;
            });
          }
        } catch (_) {}
      }

      await prefs.setStringList('videoLibrary', videoList);

      if (mounted) {
        setState(() {
          _isUploading = false;
          _selectedFiles.clear();
        });

        final base =
            '$fileCount file(s) added to your "$_selectedCategory" vault';
        String message = base;
        if (deleteOriginals && fileCount > 0) {
          if (Platform.isIOS && isMediaCategory) {
            message = '$base. iOS will ask you to confirm removal from Photos.';
          } else if (deletedOriginals > 0) {
            message = '$base. $deletedOriginals original(s) removed.';
          }
        }

        FlushBarHelper.flushBarSuccessMessage(message, context);
        widget.onVideoUploaded?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        FlushBarHelper.flushBarErrorMessage(
          'Upload failed: ${e.toString()}',
          context,
        );
      }
    }
  }

  Future<int> _totalSelectedBytes() async {
    int total = 0;
    for (final f in _selectedFiles) {
      try {
        total += await f.length();
      } catch (_) {}
    }
    return total;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    const units = ['KB', 'MB', 'GB', 'TB'];
    double size = bytes / 1024;
    int unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    return '${size.toStringAsFixed(size >= 10 ? 0 : 1)} ${units[unit]}';
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedCategory;
    final categoryColor = selected == null
        ? LiquidColors.accentBlue
        : _getCategoryColor(selected);
    final hasFiles = _selectedFiles.isNotEmpty;

    return Scaffold(
      backgroundColor: LiquidColors.backgroundDeep,
      appBar: _buildAppBar(categoryColor),
      body: Container(
        decoration: BoxDecoration(gradient: LiquidColors.backgroundGradient),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _stepHeader(
                    number: 1,
                    label: 'Choose a category',
                    done: selected != null,
                    accent: categoryColor,
                  ),
                  const SizedBox(height: 12),
                  _buildCategoryGrid(selected),
                  const SizedBox(height: 28),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SizeTransition(
                        sizeFactor: anim,
                        axisAlignment: -1,
                        child: child,
                      ),
                    ),
                    child: selected == null
                        ? _buildLockedStep(categoryColor)
                        : _buildPickStep(selected, categoryColor, hasFiles),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: (selected != null && hasFiles && !_isUploading)
          ? _buildStickyAction(selected, categoryColor)
          : null,
    );
  }

  Widget _buildPickStep(String selected, Color accent, bool hasFiles) {
    return Column(
      key: ValueKey('pick-$selected'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader(
          number: 2,
          label: 'Pick ${selected.toLowerCase()} to encrypt',
          done: hasFiles,
          accent: accent,
        ),
        const SizedBox(height: 12),
        LiquidUploadCard(
          icon: Icons.cloud_upload_outlined,
          subtitle: 'Tap to choose ${selected.toLowerCase()} from your device',
          gradient: [accent, accent.withValues(alpha: 0.7)],
          index: 0,
          onTap: _pickFiles,
        ),
        const SizedBox(height: 12),
        _securityNote(),
        const SizedBox(height: 28),
        if (_isUploading)
          _buildUploadingState(selected, accent)
        else if (hasFiles)
          _buildSelectedSection(accent)
        else
          _buildEmptyState(selected, accent),
      ],
    );
  }

  Widget _buildLockedStep(Color accent) {
    return Container(
      key: const ValueKey('locked'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Icon(
              Icons.lock_outline_rounded,
              size: 20,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pick a category first',
                  style: TextStyle(
                    color: Colors.grey.shade300,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'The upload step unlocks after you choose where the files belong.',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid(String? selected) {
    final categories = videoCategories;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: categories.length + 1,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.6,
      ),
      itemBuilder: (context, index) {
        if (index == categories.length) {
          return _AddCategoryTile(onTap: _showAddCategoryDialog);
        }
        final category = categories[index];
        final isSelected = category == selected;
        final color = _getCategoryColor(category);
        final isCustom = !_isBuiltIn(category);
        return _CategoryCard(
          label: category,
          icon: _getCategoryIcon(category),
          color: color,
          selected: isSelected,
          isCustom: isCustom,
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _selectedCategory = category);
          },
          onLongPress: isCustom
              ? () => _confirmRemoveCustomCategory(category)
              : null,
        );
      },
    );
  }

  Future<void> _showAddCategoryDialog() async {
    HapticFeedback.lightImpact();
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? validate(String? raw) {
      final name = (raw ?? '').trim();
      if (name.isEmpty) return 'Enter a name';
      if (name.length > 24) return 'Max 24 characters';
      if (!RegExp(r'^[A-Za-z0-9 _\-]+$').hasMatch(name)) {
        return 'Letters, numbers, spaces, _ and - only';
      }
      final lower = name.toLowerCase();
      final existing = videoCategories.map((c) => c.toLowerCase()).toSet();
      if (existing.contains(lower)) return 'A category with that name already exists';
      return null;
    }

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: LiquidColors.cardGradient,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: LiquidColors.accentBlue.withValues(alpha: 0.3),
            ),
          ),
          padding: const EdgeInsets.all(24),
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
                    boxShadow: [
                      BoxShadow(
                        color: LiquidColors.accentBlue.withValues(alpha: 0.4),
                        blurRadius: 16,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.create_new_folder_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'New category',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Pick a name for your custom vault folder.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 24,
                  validator: validate,
                  cursorColor: LiquidColors.accentBlue,
                  onFieldSubmitted: (_) {
                    if (formKey.currentState?.validate() ?? false) {
                      Navigator.of(dialogContext).pop(controller.text.trim());
                    }
                  },
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'e.g. Recipes, Workouts, Receipts',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.04),
                    counterStyle:
                        TextStyle(color: Colors.grey.shade600, fontSize: 11),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: LiquidColors.accentBlue, width: 1.4),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: LiquidColors.error),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: LiquidColors.error, width: 1.4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: OutlinedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: Colors.grey.shade700),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.grey.shade300,
                            fontWeight: FontWeight.w600,
                          ),
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
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Add',
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
      ),
    );

    if (result == null || !mounted) return;
    setState(() {
      _customCategories.add(result);
      _selectedCategory = result;
    });
    await _persistCustomCategories();
    if (!mounted) return;
    HapticFeedback.selectionClick();
    FlushBarHelper.flushBarSuccessMessage(
      'Added "$result" to your categories',
      context,
    );
  }

  Future<void> _confirmRemoveCustomCategory(String category) async {
    HapticFeedback.lightImpact();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: LiquidColors.backgroundLight,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Remove "$category"?',
          style: const TextStyle(color: Colors.white, fontSize: 17),
        ),
        content: Text(
          'Files already imported under this category stay in your vault. '
          'You just won\'t be able to pick this folder for new imports.',
          style: TextStyle(color: Colors.grey.shade300, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade400)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Remove',
                style: TextStyle(color: LiquidColors.error)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;
    setState(() {
      _customCategories.remove(category);
      if (_selectedCategory == category) _selectedCategory = null;
    });
    await _persistCustomCategories();
  }

  PreferredSizeWidget _buildAppBar(Color accent) {
    return AppBar(
      leadingWidth: 60,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Center(
          child: Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              gradient: LiquidColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: LiquidColors.primaryStart.withValues(alpha: 0.4),
                  blurRadius: 10,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.folder_copy_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ),
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
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Add to Vault',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
          Text(
            'Files are encrypted before they touch storage',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, color: accent, size: 14),
                const SizedBox(width: 4),
                Text(
                  'AES-256',
                  style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _stepHeader({
    required int number,
    required String label,
    required bool done,
    required Color accent,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done
                ? accent.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.05),
            border: Border.all(
              color: done ? accent : Colors.white.withValues(alpha: 0.12),
              width: 1.4,
            ),
            boxShadow: done
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.32),
                      blurRadius: 14,
                      spreadRadius: -2,
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: done
              ? Icon(Icons.check_rounded, size: 18, color: accent)
              : Text(
                  '$number',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }

  Widget _securityNote() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lock_outline_rounded,
            color: Colors.grey.shade500,
            size: 14,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Each file is encrypted with a unique IV. Originals never leave the import pipeline in plaintext.',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String category, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  accent.withValues(alpha: 0.18),
                  accent.withValues(alpha: 0.0),
                ],
              ),
            ),
            child: Icon(_getCategoryIcon(category), size: 32, color: accent),
          ),
          const SizedBox(height: 14),
          const Text(
            'No files selected yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Use the card above to pick files. You can select multiple at once.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadingState(String category, Color accent) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.40,
      child: LiquidProgressIndicator(
        progress: _uploadProgress,
        color: accent,
        category: category,
        isDownloading: false,
      ),
    );
  }

  Widget _buildSelectedSection(Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FutureBuilder<int>(
          future: _totalSelectedBytes(),
          builder: (context, snapshot) {
            final totalText = snapshot.hasData
                ? _formatBytes(snapshot.data!)
                : '…';
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      '${_selectedFiles.length} file${_selectedFiles.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      totalText,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => setState(_selectedFiles.clear),
                  icon: Icon(
                    Icons.delete_sweep_outlined,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
                  label: Text(
                    'Clear all',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                LiquidColors.backgroundLight.withValues(alpha: 0.4),
                LiquidColors.backgroundMid.withValues(alpha: 0.6),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _selectedFiles.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                thickness: 1,
                color: Colors.white.withValues(alpha: 0.04),
              ),
              itemBuilder: (context, index) {
                final file = _selectedFiles[index];
                return LiquidFileItem(
                  file: file,
                  index: index,
                  onRemove: () =>
                      setState(() => _selectedFiles.removeAt(index)),
                  getFileType: (file) => _getFileTypeFromExtension(file.path),
                  getFileIcon: _getFileTypeIcon,
                  getFileColor: _getFileTypeColor,
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStickyAction(String category, Color accent) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            LiquidColors.backgroundDeep.withValues(alpha: 0.0),
            LiquidColors.backgroundDeep,
          ],
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      child: _PressableScale(
        onPressed: () {
          HapticFeedback.mediumImpact();
          _uploadFiles();
        },
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.45),
                blurRadius: 22,
                spreadRadius: -4,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_rounded, size: 18, color: Colors.white),
              const SizedBox(width: 10),
              Text(
                'Encrypt & Add to $category',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_selectedFiles.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case "Videos":
        return Icons.video_library_rounded;
      case "Photos":
        return Icons.photo_library_rounded;
      case "Audio":
        return Icons.audiotrack_rounded;
      case "Documents":
        return Icons.description_rounded;
      case "Educational":
        return Icons.school_rounded;
      case "Personal":
        return Icons.person_rounded;
      case "Work":
        return Icons.work_rounded;
      case "Sports":
        return Icons.sports_soccer_rounded;
      case "Travel":
        return Icons.travel_explore_rounded;
      default:
        return Icons.folder_rounded;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case "Videos":
        return LiquidColors.accentBlue;
      case "Photos":
        return LiquidColors.success;
      case "Audio":
        return LiquidColors.accentPurple;
      case "Documents":
        return LiquidColors.accentOrange;
      case "Educational":
        return const Color(0xFF2196F3);
      case "Personal":
        return const Color(0xFFE91E63);
      case "Work":
        return const Color(0xFF795548);
      case "Sports":
        return const Color(0xFF4CAF50);
      case "Travel":
        return const Color(0xFF3F51B5);
      default:
        return LiquidColors.accentPink;
    }
  }

  IconData _getFileTypeIcon(String fileType) {
    switch (fileType) {
      case "video":
        return Icons.video_file_rounded;
      case "image":
        return Icons.image_rounded;
      case "audio":
        return Icons.audio_file_rounded;
      case "document":
        return Icons.description_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color _getFileTypeColor(String fileType) {
    switch (fileType) {
      case "video":
        return LiquidColors.accentBlue;
      case "image":
        return LiquidColors.success;
      case "audio":
        return LiquidColors.accentPurple;
      case "document":
        return LiquidColors.accentOrange;
      default:
        return LiquidColors.accentPink;
    }
  }
}

class _CategoryCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final bool isCustom;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _CategoryCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
    this.isCustom = false,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        splashColor: color.withValues(alpha: 0.12),
        highlightColor: color.withValues(alpha: 0.06),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.22),
                      color.withValues(alpha: 0.10),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: selected ? null : Colors.white.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.07),
              width: selected ? 1.4 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.32),
                      blurRadius: 18,
                      spreadRadius: -4,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: selected
                      ? color.withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: 16,
                  color: selected ? color : Colors.grey.shade400,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.grey.shade300,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: selected
                    ? Icon(
                        Icons.check_circle_rounded,
                        key: const ValueKey('on'),
                        size: 16,
                        color: color,
                      )
                    : isCustom
                        ? Container(
                            key: const ValueKey('custom-dot'),
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                          )
                        : const SizedBox(key: ValueKey('off'), width: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddCategoryTile extends StatelessWidget {
  final VoidCallback onTap;

  const _AddCategoryTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: LiquidColors.accentBlue.withValues(alpha: 0.12),
        highlightColor: LiquidColors.accentBlue.withValues(alpha: 0.06),
        child: DottedBorderBox(
          color: Colors.white.withValues(alpha: 0.18),
          radius: 16,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                      const Text(
                        'Add custom',
                        style: TextStyle(
                          color: Colors.white,
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
                          color: Colors.grey.shade500,
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

class _PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;

  const _PressableScale({required this.child, required this.onPressed});

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _down ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: widget.child,
        ),
      ),
    );
  }
}
