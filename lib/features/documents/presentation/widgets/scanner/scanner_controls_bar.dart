import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';

/// Top bar with back, flash toggle, and camera flip controls.
class ScannerTopBar extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onToggleFlash;
  final VoidCallback? onSwitchCamera;
  final bool isFlashOn;
  final bool hasMultipleCameras;

  const ScannerTopBar({
    super.key,
    required this.onClose,
    required this.onToggleFlash,
    this.onSwitchCamera,
    this.isFlashOn = false,
    this.hasMultipleCameras = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.75),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Close / Back button
            _CircularGlassButton(
              icon: Icons.close_rounded,
              tooltip: 'Close scanner',
              onPressed: onClose,
            ),

            // Right actions: Flash & Camera switch
            Row(
              children: [
                _CircularGlassButton(
                  icon: isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                  iconColor: isFlashOn ? AppColors.glassAccentPink : Colors.white,
                  tooltip: isFlashOn ? 'Turn off flash' : 'Turn on flash',
                  onPressed: onToggleFlash,
                ),
                if (hasMultipleCameras && onSwitchCamera != null) ...[
                  const SizedBox(width: 12),
                  _CircularGlassButton(
                    icon: Icons.flip_camera_ios_rounded,
                    tooltip: 'Switch camera',
                    onPressed: onSwitchCamera!,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom shutter bar containing the capture button, gallery import fallback,
/// and review / preview indicator.
class ScannerBottomBar extends StatelessWidget {
  final VoidCallback onCapture;
  final VoidCallback onPickFromGallery;
  final VoidCallback? onReviewPages;
  final int pageCount;
  final bool isCapturing;

  const ScannerBottomBar({
    super.key,
    required this.onCapture,
    required this.onPickFromGallery,
    this.onReviewPages,
    this.pageCount = 0,
    this.isCapturing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.85),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Gallery import button
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CircularGlassButton(
                  icon: Icons.photo_library_outlined,
                  size: 48,
                  tooltip: 'Import document photo',
                  onPressed: onPickFromGallery,
                ),
                const SizedBox(height: 4),
                Text(
                  'Gallery',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: Colors.white70,
                    fontSize: 10,
                  ),
                ),
              ],
            ),

            // Central Shutter Button
            GestureDetector(
              key: const Key('scanner_shutter_button'),
              onTap: isCapturing ? null : onCapture,
              child: Container(
                width: 76,
                height: 76,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 3.5,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: isCapturing
                        ? AppColors.glassAccentPink.withValues(alpha: 0.5)
                        : Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: isCapturing
                      ? const Center(
                          child: SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : null,
                ),
              ),
            ),

            // Review Pages Button (when 1 or more pages captured)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _CircularGlassButton(
                      icon: Icons.check_circle_outline_rounded,
                      size: 48,
                      iconColor: pageCount > 0
                          ? AppColors.glassAccentGreen
                          : Colors.white38,
                      tooltip: pageCount > 0 ? 'Review scanned pages' : 'No pages',
                      onPressed: pageCount > 0 ? onReviewPages : null,
                    ),
                    if (pageCount > 0)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppColors.glassAccentPink,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$pageCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  pageCount > 0 ? 'Review ($pageCount)' : 'Review',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: pageCount > 0 ? Colors.white : Colors.white38,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CircularGlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final Color iconColor;
  final String? tooltip;

  const _CircularGlassButton({
    required this.icon,
    this.onPressed,
    this.size = 44,
    this.iconColor = Colors.white,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ),
          child: Icon(
            icon,
            size: size * 0.52,
            color: onPressed != null ? iconColor : Colors.white24,
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}
