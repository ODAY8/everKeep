import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_radius.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../models/scanned_page.dart';

/// Toolbar offering Retake, Crop, Rotate 90°, and Filter Enhancements.
class PageEnhancementControls extends StatelessWidget {
  final PageFilter activeFilter;
  final VoidCallback onRetake;
  final VoidCallback onCrop;
  final VoidCallback onRotate;
  final ValueChanged<PageFilter> onFilterSelected;
  final bool isProcessing;

  const PageEnhancementControls({
    super.key,
    required this.activeFilter,
    required this.onRetake,
    required this.onCrop,
    required this.onRotate,
    required this.onFilterSelected,
    this.isProcessing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Filter selector chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: PageFilter.values.map((filter) {
                final isSelected = filter == activeFilter;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    selected: isSelected,
                    showCheckmark: false,
                    avatar: Icon(
                      filter.icon,
                      size: 14,
                      color: isSelected ? Colors.white : Colors.white70,
                    ),
                    label: Text(
                      filter.label,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    selectedColor: AppColors.glassAccentPink,
                    side: BorderSide(
                      color: isSelected
                          ? AppColors.glassAccentPink
                          : Colors.white.withValues(alpha: 0.15),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusPill),
                    onSelected: isProcessing ? null : (_) => onFilterSelected(filter),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),

          // Primary page action buttons (Retake, Crop, Rotate)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ActionButton(
                icon: Icons.refresh_rounded,
                label: 'Retake',
                onPressed: isProcessing ? null : onRetake,
              ),
              _ActionButton(
                icon: Icons.crop_rounded,
                label: 'Crop',
                onPressed: isProcessing ? null : onCrop,
              ),
              _ActionButton(
                icon: Icons.rotate_right_rounded,
                label: 'Rotate',
                onPressed: isProcessing ? null : onRotate,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white24,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: onPressed != null ? Colors.white : Colors.white24),
      label: Text(
        label,
        style: AppTextStyles.bodySmall.copyWith(
          color: onPressed != null ? Colors.white : Colors.white24,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
