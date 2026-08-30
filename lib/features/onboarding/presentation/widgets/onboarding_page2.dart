import 'package:flutter/material.dart';
import '../../../../core/config/app_image_urls.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../widgets/app_network_image.dart';

class OnboardingPage2 extends StatefulWidget {
  const OnboardingPage2({Key? key}) : super(key: key);

  @override
  State<OnboardingPage2> createState() => _OnboardingPage2State();
}

class _OnboardingPage2State extends State<OnboardingPage2>
    with TickerProviderStateMixin {
  late AnimationController _scanController;
  late AnimationController _fadeController;
  late Animation<double> _scanAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _scanAnim = Tween<double>(begin: 0.12, end: 0.88).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.easeInOut),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _scanController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cardWidth = size.width * 0.62;
    final cardHeight = size.width * 0.78;

    return FadeTransition(
      opacity: _fadeAnim,
      child: Column(
        children: [
          Expanded(
            flex: 6,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: cardWidth,
                  height: cardHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: AppShadows.onboardingCardShadow,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Identity subject photograph.
                        AppNetworkImage(
                          url: AppImageUrls.onboardingSecurityFace,
                          fallbackIcon: Icons.face_outlined,
                          placeholderColor: AppColors.glassSurface,
                        ),
                        // Dark tonal wash so the photo reads as part of the
                        // app's near-black canvas.
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.glassBackground.withValues(alpha: 0.1),
                                  AppColors.glassBackground.withValues(alpha: 0.4),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ),
                        // Scan viewfinder corner brackets.
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: CustomPaint(
                              painter: _ScanCornersPainter(
                                color: AppColors.glassAccentPink.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        ),
                        // Vertical biometric scan line.
                        AnimatedBuilder(
                          animation: _scanAnim,
                          builder: (context, _) => Positioned(
                            top: cardHeight * _scanAnim.value,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 2,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    AppColors.glassAccentPink.withValues(alpha: 0.9),
                                    Colors.transparent,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.glassAccentPink.withValues(alpha: 0.6),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Verification badge, top-right of the card.
                Positioned(
                  top: -8,
                  right: (size.width - cardWidth) / 2 - 8,
                  child: _buildVerifiedBadge(),
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
                    'Security You\nCan Trust',
                    style: AppTextStyles.serifDisplayMedium.copyWith(
                      color: Colors.white,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Rest easy with military-grade encryption safeguarding all your information.',
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

  Widget _buildVerifiedBadge() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.glassAccentPink,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: AppShadows.onboardingCardShadow,
      ),
      child: const Icon(
        Icons.verified_rounded,
        color: Colors.white,
        size: 22,
      ),
    );
  }
}

/// Draws four L-shaped corner brackets, evoking a biometric scan viewfinder
/// over the identity photo without depending on where the face sits in it.
class _ScanCornersPainter extends CustomPainter {
  final Color color;
  static const double _armLength = 22;

  const _ScanCornersPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Top-left
    canvas.drawLine(Offset.zero, const Offset(_armLength, 0), paint);
    canvas.drawLine(Offset.zero, const Offset(0, _armLength), paint);
    // Top-right
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width - _armLength, 0),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width, _armLength),
      paint,
    );
    // Bottom-left
    canvas.drawLine(
      Offset(0, size.height),
      Offset(_armLength, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height),
      Offset(0, size.height - _armLength),
      paint,
    );
    // Bottom-right
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width - _armLength, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width, size.height - _armLength),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ScanCornersPainter oldDelegate) =>
      oldDelegate.color != color;
}
