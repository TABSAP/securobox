import 'package:flutter/material.dart';
import 'dart:io';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PDFReaderScreen extends StatefulWidget {
  final String filePath;
  final String fileName;

  const PDFReaderScreen({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  State<PDFReaderScreen> createState() => _PDFReaderScreenState();
}

class _PDFReaderScreenState extends State<PDFReaderScreen> {
  late PdfViewerController _pdfViewerController;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  int _currentPage = 1;
  int _totalPages = 1;
  double _zoomLevel = 1.0;
  bool _isDarkMode = true;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    _checkFileAndLoadPDF();
  }

  Future<void> _checkFileAndLoadPDF() async {
    try {
      final file = File(widget.filePath);
      bool exists = await file.exists();

      if (!exists) {
        setState(() {
          _hasError = true;
          _errorMessage = 'PDF file not found';
          _isLoading = false;
        });
        return;
      }

      final length = await file.length();
      if (length == 0) {
        setState(() {
          _hasError = true;
          _errorMessage = 'PDF file is empty (0 bytes)';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Error loading PDF: $e';
        _isLoading = false;
      });
    }
  }

  void _zoomIn() {
    setState(() {
      _zoomLevel += 0.2;
      _pdfViewerController.zoomLevel = _zoomLevel;
    });
  }

  void _zoomOut() {
    if (_zoomLevel > 0.5) {
      setState(() {
        _zoomLevel -= 0.2;
        _pdfViewerController.zoomLevel = _zoomLevel;
      });
    }
  }

  void _resetZoom() {
    setState(() {
      _zoomLevel = 1.0;
      _pdfViewerController.zoomLevel = _zoomLevel;
    });
  }

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  void _goToPage() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: _isDarkMode ? const Color(0xFF1A1A3E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: _isDarkMode ? Colors.white.withValues(alpha: .1) : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Go to Page',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Enter page number (1-$_totalPages)',
                style: TextStyle(
                  color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                keyboardType: TextInputType.number,
                style: TextStyle(
                  color: _isDarkMode ? Colors.white : Colors.black,
                ),
                decoration: InputDecoration(
                  hintText: 'Page number',
                  hintStyle: TextStyle(
                    color: _isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: _isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Color(0xFF4788FF),
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: _isDarkMode ? const Color(0xFF141432) : Colors.grey.shade100,
                ),
                onSubmitted: (value) {
                  final page = int.tryParse(value);
                  if (page != null && page >= 1 && page <= _totalPages) {
                    _pdfViewerController.jumpToPage(page);
                    Navigator.pop(context);
                  }
                },
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: _isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                          ),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // Implementation would need a controller
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4788FF),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Go',
                        style: TextStyle(color: Colors.white),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkMode ? const Color(0xFF0A0A1F) : Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: _isDarkMode ? const Color(0xFF1A1A3E) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_outlined,
            color: _isDarkMode ? Colors.white : Colors.black,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.fileName.length > 30
                  ? '${widget.fileName.substring(0, 30)}...'
                  : widget.fileName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _isDarkMode ? Colors.white : Colors.black,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'PDF Reader',
              style: TextStyle(
                fontSize: 12,
                color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.search,
              color: _isDarkMode ? Colors.white : Colors.black,
            ),
            onPressed: () {
              // Search functionality
            },
          ),
          IconButton(
            icon: Icon(
              _isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: _isDarkMode ? Colors.amber : Colors.black,
            ),
            onPressed: _toggleTheme,
          ),
          // PopupMenuButton<String>(
          //
          //   icon: Icon(
          //     Icons.more_vert,
          //     color: _isDarkMode ? Colors.white : Colors.black,
          //   ),
          //   onSelected: (value) {
          //     _handleMenuSelection(value);
          //   },
          //   itemBuilder: (context) => [
          //     PopupMenuItem(
          //       textStyle: TextStyle(
          //         //backgroundColor: _isDarkMode ? Colors.white : Colors.black,
          //         //color: _isDarkMode ? Colors.white : Colors.black,
          //       ),
          //       value: 'bookmark',
          //       child: Row(
          //         children: [
          //           Icon(
          //             Icons.bookmark_border,
          //             size: 20,
          //             //color: _isDarkMode ? Colors.white : Colors.black,
          //           ),
          //           const SizedBox(width: 8),
          //           Text(
          //             'Add Bookmark',
          //             style: TextStyle(
          //               //color: _isDarkMode ? Colors.white : Colors.black,
          //             ),
          //           ),
          //         ],
          //       ),
          //     ),
          //     PopupMenuItem(
          //       value: 'print',
          //       child: Row(
          //         children: [
          //           Icon(
          //             Icons.print,
          //             size: 20,
          //             //color: _isDarkMode ? Colors.white : Colors.black,
          //           ),
          //           const SizedBox(width: 8),
          //           Text(
          //             'Print',
          //             style: TextStyle(
          //               //color: _isDarkMode ? Colors.white : Colors.black,
          //             ),
          //           ),
          //         ],
          //       ),
          //     ),
          //     PopupMenuItem(
          //       value: 'share',
          //       child: Row(
          //         children: [
          //           Icon(
          //             Icons.share,
          //             size: 20,
          //             //color: _isDarkMode ? Colors.white : Colors.black,
          //           ),
          //           const SizedBox(width: 8),
          //           Text(
          //             'Share PDF',
          //             style: TextStyle(
          //               //color: _isDarkMode ? Colors.white : Colors.black,
          //             ),
          //           ),
          //         ],
          //       ),
          //     ),
          //     PopupMenuItem(
          //       value: 'info',
          //       child: Row(
          //         children: [
          //           Icon(
          //             Icons.info_outline,
          //             size: 20,
          //             //color: _isDarkMode ? Colors.white : Colors.black,
          //           ),
          //           const SizedBox(width: 8),
          //           Text(
          //             'File Info',
          //             style: TextStyle(
          //               //color: _isDarkMode ? Colors.white : Colors.black,
          //             ),
          //           ),
          //         ],
          //       ),
          //     ),
          //   ],
          // ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _isLoading || _hasError ? null : _buildBottomBar(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Loading PDF...',
              style: TextStyle(
                fontSize: 16,
                color: _isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Preparing document for viewing',
              style: TextStyle(
                fontSize: 12,
                color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: .3),
                    width: 2,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.error_outline_rounded,
                    color: Colors.red,
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Unable to Load PDF',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _checkFileAndLoadPDF,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Try Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4788FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('Go Back'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: _isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    try {
      return SfPdfViewer.file(
        File(widget.filePath),
        controller: _pdfViewerController,
        pageLayoutMode: PdfPageLayoutMode.single,
        scrollDirection: PdfScrollDirection.vertical,
        canShowPaginationDialog: true,
        canShowScrollHead: true,
        onDocumentLoaded: (PdfDocumentLoadedDetails details) {
          if (mounted) {
            setState(() {
              _totalPages = details.document.pages.count;
            });
          }
        },
        onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
          if (mounted) {
            setState(() {
              _hasError = true;
              _errorMessage = 'Failed to load PDF: ${details.error}';
            });
          }
        },
        onPageChanged: (PdfPageChangedDetails details) {
          if (mounted) {
            setState(() {
              _currentPage = details.newPageNumber;
            });
          }
        },
      );
    } catch (e) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(
                  color: Colors.red.withValues(alpha: .3),
                  width: 2,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.error_outline_rounded,
                  color: Colors.red,
                  size: 40,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Error Loading PDF',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'An unexpected error occurred while loading the PDF file.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1A1A3E) : Colors.white,
        border: Border(
          top: BorderSide(
            color: _isDarkMode ? Colors.white.withValues(alpha: .1) : Colors.grey.shade300,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Zoom controls
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: _isDarkMode ? const Color(0xFF141432) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.remove,
                      size: 18,
                      color: _isDarkMode ? Colors.white : Colors.black,
                    ),
                    onPressed: _zoomOut,
                    padding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isDarkMode ? const Color(0xFF141432) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${(_zoomLevel * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: _isDarkMode ? const Color(0xFF141432) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.add,
                      size: 18,
                      color: _isDarkMode ? Colors.white : Colors.black,
                    ),
                    onPressed: _zoomIn,
                    padding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: _isDarkMode ? const Color(0xFF141432) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.fullscreen_exit,
                      size: 18,
                      color: _isDarkMode ? Colors.white : Colors.black,
                    ),
                    onPressed: _resetZoom,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Page navigation
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: _isDarkMode ? const Color(0xFF141432) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.first_page,
                      size: 18,
                      color: _isDarkMode ? Colors.white : Colors.black,
                    ),
                    onPressed: () {
                      _pdfViewerController.jumpToPage(1);
                    },
                    padding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: _isDarkMode ? const Color(0xFF141432) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.navigate_before,
                      size: 18,
                      color: _isDarkMode ? Colors.white : Colors.black,
                    ),
                    onPressed: () {
                      if (_currentPage > 1) {
                        _pdfViewerController.jumpToPage(_currentPage - 1);
                      }
                    },
                    padding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(width: 5),

                // Page indicator with go-to functionality
                GestureDetector(
                  onTap: _goToPage,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4788FF),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4788FF).withValues(alpha: .3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      '$_currentPage / $_totalPages',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 5),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: _isDarkMode ? const Color(0xFF141432) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.navigate_next,
                      size: 18,
                      color: _isDarkMode ? Colors.white : Colors.black,
                    ),
                    onPressed: () {
                      if (_currentPage < _totalPages) {
                        _pdfViewerController.jumpToPage(_currentPage + 1);
                      }
                    },
                    padding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: _isDarkMode ? const Color(0xFF141432) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.last_page,
                      size: 18,
                      color: _isDarkMode ? Colors.white : Colors.black,
                    ),
                    onPressed: () {
                      _pdfViewerController.jumpToPage(_totalPages);
                    },
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'bookmark':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bookmark added for page $_currentPage'),
            backgroundColor: const Color(0xFF4788FF),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
        break;
      case 'print':
      // Print functionality would go here
        break;
      case 'share':
      // Share functionality would go here
        break;
      case 'info':
        _showFileInfo();
        break;
    }
  }

  void _showFileInfo() async {
    try {
      final file = File(widget.filePath);
      bool exists = await file.exists();
      final size = exists ? await file.length() : 0;
      final modified = exists ? await file.lastModified() : DateTime.now();

      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: _isDarkMode ? const Color(0xFF1A1A3E) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: _isDarkMode ? Colors.white.withValues(alpha: .1) : Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: .3),
                          width: 1,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.picture_as_pdf,
                          color: Colors.red,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        widget.fileName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _isDarkMode ? Colors.white : Colors.black,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildInfoRow('File Path:', widget.filePath),
                const SizedBox(height: 12),
                _buildInfoRow('File Size:', '${(size / (1024 * 1024)).toStringAsFixed(2)} MB'),
                const SizedBox(height: 12),
                _buildInfoRow('Total Pages:', '$_totalPages pages'),
                const SizedBox(height: 12),
                _buildInfoRow('Modified:', '${modified.day}/${modified.month}/${modified.year}'),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4788FF),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: _isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.w400,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}