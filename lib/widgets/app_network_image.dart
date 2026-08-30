import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// A photographic image loaded from [url] — a bundled `assets/images/...`
/// path or a network URL, detected automatically — with a soft placeholder
/// while loading and a graceful icon fallback if the load fails.
///
/// Decode resolution is capped to the widget's actual rendered size (in
/// device pixels), so a large source photo shown in a small card doesn't
/// get decoded at full resolution — this matters most where several
/// instances are visible at once, e.g. the Memories grid.
///
/// Used only for photographic/decorative imagery (see [AppImageUrls]) —
/// never for logos, icons, or UI chrome, which stay vector/local.
class AppNetworkImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final IconData fallbackIcon;
  final Color? placeholderColor;

  const AppNetworkImage({
    Key? key,
    required this.url,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fallbackIcon = Icons.image_outlined,
    this.placeholderColor,
  }) : super(key: key);

  bool get _isLocalAsset => url.startsWith('assets/');

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.zero;
    final dpr = MediaQuery.of(context).devicePixelRatio;

    return ClipRRect(
      borderRadius: radius,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final rawCacheWidth = (constraints.maxWidth * dpr).round();
          final rawCacheHeight = (constraints.maxHeight * dpr).round();
          final cacheWidth = constraints.maxWidth.isFinite && rawCacheWidth > 0
              ? rawCacheWidth
              : null;
          final cacheHeight =
              constraints.maxHeight.isFinite && rawCacheHeight > 0
                  ? rawCacheHeight
                  : null;

          if (_isLocalAsset) {
            return Image.asset(
              url,
              fit: fit,
              cacheWidth: cacheWidth,
              cacheHeight: cacheHeight,
              errorBuilder: (context, error, stackTrace) => Container(
                color: placeholderColor ?? AppColors.lightSurfaceVariant,
                alignment: Alignment.center,
                child: Icon(
                  fallbackIcon,
                  color: AppColors.lightOnSurface.withValues(alpha: 0.25),
                  size: 32,
                ),
              ),
            );
          }

          return CachedNetworkImage(
            imageUrl: url,
            fit: fit,
            memCacheWidth: cacheWidth,
            memCacheHeight: cacheHeight,
            fadeInDuration: const Duration(milliseconds: 300),
            fadeOutDuration: const Duration(milliseconds: 150),
            placeholder: (context, _) => Container(
              color: placeholderColor ?? AppColors.lightSurfaceVariant,
            ),
            errorWidget: (context, _, error) => Container(
              color: placeholderColor ?? AppColors.lightSurfaceVariant,
              alignment: Alignment.center,
              child: Icon(
                fallbackIcon,
                color: AppColors.lightOnSurface.withValues(alpha: 0.25),
                size: 32,
              ),
            ),
          );
        },
      ),
    );
  }
}
