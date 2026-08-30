import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';

/// The dark glass search field shared by Vault, Documents, Accounts, and
/// Trusted People.
class GlassSearchBar extends StatelessWidget {
  final String hintText;
  final ValueChanged<String>? onChanged;

  const GlassSearchBar({Key? key, required this.hintText, this.onChanged})
      : super(key: key);

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
