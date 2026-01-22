import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_models.dart';

class DownloadScreen extends StatefulWidget {
  const DownloadScreen({super.key});

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen>
    with SingleTickerProviderStateMixin {

  final List<DownloadItem> _downloads = [];
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

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

    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );

    _animationController.forward();
    _loadDownloads();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _addToDownloadHistory({
    required String fileName,
    required String filePath,
    required String fileSize,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final downloadList = prefs.getStringList('downloadHistory') ?? [];

    final downloadItem = DownloadItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fileName: fileName,
      fileSize: fileSize,
      status: 'completed',
      date: DateTime.now().toIso8601String(),
      videoPath: filePath,
      downloadUrl: '',
      progress: 1.0,
    );

    final downloadData = '${downloadItem.id}|${downloadItem.fileName}|${downloadItem.fileSize}|'
        '${downloadItem.status}|${downloadItem.date}|${downloadItem.videoPath}||'
        '${downloadItem.downloadUrl}::${downloadItem.progress}';

    downloadList.add(downloadData);
    await prefs.setStringList('downloadHistory', downloadList);

    await _loadDownloads();
  }

  Future<void> _loadDownloads() async {
    final prefs = await SharedPreferences.getInstance();
    final downloadList = prefs.getStringList('downloadHistory') ?? [];

    setState(() {
      _downloads.clear();
      for (final downloadData in downloadList) {
        try {
          if (downloadData.contains('||')) {
            final parts = downloadData.split('||');
            if (parts.length == 2) {
              final mainParts = parts[0].split('|');
              final extraParts = parts[1].split('::');

              if (mainParts.length >= 6) {
                _downloads.add(DownloadItem(
                  id: mainParts[0],
                  fileName: mainParts[1],
                  fileSize: mainParts[2],
                  status: mainParts[3],
                  date: mainParts[4],
                  videoPath: mainParts[5],
                  downloadUrl: extraParts.isNotEmpty ? extraParts[0] : '',
                  progress: extraParts.length > 1 ? double.tryParse(extraParts[1]) ?? 1.0 : 1.0,
                ));
              }
            }
          }
          else {
            final parts = downloadData.split('|');
            if (parts.length >= 6) {
              _downloads.add(DownloadItem(
                id: parts[0],
                fileName: parts[1],
                fileSize: parts[2],
                status: parts[3],
                date: parts[4],
                videoPath: parts[5],
                downloadUrl: '',
                progress: 1.0,
              ));
            }
          }
        } catch (e) {
          debugPrint('Error parsing download item: $e');
        }
      }
      _downloads.sort((a, b) => b.id.compareTo(a.id));
      _isLoading = false;
    });
  }

