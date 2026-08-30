import 'package:flutter/material.dart';
import 'package:everkeep/core/config/app_image_urls.dart';
import 'package:everkeep/core/routing/app_router.dart';
import 'package:everkeep/core/theme/app_colors.dart';
import 'package:everkeep/core/theme/app_spacing.dart';
import 'package:everkeep/core/theme/app_text_styles.dart';
import 'package:everkeep/widgets/app_network_image.dart';
import 'package:everkeep/widgets/glass/glass_primary_button.dart';

/// Full-bleed hero photo with content overlaid at the bottom behind a
/// diagonal scrim, matching the Figma welcome frame.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.glassBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AppNetworkImage(
            url: AppImageUrls.welcomeHero,
            fallbackIcon: Icons.family_restroom_rounded,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: const Alignment(-1, -1),
                end: const Alignment(0.6, 1),
                colors: [
                  Colors.transparent,
                  AppColors.glassBackground.withValues(alpha: 0.9),
                  AppColors.glassBackground,
                ],
                stops: const [0.25, 0.6, 0.85],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your legacy deserves\nto live on.',
                    style: AppTextStyles.serifDisplayLarge.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Safeguard your most precious memories, documents, and messages for the people who matter most.',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.glassOnSurfaceMuted,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                  GlassPrimaryButton(
                    text: 'Create Your Legacy',
                    onPressed: () =>
                        Navigator.of(context).pushNamed(AppRouter.signIn),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Center(
                    child: GestureDetector(
                      onTap: () =>
                          Navigator.of(context).pushNamed(AppRouter.signIn),
                      child: Text(
                        'I already have an account',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.glassOnSurfaceMuted,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.glassOnSurfaceMuted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
