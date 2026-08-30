import 'package:flutter/material.dart';
import '../../../../core/config/app_image_urls.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../widgets/app_network_image.dart';

class OnboardingPage1 extends StatefulWidget {
  const OnboardingPage1({Key? key}) : super(key: key);

  @override
  State<OnboardingPage1> createState() => _OnboardingPage1State();
}

class _OnboardingPage1State extends State<OnboardingPage1>
    with TickerProviderStateMixin {
  late AnimationController _floatController;
  late AnimationController _fadeController;
  late Animation<double> _floatAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _floatAnim = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _floatController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return FadeTransition(
      opacity: _fadeAnim,
      child: Column(
        children: [
          // Visual area
          Expanded(
            flex: 6,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Back card (rotated)
                AnimatedBuilder(
                  animation: _floatAnim,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(0, -_floatAnim.value * 0.5),
                    child: Transform.rotate(
                      angle: -0.12,
                      child: child,
                    ),
                  ),
                  child: _buildPhotoCard(
                    width: size.width * 0.55,
                    height: size.width * 0.68,
                    color: AppColors.glassSurfaceRaised,
                    offset: const Offset(-30, 20),
                    child: _buildFamilyIllustration(isBack: true),
                  ),
                ),
                // Front card
                AnimatedBuilder(
                  animation: _floatAnim,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(0, _floatAnim.value),
                    child: child,
                  ),
                  child: _buildPhotoCard(
                    width: size.width * 0.58,
                    height: size.width * 0.72,
                    color: AppColors.glassSurface,
                    offset: const Offset(20, -10),
                    child: _buildFamilyIllustration(isBack: false),
                  ),
                ),
                // Blue accent badge
                Positioned(
                  bottom: 30,
                  right: size.width * 0.1,
                  child: AnimatedBuilder(
                    animation: _floatAnim,
                    builder: (context, child) => Transform.translate(
                      offset: Offset(0, -_floatAnim.value * 0.7),
                      child: child,
                    ),
                    child: _buildBadge(),
                  ),
                ),
              ],
            ),
          ),
          // Text area
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    'Your Legacy\nis Secured',
                    style: AppTextStyles.serifDisplayMedium.copyWith(
                      color: Colors.white,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Safely store your documents, memories, and messages — available to your loved ones when they need them most.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white.withValues(alpha: 0.65),
                      height: 1.6,
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

  Widget _buildPhotoCard({
    required double width,
    required double height,
    required Color color,
    required Offset offset,
    required Widget child,
  }) {
    return Transform.translate(
      offset: offset,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppShadows.onboardingCardShadow,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: child,
        ),
      ),
    );
  }

  Widget _buildFamilyIllustration({required bool isBack}) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AppNetworkImage(
          url: isBack
              ? AppImageUrls.onboardingFamilySecondary
              : AppImageUrls.onboardingFamilyPrimary,
          fallbackIcon: Icons.photo_outlined,
          placeholderColor: AppColors.glassSurfaceRaised,
        ),
        // Subtle dark tonal wash to keep the photo consistent with the
        // app's near-black canvas.
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.glassBackground.withValues(alpha: isBack ? 0.45 : 0.28),
                  AppColors.glassBackground.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        // Heart icon
        if (!isBack)
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.glassAccentPink.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite_rounded,
                color: AppColors.glassAccentPink,
                size: 14,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.glassSurfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
        boxShadow: AppShadows.onboardingCardShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.glassAccentGreen,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Legacy Protected',
            style: AppTextStyles.labelSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