  void _showDownloadConfirmation(DownloadItem downloads) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A3E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Colors.white.withValues(alpha: .1),
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
                    color: const Color(0xFF4788FF).withValues(alpha: .3),
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
                'Download ${getFileTypeLabel(downloads.videoPath)}',
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
                    'Do you want to download this ${getFileTypeLabel(downloads.videoPath)}?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade400,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${getFileTypeLabel(downloads.videoPath)}: ${downloads.fileName}',
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
                      onPressed: () async {
                        Navigator.pop(context);
                        await downloadFile(
                          filePath: downloads.videoPath,
                          fileName: downloads.fileName,
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

  Future<void> downloadFile({
    required String filePath,
    required String fileName,
  }) async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) {
      debugPrint('❌ Permission denied');
      _showSnackBar('Permission denied', Colors.red.withValues(alpha: .9));
      return;
    }

    final file = File(filePath);
    if (!await file.exists()) {
      debugPrint('❌ File not found');
      _showSnackBar('File not found', Colors.red.withValues(alpha: .9));
      return;
    }

    final ext = filePath.split('.').last.toLowerCase();

    try {
      // Get file size
      final fileSize = await file.length();
      final fileSizeStr = _formatBytes(fileSize);

      // 🎥 VIDEO
      if (['mp4', 'mkv', 'avi', 'mov'].contains(ext)) {
        await PhotoManager.editor.saveVideo(
          file,
          title: fileName,
          relativePath: 'Movies/SecureVideo',
        );
        debugPrint('✅ Video saved');

        // ✅ AUTO ADD TO DOWNLOAD HISTORY
        await _addToDownloadHistory(
          fileName: fileName,
          filePath: filePath,
          fileSize: fileSizeStr,
        );

        // 📷 IMAGE
      } else if (['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
        await PhotoManager.editor.saveImage(
          await file.readAsBytes(),
          title: fileName,
          relativePath: 'Pictures/SecureImages',
          filename: 'name',
        );
        debugPrint('✅ Image saved');

        // ✅ AUTO ADD TO DOWNLOAD HISTORY
        await _addToDownloadHistory(
          fileName: fileName,
          filePath: filePath,
          fileSize: fileSizeStr,
        );

        // 🎵 AUDIO
      } else if (['mp3', 'wav', 'aac', 'ogg', 'm4a'].contains(ext)) {
        final dir = Directory('/storage/emulated/0/Music/SecureVideo');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }

        final newFile = File('${dir.path}/$fileName.$ext');
        await file.copy(newFile.path);
        debugPrint('✅ Audio saved to Music');

        // ✅ AUTO ADD TO DOWNLOAD HISTORY
        await _addToDownloadHistory(
          fileName: fileName,
          filePath: newFile.path,
          fileSize: fileSizeStr,
        );

        // 📄 PDF / ZIP / DOC / OTHER FILES
      } else {
        final dir = Directory('/storage/emulated/0/Download/SecureVideo');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }

        final newFile = File('${dir.path}/$fileName.$ext');
        await file.copy(newFile.path);
        debugPrint('✅ File saved to Downloads');

        // ✅ AUTO ADD TO DOWNLOAD HISTORY
        await _addToDownloadHistory(
          fileName: fileName,
          filePath: newFile.path,
          fileSize: fileSizeStr,
        );
      }

      // ✅ Success message
      if (mounted) {
        _showSnackBar('$fileName downloaded successfully', const Color(0xFF00C853).withValues(alpha: .9));
      }

    } catch (e) {
      debugPrint('❌ Save error: $e');
      if (mounted) {
        _showSnackBar('Download failed: ${e.toString()}', Colors.red.withValues(alpha: .9));
      }
    }
  }

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

    if (['mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'm4v', 'mpg', 'mpeg', '3gp', 'webm', 'ts', 'mts', 'm2ts'].contains(ext)) {
      return 'Video';
    }
    else if (['mp3', 'wav', 'aac', 'flac', 'ogg', 'm4a', 'wma', 'aiff', 'alac', 'opus', 'mid', 'midi', 'amr', 'ape', 'ra', 'rm', 'mka', 'm4b', 'm4p', 'ac3', 'dts'].contains(ext)) {
      return 'Audio';
    }
    else if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'tiff', 'tif', 'svg', 'ico', 'heic', 'heif', 'raw', 'cr2', 'nef', 'arw', 'dng'].contains(ext)) {
      return 'Image';
    }
    else if ([
      'pdf',
      'doc', 'docx',
      'txt', 'rtf', 'odt',
      'ppt', 'pptx',
      'xls', 'xlsx', 'csv',
      'md', 'markdown',
      'html', 'htm',
      'epub', 'mobi', 'azw3',
      'tex', 'latex',
      'xml', 'json', 'yaml', 'yml'
    ].contains(ext)) {
      return 'PDF/Doc';
    }
    else if (['zip', 'rar', '7z', 'tar', 'gz', 'bz2', 'xz', 'iso', 'dmg', 'pkg', 'deb', 'rpm', 'cab'].contains(ext)) {
      return 'Archive';
    }
    else if (['exe', 'msi', 'apk', 'dmg', 'app', 'bat', 'sh', 'bash'].contains(ext)) {
      return 'Executable';
    }
    else if (['dart', 'java', 'cpp', 'c', 'h', 'py', 'js', 'ts', 'php', 'rb', 'go', 'rs', 'swift', 'kt', 'cs'].contains(ext)) {
      return 'Code';
    }
    else {
      return 'File';
    }
  }

  Future<void> _shareVideo(String videoPath) async {
    if (!await File(videoPath).exists()) {
      _showSnackBar('Video file not found', Colors.red.withValues(alpha: .9));
      return;
    }

    try {
      await Share.shareXFiles([XFile(videoPath)], text: 'Check out this ${getFileTypeLabel(videoPath)}!');
    } catch (e) {
      _showSnackBar('Failed to share: ${e.toString()}', Colors.red.withValues(alpha: .9));
    }
  }

  Future<void> _refreshDownloads() async {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }

    setState(() {
      _isLoading = true;
    });
    await _loadDownloads();
    _showSnackBar('Downloads refreshed', const Color(0xFF4788FF).withValues(alpha: .9));
  }

  Future<void> _clearDownloads() async {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A3E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Colors.white.withValues(alpha: .1),
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
                      Colors.red.withValues(alpha: .2),
                      Colors.orange.withValues(alpha: .2),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: .3),
                    width: 2,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.delete_forever_rounded,
                    color: Colors.red,
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Clear All Downloads?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'This will permanently remove all download history.',
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
                      onPressed: () async {
                        Navigator.pop(context);
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.remove('downloadHistory');
                        setState(() {
                          _downloads.clear();
                        });
                        _showSnackBar('Download history cleared', Colors.red.withValues(alpha: .9));
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
                        'Clear All',
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

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
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
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00C853), Color(0xFF64DD17)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00C853).withValues(alpha: .4),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.download_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DOWNLOAD HISTORY',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    '${_downloads.length} downloaded videos',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                const SizedBox(width: 10),
                Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A3E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .1),
                      width: 1,
                    ),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.refresh_rounded,
                      size: 22,
                      color: Colors.white,
                    ),
                    onPressed: _refreshDownloads,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: .3),
                      width: 1,
                    ),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 22,
                      color: Colors.red,
                    ),
                    onPressed: _downloads.isEmpty ? null : _clearDownloads,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Transform.translate(
              offset: Offset(0, _slideAnimation.value),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF0A0A1F),
                      const Color(0xFF141432),
                      const Color(0xFF1A1A3E),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A3E).withValues(alpha: .5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF4788FF).withValues(alpha: .3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_rounded,
                              color: Color(0xFF4788FF),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'To save downloads from Video Library: Tap the download button (↓) on any video',
                                style: TextStyle(
                                  color: Colors.grey.shade300,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: _isLoading && _downloads.isEmpty
                          ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(
                              color: Color(0xFF4788FF),
                              strokeWidth: 2,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Loading Downloads...',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                          : _downloads.isEmpty
                          ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF1A1A3E),
                                    const Color(0xFF141432),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: .1),
                                  width: 1,
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.download_done_outlined,
                                  size: 60,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),
                            Text(
                              'No Downloads Yet',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Download videos from Video Library to get started',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).popUntil((route) => route.isFirst);
                                _showSnackBar(
                                  'Go to Video Library tab to download videos',
                                  const Color(0xFF4788FF).withValues(alpha: .9),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4788FF),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.video_library_rounded, color: Colors.white),
                              label: const Text(
                                'Go to Video Library',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                          : RefreshIndicator(
                        backgroundColor: const Color(0xFF1A1A3E),
                        color: const Color(0xFF4788FF),
                        onRefresh: _refreshDownloads,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _downloads.length,
                          itemBuilder: (context, index) {
                            final download = _downloads[index];
                            return _buildDownloadCard(download, index);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDownloadCard(DownloadItem download, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: const Color(0xFF1A1A3E),
        borderRadius: BorderRadius.circular(16),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: .05),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: download.status == 'completed'
                          ? [
                        const Color(0xFF00C853).withValues(alpha: .2),
                        const Color(0xFF64DD17).withValues(alpha: .1),
                      ]
                          : [
                        Colors.orange.withValues(alpha: .2),
                        Colors.red.withValues(alpha: .1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: download.status == 'completed'
                          ? const Color(0xFF00C853).withValues(alpha: .3)
                          : Colors.orange.withValues(alpha: .3),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      download.status == 'completed'
                          ? Icons.check_circle_rounded
                          : Icons.error_outline_rounded,
                      color: download.status == 'completed'
                          ? const Color(0xFF00C853)
                          : Colors.orange,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        download.fileName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: download.status == 'completed'
                                  ? const Color(0xFF00C853).withValues(alpha: .1)
                                  : Colors.orange.withValues(alpha: .1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: download.status == 'completed'
                                    ? const Color(0xFF00C853).withValues(alpha: .3)
                                    : Colors.orange.withValues(alpha: .3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              download.status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: download.status == 'completed'
                                    ? const Color(0xFF00C853)
                                    : Colors.orange,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              download.fileSize,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(download.date),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      if (download.downloadUrl.isEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.video_library_rounded,
                              size: 12,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'From Library',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (File(download.videoPath).existsSync())
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4788FF).withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF4788FF).withValues(alpha: .3),
                            width: 1,
                          ),
                        ),
                        child: IconButton(
                          onPressed: () => _showDownloadConfirmation(_downloads[index]),
                          icon: const Icon(
                            Icons.save_alt_rounded,
                            color: Color(0xFF4788FF),
                            size: 20,
                          ),
                          padding: EdgeInsets.zero,
                          tooltip: 'Save to Gallery',
                        ),
                      ),
                    if (File(download.videoPath).existsSync()) const SizedBox(width: 8),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00C853).withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF00C853).withValues(alpha: .3),
                          width: 1,
                        ),
                      ),
                      child: IconButton(
                        onPressed: () => _shareVideo(download.videoPath),
                        icon: const Icon(
                          Icons.share_rounded,
                          color: Color(0xFF00C853),
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        tooltip: 'Share ${getFileTypeLabel(download.videoPath)}',
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

  String _formatDate(String dateString) {
    try {
      final date = DateTime.tryParse(dateString);
      if (date == null) return dateString;

      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 365) {
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      } else if (difference.inDays > 30) {
        return '${(difference.inDays / 30).floor()} months ago';
      } else if (difference.inDays > 7) {
        return '${(difference.inDays / 7).floor()} weeks ago';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} days ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hours ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minutes ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return dateString;
    }
  }
}