import 'package:flutter/material.dart';
import '../../../../core/security/password_strength.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';

/// A glass-styled password strength bar that visualizes password security
/// and provides helpful local feedback.
class PasswordStrengthBar extends StatelessWidget {
  final PasswordStrength strength;

  const PasswordStrengthBar({
    super.key,
    required this.strength,
  });

  @override
  Widget build(BuildContext context) {
    if (strength.level == PasswordStrengthLevel.empty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: AppRadius.radiusPill,
                child: Container(
                  height: 4,
                  color: AppColors.glassBorder,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AnimatedFractionallySizedBox(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      widthFactor: strength.progress,
                      child: Container(
                        decoration: BoxDecoration(
                          color: strength.color,
                          borderRadius: AppRadius.radiusPill,
                          boxShadow: [
                            BoxShadow(
                              color: strength.color.withValues(alpha: 0.4),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              strength.label,
              style: AppTextStyles.bodySmall.copyWith(
                color: strength.color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          strength.feedback,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.glassOnSurfaceMuted,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
