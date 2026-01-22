import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';

class UploadScreen extends StatefulWidget {
  final VoidCallback? onVideoUploaded;

  const UploadScreen({super.key, this.onVideoUploaded});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen>
    with SingleTickerProviderStateMixin {
  String _selectedCategory = "Videos"; // Default category
  String _selectedFileType = "video"; // Default file type
  final List<File> _selectedFiles = [];
  bool _isUploading = false;
  double _uploadProgress = 0;
  final TextEditingController _urlController = TextEditingController();
  final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  // Available categories for Upload Screen
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

    // Initialize animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
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
      // Request permissions based on platform
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
          // ✅ FIXED: Audio category permission
          status = sdkInt >= 33
              ? await Permission.audio.request()
              : await Permission.storage.request();
        } else if (_selectedCategory == "Documents") {
          // For PDF and other documents on Android 13+
          if (sdkInt >= 33) {
            // Android 13+ requires READ_MEDIA_IMAGES for documents too
            status = await Permission.photos.request();
          } else {
            status = await Permission.storage.request();
          }
        } else {
          status = await Permission.storage.request();
        }

        if (status.isPermanentlyDenied) {
          _showPermissionSettingsDialog();
          return;
        }

        if (!status.isGranted) {
          if (!mounted) return;
          _showSnackBar(
            'Permission required to access $_selectedCategory files',
            Colors.red.withOpacity(0.9),
          );
          return;
        }
      } else if (Platform.isIOS) {
        final status = await Permission.photos.request();
        if (!status.isGranted) {
          if (!mounted) return;
          _showSnackBar(
            'Permission required to access files',
            Colors.red.withOpacity(0.9),
          );
          return;
        }
      }

      // Determine file type based on selected category
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
          const Color(0xFF00C853).withOpacity(0.9),
        );
      } else {
        if (!mounted) return;
        _showSnackBar(
          'No files selected',
          Colors.orange.withOpacity(0.9),
        );
      }
    } catch (e) {
      debugPrint('Error picking files: $e');
      if (!mounted) return;
      _showSnackBar(
        'Error: ${e.toString()}',
        Colors.red.withOpacity(0.9),
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

    // Video extensions
    if (['.mp4', '.avi', '.mov', '.wmv', '.mkv', '.flv', '.m4v', '.mpg', '.mpeg', '.3gp', '.webm'].contains(ext)) {
      return 'video';
    }
    // Image extensions
    else if (['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.tiff', '.svg', '.ico', '.heic'].contains(ext)) {
      return 'image';
    }
    // Audio extensions - इन्हें और comprehensive बनाएं
    else if ([
      '.mp3', '.wav', '.aac', '.flac', '.ogg', '.m4a', '.wma',
      '.aiff', '.alac', '.opus', '.mid', '.midi', '.amr', '.ape',
      '.ra', '.rm', '.mka', '.m4b', '.m4p', '.ac3', '.dts'
    ].contains(ext)) {
      return 'audio';
    }
    // Document extensions
    else if ([
      '.pdf', '.doc', '.docx', '.txt', '.ppt', '.pptx', '.xls',
      '.xlsx', '.rtf', '.odt', '.ods', '.odp', '.csv', '.xml',
      '.html', '.htm', '.epub', '.mobi', '.tex', '.md'
    ].contains(ext)) {
      return 'document';
    }
    // Archive extensions
    else if ([
      '.zip', '.rar', '.7z', '.tar', '.gz', '.bz2', '.xz',
      '.iso', '.dmg', '.pkg', '.deb', '.rpm'
    ].contains(ext)) {
      return 'archive';
    }
    else {
      return 'other';
    }
  }

  Future<void> _getDeviceInfo() async {
    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await _deviceInfoPlugin.androidInfo;
        debugPrint(
            'Android Device: ${androidInfo.model}, SDK: ${androidInfo.version.sdkInt}');
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await _deviceInfoPlugin.iosInfo;
        debugPrint('iOS Device: ${iosInfo.utsname.machine}');
      }
    } catch (e) {
      debugPrint('Error getting device info: $e');
    }
  }

  Future<void> _showPermissionSettingsDialog() async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A3E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Colors.white.withOpacity(0.1),
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
                  gradient: LinearGradient(
                    colors: [
                      Colors.orange.withOpacity(0.2),
                      Colors.red.withOpacity(0.2),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.warning_rounded,
                    size: 36,
                    color: Colors.orange,
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
                          borderRadius: BorderRadius.circular(12),
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
                        backgroundColor: const Color(0xFF4788FF),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
    );
  }

  Future<void> _uploadFiles() async {
    if (_selectedFiles.isEmpty) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });

    try {
      final appDir = await getApplicationDocumentsDirectory();

      // Create main storage directory
      final mainDir = Directory('${appDir.path}/secure_player');
      if (!await mainDir.exists()) {
        await mainDir.create(recursive: true);
      }

      // Create category-specific directory
      final categoryDir =
      Directory('${mainDir.path}/${_selectedCategory.toLowerCase()}');
      if (!await categoryDir.exists()) {
        await categoryDir.create(recursive: true);
      }

      final prefs = await SharedPreferences.getInstance();
      List<String> videoList = prefs.getStringList('videoLibrary') ?? [];

      int fileCount = 0; // Track successful uploads

      for (int i = 0; i < _selectedFiles.length; i++) {
        final file = _selectedFiles[i];
        final timestamp = DateTime.now().millisecondsSinceEpoch + i;
        final fileExt = p.extension(file.path);
        final fileName =
            '${timestamp}_${p.basenameWithoutExtension(file.path)}$fileExt';
        final destination = File('${categoryDir.path}/$fileName');

        try {
          await file.copy(destination.path);

          // ✅ FIXED: Set file type based on category
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
            // If category doesn't match, check by extension
            fileType = _getFileTypeFromExtension(file.path);
          }

          videoList.add(
            '$timestamp|${p.basenameWithoutExtension(file.path)}|${destination.path}|$fileType|false|$_selectedCategory',
          );
          fileCount++;

          if (mounted) {
            setState(() {
              _uploadProgress = (i + 1) / _selectedFiles.length;
            });
          }
        } catch (e) {
          debugPrint('Error uploading file ${file.path}: $e');
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
          const Color(0xFF00C853).withOpacity(0.9),
        );

        if (widget.onVideoUploaded != null) {
          widget.onVideoUploaded!();
        }
      }
    } catch (e) {
      debugPrint('Error in upload process: $e');
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
        _showSnackBar(
          'Upload failed: ${e.toString()}',
          Colors.red.withOpacity(0.9),
        );
      }
    }
  }

  Future<void> _downloadFromURL() async {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A3E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Colors.white.withOpacity(0.1),
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
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4A6DE5), Color(0xFF4788FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
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
              // Category Selector in Dialog
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF141432),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1A1A3E),
                  style: const TextStyle(color: Colors.white),
                  underline: const SizedBox(),
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
                        _selectedFileType =
                            _getDefaultFileTypeForCategory(value);
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
                  fillColor: const Color(0xFF141432),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF4788FF),
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
                          borderRadius: BorderRadius.circular(12),
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
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _downloadFileFromUrl(_urlController.text);
                      _urlController.clear();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4788FF),
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
                ],
              ),
            ],
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
      _showSnackBar(
        'Please enter a valid URL',
        Colors.red.withOpacity(0.9),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final mainDir = Directory('${appDir.path}/secure_player');
      if (!await mainDir.exists()) {
        await mainDir.create(recursive: true);
      }

      final categoryDir =
      Directory('${mainDir.path}/${_selectedCategory.toLowerCase()}');
      if (!await categoryDir.exists()) {
        await categoryDir.create(recursive: true);
      }

      // Extract file extension from URL
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      final originalFileName =
      pathSegments.isNotEmpty ? pathSegments.last : 'downloaded_file';

      // Determine file extension
      String fileExt = '.mp4'; // default
      if (originalFileName.contains('.')) {
        fileExt = originalFileName.substring(originalFileName.lastIndexOf('.'));
      } else {
        // Set extension based on category
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

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '$timestamp$fileExt';
      final savePath = '${categoryDir.path}/$fileName';

      final dio = Dio();
      await dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1 && mounted) {
            setState(() {
              _uploadProgress = received / total;
            });
          }
        },
      );

      final prefs = await SharedPreferences.getInstance();

      List<String> videoList = prefs.getStringList('videoLibrary') ?? [];

      //  Set file type based on category
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
        fileType = _getFileTypeFromExtension(savePath);
      }

      videoList.add(
        '$timestamp|Downloaded File|$savePath|$fileType|false|$_selectedCategory',
      );
      await prefs.setStringList('videoLibrary', videoList);

      List<String> downloadList = prefs.getStringList('downloadHistory') ?? [];
      final file = File(savePath);
      final fileSize = await file.length();
      final fileSizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(2);
      downloadList.add(
        '${DateTime.now().millisecondsSinceEpoch}|Downloaded File|$fileSizeMB MB|completed|${DateTime.now()}|$savePath|$_selectedCategory',
      );
      await prefs.setStringList('downloadHistory', downloadList);

      if (mounted) {
        _showSnackBar(
          'File downloaded successfully to "$_selectedCategory" folder',
          const Color(0xFF00C853).withOpacity(0.9),
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          'Download failed: ${e.toString()}',
          Colors.red.withOpacity(0.9),
        );
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
          borderRadius: BorderRadius.circular(8),
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
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A3E),
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4A6DE5), Color(0xFF4788FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4788FF).withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.cloud_upload_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'UPLOAD FILES',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    'Add files from device or URL',
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
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0A0A1F),
              Color(0xFF141432),
              Color(0xFF1A1A3E),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Animation
                AnimatedBuilder(
                  animation: _fadeAnimation,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _fadeAnimation.value,
                      child: Transform.translate(
                        offset: Offset(0, _slideAnimation.value),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 24),
                            // Category Selector
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF141432),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _getCategoryIcon(_selectedCategory),
                                    color: Colors.grey.shade400,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Category:',
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: DropdownButton<String>(
                                      value: _selectedCategory,
                                      isExpanded: true,
                                      dropdownColor: const Color(0xFF1A1A3E),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                      underline: const SizedBox(),
                                      items: videoCategories
                                          .map((category) => DropdownMenuItem(
                                        value: category,
                                        child: Row(
                                          children: [
                                            Icon(
                                              _getCategoryIcon(category),
                                              size: 18,
                                              color: _getCategoryColor(
                                                  category),
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
                                            _selectedFileType =
                                                _getDefaultFileTypeForCategory(
                                                    value);
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // File Type Info
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: _getCategoryColor(_selectedCategory)
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _getCategoryColor(_selectedCategory)
                                      .withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'File Type: ${_selectedFileType.toUpperCase()}',
                                    style: TextStyle(
                                      color: _getCategoryColor(_selectedCategory),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'Storage: /secure_player/${_selectedCategory.toLowerCase()}',
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Upload Options
                Row(
                  children: [
                    Expanded(
                      child: _buildUploadOption(
                        icon: Icons.folder_open_rounded,
                        title: 'From Device',
                        subtitle: 'Select files from storage',
                        gradient: const [
                          Color(0xFF4A6DE5),
                          Color(0xFF4788FF),
                        ],
                        onTap: () {
                          setState(() {
                            _selectedFileType =
                                _getDefaultFileTypeForCategory(_selectedCategory);
                          });
                          _pickFiles();
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildUploadOption(
                        icon: Icons.link_rounded,
                        title: 'From URL',
                        subtitle: 'Download from link',
                        gradient: const [
                          Color(0xFF00C853),
                          Color(0xFF64DD17),
                        ],
                        onTap: _downloadFromURL,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // Selected Files or Empty State
                if (_selectedFiles.isNotEmpty)
                  Column(
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
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getCategoryColor(_selectedCategory)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _getCategoryColor(_selectedCategory)
                                    .withOpacity(0.3),
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
                      SizedBox(
                        height: 300,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A3E).withOpacity(0.5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.05),
                              width: 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: ListView.builder(
                              itemCount: _selectedFiles.length,
                              itemBuilder: (context, index) {
                                final file = _selectedFiles[index];
                                return _buildFileItem(file, index);
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                if (_selectedFiles.isEmpty && !_isUploading)
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height*.5,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF1A1A3E),
                                  const Color(0xFF141432),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                                width: 1,
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
                          const SizedBox(height: 24),
                          Text(
                            'No Files Selected',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 40),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: _getCategoryColor(_selectedCategory)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _getCategoryColor(_selectedCategory)
                                    .withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Category: $_selectedCategory',
                                  style: TextStyle(
                                    color: _getCategoryColor(_selectedCategory),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Storage: /secure_player/${_selectedCategory.toLowerCase()}',
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Choose files from device or paste a URL',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Uploading Progress
                if (_isUploading)
                  SizedBox(
                    height: 400,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 120,
                                height: 120,
                                child: CircularProgressIndicator(
                                  value: _uploadProgress,
                                  strokeWidth: 6,
                                  backgroundColor: const Color(0xFF141432),
                                  color: _getCategoryColor(_selectedCategory),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _uploadProgress == 1.0
                                        ? const Color(0xFF00C853)
                                        : _getCategoryColor(_selectedCategory),
                                  ),
                                ),
                              ),
                              Column(
                                children: [
                                  Text(
                                    '${(_uploadProgress * 100).toStringAsFixed(0)}%',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    _urlController.text.isNotEmpty
                                        ? 'DOWNLOADING'
                                        : 'UPLOADING',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: _getCategoryColor(_selectedCategory)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _getCategoryColor(_selectedCategory)
                                    .withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'To: $_selectedCategory',
                                  style: TextStyle(
                                    color: _getCategoryColor(_selectedCategory),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Path: /secure_player/${_selectedCategory.toLowerCase()}',
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _urlController.text.isNotEmpty
                                ? 'Downloading file from URL...'
                                : 'Processing ${_selectedFiles.length} file(s)...',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Upload Button
                if (_selectedFiles.isNotEmpty && !_isUploading)
                  AnimatedBuilder(
                    animation: _fadeAnimation,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _fadeAnimation.value,
                        child: Transform.translate(
                          offset: Offset(0, _slideAnimation.value),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _uploadFiles,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                _getCategoryColor(_selectedCategory),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 18, horizontal: 24),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
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
                      );
                    },
                  ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: gradient[0].withOpacity(0.4),
                        blurRadius: 15,
                        spreadRadius: 1,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            icon,
                            size: 32,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFileItem(File file, int index) {
    final fileType = _getFileTypeFromExtension(file.path);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A3E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _getFileTypeColor(fileType).withOpacity(0.2),
                _getFileTypeColor(fileType).withOpacity(0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _getFileTypeColor(fileType).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Center(
            child: Icon(
              _getFileTypeIcon(fileType),
              color: _getFileTypeColor(fileType),
              size: 24,
            ),
          ),
        ),
        title: Text(
          p.basename(file.path),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatFileSize(file),
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 12,
              ),
            ),
            Text(
              fileType.toUpperCase(),
              style: TextStyle(
                color: _getFileTypeColor(fileType),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        trailing: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.red.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: IconButton(
            onPressed: () {
              setState(() {
                _selectedFiles.removeAt(index);
              });
            },
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.red,
              size: 20,
            ),
            padding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }

  String _formatFileSize(File file) {
    try {
      final size = file.lengthSync();
      if (size < 1024) {
        return '${size} B';
      } else if (size < 1024 * 1024) {
        return '${(size / 1024).toStringAsFixed(1)} KB';
      } else {
        return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
    } catch (e) {
      return 'Unknown size';
    }
  }

  // Helper methods for icons and colors
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case "Videos":
        return Icons.video_library_rounded;
      case "Photos":
        return Icons.photo_library_rounded;
      case "Audio": // ✅ FIXED: Audio icon
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
        return const Color(0xFF4788FF);
      case "Photos":
        return const Color(0xFF00C853);
      case "Audio": // ✅ FIXED: Audio color
        return const Color(0xFF9C27B0);
      case "Documents":
        return const Color(0xFFFF9800);
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
        return const Color(0xFF607D8B);
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
        return const Color(0xFF4788FF);
      case "image":
        return const Color(0xFF00C853);
      case "audio":
        return const Color(0xFF9C27B0);
      case "document":
        return const Color(0xFFFF9800);
      default:
        return const Color(0xFF607D8B);
    }
  }
}