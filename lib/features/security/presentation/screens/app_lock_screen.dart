import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../providers/app_lock_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../widgets/feedback.dart';
import '../../../../widgets/glass/glass_card.dart';
import '../../../../widgets/glass/glass_primary_button.dart';

/// Full-screen security gate displayed when EverKeep is locked.
/// Protects all vault content, sensitive documents, and passwords behind
/// an impenetrable glassmorphic overlay.
class AppLockScreen extends StatelessWidget {
  const AppLockScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Sign Out?',
      message: 'Signing out will exit EverKeep and end your session on this device.',
      confirmLabel: 'Sign Out',
    );
    if (!confirmed || !context.mounted) return;

    final auth = context.read<AuthProvider>();
    final lockProv = context.read<AppLockProvider>();

    await auth.signOut();
    lockProv.onSignOut();

    if (context.mounted) {
      AppRouter.navigatorKey.currentState?.pushNamedAndRemoveUntil(
        AppRouter.welcome,
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lockProv = context.watch<AppLockProvider>();
    final biometricName = lockProv.biometricName;
    final biometricIcon = lockProv.biometricIcon;
    final errorMessage = lockProv.errorMessage;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.3),
              radius: 1.2,
              colors: [
                Color(0xFF1E2838),
                Color(0xFF0F172A),
                Color(0xFF070B14),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // Brand & Security Emblem
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.glassAccentGreen.withValues(alpha: 0.12),
                      border: Border.all(
                        color: AppColors.glassAccentGreen.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.glassAccentGreen.withValues(alpha: 0.25),
                          blurRadius: 32,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        biometricIcon,
                        size: 44,
                        color: AppColors.glassAccentGreen,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  Text(
                    'EverKeep is locked',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.serifTitleMedium.copyWith(
                      color: AppColors.glassOnSurface,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Text(
                    'Unlock to access your secure vault',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.glassOnSurfaceMuted,
                      fontSize: 15,
                    ),
                  ),

                  // Error notification if authentication was rejected
                  if (errorMessage != null) ...[
                    const SizedBox(height: 24),
                    GlassCard(
                      borderRadius: AppRadius.radiusMD,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: AppColors.glassAccentPink,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              errorMessage,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.glassAccentPink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const Spacer(flex: 3),

                  // Unlock Action Button
                  GlassPrimaryButton(
                    text: lockProv.isAuthenticating
                        ? 'Verifying...'
                        : 'Unlock with $biometricName',
                    onPressed: lockProv.isAuthenticating
                        ? null
                        : () => lockProv.unlock(),
                  ),
                  const SizedBox(height: 16),

                  // Fallback Sign-Out button
                  TextButton.icon(
                    icon: const Icon(
                      Icons.logout_rounded,
                      size: 16,
                      color: AppColors.glassOnSurfaceFaint,
                    ),
                    label: Text(
                      'Sign Out',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.glassOnSurfaceFaint,
                      ),
                    ),
                    onPressed: () => _signOut(context),
                  ),

                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
