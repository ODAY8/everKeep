import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

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
          final cacheHeight = constraints.maxHeight.isFinite && rawCacheHeight > 0
              ? rawCacheHeight
              : null;

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
        },
      ),
    );
  }
}
