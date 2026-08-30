import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_text_styles.dart';

class OnboardingPage3 extends StatefulWidget {
  const OnboardingPage3({Key? key}) : super(key: key);

  @override
  State<OnboardingPage3> createState() => _OnboardingPage3State();
}

class _OnboardingPage3State extends State<OnboardingPage3>
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
          Expanded(
            flex: 6,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Back card: folder.
                AnimatedBuilder(
                  animation: _floatAnim,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(0, -_floatAnim.value * 0.5),
                    child: Transform.rotate(angle: -0.1, child: child),
                  ),
                  child: _buildFolderCard(
                    width: size.width * 0.5,
                    height: size.width * 0.58,
                    offset: const Offset(-38, 10),
                  ),
                ),
                // Front card: spreadsheet document.
                AnimatedBuilder(
                  animation: _floatAnim,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(0, _floatAnim.value),
                    child: Transform.rotate(angle: 0.08, child: child),
                  ),
                  child: _buildDocumentCard(
                    width: size.width * 0.44,
                    height: size.width * 0.5,
                    offset: const Offset(46, 34),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    'Everything in\nOne Place',
                    style: AppTextStyles.serifDisplayMedium.copyWith(
                      color: Colors.white,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Wills, IDs, insurance documents, and more — all safely stored in one place.',
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

  Widget _buildFolderCard({
    required double width,
    required double height,
    required Offset offset,
  }) {
    return Transform.translate(
      offset: offset,
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.glassSurface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.glassBorder),
          boxShadow: AppShadows.onboardingCardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.folder_rounded,
              color: AppColors.glassAccentPink,
              size: width * 0.4,
            ),
            const Spacer(),
            Text(
              'Medical Records',
              style: AppTextStyles.labelMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              'Estate & Legal Docs',
              style: AppTextStyles.labelSmall.copyWith(
                color: Colors.white.withValues(alpha: 0.55),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentCard({
    required double width,
    required double height,
    required Offset offset,
  }) {
    return Transform.translate(
      offset: offset,
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppShadows.onboardingCardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Spacer(),
                Icon(
                  Icons.more_horiz_rounded,
                  color: AppColors.navyDeep.withValues(alpha: 0.4),
                  size: 18,
                ),
              ],
            ),
            const Spacer(),
            Container(
              width: width * 0.32,
              height: width * 0.32,
              decoration: BoxDecoration(
                color: const Color(0xFF1D6F42),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  'X',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'BankAccsList.xlsx',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.navyDeep,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '12 Jun, 2025',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.navyDeep.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
