import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:everkeep/core/routing/app_router.dart';
import 'package:everkeep/core/theme/app_colors.dart';
import 'package:everkeep/core/theme/app_radius.dart';
import 'package:everkeep/core/theme/app_text_styles.dart';
import 'package:everkeep/providers/settings_provider.dart';
import 'package:everkeep/widgets/fade_slide_in.dart';
import 'package:everkeep/widgets/glass/glass_card.dart';
import 'package:everkeep/widgets/glass/glass_page_header.dart';
import 'package:everkeep/widgets/glass/glass_scaffold.dart';
import 'package:everkeep/widgets/glass/status_badge.dart';

/// Vault-score hero plus the account's security controls — 2FA, biometric
/// unlock, and login alerts (moved here from Settings), recovery key, and
/// emergency access. Matches the Figma Security frame.
class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProv = context.watch<SettingsProvider>();

    return GlassScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GlassPageHeader(title: 'Security', showBackButton: true),
          const SizedBox(height: 22),
          FadeSlideIn(index: 0, child: _buildScoreWidget()),
          const SizedBox(height: 20),
          FadeSlideIn(
            index: 1,
            child: _buildToggleRow(
              title: 'Two-Factor Authentication',
              description: 'Require a code from your phone at sign-in',
              value: settingsProv.twoFactorEnabled,
              onChanged: (v) =>
                  context.read<SettingsProvider>().toggleTwoFactor(v),
            ),
          ),
          const SizedBox(height: 12),
          FadeSlideIn(
            index: 2,
            child: _buildToggleRow(
              title: 'Biometric Lock',
              description: 'Use Face ID or fingerprint to open the vault',
              value: settingsProv.biometricEnabled,
              onChanged: (v) =>
                  context.read<SettingsProvider>().toggleBiometric(v),
            ),
          ),
          const SizedBox(height: 12),
          FadeSlideIn(
            index: 3,
            child: _buildToggleRow(
              title: 'Login Alerts',
              description: 'Get notified of new sign-ins',
              value: settingsProv.loginAlertsEnabled,
              onChanged: (v) =>
                  context.read<SettingsProvider>().toggleLoginAlerts(v),
            ),
          ),
          const SizedBox(height: 12),
          FadeSlideIn(
            index: 4,
            child: _buildStatusRow(
              title: 'Recovery Key',
              description: 'A backup key to regain vault access',
              badge: const StatusBadge.neutral('Set Up'),
              onTap: () {},
            ),
          ),
          const SizedBox(height: 12),
          FadeSlideIn(
            index: 5,
            child: _buildStatusRow(
              title: 'Emergency Access',
              description: 'Trusted contacts can request access',
              badge: const StatusBadge.pending('Configured'),
              onTap: () => Navigator.of(context).pushNamed(AppRouter.emergencyAccess),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreWidget() {
    return GlassCard(
      borderRadius: AppRadius.radiusXXXL,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.glassSuccessBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: AppColors.glassAccentGreen,
              size: 24,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Vault Score: Strong',
            style: AppTextStyles.serifTitleSmall.copyWith(
              color: AppColors.glassOnSurface,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your credentials are secured with end-to-end zero-knowledge encryption.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.glassOnSurfaceMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow({
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return GlassCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: AppColors.glassOnSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.glassOnSurfaceMuted,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.glassAccentPink,
            inactiveTrackColor: AppColors.glassSurfaceRaised,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow({
    required String title,
    required String description,
    required Widget badge,
    VoidCallback? onTap,
  }) {
    return GlassCard(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: AppColors.glassOnSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.glassOnSurfaceMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          badge,
        ],
      ),
    );
  }
}
