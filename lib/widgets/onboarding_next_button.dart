import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_shadows.dart';

class OnboardingNextButton extends StatelessWidget {
  final VoidCallback onPressed;
  final double size;

  const OnboardingNextButton({
    super.key,
    required this.onPressed,
    this.size = 52,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Ink(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: AppColors.glassAccentGradient,
            shape: BoxShape.circle,
            boxShadow: AppShadows.accentButtonShadow,
          ),
          child: Icon(
            Icons.arrow_forward_rounded,
            color: Colors.white,
            size: size * 0.42,
          ),
        ),
      ),
    );
  }
}
