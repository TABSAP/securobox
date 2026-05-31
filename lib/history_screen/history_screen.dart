import 'package:flutter/material.dart';
import 'package:video_player_app/history_screen/widgets/view.dart';
import 'package:video_player_app/utils/vault_context.dart';
import 'package:video_player_app/utils/responsive.dart';
import 'package:video_player_app/widgets/liquid_bottom_nav.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  final List<DownloadItem> _downloads = [];
  final List<_ActiveJob> _activeJobs = [];
  DateTime _lastProgressTick = DateTime.fromMillisecondsSinceEpoch(0);
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
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
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
    final downloadList =
        prefs.getStringList(VaultContext.instance.downloadHistoryKey) ?? [];

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

    final downloadData =
        '${downloadItem.id}|${downloadItem.fileName}|${downloadItem.fileSize}|'
        '${downloadItem.status}|${downloadItem.date}|${downloadItem.videoPath}||'
        '${downloadItem.downloadUrl}::${downloadItem.progress}';

    downloadList.add(downloadData);
    await prefs.setStringList(
      VaultContext.instance.downloadHistoryKey,
      downloadList,
    );

    if (!mounted) return;
    setState(() => _downloads.insert(0, downloadItem));
  }

  Future<void> _loadDownloads() async {
    final prefs = await SharedPreferences.getInstance();
    final downloadList =
        prefs.getStringList(VaultContext.instance.downloadHistoryKey) ?? [];

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
                _downloads.add(
                  DownloadItem(
                    id: mainParts[0],
                    fileName: mainParts[1],
                    fileSize: mainParts[2],
                    status: mainParts[3],
                    date: mainParts[4],
                    videoPath: mainParts[5],
                    downloadUrl: extraParts.isNotEmpty ? extraParts[0] : '',
                    progress: extraParts.length > 1
                        ? double.tryParse(extraParts[1]) ?? 1.0
                        : 1.0,
                  ),
                );
              }
            }
          } else {
            final parts = downloadData.split('|');
            if (parts.length >= 6) {
              _downloads.add(
                DownloadItem(
                  id: parts[0],
                  fileName: parts[1],
                  fileSize: parts[2],
                  status: parts[3],
                  date: parts[4],
                  videoPath: parts[5],
                  downloadUrl: '',
                  progress: 1.0,
                ),
              );
            }
          }
        } catch (_) {}
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
              color: LiquidColors.accentBlue.withValues(alpha: 0.3),
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
                        color: LiquidColors.primaryStart.withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.download_rounded,
                      size: 36,
                      color: LiquidColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Save this ${getFileTypeLabel(download.videoPath).toLowerCase()} again?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: LiquidColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Column(
                  children: [
                    Text(
                      'A fresh decrypted copy will be written to the gallery or file manager.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: LiquidColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: LiquidColors.accentBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: LiquidColors.accentBlue.withValues(alpha: 0.3),
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
                            color: LiquidColors.textTertiary,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: LiquidColors.textSecondary,
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
                        child: Text(
                          'Save again',
                          style: TextStyle(
                            color: LiquidColors.textPrimary,
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
      if (mounted) {
        FlushBarHelper.flushBarErrorMessage('Permission denied', context);
      }
      return;
    }

    final file = File(filePath);
    if (!await file.exists()) {
      if (mounted) {
        FlushBarHelper.flushBarErrorMessage('File not found', context);
      }
      return;
    }

    final ext = filePath.split('.').last.toLowerCase();
    final kind = _JobKind.from(filePath);
    final job = _ActiveJob(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fileName: fileName,
      icon: kind.icon,
      color: kind.color,
      typeLabel: kind.label,
      message: 'Preparing…',
    );
    _addJob(job);

    try {
      final fileSize = await file.length();
      final fileSizeStr = _formatBytes(fileSize);
      String savedPath = filePath;

      if ([
        'mp4',
        'mkv',
        'avi',
        'mov',
        'webm',
        '3gp',
        'm4v',
        'mpg',
        'mpeg',
      ].contains(ext)) {
        _updateJob(
          job,
          indeterminate: true,
          message: 'Saving to Movies/SecuroBox…',
        );
        final asset = await PhotoManager.editor.saveVideo(
          file,
          title: fileName,
          relativePath: 'Movies/SecuroBox',
        );
        final assetFile = await asset.file;
        if (assetFile != null) savedPath = assetFile.path;
      } else if ([
        'jpg',
        'jpeg',
        'png',
        'webp',
        'gif',
        'bmp',
        'heic',
        'heif',
      ].contains(ext)) {
        _updateJob(
          job,
          indeterminate: true,
          message: 'Saving to Pictures/SecuroBox…',
        );
        final asset = await PhotoManager.editor.saveImage(
          await file.readAsBytes(),
          title: fileName,
          relativePath: 'Pictures/SecuroBox',
          filename: fileName,
        );
        final assetFile = await asset.file;
        if (assetFile != null) savedPath = assetFile.path;
      } else if (Platform.isAndroid) {
        final folder =
            ['mp3', 'wav', 'aac', 'ogg', 'm4a', 'flac', 'opus'].contains(ext)
            ? 'Music/SecuroBox'
            : 'Download/SecuroBox';
        final dir = Directory('/storage/emulated/0/$folder');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        final newFile = File('${dir.path}/$fileName.$ext');
        _updateJob(
          job,
          progress: 0,
          indeterminate: false,
          message: 'Copying to $folder…',
        );
        await _streamCopy(file, newFile, fileSize, job);
        savedPath = newFile.path;
      } else {
        _updateJob(job, indeterminate: true, message: 'Opening share sheet…');
        await SharePlus.instance.share(
          ShareParams(files: [XFile(filePath)], text: fileName),
        );
      }

      _updateJob(
        job,
        progress: 1.0,
        indeterminate: false,
        status: _JobStatus.success,
        message: 'Saved · $fileSizeStr',
      );

      await _addToDownloadHistory(
        fileName: fileName,
        filePath: savedPath,
        fileSize: fileSizeStr,
      );

      Future.delayed(const Duration(milliseconds: 1800), () {
        if (mounted) _removeJob(job);
      });
    } catch (e) {
      _updateJob(
        job,
        status: _JobStatus.failed,
        indeterminate: false,
        message: 'Failed',
        error: e.toString(),
      );
      Future.delayed(const Duration(seconds: 6), () {
        if (mounted) _removeJob(job);
      });
    }
  }

  Future<void> _streamCopy(
    File source,
    File dest,
    int total,
    _ActiveJob job,
  ) async {
    final sink = dest.openWrite();
    int read = 0;
    try {
      await for (final chunk in source.openRead()) {
        sink.add(chunk);
        read += chunk.length;
        if (total > 0) {
          final now = DateTime.now();
          if (now.difference(_lastProgressTick).inMilliseconds >= 80 ||
              read >= total) {
            _lastProgressTick = now;
            _updateJob(
              job,
              progress: (read / total).clamp(0.0, 1.0),
              message: '${_formatBytes(read)} / ${_formatBytes(total)}',
            );
          }
        }
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
  }

  void _addJob(_ActiveJob job) {
    if (!mounted) return;
    setState(() => _activeJobs.add(job));
  }

  void _updateJob(
    _ActiveJob job, {
    double? progress,
    bool? indeterminate,
    _JobStatus? status,
    String? message,
    String? error,
  }) {
    if (!mounted) return;
    setState(() {
      if (progress != null) job.progress = progress;
      if (indeterminate != null) job.indeterminate = indeterminate;
      if (status != null) job.status = status;
      if (message != null) job.message = message;
      if (error != null) job.error = error;
    });
  }

  void _removeJob(_ActiveJob job) {
    if (!mounted) return;
    setState(() => _activeJobs.remove(job));
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
      'm2ts',
    ].contains(ext)) {
      return 'Video';
    } else if ([
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
      'dts',
    ].contains(ext)) {
      return 'Audio';
    } else if ([
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
      'dng',
    ].contains(ext)) {
      return 'Image';
    } else if ([
      'pdf',
      'doc',
      'docx',
      'txt',
      'rtf',
      'odt',
      'ppt',
      'pptx',
      'xls',
      'xlsx',
      'csv',
      'md',
      'markdown',
      'html',
      'htm',
      'epub',
      'mobi',
      'azw3',
      'tex',
      'latex',
      'xml',
      'json',
      'yaml',
      'yml',
    ].contains(ext)) {
      return 'Document';
    } else if ([
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
      'cab',
    ].contains(ext)) {
      return 'Archive';
    } else if ([
      'exe',
      'msi',
      'apk',
      'dmg',
      'app',
      'bat',
      'sh',
      'bash',
    ].contains(ext)) {
      return 'Executable';
    } else if ([
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
      'cs',
    ].contains(ext)) {
      return 'Code';
    } else {
      return 'File';
    }
  }

  Future<void> _shareVideo(DownloadItem item) async {
    String pathToShare = item.videoPath;

    if (!await File(pathToShare).exists()) {
      final fallback = await _findInGalleryByName(item.fileName);
      if (fallback == null) {
        if (!mounted) return;
        FlushBarHelper.flushBarErrorMessage(
          'File not found in gallery. It may have been moved or deleted.',
          context,
        );
        return;
      }
      pathToShare = fallback;
    }

    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(pathToShare)],
          text: 'Check out this ${getFileTypeLabel(pathToShare)}!',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      FlushBarHelper.flushBarErrorMessage(
        'Failed to share: ${e.toString()}',
        context,
      );
    }
  }

  Future<String?> _findInGalleryByName(String fileName) async {
    if (!Platform.isAndroid || fileName.isEmpty) return null;
    const folders = [
      '/storage/emulated/0/Movies/SecuroBox',
      '/storage/emulated/0/Pictures/SecuroBox',
      '/storage/emulated/0/Music/SecuroBox',
      '/storage/emulated/0/Download/SecuroBox',
      '/storage/emulated/0/Movies/SecureVideo',
      '/storage/emulated/0/Pictures/SecureImages',
      '/storage/emulated/0/Music/SecureVideo',
      '/storage/emulated/0/Download/SecureVideo',
    ];
    for (final dir in folders) {
      final candidate = File('$dir/$fileName');
      if (await candidate.exists()) return candidate.path;
    }
    return null;
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
    if (!mounted) return;
    FlushBarHelper.flushBarSuccessMessage('History refreshed', context);
  }

  Future<void> _clearDownloads() async {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: LiquidColors.cardGradient,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: LiquidColors.error.withValues(alpha: 0.3),
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
                        LiquidColors.error.withValues(alpha: 0.3),
                        LiquidColors.warning.withValues(alpha: 0.2),
                      ],
                      center: Alignment.center,
                      radius: 0.8,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: LiquidColors.error.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.delete_forever_rounded,
                      color: LiquidColors.error,
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Clear export history?',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: LiquidColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Only this list is cleared. Files already saved to your device stay where they are, and your vault is not touched.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: LiquidColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          side: BorderSide(
                            color: LiquidColors.textTertiary,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: LiquidColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(dialogContext);
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.remove(
                            VaultContext.instance.downloadHistoryKey,
                          );
                          if (!mounted) return;
                          setState(() {
                            _downloads.clear();
                          });
                          FlushBarHelper.flushBarSuccessMessage(
                            'History cleared',
                            context,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: LiquidColors.error,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
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
      bottomNavigationBar: const LiquidBottomNav(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 6,
        leadingWidth: 58,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: _AppBarAction(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back',
            onTap: () => Navigator.pop(context),
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [LiquidColors.backgroundDeep, LiquidColors.backgroundMid],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    LiquidColors.accentBlue,
                    LiquidColors.accentPurple,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(11),
                boxShadow: [
                  BoxShadow(
                    color: LiquidColors.accentBlue.withValues(alpha: 0.3),
                    blurRadius: 10,
                    spreadRadius: -2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.history_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'History',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: LiquidColors.textPrimary,
                      letterSpacing: 0.2,
                    ),
                  ),
                  Text(
                    'Files you exported to this device',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: LiquidColors.textTertiary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          _AppBarAction(
            icon: Icons.delete_outline_rounded,
            tooltip: _downloads.isEmpty ? 'Nothing to clear' : 'Clear history',
            color: LiquidColors.error,
            onTap: _downloads.isEmpty ? null : _clearDownloads,
          ),
          const SizedBox(width: 12),
        ],
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
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              children: [
                if (_activeJobs.isNotEmpty) _buildActiveSection(),
                if (!_isLoading && _downloads.isNotEmpty) _buildStatsStrip(),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, anim) =>
                        FadeTransition(opacity: anim, child: child),
                    child: _isLoading && _downloads.isEmpty
                        ? KeyedSubtree(
                            key: const ValueKey('loading'),
                            child: _buildLoadingState(),
                          )
                        : _downloads.isEmpty
                        ? KeyedSubtree(
                            key: const ValueKey('empty'),
                            child: LiquidEmptyState(
                              icon: Icons.download_done_outlined,
                              title: 'Nothing exported yet',
                              subtitle:
                                  'Open a file from your library and tap the download icon to save a copy to your device. Saved files appear here.',
                              buttonText: 'Close',
                              onButtonPressed: () =>
                                  Navigator.of(context).pop(),
                              iconColor: LiquidColors.success,
                            ),
                          )
                        : KeyedSubtree(
                            key: const ValueKey('list'),
                            child: _buildDownloadList(),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _SkeletonCard(delayMs: i * 80),
      ),
    );
  }

  Widget _buildActiveSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              LiquidColors.accentBlue.withValues(alpha: 0.14),
              LiquidColors.accentPurple.withValues(alpha: 0.06),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: LiquidColors.accentBlue.withValues(alpha: 0.25),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color: LiquidColors.accentBlue,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'SAVING TO YOUR DEVICE',
                  style: TextStyle(
                    color: LiquidColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: LiquidColors.accentBlue.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_activeJobs.length}',
                    style: TextStyle(
                      color: LiquidColors.accentBlue,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Decrypting from your vault and copying into the gallery / file manager.',
              style: TextStyle(
                color: LiquidColors.textTertiary,
                fontSize: 11,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            for (final job in _activeJobs)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ActiveJobCard(job: job),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsStrip() {
    int totalBytes = 0;
    int withSize = 0;
    for (final d in _downloads) {
      final bytes = _parseSize(d.fileSize);
      if (bytes > 0) {
        totalBytes += bytes;
        withSize++;
      }
    }
    final sizeText = withSize > 0 ? _formatBytes(totalBytes) : '—';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildExplainerBanner(),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  LiquidColors.success.withValues(alpha: 0.14),
                  LiquidColors.accentBlue.withValues(alpha: 0.06),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: LiquidColors.success.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _StatTile(
                    icon: Icons.folder_open_rounded,
                    color: LiquidColors.success,
                    label: 'Items saved',
                    value: '${_downloads.length}',
                  ),
                ),
                Container(
                  width: 1,
                  height: 28,
                  color: LiquidColors.textPrimary.withValues(alpha: 0.08),
                ),
                Expanded(
                  child: _StatTile(
                    icon: Icons.storage_rounded,
                    color: LiquidColors.accentBlue,
                    label: 'Total size',
                    value: sizeText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExplainerBanner() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: LiquidColors.textPrimary.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: LiquidColors.textPrimary.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: LiquidColors.accentBlue.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.info_outline_rounded,
              color: LiquidColors.accentBlue,
              size: 17,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'These files now live on your device',
                  style: TextStyle(
                    color: LiquidColors.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Each item here was decrypted out of your vault and saved to the gallery or file manager. The encrypted original stays inside SecuroBox.',
                  style: TextStyle(
                    color: LiquidColors.textSecondary,
                    fontSize: 11,
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

  int _parseSize(String text) {
    final match = RegExp(
      r'([\d.]+)\s*(B|KB|MB|GB|TB|PB)',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) return 0;
    final value = double.tryParse(match.group(1) ?? '') ?? 0;
    final unit = (match.group(2) ?? 'B').toUpperCase();
    const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
    final idx = units.indexOf(unit);
    if (idx < 0) return value.toInt();
    return (value * (1 << (idx * 10))).toInt();
  }

  Widget _buildDownloadList() {
    return RefreshIndicator(
      backgroundColor: LiquidColors.backgroundLight,
      color: LiquidColors.accentBlue,
      strokeWidth: 2.5,
      onRefresh: _refreshDownloads,
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.symmetric(
          horizontal: context.contentInset(phone: 16),
        ),
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
            onShare: () => _shareVideo(download),
          );
        },
      ),
    );
  }
}

class _AppBarAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? color;

  const _AppBarAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tint = color ?? LiquidColors.textPrimary;
    final disabled = onTap == null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 40,
              decoration: BoxDecoration(
                color: disabled
                    ? LiquidColors.textPrimary.withValues(alpha: 0.03)
                    : LiquidColors.textPrimary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: disabled
                      ? LiquidColors.textPrimary.withValues(alpha: 0.05)
                      : LiquidColors.textPrimary.withValues(alpha: 0.08),
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: disabled ? tint.withValues(alpha: 0.3) : tint,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _StatTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: LiquidColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF8A8FA3),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SkeletonCard extends StatefulWidget {
  final int delayMs;

  const _SkeletonCard({required this.delayMs});

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _controller.repeat();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) {
        final t = _controller.value;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: LiquidColors.textPrimary.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: LiquidColors.textPrimary.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            children: [
              _box(width: 56, height: 56, radius: 14, t: t),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _box(width: double.infinity, height: 14, radius: 4, t: t),
                    const SizedBox(height: 8),
                    _box(width: 110, height: 10, radius: 4, t: t),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _box(width: 36, height: 36, radius: 10, t: t),
              const SizedBox(width: 6),
              _box(width: 36, height: 36, radius: 10, t: t),
            ],
          ),
        );
      },
    );
  }

  Widget _box({
    required double width,
    required double height,
    required double radius,
    required double t,
  }) {
    final shift = (t * 2 - 1).clamp(-1.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: width,
        height: height,
        color: LiquidColors.textPrimary.withValues(alpha: 0.05),
        foregroundDecoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(shift - 0.3, 0),
            end: Alignment(shift + 0.3, 0),
            colors: [
              LiquidColors.textPrimary.withValues(alpha: 0.0),
              LiquidColors.textPrimary.withValues(alpha: 0.08),
              LiquidColors.textPrimary.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
      ),
    );
  }
}

