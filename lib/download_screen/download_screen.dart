import 'package:flutter/material.dart';
import 'package:video_player_app/download_screen/widgets/view.dart';

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
  late Animation<Offset> _slideAnimation;
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
          } else {
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

  void _showDownloadConfirmation(DownloadItem download) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: LiquidColors.cardGradient,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: LiquidColors.accentBlue.withOpacity(0.3),
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
                    gradient: LiquidColors.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: LiquidColors.primaryStart.withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
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
                  'Download ${getFileTypeLabel(download.videoPath)}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Column(
                  children: [
                    Text(
                      'Do you want to download this ${getFileTypeLabel(download.videoPath)}?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade400,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: LiquidColors.accentBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: LiquidColors.accentBlue.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        '${getFileTypeLabel(download.videoPath)}: ${download.fileName}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: LiquidColors.accentBlue,
                          fontStyle: FontStyle.italic,
                        ),
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
                          await downloadFile(
                            filePath: download.videoPath,
                            fileName: download.fileName,
                          );
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

  Future<void> downloadFile({
    required String filePath,
    required String fileName,
  }) async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) {
      debugPrint('❌ Permission denied');
      FlushBarHelper.flushBarErrorMessage('Permission denied', context);

      return;
    }

    final file = File(filePath);
    if (!await file.exists()) {
      debugPrint('❌ File not found');
      FlushBarHelper.flushBarErrorMessage('File not found', context);

      return;
    }

    final ext = filePath.split('.').last.toLowerCase();

    try {
      final fileSize = await file.length();
      final fileSizeStr = _formatBytes(fileSize);

      if (['mp4', 'mkv', 'avi', 'mov'].contains(ext)) {
        await PhotoManager.editor.saveVideo(
          file,
          title: fileName,
          relativePath: 'Movies/SecureVideo',
        );
        debugPrint('✅ Video saved');
        await _addToDownloadHistory(
          fileName: fileName,
          filePath: filePath,
          fileSize: fileSizeStr,
        );
      } else if (['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
        await PhotoManager.editor.saveImage(
          await file.readAsBytes(),
          title: fileName,
          relativePath: 'Pictures/SecureImages',
          filename: 'name',
        );
        debugPrint('✅ Image saved');
        await _addToDownloadHistory(
          fileName: fileName,
          filePath: filePath,
          fileSize: fileSizeStr,
        );
      } else if (['mp3', 'wav', 'aac', 'ogg', 'm4a'].contains(ext)) {
        final dir = Directory('/storage/emulated/0/Music/SecureVideo');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        final newFile = File('${dir.path}/$fileName.$ext');
        await file.copy(newFile.path);
        debugPrint('✅ Audio saved to Music');
        await _addToDownloadHistory(
          fileName: fileName,
          filePath: newFile.path,
          fileSize: fileSizeStr,
        );
      } else {
        final dir = Directory('/storage/emulated/0/Download/SecureVideo');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        final newFile = File('${dir.path}/$fileName.$ext');
        await file.copy(newFile.path);
        debugPrint('✅ File saved to Downloads');
        await _addToDownloadHistory(
          fileName: fileName,
          filePath: newFile.path,
          fileSize: fileSizeStr,
        );
      }

      if (mounted) {
        FlushBarHelper.flushBarSuccessMessage('$fileName downloaded successfully', context);

      }
    } catch (e) {
      debugPrint('❌ Save error: $e');
      if (mounted) {
        FlushBarHelper.flushBarErrorMessage('Download failed: ${e.toString()}', context);

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
    } else if (['mp3', 'wav', 'aac', 'flac', 'ogg', 'm4a', 'wma', 'aiff', 'alac', 'opus', 'mid', 'midi', 'amr', 'ape', 'ra', 'rm', 'mka', 'm4b', 'm4p', 'ac3', 'dts'].contains(ext)) {
      return 'Audio';
    } else if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'tiff', 'tif', 'svg', 'ico', 'heic', 'heif', 'raw', 'cr2', 'nef', 'arw', 'dng'].contains(ext)) {
      return 'Image';
    } else if ([
      'pdf', 'doc', 'docx', 'txt', 'rtf', 'odt', 'ppt', 'pptx',
      'xls', 'xlsx', 'csv', 'md', 'markdown', 'html', 'htm',
      'epub', 'mobi', 'azw3', 'tex', 'latex', 'xml', 'json', 'yaml', 'yml'
    ].contains(ext)) {
      return 'Document';
    } else if (['zip', 'rar', '7z', 'tar', 'gz', 'bz2', 'xz', 'iso', 'dmg', 'pkg', 'deb', 'rpm', 'cab'].contains(ext)) {
      return 'Archive';
    } else if (['exe', 'msi', 'apk', 'dmg', 'app', 'bat', 'sh', 'bash'].contains(ext)) {
      return 'Executable';
    } else if (['dart', 'java', 'cpp', 'c', 'h', 'py', 'js', 'ts', 'php', 'rb', 'go', 'rs', 'swift', 'kt', 'cs'].contains(ext)) {
      return 'Code';
    } else {
      return 'File';
    }
  }

  Future<void> _shareVideo(String videoPath) async {
    if (!await File(videoPath).exists()) {
      FlushBarHelper.flushBarErrorMessage('Video file not found', context);

      return;
    }

    try {
      await Share.shareXFiles([XFile(videoPath)], text: 'Check out this ${getFileTypeLabel(videoPath)}!');
    } catch (e) {
      FlushBarHelper.flushBarErrorMessage('Failed to share: ${e.toString()}', context);

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

    setState(() => _isLoading = true);
    await _loadDownloads();
    FlushBarHelper.flushBarSuccessMessage('Downloads refreshed', context);
  }

  Future<void> _clearDownloads() async {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: LiquidColors.cardGradient,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: LiquidColors.error.withOpacity(0.3),
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
                        LiquidColors.error.withOpacity(0.3),
                        LiquidColors.warning.withOpacity(0.2),
                      ],
                      center: Alignment.center,
                      radius: 0.8,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: LiquidColors.error.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.delete_forever_rounded,
                      color: LiquidColors.error,
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
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.remove('downloadHistory');
                          setState(() {
                            _downloads.clear();
                          });
                          FlushBarHelper.flushBarSuccessMessage('Download history cleared', context);

                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: LiquidColors.error,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
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
                          color: LiquidColors.success.withOpacity(0.4),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.download_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Export History',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.3,
                            shadows: [
                              Shadow(
                                color: LiquidColors.success.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${_downloads.length} ${_downloads.length == 1 ? "file" : "files"} exported',
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
        actions: [
          TweenAnimationBuilder(
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
                        color: LiquidColors.backgroundLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: LiquidColors.accentBlue.withOpacity(0.3),
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
                    const SizedBox(width: 8),
                    Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        color: LiquidColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: LiquidColors.error.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 22,
                          color: LiquidColors.error,
                        ),
                        onPressed: _downloads.isEmpty ? null : _clearDownloads,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Container(
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LiquidInfoCard(
                  message: 'To save downloads from Video Library: Tap the download button (↓) on any video',
                  icon: Icons.info_rounded,
                  color: LiquidColors.accentBlue,
                ),
                Expanded(
                  child: _isLoading && _downloads.isEmpty
                      ? _buildLoadingState()
                      : _downloads.isEmpty
                      ? LiquidEmptyState(
                    icon: Icons.download_done_outlined,
                    title: 'No Downloads Yet',
                    subtitle: 'Download videos from Video Library to get started',
                    buttonText: 'Go to Video Library',
                    onButtonPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                      FlushBarHelper.flushBarSuccessMessage('Go to Video Library tab to download videos', context);

                    },
                    iconColor: LiquidColors.success,
                  )
                      : _buildDownloadList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
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
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LiquidColors.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: LiquidColors.primaryStart.withOpacity(0.4),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),
                ),
              );
            },
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
    );
  }

  Widget _buildDownloadList() {
    return RefreshIndicator(
      backgroundColor: LiquidColors.backgroundLight,
      color: LiquidColors.accentBlue,
      strokeWidth: 2.5,
      onRefresh: _refreshDownloads,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _downloads.length,
        itemBuilder: (context, index) {
          final download = _downloads[index];
          return LiquidDownloadCard(
            fileName: download.fileName,
            fileSize: download.fileSize,
            status: download.status,
            date: download.date,
            videoPath: download.videoPath,
            fileExists: File(download.videoPath).existsSync(),
            index: index,
            onSave: () => _showDownloadConfirmation(download),
            onShare: () => _shareVideo(download.videoPath),
          );
        },
      ),
    );
  }
}
