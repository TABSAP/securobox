import 'dart:async';

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

  // Search related variables
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearching = false;
  String _searchText = '';
  int _currentSearchIndex = 0;
  int _totalSearchResults = 0;
  final GlobalKey _searchFieldKey = GlobalKey();
  Timer? _searchDebounceTimer;
  bool _isSearchInProgress = false;

  // Book reading preferences
  bool _isDoubleTapped = false;
  PdfPageLayoutMode _pageLayoutMode = PdfPageLayoutMode.continuous;
  PdfScrollDirection _scrollDirection = PdfScrollDirection.vertical;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    _checkFileAndLoadPDF();
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _pdfViewerController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
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

  void _toggleLayoutMode() {
    setState(() {
      if (_pageLayoutMode == PdfPageLayoutMode.continuous) {
        _pageLayoutMode = PdfPageLayoutMode.single;
      } else {
        _pageLayoutMode = PdfPageLayoutMode.continuous;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_pageLayoutMode == PdfPageLayoutMode.continuous
            ? 'Continuous scroll mode'
            : 'Single page mode'),
        duration: const Duration(seconds: 1),
        backgroundColor: const Color(0xFF4788FF),
      ),
    );
  }

  void _toggleScrollDirection() {
    setState(() {
      if (_scrollDirection == PdfScrollDirection.vertical) {
        _scrollDirection = PdfScrollDirection.horizontal;
      } else {
        _scrollDirection = PdfScrollDirection.vertical;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_scrollDirection == PdfScrollDirection.vertical
            ? 'Vertical scrolling'
            : 'Horizontal scrolling'),
        duration: const Duration(seconds: 1),
        backgroundColor: const Color(0xFF4788FF),
      ),
    );
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _clearSearch();
      } else {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _searchText = '';
    _currentSearchIndex = 0;
    _totalSearchResults = 0;
    _isSearchInProgress = false;
    _pdfViewerController.clearSelection();
  }

  void _performSearchWithDebounce() {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (_searchController.text.trim().isEmpty) {
        _clearSearch();
        return;
      }

      setState(() {
        _searchText = _searchController.text.trim();
        _isSearchInProgress = true;
      });

      // Perform search using the PDF viewer controller
      _pdfViewerController.searchText(_searchText);
    });
  }

  void _performSearch() {
    if (_searchController.text.trim().isEmpty) {
      _clearSearch();
      return;
    }

    setState(() {
      _searchText = _searchController.text.trim();
      _isSearchInProgress = true;
    });

    // Perform search using the PDF viewer controller
    _pdfViewerController.searchText(_searchText);
  }

  void _goToNextSearchResult() {
    if (_totalSearchResults > 0) {
      // Simply perform search again to go to next result
      _pdfViewerController.searchText(_searchText);
    }
  }

  void _goToPreviousSearchResult() {
    if (_totalSearchResults > 0) {
      // Simply perform search again to go to previous result
      _pdfViewerController.searchText(_searchText);
    }
  }

  void _goToPage() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: _isDarkMode ? const Color(0xFF1A1A3E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.shade300,
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
        title: _isSearching
            ? _buildSearchBar()
            : Column(
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
          if (_isSearching) ...[
            if (_isSearchInProgress)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4788FF)),
                  ),
                ),
              )
            else if (_totalSearchResults > 0)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4788FF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_currentSearchIndex/$_totalSearchResults',
                  style: TextStyle(
                    color: const Color(0xFF4788FF),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            IconButton(
              icon: Icon(
                Icons.arrow_upward,
                color: _totalSearchResults > 0
                    ? (_isDarkMode ? Colors.white : Colors.black)
                    : Colors.grey,
                size: 20,
              ),
              onPressed: _totalSearchResults > 0 ? _goToPreviousSearchResult : null,
              tooltip: 'Previous Result',
            ),
            IconButton(
              icon: Icon(
                Icons.arrow_downward,
                color: _totalSearchResults > 0
                    ? (_isDarkMode ? Colors.white : Colors.black)
                    : Colors.grey,
                size: 20,
              ),
              onPressed: _totalSearchResults > 0 ? _goToNextSearchResult : null,
              tooltip: 'Next Result',
            ),
            IconButton(
              icon: Icon(
                Icons.close,
                color: _isDarkMode ? Colors.white : Colors.black,
              ),
              onPressed: _toggleSearch,
              tooltip: 'Close Search',
            ),
          ] else ...[
            IconButton(
              icon: Icon(
                Icons.search,
                color: _isDarkMode ? Colors.white : Colors.black,
              ),
              onPressed: _toggleSearch,
              tooltip: 'Search in PDF',
            ),
            IconButton(
              icon: Icon(
                _pageLayoutMode == PdfPageLayoutMode.continuous
                    ? Icons.view_stream
                    : Icons.view_compact,
                color: _isDarkMode ? Colors.white : Colors.black,
              ),
              onPressed: _toggleLayoutMode,
              tooltip: 'Toggle Layout',
            ),
            IconButton(
              icon: Icon(
                _scrollDirection == PdfScrollDirection.vertical
                    ? Icons.swap_vert
                    : Icons.swap_horiz,
                color: _isDarkMode ? Colors.white : Colors.black,
              ),
              onPressed: _toggleScrollDirection,
              tooltip: 'Toggle Scroll Direction',
            ),
            IconButton(
              icon: Icon(
                _isDarkMode ? Icons.light_mode : Icons.dark_mode,
                color: _isDarkMode ? Colors.amber : Colors.black,
              ),
              onPressed: _toggleTheme,
              tooltip: 'Toggle Theme',
            ),
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                color: _isDarkMode ? Colors.white : Colors.black,
              ),
              onSelected: (value) => _handleMenuSelection(value),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'info',
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: _isDarkMode ? Colors.white : Colors.black,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'File Info',
                        style: TextStyle(
                          color: _isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: GestureDetector(
        onDoubleTap: () {
          setState(() {
            _isDoubleTapped = !_isDoubleTapped;
            if (_isDoubleTapped) {
              _pageLayoutMode = PdfPageLayoutMode.single;
            } else {
              _pageLayoutMode = PdfPageLayoutMode.continuous;
            }
          });
        },
        child: _buildBody(),
      ),
      bottomNavigationBar: _isLoading || _hasError ? null : _buildBottomBar(),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      key: _searchFieldKey,
      height: 45,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF141432) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: const Color(0xFF4788FF).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(Icons.search, color: Color(0xFF4788FF), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: TextStyle(
                color: _isDarkMode ? Colors.white : Colors.black,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Search in document...',
                hintStyle: TextStyle(
                  color: _isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400,
                  fontSize: 14,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (value) {
                if (value.isEmpty) {
                  _clearSearch();
                } else {
                  _performSearchWithDebounce();
                }
              },
              onSubmitted: (value) => _performSearch(),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.clear,
                size: 18,
                color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              onPressed: () {
                _searchController.clear();
                _clearSearch();
                _searchFocusNode.requestFocus();
              },
              padding: EdgeInsets.zero,
            ),
        ],
      ),
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
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.3),
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
        pageLayoutMode: _pageLayoutMode,
        scrollDirection: _scrollDirection,
        canShowPaginationDialog: true,
        canShowScrollHead: true,
        enableDoubleTapZooming: true,
        enableTextSelection: true,
        maxZoomLevel: 5.0,
        initialZoomLevel: 1.0,
        onDocumentLoaded: (PdfDocumentLoadedDetails details) {
          if (mounted) {
            setState(() {
              _totalPages = details.document.pages.count;
            });

            // Smooth initial animation
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) {
                _pdfViewerController.jumpToPage(1);
              }
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
        onTextSelectionChanged: (PdfTextSelectionChangedDetails details) {
          // Handle text selection if needed
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
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(
                  color: Colors.red.withOpacity(0.3),
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
            color: _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.shade300,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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
                          color: const Color(0xFF4788FF).withOpacity(0.3),
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
              color: _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.shade300,
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
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.red.withOpacity(0.3),
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