import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_app/audio_hear_screen/audio_hear_screen.dart';
import 'package:video_player_app/pdf_reader_screen/pdf_reader_screen.dart';
import '../db/deleted_video_screen/deleted_video_screen.dart';
import '../models/app_models.dart';
import '../video_player_screen/video_player_screen.dart';

class VideoLibraryScreen extends StatefulWidget {
  final VoidCallback? onVideosChanged;

  const VideoLibraryScreen({
    super.key,
    this.onVideosChanged,
  });

  @override
  State<VideoLibraryScreen> createState() => VideoLibraryScreenState();
}

class VideoLibraryScreenState extends State<VideoLibraryScreen> {
  final List<VideoItem> _allMedia = [];
  final List<VideoItem> _filteredMedia = [];
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = "All";

  // UNDO Related Variables
  Timer? _undoTimer;
  VideoItem? _lastDeletedVideo;
  int _undoCountdown = 2; // 2 seconds

  // Available categories
  static const List<String> mediaCategories = [
    "All",
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
    _loadMedia();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _undoTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _filterMedia();
  }

  void _filterMedia() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      _filteredMedia.clear();

      if (query.isEmpty && _selectedCategory == "All") {
        _filteredMedia.addAll(_allMedia.where((media) => !media.isDeleted));
        return;
      }

