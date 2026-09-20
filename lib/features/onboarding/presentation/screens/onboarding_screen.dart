import 'package:flutter/material.dart';
import 'package:everkeep/core/routing/app_router.dart';
import 'package:everkeep/core/theme/app_spacing.dart';
import 'package:everkeep/core/theme/app_text_styles.dart';
import 'package:everkeep/features/onboarding/presentation/widgets/onboarding_page1.dart';
import 'package:everkeep/features/onboarding/presentation/widgets/onboarding_page2.dart';
import 'package:everkeep/features/onboarding/presentation/widgets/onboarding_page3.dart';
import 'package:everkeep/widgets/page_indicator.dart';
import 'package:everkeep/widgets/onboarding_next_button.dart';
import 'package:everkeep/core/theme/app_colors.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context).pushReplacementNamed(AppRouter.welcome);
    }
  }

  void _skip() {
    Navigator.of(context).pushReplacementNamed(AppRouter.welcome);
  }

  @override
  Widget build(BuildContext context) {
    // Flat near-black canvas, matching the Figma reference — no gradient.
    return Scaffold(
      backgroundColor: AppColors.glassBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xl,
          ),
          child: Column(
            children: [
              // Skip button
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: _skip,
                  child: Text(
                    'Skip',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.glassOnSurfaceMuted,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // PageView
              Expanded(
                flex: 3,
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  children: [
                    OnboardingPage1(),
                    OnboardingPage2(),
                    OnboardingPage3(),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              // Page indicator + circular next action, matching the
              // reference design's compact bottom control row.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  PageIndicator(
                    count: 3,
                    currentIndex: _currentPage,
                  ),
                  OnboardingNextButton(onPressed: _nextPage),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}