class _ActiveJobCard extends StatelessWidget {
  final _ActiveJob job;

  const _ActiveJobCard({required this.job});

  @override
  Widget build(BuildContext context) {
    final isFailed = job.status == _JobStatus.failed;
    final isSuccess = job.status == _JobStatus.success;
    final tint = isFailed
        ? LiquidColors.error
        : isSuccess
        ? LiquidColors.success
        : job.color;
    final pct = (job.progress.clamp(0.0, 1.0) * 100).round();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: LiquidColors.textPrimary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tint.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(job.icon, color: tint, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: LiquidColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: job.color.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            job.typeLabel.toUpperCase(),
                            style: TextStyle(
                              color: job.color,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isFailed
                                ? (job.error?.isNotEmpty == true
                                      ? job.error!
                                      : 'Failed')
                                : job.message,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isFailed
                                  ? LiquidColors.error
                                  : LiquidColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _statusBadge(tint, isFailed, isSuccess, pct),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 4,
              child: LinearProgressIndicator(
                value: isFailed
                    ? 0
                    : isSuccess
                    ? 1
                    : (job.indeterminate ? null : job.progress),
                backgroundColor: LiquidColors.textPrimary.withValues(
                  alpha: 0.06,
                ),
                valueColor: AlwaysStoppedAnimation(tint),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(Color tint, bool isFailed, bool isSuccess, int pct) {
    if (isFailed) {
      return Icon(
        Icons.error_outline_rounded,
        color: LiquidColors.error,
        size: 18,
      );
    }
    if (isSuccess) {
      return Icon(
        Icons.check_circle_rounded,
        color: LiquidColors.success,
        size: 20,
      );
    }
    if (job.indeterminate) {
      return SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: tint),
      );
    }
    return Text(
      '$pct%',
      style: TextStyle(color: tint, fontSize: 12, fontWeight: FontWeight.w800),
    );
  }
}

enum _JobStatus { running, success, failed }

class _ActiveJob {
  final String id;
  final String fileName;
  final IconData icon;
  final Color color;
  final String typeLabel;
  double progress = 0;
  bool indeterminate = false;
  _JobStatus status = _JobStatus.running;
  String message;
  String? error;

  _ActiveJob({
    required this.id,
    required this.fileName,
    required this.icon,
    required this.color,
    required this.typeLabel,
    this.message = 'Starting…',
  });
}

class _JobKind {
  final String label;
  final IconData icon;
  final Color color;

  const _JobKind(this.label, this.icon, this.color);

  static _JobKind from(String path) {
    final dot = path.lastIndexOf('.');
    final ext = dot < 0 ? '' : path.substring(dot + 1).toLowerCase();
    if (const {
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
      'm2ts',
    }.contains(ext)) {
      return _JobKind('Video', Icons.movie_outlined, LiquidColors.accentBlue);
    }
    if (const {
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
      'dts',
    }.contains(ext)) {
      return _JobKind(
        'Audio',
        Icons.audiotrack_rounded,
        LiquidColors.accentPurple,
      );
    }
    if (const {
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
      'dng',
    }.contains(ext)) {
      return _JobKind('Photo', Icons.image_outlined, LiquidColors.success);
    }
    if (const {
      'pdf',
      'doc',
      'docx',
      'txt',
      'rtf',
      'odt',
      'ppt',
      'pptx',
      'xls',
      'xlsx',
      'csv',
      'md',
      'markdown',
      'html',
      'htm',
      'epub',
      'mobi',
      'azw3',
      'tex',
      'latex',
      'xml',
      'json',
      'yaml',
      'yml',
    }.contains(ext)) {
      return _JobKind(
        'Document',
        Icons.description_outlined,
        LiquidColors.accentOrange,
      );
    }
    return const _JobKind(
      'File',
      Icons.insert_drive_file_outlined,
      Color(0xFF9CA3AF),
    );
  }
}