      for (final media in _allMedia) {
        if (media.isDeleted) continue; // Skip deleted media

        bool matchesCategory = _selectedCategory == "All" ||
            media.category.toLowerCase() == _selectedCategory.toLowerCase();

        bool matchesSearch = query.isEmpty ||
            media.title.toLowerCase().contains(query) ||
            media.category.toLowerCase().contains(query);

        if (matchesCategory && matchesSearch) {
          _filteredMedia.add(media);
        }
      }
    });
  }

  // Public method to refresh media from parent
  Future<void> refreshVideos() async {
    await _loadMedia();
  }

  Future<void> _loadMedia() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 300));

      final prefs = await SharedPreferences.getInstance();
      final mediaList = prefs.getStringList('videoLibrary') ?? [];

      if (!mounted) return;

      setState(() {
        _allMedia.clear();
        for (final mediaData in mediaList) {
          try {
            _allMedia.add(VideoItem.fromStorageString(mediaData));
          } catch (e) {
            debugPrint('Error parsing media data: $e');
          }
        }
        // Sort by ID (timestamp) to show newest first
        _allMedia.sort((a, b) => b.id.compareTo(a.id));
        _filterMedia(); // Apply current filters
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      debugPrint('Error loading media: $e');
    }
  }

  Future<void> _updateMediaCategory(int index, String newCategory) async {
    final media = _allMedia[index];

    setState(() {
      _allMedia[index] = media.copyWith(category: newCategory);
    });

    _filterMedia(); // Re-apply filters after category change

    final prefs = await SharedPreferences.getInstance();
    final mediaList = _allMedia.map((v) => v.toStorageString()).toList();
    await prefs.setStringList('videoLibrary', mediaList);
  }

  Future<void> _toggleMediaLock(int index) async {
    final media = _allMedia[index];

    // If unlocking a locked video, require biometric authentication
    if (media.isLocked) {
      final prefs = await SharedPreferences.getInstance();
      final videoLockEnabled = prefs.getBool('videoLock') ?? false;

      if (videoLockEnabled) {
        final authenticated = await _authenticateForLockedAction();
        if (!authenticated) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Authentication required to unlock'),
                backgroundColor: Colors.red.withOpacity(0.9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
                duration: const Duration(seconds: 2),
              ),
            );
          }
          return;
        }
      }
    }

    // Proceed with toggling lock
    setState(() {
      _allMedia[index] = media.copyWith(
        isLocked: !media.isLocked,
      );
    });

    final prefs = await SharedPreferences.getInstance();
    final mediaList = _allMedia.map((v) => v.toStorageString()).toList();
    await prefs.setStringList('videoLibrary', mediaList);

    _filterMedia(); // Re-apply filters
  }

  Future<void> _deleteMedia(int index) async {
    final media = _filteredMedia[index];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A3E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
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
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Move to Trash?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '"${media.title}" will be moved to recycle bin.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade400,
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
                      onPressed: () async {
                        Navigator.pop(context);

                        // Mark video as deleted
                        await _softDeleteVideoItem(media);

                        // Notify about media change
                        if (widget.onVideosChanged != null) {
                          widget.onVideosChanged!();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Move to Trash',
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

  // Soft delete video function with 2-second UNDO timer
  Future<void> _softDeleteVideoItem(VideoItem video) async {
    try {
      _lastDeletedVideo = video; // Store the deleted video

      final prefs = await SharedPreferences.getInstance();
      final mediaList = prefs.getStringList('videoLibrary') ?? [];
      final updatedMediaList = <String>[];

      // Update the video to mark as deleted
      for (final mediaData in mediaList) {
        final parts = mediaData.split('|');
        if (parts[0] == video.id) {
          // This is the video to delete - update it with deleted status
          final deletedVideo = VideoItem(
            id: parts[0],
            title: parts[1],
            path: parts[2],
            type: parts[3],
            isLocked: parts[4] == 'true',
            category: parts[5],
            isDeleted: true, // Mark as deleted
            deletedDate: DateTime.now(),
          ).toStorageString();

          updatedMediaList.add(deletedVideo);
        } else {
          updatedMediaList.add(mediaData);
        }
      }

      // Save updated list
      await prefs.setStringList('videoLibrary', updatedMediaList);

      // Show UNDO snackbar for 2 seconds
      //_showUndoSnackbar(video);

      // Refresh the media list
      await _loadMedia();

    } catch (e) {
      debugPrint('Error deleting video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error moving to trash'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  // Show UNDO snackbar for 1 seconds
  void _showUndoSnackbar(VideoItem video) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.delete_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Moved to recycle bin',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.withOpacity(0.9),
        duration: const Duration(seconds: 1), // Total duration 1 seconds
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: Colors.yellow,
          onPressed: () async {
            // Cancel the timer
            _undoTimer?.cancel();

            // Restore the video immediately
            await _restoreVideoItem(video.id);

            // Clear the last deleted video
            _lastDeletedVideo = null;
          },
        ),
      ),
    );
  }

  // Enhanced restore video function with confirmation
  Future<void> _restoreVideoItem(String videoId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mediaList = prefs.getStringList('videoLibrary') ?? [];
      final updatedMediaList = <String>[];

      for (final mediaData in mediaList) {
        final parts = mediaData.split('|');
        if (parts[0] == videoId) {
          // Restore this video
          final restoredVideo = VideoItem(
            id: parts[0],
            title: parts[1],
            path: parts[2],
            type: parts[3],
            isLocked: parts[4] == 'true',
            category: parts[5],
            isDeleted: false, // Mark as not deleted
            deletedDate: null, // Clear deletion date
          ).toStorageString();

          updatedMediaList.add(restoredVideo);
        } else {
          updatedMediaList.add(mediaData);
        }
      }

      await prefs.setStringList('videoLibrary', updatedMediaList);

      if (mounted) {
        // Show restore success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                const Text('Video restored successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Refresh media list
      await _loadMedia();

    } catch (e) {
      debugPrint('Error restoring video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error restoring video'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openMedia(VideoItem media) async {
    if (media.isLocked) {
      final prefs = await SharedPreferences.getInstance();
      final mediaLockEnabled = prefs.getBool('videoLock') ?? false;

      if (mediaLockEnabled) {
        final authenticated = await _authenticateMedia();
        if (!authenticated) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Authentication failed'),
                backgroundColor: Colors.red.withOpacity(0.9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
              ),
            );
          }
          return;
        }
      }
    }

    if (!await File(media.path).exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('File not found'),
            backgroundColor: Colors.red.withOpacity(0.9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
      return;
    }

    // Open based on media type
    switch (media.type) {
      case 'video':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoPlayerScreen(
              videoPath: media.path,
              videoTitle: media.title,
            ),
          ),
        ).then((_) {
          _loadMedia();
        });
        break;

      case 'image':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  media.title,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              body: Center(
                child: InteractiveViewer(
                  child: Image.file(
                    File(media.path),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image,
                              color: Colors.white,
                              size: 60,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Unable to load image',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        break;

      case 'audio':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (builder) => AudioPlayerScreen(
              filePath: media.path,
              fileName: media.title,
            ),
          ),
        );
        break;

      case 'document':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (builder) => PDFReaderScreen(
              filePath: media.path,
              fileName: media.title,
            ),
          ),
        );
        break;

      default:
        _showGenericFileDialog(media);
        break;
    }
  }

  void _showGenericFileDialog(VideoItem media) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A3E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF607D8B), Color(0xFF455A64)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF607D8B).withOpacity(0.4),
                      blurRadius: 15,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.insert_drive_file_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                media.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'File Type: ${media.type.toUpperCase()}',
                style: TextStyle(
                  color: Colors.grey.shade400,
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4788FF),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _authenticateMedia() async {
    try {
      final LocalAuthentication localAuth = LocalAuthentication();
      final bool canCheck = await localAuth.canCheckBiometrics;
      if (!canCheck) return false;

      final List<BiometricType> availableBiometrics =
      await localAuth.getAvailableBiometrics();
      if (availableBiometrics.isEmpty) return false;

      return await localAuth.authenticate(
        localizedReason: 'Authenticate to access locked media',
        biometricOnly: true,
        sensitiveTransaction: true,
      );
    } catch (e) {
      return false;
    }
  }

  // Function to authenticate for locked media actions (including unlocking)
  Future<bool> _authenticateForLockedAction() async {
    try {
      final LocalAuthentication localAuth = LocalAuthentication();
      final bool canCheck = await localAuth.canCheckBiometrics;
      if (!canCheck) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Biometric authentication not available'),
              backgroundColor: Colors.red.withOpacity(0.9),
            ),
          );
        }
        return false;
      }

      final List<BiometricType> availableBiometrics =
      await localAuth.getAvailableBiometrics();
      if (availableBiometrics.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('No biometric methods available'),
              backgroundColor: Colors.red.withOpacity(0.9),
            ),
          );
        }
        return false;
      }

      final authenticated = await localAuth.authenticate(
        localizedReason: 'Authenticate to perform this action',
        biometricOnly: true,
        sensitiveTransaction: true,
      );

      return authenticated;
    } catch (e) {
      debugPrint('Authentication error: $e');
      return false;
    }
  }

  // Download video to gallery
  void _showDownloadConfirmation(VideoItem video) {
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
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4A6DE5), Color(0xFF4788FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF4788FF).withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.download_rounded,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Download ${getFileTypeLabel(video.path)}',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Column(
                children: [
                  Text(
                    'Do you want to download this ${getFileTypeLabel(video.path)}?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade400,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${getFileTypeLabel(video.path)}: ${video.title}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
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
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.white,
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
                        _downloadFile(
                          filePath: video.path,
                          fileName: video.title,
                        );
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
    );
  }

  /// download file method
  Future<void> _downloadFile({
    required String filePath,
    required String fileName,
  }) async
  {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) {
      debugPrint('❌ Permission denied');
      return;
    }

    final file = File(filePath);
    if (!await file.exists()) {
      debugPrint('❌ File not found');
      return;
    }

    final ext = filePath.split('.').last.toLowerCase();

    try {
      // Get file size
      final fileSize = await file.length();
      final fileSizeStr = _formatBytes(fileSize);

      // ✅ Add to download history
      await _addToDownloadHistory(
        fileName: fileName,
        filePath: filePath,
        fileSize: fileSizeStr,
      );

      // 🎥 VIDEO
      if (['mp4', 'mkv', 'avi', 'mov'].contains(ext)) {
        await PhotoManager.editor.saveVideo(
          file,
          title: fileName,
          relativePath: 'Movies/SecureVideo',
        );
        debugPrint('✅ Video saved');

        // 📷 IMAGE
      } else if (['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
        await PhotoManager.editor.saveImage(
          await file.readAsBytes(),
          title: fileName,
          relativePath: 'Pictures/SecureImages', filename: 'images',
        );
        debugPrint('✅ Image saved');

        // 🎵 AUDIO
      } else if (['mp3', 'wav', 'aac', 'ogg', 'm4a'].contains(ext)) {
        final dir = Directory('/storage/emulated/0/Music/SecureVideo');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }

        final newFile = File('${dir.path}/$fileName.$ext');
        await file.copy(newFile.path);
        debugPrint('✅ Audio saved to Music');

        // 📄 PDF / ZIP / DOC / OTHER FILES
      } else {
        final dir = Directory('/storage/emulated/0/Download/SecureVideo');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }

        final newFile = File('${dir.path}/$fileName.$ext');
        await file.copy(newFile.path);
        debugPrint('✅ File saved to Downloads');
      }

      // ✅ Success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$fileName downloaded successfully'),
            backgroundColor: const Color(0xFF00C853).withOpacity(0.9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: ${e.toString()}'),
            backgroundColor: Colors.red.withOpacity(0.9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  // ✅ Add to download history
  Future<void> _addToDownloadHistory({
    required String fileName,
    required String filePath,
    required String fileSize,
  }) async
  {
    try {
      final prefs = await SharedPreferences.getInstance();
      final downloadList = prefs.getStringList('downloadHistory') ?? [];

      // Create download item
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final date = DateTime.now().toIso8601String();

      // Format: id|fileName|fileSize|status|date|videoPath||downloadUrl::progress
      final downloadData =
          '$id|$fileName|$fileSize|completed|$date|$filePath||::1.0';

      downloadList.add(downloadData);
      await prefs.setStringList('downloadHistory', downloadList);

      debugPrint('✅ Added to download history: $fileName');
    } catch (e) {
      debugPrint('❌ Error adding to download history: $e');
    }
  }

  // ✅ Format bytes helper method
  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';

    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
    int i = 0;
    double bytesDouble = bytes.toDouble();

    while (bytesDouble >= 1024 && i < suffixes.length - 1) {
      bytesDouble /= 1024;
      i++;
    }

    return '${bytesDouble.toStringAsFixed(1)} ${suffixes[i]}';
  }

  String getFileTypeLabel(String path) {
    final ext = path.split('.').last.toLowerCase();

    // Video extensions
    if ([
      'mp4',
      'mkv',
      'avi',
      'mov',
      'wmv',
      'flv',
      'm4v',
      'mpg',
      'mpeg',
      '3gp',
      'webm',
      'ts',
      'mts',
      'm2ts'
    ].contains(ext)) {
      return 'Video';
    }
    // Audio extensions
    else if ([
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
      'mid',
      'midi',
      'amr',
      'ape',
      'ra',
      'rm',
      'mka',
      'm4b',
      'm4p',
      'ac3',
      'dts'
    ].contains(ext)) {
      return 'Audio';
    }
    // Image extensions
    else if ([
      'jpg',
      'jpeg',
      'png',
      'gif',
      'bmp',
      'webp',
      'tiff',
      'tif',
      'svg',
      'ico',
      'heic',
      'heif',
      'raw',
      'cr2',
      'nef',
      'arw',
      'dng'
    ].contains(ext)) {
      return 'Image';
    }
    // PDF and Document extensions
    else if ([
      'pdf', // PDF files
      'doc',
      'docx', // Microsoft Word
      'txt',
      'rtf',
      'odt', // Text files
      'ppt',
      'pptx', // Microsoft PowerPoint
      'xls',
      'xlsx',
      'csv', // Microsoft Excel
      'md',
      'markdown', // Markdown
      'html',
      'htm', // Web pages
      'epub',
      'mobi',
      'azw3', // E-books
      'tex',
      'latex', // LaTeX
      'xml',
      'json',
      'yaml',
      'yml' // Data files
    ].contains(ext)) {
      return 'PDF/Doc';
    }
    // Archive/Compressed files
    else if ([
      'zip',
      'rar',
      '7z',
      'tar',
      'gz',
      'bz2',
      'xz',
      'iso',
      'dmg',
      'pkg',
      'deb',
      'rpm',
      'cab'
    ].contains(ext)) {
      return 'Archive';
    }
    // Executable files
    else if (['exe', 'msi', 'apk', 'dmg', 'app', 'bat', 'sh', 'bash']
        .contains(ext)) {
      return 'Executable';
    }
    // Code files
    else if ([
      'dart',
      'java',
      'cpp',
      'c',
      'h',
      'py',
      'js',
      'ts',
      'php',
      'rb',
      'go',
      'rs',
      'swift',
      'kt',
      'cs'
    ].contains(ext)) {
      return 'Code';
    } else {
      return 'File';
    }
  }

  // Pull to Refresh Function
  Future<void> _onRefresh() async {
    try {
      // Show refreshing animation
      setState(() {
        _isLoading = true;
      });

      await Future.delayed(const Duration(milliseconds: 800));

      // Load fresh data
      await _loadMedia();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Refreshed ${_filteredMedia.length} files'),
              ],
            ),
            backgroundColor: const Color(0xFF00C853),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      debugPrint('Refresh error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Refresh failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
                  Icons.add,
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
                    'LIBRARY VIDEOS',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    'Add files from device',
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
        actions: [
          // Deleted Videos Button
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              color: Colors.white,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DeletedVideosScreen(
                    onVideosChanged: () {
                      // Refresh when returning from deleted videos
                      _loadMedia();
                    },
                  ),
                ),
              );
            },
            tooltip: 'Recycle Bin',
          ),
        ],
      ),
      backgroundColor: const Color(0xFF1A1A3E),
      body: Column(
        children: [
          // Header with Search and Filter
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF141432),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search Bar
                Container(
                  height: 45,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A3E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Search media...',
                            hintStyle: TextStyle(color: Colors.grey.shade500),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          onPressed: () {
                            _searchController.clear();
                          },
                          icon: Icon(
                            Icons.close,
                            color: Colors.grey.shade400,
                            size: 20,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Category Filter
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: mediaCategories.length,
                    itemBuilder: (context, index) {
                      final category = mediaCategories[index];
                      final isSelected = _selectedCategory == category;
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            category,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedCategory = selected ? category : "All";
                              _filterMedia();
                            });
                          },
                          backgroundColor: const Color(0xFF1A1A3E),
                          selectedColor: const Color(0xFF4788FF),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey.shade400,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected
                                  ? const Color(0xFF4788FF)
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                // Filter Info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_filteredMedia.length} files found',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 12,
                      ),
                    ),
                    if (_selectedCategory != "All" ||
                        _searchController.text.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedCategory = "All";
                            _searchController.clear();
                          });
                          _filterMedia();
                        },
                        child: Text(
                          'Clear filters',
                          style: TextStyle(
                            color: const Color(0xFF4788FF),
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Media List with Pull to Refresh
          Expanded(
            child: _isLoading && _allMedia.isEmpty
                ? _buildLoadingState()
                : _filteredMedia.isEmpty
                ? _buildEmptyState()
                : _buildMediaListWithRefresh(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: const Color(0xFF4788FF),
      backgroundColor: const Color(0xFF1A1A3E),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.8,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                  color: Color(0xFF4788FF),
                  strokeWidth: 2,
                ),
                const SizedBox(height: 20),
                Text(
                  'Loading Media...',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: const Color(0xFF4788FF),
      backgroundColor: const Color(0xFF1A1A3E),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.8,
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
                      _searchController.text.isNotEmpty || _selectedCategory != "All"
                          ? Icons.search_off_rounded
                          : Icons.library_music_outlined,
                      size: 50,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _searchController.text.isNotEmpty || _selectedCategory != "All"
                      ? 'No Files Found'
                      : 'No Files Yet',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _searchController.text.isNotEmpty || _selectedCategory != "All"
                      ? 'Try different search terms or categories'
                      : 'Upload your first file to get started',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                  ),
                ),
                if (_searchController.text.isNotEmpty || _selectedCategory != "All")
                  const SizedBox(height: 20),
                if (_searchController.text.isNotEmpty || _selectedCategory != "All")
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _selectedCategory = "All";
                        _searchController.clear();
                      });
                      _filterMedia();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4788FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Clear Filters',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMediaListWithRefresh() {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: const Color(0xFF4788FF),
      backgroundColor: const Color(0xFF1A1A3E),
      strokeWidth: 2.5,
      displacement: 40,
      edgeOffset: 0,
      triggerMode: RefreshIndicatorTriggerMode.anywhere,
      child: ListView.builder(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.all(16),
        itemCount: _filteredMedia.length,
        itemBuilder: (context, index) {
          final media = _filteredMedia[index];
          return _buildMediaCard(media, index);
        },
      ),
    );
  }

  Widget _buildMediaCard(VideoItem media, int index) {
    // Get appropriate icon and color based on media type
    final iconData = _getMediaIcon(media.type);
    final iconColor = _getMediaColor(media.type);
    final isLocked = media.isLocked;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: const Color(0xFF1A1A3E),
        borderRadius: BorderRadius.circular(16),
        elevation: 0,
        child: InkWell(
          onTap: () => _openMedia(media),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.05),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Media Thumbnail/Icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isLocked
                          ? [
                        Colors.orange.withOpacity(0.2),
                        Colors.orange.withOpacity(0.1),
                      ]
                          : [
                        iconColor.withOpacity(0.2),
                        iconColor.withOpacity(0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isLocked
                          ? Colors.orange.withOpacity(0.3)
                          : iconColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      isLocked ? Icons.lock_outline_rounded : iconData,
                      color: isLocked ? Colors.orange : iconColor,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Media Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        media.title,
                        style: TextStyle(
                          color: isLocked ? Colors.orange : Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          // Media Type
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isLocked
                                  ? Colors.orange.withOpacity(0.1)
                                  : iconColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isLocked
                                    ? Colors.orange.withOpacity(0.3)
                                    : iconColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              media.type.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isLocked ? Colors.orange : iconColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          // Category (only show if not locked)
                          if (!isLocked)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.green.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.category,
                                    size: 10,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      media.category,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (isLocked)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.orange.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.lock_rounded,
                                    size: 10,
                                    color: Colors.orange,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Locked',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // Date
                          Text(
                            _formatDate(media.id),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Action Buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Category Selector (only if not locked)
                    if (!isLocked)
                      PopupMenuButton<String>(
                        onSelected: (newCategory) {
                          _updateMediaCategory(
                            _allMedia.indexWhere((v) => v.id == media.id),
                            newCategory,
                          );
                        },
                        itemBuilder: (context) => mediaCategories
                            .where((c) => c != "All")
                            .map((category) => PopupMenuItem(
                          value: category,
                          child: Row(
                            children: [
                              Icon(
                                Icons.category,
                                size: 18,
                                color: const Color(0xFF4788FF),
                              ),
                              const SizedBox(width: 8),
                              Text(category),
                            ],
                          ),
                        ))
                            .toList(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.green.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.category,
                              color: Colors.green,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    if (!isLocked) const SizedBox(width: 8),

                    // Lock/Unlock Button
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isLocked
                            ? Colors.orange.withOpacity(0.1)
                            : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isLocked
                              ? Colors.orange.withOpacity(0.3)
                              : Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: IconButton(
                        onPressed: () => _toggleMediaLock(
                          _allMedia.indexWhere((v) => v.id == media.id),
                        ),
                        icon: Icon(
                          isLocked
                              ? Icons.lock_open_rounded
                              : Icons.lock_outline_rounded,
                          color: isLocked ? Colors.orange : Colors.white,
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Action Buttons Column
                    Column(
                      children: [
                        // Download Button (only if not locked)
                        if (!isLocked)
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4788FF).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFF4788FF).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: IconButton(
                              onPressed: () {
                                _showDownloadConfirmation(media);
                                debugPrint('Download video: ${media.title}');
                              },
                              icon: const Icon(
                                Icons.download_rounded,
                                color: Color(0xFF4788FF),
                                size: 20,
                              ),
                              padding: EdgeInsets.zero,
                              tooltip: 'Download ${getFileTypeLabel(media.path)}',
                            ),
                          ),
                        if (isLocked)
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.grey.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: IconButton(
                              onPressed: () async {
                                final authenticated =
                                await _authenticateForLockedAction();
                                if (authenticated) {
                                  _showDownloadConfirmation(media);
                                }
                              },
                              icon: Icon(
                                Icons.download_rounded,
                                color: Colors.grey.withOpacity(0.5),
                                size: 20,
                              ),
                              padding: EdgeInsets.zero,
                              tooltip: 'Authenticate to download',
                            ),
                          ),
                        const SizedBox(height: 7),

                        // Delete Button (only if not locked)
                        if (!isLocked)
                          Container(
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
                              onPressed: () => _deleteMedia(index),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.red,
                                size: 20,
                              ),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        if (isLocked)
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.grey.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: IconButton(
                              onPressed: () async {
                                final authenticated =
                                await _authenticateForLockedAction();
                                if (authenticated) {
                                  _deleteMedia(index);
                                }
                              },
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.grey.withOpacity(0.5),
                                size: 20,
                              ),
                              padding: EdgeInsets.zero,
                              tooltip: 'Authenticate to delete',
                            ),
                          ),
                      ],
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

  String _formatDate(String timestamp) {
    try {
      final date = DateTime.fromMillisecondsSinceEpoch(int.parse(timestamp));
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 365) {
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      } else if (difference.inDays > 7) {
        return '${date.month}/${date.day}/${date.year}';
      } else if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Unknown date';
    }
  }

  // Helper methods for icons and colors
  IconData _getMediaIcon(String type) {
    switch (type) {
      case 'video':
        return Icons.video_library_rounded;
      case 'image':
        return Icons.image_rounded;
      case 'audio':
        return Icons.music_note_rounded;
      case 'document':
        return Icons.description_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color _getMediaColor(String type) {
    switch (type) {
      case 'video':
        return const Color(0xFF4788FF);
      case 'image':
        return const Color(0xFF00C853);
      case 'audio':
        return const Color(0xFF9C27B0);
      case 'document':
        return const Color(0xFFFF9800);
      default:
        return const Color(0xFF607D8B);
    }
  }
}