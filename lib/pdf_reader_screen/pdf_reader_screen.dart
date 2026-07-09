import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player_app/widgets/app_loader.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import 'package:video_player_app/utils/liquid_circular_progress.dart';
import 'package:video_player_app/utils/liquid_colors.dart';

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
  late final PdfViewerController _controller;
  bool _loading = true;
  bool _hasError = false;
  String _errorMessage = '';

  int _currentPage = 1;
  int _totalPages = 1;

  PdfPageLayoutMode _layout = PdfPageLayoutMode.continuous;
  PdfScrollDirection _scroll = PdfScrollDirection.vertical;

  bool _searching = false;
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _searchDebounce;
  String _lastQuery = '';
  PdfTextSearchResult? _searchResult;

  @override
  void initState() {
    super.initState();
    _controller = PdfViewerController();
    _checkFile();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchResult?.removeListener(_onSearchUpdate);
    _searchResult?.clear();
    _controller.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _checkFile() async {
    setState(() {
      _loading = true;
      _hasError = false;
      _errorMessage = '';
    });
    try {
      final file = File(widget.filePath);
      if (widget.filePath.isEmpty || !await file.exists()) {
        _fail('This PDF could not be found.');
        return;
      }
      if (await file.length() == 0) {
        _fail('This PDF file is empty.');
        return;
      }
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      _fail('Couldn\'t open this PDF.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _hasError = true;
      _errorMessage = message;
      _loading = false;
    });
  }

  void _jump(int page) {
    final p = page.clamp(1, _totalPages);
    _controller.jumpToPage(p);
  }

  Future<void> _goToPageDialog() async {
    final ctrl = TextEditingController(text: '$_currentPage');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LiquidColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Go to page',
            style: TextStyle(
                color: LiquidColors.textPrimary, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Page 1 – $_totalPages',
                style: TextStyle(color: LiquidColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              style: TextStyle(color: LiquidColors.textPrimary),
              cursorColor: LiquidColors.accentBlue,
              decoration: InputDecoration(
                hintText: 'Page number',
                hintStyle: TextStyle(color: LiquidColors.textTertiary),
              ),
              onSubmitted: (v) => Navigator.pop(ctx, int.tryParse(v.trim())),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: LiquidColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(ctx, int.tryParse(ctrl.text.trim())),
            style: ElevatedButton.styleFrom(
              backgroundColor: LiquidColors.accentBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Go'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result != null && result >= 1 && result <= _totalPages) {
      _controller.jumpToPage(result);
    }
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (_searching) {
        // The screen can be popped before the frame ends, disposing the node.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _searchFocus.requestFocus();
        });
      } else {
        _clearSearch();
      }
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchCtrl.clear();
    _lastQuery = '';
    _searchResult?.removeListener(_onSearchUpdate);
    _searchResult?.clear();
    _searchResult = null;
    _controller.clearSelection();
    if (mounted) setState(() {});
  }

  void _onSearchTextChanged(String value) {
    _searchDebounce?.cancel();
    if (value.trim().isEmpty) {
      _clearSearch();
      return;
    }
    _searchDebounce =
        Timer(const Duration(milliseconds: 350), () => _runSearch());
  }

  void _runSearch() {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) {
      _clearSearch();
      return;
    }
    if (q == _lastQuery && _searchResult != null) return;
    _lastQuery = q;
    _searchResult?.removeListener(_onSearchUpdate);
    _searchResult?.clear();
    _searchResult = _controller.searchText(q);
    _searchResult!.addListener(_onSearchUpdate);
    setState(() {});
  }

  void _onSearchUpdate() {
    if (mounted) setState(() {});
  }

  void _onMenu(String value) {
    switch (value) {
      case 'continuous':
        setState(() => _layout = PdfPageLayoutMode.continuous);
        break;
      case 'single':
        setState(() => _layout = PdfPageLayoutMode.single);
        break;
      case 'vertical':
        setState(() => _scroll = PdfScrollDirection.vertical);
        break;
      case 'horizontal':
        setState(() => _scroll = PdfScrollDirection.horizontal);
        break;
      case 'info':
        _showInfo();
        break;
    }
  }

  Future<void> _showInfo() async {
    int size = 0;
    DateTime? modified;
    try {
      final f = File(widget.filePath);
      if (await f.exists()) {
        size = await f.length();
        modified = await f.lastModified();
      }
    } catch (_) {}
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LiquidColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: LiquidColors.error.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.picture_as_pdf_rounded,
                  color: LiquidColors.error, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(widget.fileName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: LiquidColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('Pages', '$_totalPages'),
            _infoRow('Size',
                size > 0 ? '${(size / 1048576).toStringAsFixed(2)} MB' : '—'),
            _infoRow(
                'Modified',
                modified == null
                    ? '—'
                    : '${modified.day}/${modified.month}/${modified.year}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close',
                style: TextStyle(color: LiquidColors.accentBlue)),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 78,
              child: Text(label,
                  style: TextStyle(
                      color: LiquidColors.textTertiary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
            Expanded(
              child: Text(value,
                  style: TextStyle(
                      color: LiquidColors.textPrimary, fontSize: 13)),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LiquidColors.backgroundDeep,
      appBar: AppBar(
        backgroundColor: LiquidColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: LiquidColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: _searching ? _searchField() : _titleBlock(),
        actions: _searching ? _searchActions() : _normalActions(),
      ),
      body: _buildBody(),
      bottomNavigationBar: (_loading || _hasError) ? null : _bottomBar(),
    );
  }

  Widget _titleBlock() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: LiquidColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          _totalPages > 1 ? '$_totalPages pages' : 'PDF document',
          style: TextStyle(color: LiquidColors.textTertiary, fontSize: 11.5),
        ),
      ],
    );
  }

  List<Widget> _normalActions() => [
        IconButton(
          tooltip: 'Search',
          icon: Icon(Icons.search_rounded, color: LiquidColors.textPrimary),
          onPressed: _toggleSearch,
        ),
        PopupMenuButton<String>(
          tooltip: 'More',
          icon: Icon(Icons.more_vert_rounded, color: LiquidColors.textPrimary),
          position: PopupMenuPosition.under,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          onSelected: _onMenu,
          itemBuilder: (ctx) => [
            _menuItem(
              _layout == PdfPageLayoutMode.continuous ? 'single' : 'continuous',
              _layout == PdfPageLayoutMode.continuous
                  ? Icons.view_agenda_outlined
                  : Icons.view_stream_rounded,
              _layout == PdfPageLayoutMode.continuous
                  ? 'Single page'
                  : 'Continuous scroll',
            ),
            _menuItem(
              _scroll == PdfScrollDirection.vertical
                  ? 'horizontal'
                  : 'vertical',
              _scroll == PdfScrollDirection.vertical
                  ? Icons.swap_horiz_rounded
                  : Icons.swap_vert_rounded,
              _scroll == PdfScrollDirection.vertical
                  ? 'Horizontal scroll'
                  : 'Vertical scroll',
            ),
            const PopupMenuDivider(),
            _menuItem('info', Icons.info_outline_rounded, 'File info'),
          ],
        ),
        const SizedBox(width: 4),
      ];

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label) =>
      PopupMenuItem<String>(
        value: value,
        child: Row(
          children: [
            Icon(icon, size: 19, color: LiquidColors.textSecondary),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(color: LiquidColors.textPrimary)),
          ],
        ),
      );

  Widget _searchField() {
    return Container(
      height: 42,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: LiquidColors.surfaceMuted,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: LiquidColors.accentBlue.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: LiquidColors.accentBlue, size: 19),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              style: TextStyle(color: LiquidColors.textPrimary, fontSize: 14),
              cursorColor: LiquidColors.accentBlue,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search in document…',
                hintStyle:
                    TextStyle(color: LiquidColors.textTertiary, fontSize: 14),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: _onSearchTextChanged,
              onSubmitted: (_) => _runSearch(),
            ),
          ),
          if (_searchCtrl.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchCtrl.clear();
                _clearSearch();
                _searchFocus.requestFocus();
              },
              child: Icon(Icons.close_rounded,
                  size: 18, color: LiquidColors.textSecondary),
            ),
        ],
      ),
    );
  }

  List<Widget> _searchActions() {
    final r = _searchResult;
    final searching = r != null && !r.isSearchCompleted;
    final count = r?.totalInstanceCount ?? 0;
    final hasResults = count > 0;
    return [
      if (searching)
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: AppLoader(size: 20),
        )
      else if (r != null && r.isSearchCompleted)
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (hasResults ? LiquidColors.accentBlue : LiquidColors.error)
                    .withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                hasResults ? '${r.currentInstanceIndex} / $count' : 'No matches',
                style: TextStyle(
                  color: hasResults ? LiquidColors.accentBlue : LiquidColors.error,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      IconButton(
        tooltip: 'Previous',
        icon: Icon(Icons.keyboard_arrow_up_rounded,
            color:
                hasResults ? LiquidColors.textPrimary : LiquidColors.textTertiary),
        onPressed: hasResults ? () => r!.previousInstance() : null,
      ),
      IconButton(
        tooltip: 'Next',
        icon: Icon(Icons.keyboard_arrow_down_rounded,
            color:
                hasResults ? LiquidColors.textPrimary : LiquidColors.textTertiary),
        onPressed: hasResults ? () => r!.nextInstance() : null,
      ),
      IconButton(
        tooltip: 'Close search',
        icon: Icon(Icons.close_rounded, color: LiquidColors.textPrimary),
        onPressed: _toggleSearch,
      ),
    ];
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const LiquidCircularProgress(size: 80),
            const SizedBox(height: 20),
            Text('Loading PDF…',
                style: TextStyle(
                    color: LiquidColors.textSecondary, fontSize: 14)),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: LiquidColors.error.withValues(alpha: 0.14),
                  border: Border.all(
                      color: LiquidColors.error.withValues(alpha: 0.4)),
                ),
                child: Icon(Icons.picture_as_pdf_rounded,
                    color: LiquidColors.error, size: 44),
              ),
              const SizedBox(height: 20),
              Text('Couldn\'t open this PDF',
                  style: TextStyle(
                      color: LiquidColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: LiquidColors.textSecondary,
                    fontSize: 13,
                    height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _checkFile,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Try again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LiquidColors.accentBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: LiquidColors.textSecondary,
                      side: BorderSide(color: LiquidColors.cardBorder),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Go back'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return SfPdfViewer.file(
      File(widget.filePath),
      controller: _controller,
      pageLayoutMode: _layout,
      scrollDirection: _scroll,
      canShowScrollHead: true,
      canShowPaginationDialog: false,
      enableDoubleTapZooming: true,
      enableTextSelection: true,
      maxZoomLevel: 5.0,
      initialZoomLevel: 1.0,
      onDocumentLoaded: (details) {
        if (!mounted) return;
        setState(() => _totalPages = details.document.pages.count);
      },
      onDocumentLoadFailed: (details) {
        _fail(details.description.isNotEmpty
            ? details.description
            : 'This PDF couldn\'t be rendered.');
      },
      onPageChanged: (details) {
        if (mounted) setState(() => _currentPage = details.newPageNumber);
      },
    );
  }

  Widget _bottomBar() {
    final progress = _totalPages <= 1 ? 0.0 : _currentPage / _totalPages;
    return Material(
      color: LiquidColors.surface,
      elevation: 0,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 2.5,
              backgroundColor: LiquidColors.cardBorder,
              valueColor: AlwaysStoppedAnimation<Color>(LiquidColors.accentBlue),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _miniBtn(Icons.keyboard_double_arrow_left_rounded,
                      onTap: _currentPage > 1 ? () => _jump(1) : null),
                  _miniBtn(Icons.chevron_left_rounded,
                      onTap: _currentPage > 1
                          ? () => _jump(_currentPage - 1)
                          : null),
                  GestureDetector(
                    onTap: _totalPages > 1 ? _goToPageDialog : null,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: LiquidColors.accentBlue,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$_currentPage / $_totalPages',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  _miniBtn(Icons.chevron_right_rounded,
                      onTap: _currentPage < _totalPages
                          ? () => _jump(_currentPage + 1)
                          : null),
                  _miniBtn(Icons.keyboard_double_arrow_right_rounded,
                      onTap: _currentPage < _totalPages
                          ? () => _jump(_totalPages)
                          : null),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniBtn(IconData icon, {VoidCallback? onTap}) {
    final enabled = onTap != null;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 19,
            color:
                enabled ? LiquidColors.textPrimary : LiquidColors.textTertiary,
          ),
        ),
      ),
    );
  }
}
