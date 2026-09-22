import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:everkeep/core/routing/app_router.dart';
import 'package:everkeep/core/theme/app_colors.dart';
import 'package:everkeep/core/theme/app_radius.dart';
import 'package:everkeep/core/theme/app_text_styles.dart';
import 'package:everkeep/features/settings/presentation/widgets/change_password_sheet.dart';
import 'package:everkeep/models/vault_summary.dart';
import 'package:everkeep/providers/auth_provider.dart';
import 'package:everkeep/providers/vault_provider.dart';
import 'package:everkeep/widgets/fade_slide_in.dart';
import 'package:everkeep/widgets/feedback.dart';
import 'package:everkeep/widgets/glass/glass_card.dart';
import 'package:everkeep/widgets/glass/glass_page_header.dart';
import 'package:everkeep/widgets/glass/glass_scaffold.dart';
import 'package:everkeep/widgets/glass/status_badge.dart';

/// What protects the account, stated truthfully: the safeguards that are in
/// place, the ones still to do, and the ones that aren't available yet.
class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});

  Future<void> _signOutEverywhere(BuildContext context) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Sign out everywhere?',
      message: 'You\'ll be signed out on this device and every other device '
          'where you\'re signed in.',
      confirmLabel: 'Sign Out Everywhere',
    );
    if (!confirmed || !context.mounted) return;

    final auth = context.read<AuthProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final ok = await auth.signOutEverywhere();
    // This device is signed out whether or not the other devices could be
    // reached, so always leave the signed-in area; explain if it half-worked.
    navigator.pushNamedAndRemoveUntil(AppRouter.welcome, (route) => false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Signed out of all devices.'
              : auth.error ?? 'Signed out on this device.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GlassPageHeader(title: 'Security', showBackButton: true),
          const SizedBox(height: 22),
          FadeSlideIn(index: 0, child: _buildScoreCard()),
          const SizedBox(height: 22),
          _sectionLabel('SAFEGUARDS'),
          const SizedBox(height: 10),
          Selector<VaultProvider, VaultSummary>(
            selector: (_, vault) => vault.vaultSummary,
            builder: (context, summary, _) {
              return Column(
                children: [
                  _buildStatusRow(
                    title: 'Confirmed email',
                    description: 'Proves the address on your account is yours',
                    badge: summary.emailVerified
                        ? const StatusBadge.success('Done')
                        : const StatusBadge.pending('To do'),
                    onTap: summary.emailVerified
                        ? null
                        : () => Navigator.of(
                            context,
                          ).pushNamed(AppRouter.settings),
                  ),
                  const SizedBox(height: 12),
                  _buildStatusRow(
                    title: 'A trusted person',
                    description: 'Someone you\'ve chosen to carry out your wishes',
                    badge: summary.trustedContactsCount > 0
                        ? const StatusBadge.success('Done')
                        : const StatusBadge.pending('To do'),
                    onTap: summary.trustedContactsCount > 0
                        ? null
                        : () => Navigator.of(
                            context,
                          ).pushNamed(AppRouter.trustedContacts),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          _buildStatusRow(
            title: 'Two-Factor Authentication',
            description: 'A code from your phone at sign-in',
            badge: const StatusBadge.neutral('Coming soon'),
          ),
          const SizedBox(height: 12),
          _buildStatusRow(
            title: 'Biometric Lock',
            description: 'Face ID or fingerprint to open the app',
            badge: const StatusBadge.neutral('Coming soon'),
          ),
          const SizedBox(height: 26),
          _sectionLabel('ACCOUNT'),
          const SizedBox(height: 10),
          _buildStatusRow(
            title: 'Change password',
            description: 'Choose a new password for this account',
            onTap: () => showChangePasswordSheet(context),
          ),
          const SizedBox(height: 12),
          _buildStatusRow(
            title: 'Sign out of all devices',
            description: 'Ends every session, including this one',
            onTap: () => _signOutEverywhere(context),
          ),
          const SizedBox(height: 12),
          _buildStatusRow(
            title: 'Emergency Access',
            description: 'How trusted contacts will reach your vault',
            onTap: () =>
                Navigator.of(context).pushNamed(AppRouter.emergencyAccess),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: AppTextStyles.overline.copyWith(
        color: AppColors.glassOnSurfaceFaint,
      ),
    );
  }

  Widget _buildScoreCard() {
    return Selector<VaultProvider, VaultSummary>(
      selector: (_, vault) => vault.vaultSummary,
      builder: (context, summary, _) {
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
                'Security: ${summary.securityScoreLabel}',
                textAlign: TextAlign.center,
                style: AppTextStyles.serifTitleSmall.copyWith(
                  color: AppColors.glassOnSurface,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your data is kept separate from every other user, and the '
                'database itself blocks anyone else from reading it. The score '
                'counts the safeguards below that you have in place.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.glassOnSurfaceMuted,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// A card with a title and description. With [onTap] it shows a chevron (or a
  /// [badge] if one is given); without it, it is informational only.
  Widget _buildStatusRow({
    required String title,
    required String description,
    Widget? badge,
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
          if (badge != null) ...[const SizedBox(width: 8), badge],
          if (badge == null && onTap != null) ...[
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.glassOnSurfaceFaint,
            ),
          ],
        ],
      ),
    );
  }
}
