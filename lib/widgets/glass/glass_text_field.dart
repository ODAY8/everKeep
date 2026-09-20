import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';

/// The dark glass text input used on auth screens. Matches the Figma Sign
/// In spec: an optional uppercase [label] above a rectangular (not pill)
/// field on the app's base background color.
class GlassTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String hintText;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? errorText;

  const GlassTextField({
    super.key,
    this.controller,
    this.label,
    required this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!.toUpperCase(),
            style: AppTextStyles.overline.copyWith(
              color: AppColors.glassOnSurfaceMuted,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.glassBackground,
            borderRadius: AppRadius.radiusLG,
            border: Border.all(
              color: errorText != null ? AppColors.glassDestructive : AppColors.glassBorder,
            ),
          ),
          child: Row(
            children: [
              if (prefixIcon != null) ...[
                Icon(prefixIcon, color: AppColors.glassOnSurfaceFaint, size: 20),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscureText,
                  keyboardType: keyboardType,
                  textInputAction: textInputAction,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontSize: 15,
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
              if (suffixIcon != null)
                GestureDetector(
                  onTap: onSuffixTap,
                  child: Icon(suffixIcon, color: AppColors.glassOnSurfaceFaint, size: 20),
                ),
            ],
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.glassDestructive,
            ),
          ),
        ],
      ],
    );
  }
}
