import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';

/// The dark glass search field shared by Vault, Documents, Accounts, and
/// Trusted People.
class GlassSearchBar extends StatelessWidget {
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextEditingController? controller;
  final VoidCallback? onClear;

  /// Open the keyboard as soon as the bar appears (for a search that was just
  /// asked for).
  final bool autofocus;

  const GlassSearchBar({
    super.key,
    required this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.controller,
    this.onClear,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasText = controller?.text.isNotEmpty ?? false;

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
          const Icon(
            Icons.search_rounded,
            color: AppColors.glassOnSurfaceFaint,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: autofocus,
              textInputAction: TextInputAction.search,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
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
          if (hasText || onClear != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                controller?.clear();
                onChanged?.call('');
                onClear?.call();
              },
              child: const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(
                  Icons.close_rounded,
                  color: AppColors.glassOnSurfaceFaint,
                  size: 18,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
