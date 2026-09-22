import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';

/// The dark glass search field shared by Vault, Documents, Accounts, and
/// Trusted People.
class GlassSearchBar extends StatelessWidget {
  final String hintText;
  final ValueChanged<String>? onChanged;

  /// Open the keyboard as soon as the bar appears (for a search that was just
  /// asked for).
  final bool autofocus;

  const GlassSearchBar({
    super.key,
    required this.hintText,
    this.onChanged,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.glassSurface,
        borderRadius: AppRadius.radiusPill,
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: AppColors.glassOnSurfaceFaint, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              autofocus: autofocus,
              textInputAction: TextInputAction.search,
              onChanged: onChanged,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.glassOnSurface,
              ),
              decoration: InputDecoration(
                filled: false,
                border: InputBorder.none,
                isDense: true,
                hintText: hintText,
                hintStyle: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.glassOnSurfaceFaint,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
