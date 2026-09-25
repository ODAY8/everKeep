import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../models/memory_media_item.dart';

/// Full-screen photo gallery viewer allowing pinch-to-zoom, pan, and swipe
/// between multiple photos belonging to a memory.
class FullScreenPhotoViewer extends StatefulWidget {
  final List<MemoryMediaItem> photos;
  final int initialIndex;
  final Map<String, String> signedUrls;

  const FullScreenPhotoViewer({
    super.key,
    required this.photos,
    this.initialIndex = 0,
    required this.signedUrls,
  });

  /// Opens the full-screen photo viewer in the given [context].
  static Future<void> show(
    BuildContext context, {
    required List<MemoryMediaItem> photos,
    int initialIndex = 0,
    required Map<String, String> signedUrls,
  }) {
    return Navigator.of(context).push<void>(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.92),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: FullScreenPhotoViewer(
              photos: photos,
              initialIndex: initialIndex,
              signedUrls: signedUrls,
            ),
          );
        },
      ),
    );
  }

  @override
  State<FullScreenPhotoViewer> createState() => _FullScreenPhotoViewerState();
}

class _FullScreenPhotoViewerState extends State<FullScreenPhotoViewer> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.photos.isNotEmpty ? widget.photos.length - 1 : 0);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            tooltip: 'Close viewer',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      );
    }

    final total = widget.photos.length;
    final currentPhoto = widget.photos[_currentIndex];
    final caption = currentPhoto.caption?.trim();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            // Swipeable Photo Pages
            PageView.builder(
              controller: _pageController,
              itemCount: total,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              itemBuilder: (context, index) {
                final photo = widget.photos[index];
                final url = widget.signedUrls[photo.filePath];

                return _PhotoPage(
                  photo: photo,
                  url: url,
                  onLoading: () => _buildLoadingState(index),
                  onError: () => _buildErrorState(index),
                );
              },
            ),

            // Top Bar: Counter & Close Button
            Positioned(
              top: 10,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Semantics(
                    label: 'Photo ${_currentIndex + 1} of $total',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: AppRadius.radiusPill,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        '${_currentIndex + 1} / $total',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  Semantics(
                    label: 'Close photo viewer',
                    button: true,
                    child: IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Caption overlay if present
            if (caption != null && caption.isNotEmpty)
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Semantics(
                  label: 'Caption: $caption',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: AppRadius.radiusMD,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Text(
                      caption,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(int index) {
    return Semantics(
      label: 'Loading photo ${index + 1}',
      child: const Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(int index) {
    return Semantics(
      label: 'Unable to load photo ${index + 1}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.broken_image_outlined,
            color: AppColors.glassDestructive,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            'Unable to load photo',
            style: AppTextStyles.bodySmall.copyWith(
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoPage extends StatefulWidget {
  final MemoryMediaItem photo;
  final String? url;
  final Widget Function() onLoading;
  final Widget Function() onError;

  const _PhotoPage({
    required this.photo,
    required this.url,
    required this.onLoading,
    required this.onError,
  });

  @override
  State<_PhotoPage> createState() => _PhotoPageState();
}

class _PhotoPageState extends State<_PhotoPage> {
  late final TransformationController _controller;
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _controller = TransformationController();
    _controller.addListener(_onTransformationChanged);
  }

  void _onTransformationChanged() {
    final scale = _controller.value.getMaxScaleOnAxis();
    final zoomed = (scale - 1.0).abs() > 0.05;
    if (zoomed != _isZoomed) {
      setState(() => _isZoomed = zoomed);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTransformationChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: _controller,
      minScale: 1.0,
      maxScale: 4.0,
      panEnabled: _isZoomed,
      scaleEnabled: true,
      child: Center(
        child: widget.url != null
            ? Image.network(
                widget.url!,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white70,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => widget.onError(),
              )
            : widget.onLoading(),
      ),
    );
  }
}

