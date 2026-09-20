import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';
import '../pressable_scale.dart';

/// The full-width pink→crimson gradient CTA button shared by auth and
/// wizard flows (Sign In, Emergency Access).
class GlassPrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final double height;

  const GlassPrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    return PressableScale(
      onTap: onPressed,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: isEnabled ? AppColors.glassAccentGradient : null,
          color: isEnabled ? null : AppColors.glassSurfaceRaised,
          borderRadius: AppRadius.radiusPill,
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: AppColors.glassAccentCrimson.withValues(alpha: 0.4),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: AppTextStyles.titleMedium.copyWith(
            color: isEnabled ? Colors.white : AppColors.glassOnSurfaceFaint,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// A transparent glass button with a hairline border, used for secondary
/// actions ("Previous", "Back") beside a [GlassPrimaryButton].
class GlassOutlineButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final double height;

  const GlassOutlineButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onPressed,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.glassSurface,
          borderRadius: AppRadius.radiusPill,
          border: Border.all(color: AppColors.glassBorder),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.glassOnSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
