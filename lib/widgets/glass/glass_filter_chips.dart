import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';

/// A horizontal row of selectable pill filters, gradient-filled when active.
/// Shared by Memories, Documents, and Accounts.
class GlassFilterChips extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const GlassFilterChips({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isSelected = selectedIndex == index;
          return GestureDetector(
            onTap: () => onSelected(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.glassIconChipBg
                    : AppColors.glassSurface,
                borderRadius: AppRadius.radiusXL,
                border: Border.all(
                  color: isSelected
                      ? AppColors.glassAccentPink
                      : AppColors.glassBorder,
                ),
              ),
              child: Text(
                labels[index],
                style: AppTextStyles.labelLarge.copyWith(
                  color: isSelected ? Colors.white : AppColors.glassOnSurfaceMuted,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
