import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_text_styles.dart';
import '../pressable_scale.dart';

/// The coral→crimson gradient floating action button used to add new items
/// (documents, future messages) throughout the app. With [label] omitted it
/// renders as the plain 60px icon-only circle from the Figma reference;
/// pass a [label] for the pill+text variant.
class GlassFab extends StatelessWidget {
  final String? label;
  final IconData icon;
  final VoidCallback onPressed;

  const GlassFab({
    Key? key,
    this.label,
    required this.onPressed,
    this.icon = Icons.add_rounded,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (label == null) {
      return PressableScale(
        onTap: onPressed,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            gradient: AppColors.glassAccentGradient,
            shape: BoxShape.circle,
            boxShadow: AppShadows.accentButtonShadow,
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      );
    }

    return PressableScale(
      onTap: onPressed,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          gradient: AppColors.glassAccentGradient,
          borderRadius: AppRadius.radiusPill,
          boxShadow: AppShadows.accentButtonShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label!,
              style: AppTextStyles.titleMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
