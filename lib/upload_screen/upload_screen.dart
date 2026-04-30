import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:video_player_app/download_screen/widgets/view.dart';
import 'package:video_player_app/utils/media_helper.dart';
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

  final MediaHelper _mediaHelper = MediaHelper();
  String _selectedCategory = "Videos";
  String _selectedFileType = "video";
  final List<File> _selectedFiles = [];
  bool _isUploading = false;
  double _uploadProgress = 0;
  final TextEditingController _urlController = TextEditingController();
  final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  static const List<String> videoCategories = [
    "Videos",
    "Photos",
    "Audio",
    "Documents",
    "Educational",
    "Personal",
    "Work",
    "Sports",
    "Travel",
    "Others"
  ];

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animationController.forward();
    _getDeviceInfo();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfoPlugin.androidInfo;
        final sdkInt = androidInfo.version.sdkInt;

        PermissionStatus status;

        if (_selectedCategory == "Videos") {
          status = sdkInt >= 33
              ? await Permission.videos.request()
              : await Permission.storage.request();
        } else if (_selectedCategory == "Photos") {
          status = sdkInt >= 33
              ? await Permission.photos.request()
              : await Permission.storage.request();
        } else if (_selectedCategory == "Audio") {
          status = sdkInt >= 33
              ? await Permission.audio.request()
              : await Permission.storage.request();
        } else {
          status = sdkInt >= 33
              ? await Permission.photos.request()
              : await Permission.storage.request();
        }

        if (status.isPermanentlyDenied) {
          _showPermissionSettingsDialog();
          return;
        }

        if (!status.isGranted) {
          if (!mounted) return;
          _showSnackBar(
            'Permission required to access $_selectedCategory files',
            LiquidColors.error,
          );
          return;
        }
      } else if (Platform.isIOS) {
        final status = await Permission.photos.request();
        if (!status.isGranted) {
          if (!mounted) return;
          _showSnackBar(
            'Permission required to access files',
            LiquidColors.error,
          );
          return;
        }
      }

      FileType fileType = FileType.any;
      List<String>? allowedExtensions;

      if (_selectedCategory == "Documents") {
        fileType = FileType.custom;
        allowedExtensions = _getAllowedExtensions();
      } else {
        switch (_selectedCategory) {
          case "Videos":
            fileType = FileType.video;
            break;
          case "Photos":
            fileType = FileType.image;
            break;
          case "Audio":
            fileType = FileType.audio;
            break;
          default:
            fileType = FileType.any;
        }
      }

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: fileType,
        allowMultiple: true,
        withData: false,
        withReadStream: false,
        allowedExtensions: fileType == FileType.custom ? allowedExtensions : null,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFiles.clear();
          for (var platformFile in result.files) {
            if (platformFile.path != null) {
              _selectedFiles.add(File(platformFile.path!));
            }
          }
        });

        if (!mounted) return;
        _showSnackBar(
          '${_selectedFiles.length} file(s) selected for $_selectedCategory',
          LiquidColors.success,
        );
      } else {
        if (!mounted) return;
        _showSnackBar(
          'No files selected',
          LiquidColors.warning,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(
        'Error: ${e.toString()}',
        LiquidColors.error,
      );
    }
  }

  List<String>? _getAllowedExtensions() {
    switch (_selectedCategory) {
      case "Videos":
        return ['mp4', 'avi', 'mov', 'wmv', 'mkv', 'flv', 'm4v'];
      case "Photos":
        return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'];
      case "Audio":
        return ['mp3', 'wav', 'aac', 'flac', 'ogg', 'm4a', 'wma', 'aiff', 'alac'];
      case "Documents":
        return ['pdf', 'doc', 'docx', 'txt', 'ppt', 'pptx', 'xls', 'xlsx'];
      default:
        return null;
    }
  }

  String _getFileTypeFromExtension(String path) {
    final ext = p.extension(path).toLowerCase();

    if (['.mp4', '.avi', '.mov', '.wmv', '.mkv', '.flv', '.m4v', '.mpg', '.mpeg', '.3gp', '.webm'].contains(ext)) {
      return 'video';
    } else if (['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.tiff', '.svg', '.ico', '.heic'].contains(ext)) {
      return 'image';
    } else if ([
      '.mp3', '.wav', '.aac', '.flac', '.ogg', '.m4a', '.wma',
      '.aiff', '.alac', '.opus', '.mid', '.midi', '.amr', '.ape',
      '.ra', '.rm', '.mka', '.m4b', '.m4p', '.ac3', '.dts'
    ].contains(ext)) {
      return 'audio';
    } else if ([
      '.pdf', '.doc', '.docx', '.txt', '.ppt', '.pptx', '.xls',
      '.xlsx', '.rtf', '.odt', '.ods', '.odp', '.csv', '.xml',
      '.html', '.htm', '.epub', '.mobi', '.tex', '.md'
    ].contains(ext)) {
      return 'document';
    } else {
      return 'other';
    }
  }

  Future<void> _getDeviceInfo() async {
    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await _deviceInfoPlugin.androidInfo;
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await _deviceInfoPlugin.iosInfo;
      }
    } catch (e) {
    }
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
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        LiquidColors.warning.withValues(alpha: .2),
                        LiquidColors.error.withValues(alpha: .2),
                      ],
                      center: Alignment.center,
                      radius: 0.8,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: LiquidColors.warning.withValues(alpha: .2),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.warning_rounded,
                      size: 36,
                      color: LiquidColors.warning,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Permission Required',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Permission was permanently denied. Please enable it from app settings.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade400,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          side: BorderSide(
                            color: Colors.grey.shade700,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.grey.shade400,
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
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
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
    if (_selectedFiles.isEmpty) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> videoList = prefs.getStringList('videoLibrary') ?? [];

      int fileCount = 0;

      for (int i = 0; i < _selectedFiles.length; i++) {
        final file = _selectedFiles[i];
        final timestamp = DateTime.now().millisecondsSinceEpoch + i;
        final originalName = p.basenameWithoutExtension(file.path);

        try {
          final encryptedPath = await VaultCrypto.instance.importEncrypted(file);

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

          if (mounted) {
            setState(() {
              _uploadProgress = (i + 1) / _selectedFiles.length;
            });
          }
        } catch (e) {
        }
      }

      await prefs.setStringList('videoLibrary', videoList);

      if (mounted) {
        setState(() {
          _isUploading = false;
          _selectedFiles.clear();
        });

        _showSnackBar(
          '$fileCount file(s) uploaded successfully to "$_selectedCategory" folder',
          LiquidColors.success,
        );

        if (widget.onVideoUploaded != null) {
          widget.onVideoUploaded!();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
        _showSnackBar(
          'Upload failed: ${e.toString()}',
          LiquidColors.error,
        );
      }
    }
  }

  Future<void> _downloadFromURL() async {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: LiquidColors.cardGradient,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: LiquidColors.accentBlue.withValues(alpha: .3),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LiquidColors.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: LiquidColors.primaryStart.withValues(alpha: .4),
                        blurRadius: 15,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.link_rounded,
                      size: 30,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Download from URL',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: LiquidColors.backgroundMid,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: LiquidColors.primaryStart.withValues(alpha: .3),
                    ),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedCategory,
                    isExpanded: true,
                    dropdownColor: LiquidColors.backgroundLight,
                    style: const TextStyle(color: Colors.white),
                    underline: const SizedBox(),
                    icon: Icon(
                      Icons.arrow_drop_down_rounded,
                      color: _getCategoryColor(_selectedCategory),
                    ),
                    items: videoCategories
                        .map((category) => DropdownMenuItem(
                      value: category,
                      child: Row(
                        children: [
                          Icon(
                            _getCategoryIcon(category),
                            size: 18,
                            color: _getCategoryColor(category),
                          ),
                          const SizedBox(width: 8),
                          Text(category),
                        ],
                      ),
                    ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedCategory = value;
                          _selectedFileType = _getDefaultFileTypeForCategory(value);
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _urlController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Enter file URL (e.g., https://example.com/file.mp4)',
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    filled: true,
                    fillColor: LiquidColors.backgroundMid,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: _getCategoryColor(_selectedCategory),
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _urlController.clear();
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          side: BorderSide(
                            color: Colors.grey.shade700,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _downloadFileFromUrl(_urlController.text);
                          _urlController.clear();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _getCategoryColor(_selectedCategory),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Download',
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

  String _getDefaultFileTypeForCategory(String category) {
    switch (category) {
      case "Videos":
        return "video";
      case "Photos":
        return "image";
      case "Audio":
        return "audio";
      case "Documents":
        return "pdf";
      default:
        return "video";
    }
  }

  Future<void> _downloadFileFromUrl(String url) async {
    if (url.isEmpty) {
      if (!mounted) return;
      _showSnackBar('Please enter a valid URL', LiquidColors.error);
      return;
    }

    final parsedUri = Uri.tryParse(url);
    if (parsedUri == null ||
        !parsedUri.hasScheme ||
        parsedUri.scheme.toLowerCase() != 'https' ||
        !parsedUri.hasAuthority) {
      if (!mounted) return;
      _showSnackBar(
        'Only HTTPS URLs are allowed',
        LiquidColors.error,
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });

    try {
      final tmp = await getTemporaryDirectory();
      final stagingPath = '${tmp.path}/sp_dl_${DateTime.now().millisecondsSinceEpoch}';

      final pathSegments = parsedUri.pathSegments;
      final originalFileName = pathSegments.isNotEmpty ? pathSegments.last : 'downloaded_file';

      String fileExt = '.mp4';
      if (originalFileName.contains('.')) {
        fileExt = originalFileName.substring(originalFileName.lastIndexOf('.'));
      } else {
        switch (_selectedCategory) {
          case "Videos":
            fileExt = '.mp4';
            break;
          case "Photos":
            fileExt = '.jpg';
            break;
          case "Audio":
            fileExt = '.mp3';
            break;
          case "Documents":
            fileExt = '.pdf';
            break;
        }
      }

      final stagingFile = File('$stagingPath$fileExt');

      final dio = Dio();
      await dio.download(
        url,
        stagingFile.path,
        onReceiveProgress: (received, total) {
          if (total != -1 && mounted) {
            setState(() {
              _uploadProgress = received / total;
            });
          }
        },
      );

      final encryptedPath = await VaultCrypto.instance.importEncrypted(stagingFile);
      try {
        await stagingFile.delete();
      } catch (_) {}

      final prefs = await SharedPreferences.getInstance();
      List<String> videoList = prefs.getStringList('videoLibrary') ?? [];

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
        fileType = _getFileTypeFromExtension(stagingFile.path);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      videoList.add(
        '$timestamp|Downloaded File|$encryptedPath|$fileType|false|$_selectedCategory|false||true',
      );
      await prefs.setStringList('videoLibrary', videoList);

      if (mounted) {
        FlushBarHelper.flushBarSuccessMessage('File downloaded successfully to "$_selectedCategory" folder', context);

      }
    } catch (e) {
      if (mounted) {
        FlushBarHelper.flushBarErrorMessage('Download failed: ${e.toString()}', context);

      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });

        if (widget.onVideoUploaded != null) {
          widget.onVideoUploaded!();
        }
      }
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
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
              colors: [
                LiquidColors.backgroundDeep,
                LiquidColors.backgroundMid,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        title: TweenAnimationBuilder(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 600),
          curve: Curves.elasticOut,
          builder: (context, double value, child) {
            return Transform.scale(
              scale: value,
              child: Row(
                children: [
                  Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      gradient: LiquidColors.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: LiquidColors.primaryStart.withValues(alpha: .4),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add to Vault',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.3,
                            shadows: [
                              Shadow(
                                color: LiquidColors.primaryStart.withValues(alpha: .3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'Import media from your device',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
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
            stops: const [0.0, 0.3, 1.0],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        LiquidCategorySelector(
                          selectedCategory: _selectedCategory,
                          onCategoryChanged: (category) {
                            setState(() {
                              _selectedCategory = category;
                              _selectedFileType = _getDefaultFileTypeForCategory(category);
                            });
                          },
                          categories: videoCategories,
                          getIcon: _getCategoryIcon,
                          getColor: _getCategoryColor,
                        ),
                        const SizedBox(height: 12),

                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _getCategoryColor(_selectedCategory).withValues(alpha: .1),
                                Colors.transparent,
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _getCategoryColor(_selectedCategory).withValues(alpha: .3),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.insert_drive_file_rounded,
                                    size: 16,
                                    color: _getCategoryColor(_selectedCategory),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'File Type: ${_selectedFileType.toUpperCase()}',
                                    style: TextStyle(
                                      color: _getCategoryColor(_selectedCategory),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Icon(
                                    Icons.folder_rounded,
                                    size: 14,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '/secure_player/${_selectedCategory.toLowerCase()}',
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: LiquidUploadCard(
                        icon: Icons.folder_open_rounded,
                        title: 'From Device',
                        subtitle: 'Select files from storage',
                        gradient: [LiquidColors.accentBlue, LiquidColors.primaryMid],
                        index: 0,
                        onTap: () {
                          setState(() {
                            _selectedFileType = _getDefaultFileTypeForCategory(_selectedCategory);
                          });
                          _pickFiles();
                        },
                      ),
                    ),
                    const SizedBox(width: 16),

                  ],
                ),

                const SizedBox(height: 30),

                if (_selectedFiles.isNotEmpty)
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Selected Files (${_selectedFiles.length})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  colors: [
                                    _getCategoryColor(_selectedCategory).withValues(alpha: .2),
                                    _getCategoryColor(_selectedCategory).withValues(alpha: .1),
                                  ],
                                  center: Alignment.center,
                                  radius: 0.8,
                                ),
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(
                                  color: _getCategoryColor(_selectedCategory).withValues(alpha: .3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getCategoryIcon(_selectedCategory),
                                    size: 14,
                                    color: _getCategoryColor(_selectedCategory),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _selectedCategory,
                                    style: TextStyle(
                                      color: _getCategoryColor(_selectedCategory),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          height: 300,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                LiquidColors.backgroundLight.withValues(alpha: .3),
                                LiquidColors.backgroundMid.withValues(alpha: .5),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: .05),
                              width: 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: ListView.builder(
                              itemCount: _selectedFiles.length,
                              itemBuilder: (context, index) {
                                final file = _selectedFiles[index];
                                return LiquidFileItem(
                                  file: file,
                                  index: index,
                                  onRemove: () {
                                    setState(() {
                                      _selectedFiles.removeAt(index);
                                    });
                                  },
                                  getFileType: (file) => _getFileTypeFromExtension(file.path),
                                  getFileIcon: _getFileTypeIcon,
                                  getFileColor: _getFileTypeColor,
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (_selectedFiles.isEmpty && !_isUploading)
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height * 0.4,
                      child: Center(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TweenAnimationBuilder(
                                tween: Tween<double>(begin: 0, end: 1),
                                duration: const Duration(milliseconds: 800),
                                curve: Curves.elasticOut,
                                builder: (context, double value, child) {
                                  return Transform.scale(
                                    scale: value,
                                    child: Container(
                                      width: 120,
                                      height: 120,
                                      decoration: BoxDecoration(
                                        gradient: RadialGradient(
                                          colors: [
                                            _getCategoryColor(_selectedCategory).withValues(alpha: .2),
                                            LiquidColors.backgroundLight.withValues(alpha: .1),
                                          ],
                                          center: Alignment.center,
                                          radius: 0.8,
                                        ),
                                        borderRadius: BorderRadius.circular(24),
                                        border: Border.all(
                                          color: _getCategoryColor(_selectedCategory).withValues(alpha: .3),
                                          width: 2,
                                        ),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          _getCategoryIcon(_selectedCategory),
                                          size: 50,
                                          color: _getCategoryColor(_selectedCategory),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No Files Selected',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _getCategoryColor(_selectedCategory).withValues(alpha: .1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _getCategoryColor(_selectedCategory).withValues(alpha: .3),
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.folder_rounded,
                                          size: 14,
                                          color: _getCategoryColor(_selectedCategory),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Category: $_selectedCategory',
                                          style: TextStyle(
                                            color: _getCategoryColor(_selectedCategory),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '/secure_player/${_selectedCategory.toLowerCase()}',
                                      style: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Choose files from device or paste a URL',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 13,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                if (_isUploading)
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.45,
                    child: LiquidProgressIndicator(
                      progress: _uploadProgress,
                      color: _getCategoryColor(_selectedCategory),
                      category: _selectedCategory,
                      isDownloading: _urlController.text.isNotEmpty,
                    ),
                  ),

                if (_selectedFiles.isNotEmpty && !_isUploading)
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _uploadFiles,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _getCategoryColor(_selectedCategory),
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _getCategoryIcon(_selectedCategory),
                                color: Colors.white,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'UPLOAD ${_selectedFiles.length} FILE${_selectedFiles.length > 1 ? 'S' : ''}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    'To: $_selectedCategory Folder',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 20),
              ],
            ),
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
        return Icons.audio_file_rounded;
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
