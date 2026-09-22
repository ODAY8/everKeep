import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// Shows an image from either a bundled asset (`assets/...`) or the web
/// (`https://...`), decoded at the size it is displayed rather than at its full
/// resolution, with an icon shown if it can't be loaded.
class AppNetworkImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final IconData fallbackIcon;
  final Color? placeholderColor;

  const AppNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fallbackIcon = Icons.image_outlined,
    this.placeholderColor,
  });

  bool get _isRemote => url.startsWith('http://') || url.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.zero;
    final dpr = MediaQuery.devicePixelRatioOf(context);

    return ClipRRect(
      borderRadius: radius,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final rawCacheWidth = (constraints.maxWidth * dpr).round();
          final rawCacheHeight = (constraints.maxHeight * dpr).round();
          final cacheWidth = constraints.maxWidth.isFinite && rawCacheWidth > 0
              ? rawCacheWidth
              : null;
          final cacheHeight = constraints.maxHeight.isFinite && rawCacheHeight > 0
              ? rawCacheHeight
              : null;

          Widget fallback(BuildContext context, Object error, StackTrace? stack) =>
              Container(
                color: placeholderColor ?? AppColors.glassSurface,
                alignment: Alignment.center,
                child: Icon(
                  fallbackIcon,
                  color: AppColors.glassOnSurfaceFaint,
                  size: 32,
                ),
              );

          if (_isRemote) {
            return Image.network(
              url,
              fit: fit,
              cacheWidth: cacheWidth,
              cacheHeight: cacheHeight,
              errorBuilder: fallback,
              // Fade in once loaded instead of popping in.
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded) return child;
                return AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: child,
                );
              },
            );
          }

          return Image.asset(
            url,
            fit: fit,
            cacheWidth: cacheWidth,
            cacheHeight: cacheHeight,
            errorBuilder: fallback,
          );
        },
      ),
    );
  }
}
