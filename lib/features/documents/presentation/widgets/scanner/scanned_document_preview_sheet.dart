import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_radius.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../widgets/glass/glass_primary_button.dart';
import '../../../models/scanned_page.dart';
import '../../../services/document_scanner_service.dart';
import 'interactive_crop_view.dart';
import 'page_enhancement_controls.dart';
import 'scanned_page_thumbnail_strip.dart';

/// Screen/View displaying preview of captured pages, reordering, deletion,
/// page enhancements (rotation, cropping, filters), and final save trigger.
class ScannedDocumentPreviewView extends StatefulWidget {
  final List<ScannedPage> initialPages;
  final DocumentScannerService scannerService;
  final VoidCallback onAddAnotherPage;
  final Future<void> Function(List<ScannedPage> pages) onSave;
  final VoidCallback onCancel;

  const ScannedDocumentPreviewView({
    super.key,
    required this.initialPages,
    required this.scannerService,
    required this.onAddAnotherPage,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<ScannedDocumentPreviewView> createState() => _ScannedDocumentPreviewViewState();
}

class _ScannedDocumentPreviewViewState extends State<ScannedDocumentPreviewView> {
  late List<ScannedPage> _pages;
  int _currentIndex = 0;
  bool _isProcessing = false;
  bool _isCropping = false;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _pages = List.from(widget.initialPages);
    _currentIndex = _pages.isNotEmpty ? _pages.length - 1 : 0;
  }

  @override
  void didUpdateWidget(ScannedDocumentPreviewView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPages.length != _pages.length) {
      _pages = List.from(widget.initialPages);
      _currentIndex = _pages.isNotEmpty ? _pages.length - 1 : 0;
    }
  }

  ScannedPage? get _currentPage =>
      _pages.isNotEmpty && _currentIndex < _pages.length ? _pages[_currentIndex] : null;

  Future<void> _rotatePage() async {
    final page = _currentPage;
    if (page == null || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final nextRotation = (page.rotationDegrees + 90) % 360;
      final processed = await widget.scannerService.processPage(
        rawBytes: page.originalBytes,
        rotationDegrees: nextRotation,
        filter: page.filter,
        cropRect: page.cropRect,
      );

      final updated = page.copyWith(
        rotationDegrees: nextRotation,
        processedBytes: processed,
      );

      setState(() {
        _pages[_currentIndex] = updated;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not rotate image. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _applyFilter(PageFilter newFilter) async {
    final page = _currentPage;
    if (page == null || _isProcessing || page.filter == newFilter) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final processed = await widget.scannerService.processPage(
        rawBytes: page.originalBytes,
        rotationDegrees: page.rotationDegrees,
        filter: newFilter,
        cropRect: page.cropRect,
      );

      final updated = page.copyWith(
        filter: newFilter,
        processedBytes: processed,
      );

      setState(() {
        _pages[_currentIndex] = updated;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not apply filter. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _applyCrop(Rect cropRect) async {
    final page = _currentPage;
    if (page == null || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _isCropping = false;
      _errorMessage = null;
    });

    try {
      final processed = await widget.scannerService.processPage(
        rawBytes: page.originalBytes,
        rotationDegrees: page.rotationDegrees,
        filter: page.filter,
        cropRect: cropRect,
      );

      final updated = page.copyWith(
        cropRect: cropRect,
        processedBytes: processed,
      );

      setState(() {
        _pages[_currentIndex] = updated;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not crop image. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _pages.removeAt(oldIndex);
      _pages.insert(newIndex, item);
      _currentIndex = newIndex;
    });
  }

  void _deleteCurrentPage(int index) {
    if (_pages.length <= 1) {
      // If deleting the only page, go back to camera to capture
      widget.onAddAnotherPage();
      return;
    }

    setState(() {
      _pages.removeAt(index);
      if (_currentIndex >= _pages.length) {
        _currentIndex = _pages.length - 1;
      }
    });
  }

  Future<void> _handleSave() async {
    if (_isSaving || _pages.isEmpty) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await widget.onSave(_pages);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCropping && _currentPage != null) {
      return InteractiveCropView(
        imageBytes: _currentPage!.originalBytes,
        initialCropRect: _currentPage!.cropRect,
        onCropConfirmed: _applyCrop,
        onCancel: () => setState(() => _isCropping = false),
      );
    }

    final page = _currentPage;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.85),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          tooltip: 'Back to camera',
          onPressed: widget.onCancel,
        ),
        title: Text(
          _pages.length > 1
              ? 'Page ${_currentIndex + 1} of ${_pages.length}'
              : 'Scan Preview',
          style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: widget.onAddAnotherPage,
            child: Text(
              '+ Add Page',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.glassAccentPink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Error banner if any
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.glassDestructive.withValues(alpha: 0.2),
                  borderRadius: AppRadius.radiusMD,
                  border: Border.all(color: AppColors.glassDestructive),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppColors.glassDestructive, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.glassDestructive),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          size: 16, color: AppColors.glassDestructive),
                      onPressed: () => setState(() => _errorMessage = null),
                    ),
                  ],
                ),
              ),

            // Main Page Preview Area
            Expanded(
              child: Center(
                child: page == null
                    ? const CircularProgressIndicator(color: AppColors.glassAccentPink)
                    : Stack(
                        alignment: Alignment.center,
                        children: [
                          InteractiveViewer(
                            minScale: 1.0,
                            maxScale: 4.0,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: ClipRRect(
                                borderRadius: AppRadius.radiusMD,
                                child: Image.memory(
                                  page.processedBytes,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                          if (_isProcessing)
                            Container(
                              color: Colors.black45,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.glassAccentPink,
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ),

            // Thumbnail strip (shown when there is at least 1 page)
            if (_pages.isNotEmpty)
              ScannedPageThumbnailStrip(
                pages: _pages,
                selectedIndex: _currentIndex,
                onSelectPage: (idx) => setState(() => _currentIndex = idx),
                onReorder: _onReorder,
                onDeletePage: _deleteCurrentPage,
                onAddPage: widget.onAddAnotherPage,
              ),

            // Page enhancement toolbar (Retake, Crop, Rotate, Filter Chips)
            if (page != null)
              PageEnhancementControls(
                activeFilter: page.filter,
                onRetake: widget.onAddAnotherPage,
                onCrop: () => setState(() => _isCropping = true),
                onRotate: _rotatePage,
                onFilterSelected: _applyFilter,
                isProcessing: _isProcessing,
              ),

            // Pinned Bottom Save / Continue Action
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
              color: Colors.black,
              child: GlassPrimaryButton(
                text: _isSaving
                    ? 'Processing Scan...'
                    : (_pages.length > 1
                        ? 'Continue with ${_pages.length} Pages'
                        : 'Continue'),
                onPressed: _isSaving || _isProcessing ? null : _handleSave,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
