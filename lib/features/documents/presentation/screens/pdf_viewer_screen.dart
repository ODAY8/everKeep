import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../models/document_item.dart';
import '../../../../providers/document_provider.dart';
import '../../../../widgets/circular_icon_button.dart';
import '../../../../widgets/feedback.dart';

/// Optional builder callback for injecting a mock or alternate PDF view
/// during headless widget tests where native PDFium FFI is unavailable.
typedef PdfViewerWidgetBuilder = Widget Function(
  BuildContext context, {
  required Uri uri,
  required PdfViewerController controller,
  required void Function(PdfDocument document)? onDocumentLoaded,
  required void Function(int? pageNumber)? onPageChanged,
  required void Function(Object error)? onError,
});

/// Dedicated full-screen PDF viewer with native page streaming, pinch/touch zoom,
/// zoom controls, page indicator, error recovery, and private Supabase signed URL caching.
class PdfViewerScreen extends StatefulWidget {
  final DocumentItem document;
  final PdfViewerWidgetBuilder? viewerBuilder;

  const PdfViewerScreen({
    super.key,
    required this.document,
    this.viewerBuilder,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late final PdfViewerController _controller;
  bool _isLoading = true;
  String? _error;
  String? _signedUrl;
  int _currentPage = 1;
  int? _pageCount;

  @override
  void initState() {
    super.initState();
    _controller = PdfViewerController();
    _loadPdf();
  }

  Future<void> _loadPdf({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final docProv = context.read<DocumentProvider>();
    try {
      final url = await docProv.downloadUrlFor(
        widget.document,
        forceRefresh: forceRefresh,
      );

      if (!mounted) return;

      if (url == null || url.isEmpty) {
        setState(() {
          _isLoading = false;
          _error = docProv.error ?? 'Could not generate a secure link for this PDF.';
        });
        return;
      }

      setState(() {
        _signedUrl = url;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Failed to load document: $e';
      });
    }
  }

  void _onDocumentLoaded(PdfDocument doc) {
    if (!mounted) return;
    setState(() {
      _pageCount = doc.pages.length;
      _isLoading = false;
      _error = null;
    });
  }

  void _onPageChanged(int? page) {
    if (!mounted || page == null) return;
    setState(() {
      _currentPage = page;
    });
  }

  void _onViewerError(Object error) {
    if (!mounted) return;
    // When a signed URL expires or fails during render, invalidate cache and show error
    context.read<DocumentProvider>().invalidateSignedUrlCache(widget.document.filePath);
    setState(() {
      _error = 'Failed to render PDF: $error';
    });
  }

  void _zoomIn() {
    _controller.zoomUp();
  }

  void _zoomOut() {
    _controller.zoomDown();
  }

  void _resetZoom() {
    _controller.setZoom(Offset.zero, 1.0);
  }

  void _openExternally() {
    final docProv = context.read<DocumentProvider>();
    openRemoteFile(
      context,
      fetchUrl: () => docProv.downloadUrlFor(widget.document),
      errorMessage: () => docProv.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.glassBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: _buildBody(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.glassSurface,
        border: const Border(
          bottom: BorderSide(color: AppColors.glassBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          CircularIconButton(
            icon: Icons.arrow_back_rounded,
            background: AppColors.glassSurfaceRaised,
            foreground: AppColors.glassOnSurface,
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.document.title,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.glassOnSurface,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'PDF VIEWER',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.glassAccentPink,
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          if (_pageCount != null && _pageCount! > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.glassSurfaceRaised,
                borderRadius: AppRadius.radiusPill,
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Text(
                '$_currentPage / $_pageCount',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.glassOnSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          IconButton(
            icon: const Icon(Icons.zoom_out_rounded, size: 20),
            color: AppColors.glassOnSurfaceMuted,
            tooltip: 'Zoom out',
            onPressed: _zoomOut,
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in_rounded, size: 20),
            color: AppColors.glassOnSurfaceMuted,
            tooltip: 'Zoom in',
            onPressed: _zoomIn,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.glassOnSurfaceMuted),
            color: AppColors.glassSurfaceRaised,
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.radiusMD,
              side: const BorderSide(color: AppColors.glassBorder),
            ),
            onSelected: (value) {
              if (value == 'external') {
                _openExternally();
              } else if (value == 'reset_zoom') {
                _resetZoom();
              } else if (value == 'refresh') {
                _loadPdf(forceRefresh: true);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'reset_zoom',
                child: Row(
                  children: [
                    Icon(Icons.fit_screen_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Fit to width'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Reload PDF'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'external',
                child: Row(
                  children: [
                    Icon(Icons.open_in_new_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Open externally'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.glassAccentPink),
            const SizedBox(height: 16),
            Text(
              'Loading PDF...',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.glassOnSurfaceMuted,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.glassDestructive.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.glassDestructive,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Unable to open PDF',
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.glassOnSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.glassOnSurfaceMuted,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.glassAccentPink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.radiusPill,
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                onPressed: () => _loadPdf(forceRefresh: true),
              ),
            ],
          ),
        ),
      );
    }

    if (_signedUrl == null) {
      return const SizedBox.shrink();
    }

    final uri = Uri.parse(_signedUrl!);

    if (widget.viewerBuilder != null) {
      return widget.viewerBuilder!(
        context,
        uri: uri,
        controller: _controller,
        onDocumentLoaded: _onDocumentLoaded,
        onPageChanged: _onPageChanged,
        onError: _onViewerError,
      );
    }

    return PdfViewer.uri(
      uri,
      controller: _controller,
      params: PdfViewerParams(
        onViewerReady: (document, controller) {
          _onDocumentLoaded(document);
        },
      ),
    );
  }
}
