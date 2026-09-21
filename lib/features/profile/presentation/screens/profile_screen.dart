import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:everkeep/core/config/app_image_urls.dart';
import 'package:everkeep/core/routing/app_router.dart';
import 'package:everkeep/core/theme/app_colors.dart';
import 'package:everkeep/core/theme/app_radius.dart';
import 'package:everkeep/core/theme/app_text_styles.dart';
import 'package:everkeep/core/session/sign_out.dart';
import 'package:everkeep/providers/trusted_contact_provider.dart';
import 'package:everkeep/providers/user_provider.dart';
import 'package:everkeep/providers/vault_provider.dart';
import 'package:everkeep/widgets/app_network_image.dart';
import 'package:everkeep/widgets/circular_progress_ring.dart';
import 'package:everkeep/widgets/fade_slide_in.dart';
import 'package:everkeep/widgets/feedback.dart';
import 'package:everkeep/widgets/glass/dashboard_grid_card.dart';
import 'package:everkeep/widgets/glass/glass_scaffold.dart';
import 'package:everkeep/widgets/glass/glass_sheet.dart';
import 'package:everkeep/widgets/glass/status_badge.dart';
import 'package:everkeep/widgets/profile_avatar.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _editProfile(BuildContext context) async {
    final userProv = context.read<UserProvider>();
    final current = userProv.user;
    if (current == null) return;

    final saved = await showGlassFormSheet(
      context,
      title: 'Personal Info',
      submitLabel: 'Save Changes',
      fields: [
        GlassFormField(
          key: 'name',
          label: 'Full name',
          hint: 'Your name',
          initialValue: current.name,
        ),
        GlassFormField(
          key: 'phone',
          label: 'Phone',
          hint: 'Optional',
          required: false,
          keyboardType: TextInputType.phone,
          initialValue: current.phone ?? '',
        ),
      ],
      onSubmit: (values) async {
        final updated = await userProv.updateUserProfile(
          current.copyWith(name: values['name'], phone: values['phone']),
        );
        return updated
            ? null
            : userProv.error ?? 'Could not save your changes.';
      },
    );

    if (saved && context.mounted) showAppSnackBar(context, 'Profile updated');
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Profile',
            style: AppTextStyles.serifHeadline.copyWith(
              color: AppColors.glassOnSurface,
            ),
          ),
          const SizedBox(height: 18),
          _buildHeroCard(),
          const SizedBox(height: 22),
          DashboardGrid(
            cards: [
              FadeSlideIn(
                index: 0,
                child: Selector<UserProvider, String>(
                  selector: (_, userProv) => userProv.displayName,
                  builder: (context, name, _) {
                    return DashboardGridCard(
                      icon: Icons.person_outline_rounded,
                      tintColor: AppColors.glassAccentPink,
                      title: 'Personal Info',
                      meta: name,
                      onTap: () => _editProfile(context),
                    );
                  },
                ),
              ),
              FadeSlideIn(
                index: 1,
                child: DashboardGridCard(
                  icon: Icons.explore_outlined,
                  tintColor: AppColors.glassAccentBlue,
                  title: 'Legacy Prefs',
                  meta: '3 emergency rules',
                  onTap: () {},
                ),
              ),
              FadeSlideIn(
                index: 2,
                child: DashboardGridCard(
                  icon: Icons.shield_outlined,
                  tintColor: AppColors.glassAccentGreen,
                  title: 'Security',
                  meta: 'Vault score: strong',
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRouter.security),
                ),
              ),
              FadeSlideIn(
                index: 3,
                child: Selector<TrustedContactProvider, int>(
                  selector: (_, contactProv) => contactProv.count,
                  builder: (context, count, _) {
                    return DashboardGridCard(
                      icon: Icons.people_outline_rounded,
                      tintColor: AppColors.glassAccentSecondary,
                      title: 'Trusted People',
                      meta: '$count secure ${count == 1 ? 'trustee' : 'trustees'}',
                      onTap: () => Navigator.of(context)
                          .pushNamed(AppRouter.trustedContacts),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSubscriptionRow(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildRow(
            icon: Icons.history_rounded,
            tintColor: AppColors.glassOnSurfaceMuted,
            title: 'Activity Log',
            meta: 'Last login 2h ago',
            onTap: () {},
          ),
          const SizedBox(height: 10),
          _buildRow(
            icon: Icons.warning_amber_rounded,
            tintColor: AppColors.glassAccentSecondary,
            title: 'Emergency Access',
            meta: 'Legacy access for trusted contacts',
            onTap: () =>
                Navigator.of(context).pushNamed(AppRouter.emergencyAccess),
          ),
          const SizedBox(height: 10),
          _buildRow(
            icon: Icons.settings_outlined,
            tintColor: AppColors.glassOnSurfaceMuted,
            title: 'Settings',
            meta: 'Notifications, privacy, and more',
            onTap: () => Navigator.of(context).pushNamed(AppRouter.settings),
          ),
          const SizedBox(height: 22),
          _buildSignOutRow(context),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      height: 160,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: AppRadius.radiusXXL),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const AppNetworkImage(url: AppImageUrls.mockUserAvatar),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.black.withValues(alpha: 0.9),
                  Colors.black.withValues(alpha: 0.5),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const ProfileAvatar(
                  url: AppImageUrls.mockUserAvatar,
                  size: 48,
                  borderColor: Colors.white54,
                  borderWidth: 1,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Consumer<UserProvider>(
                    builder: (context, userProv, _) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            userProv.displayName,
                            style: AppTextStyles.serifTitleSmall.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            userProv.displayEmail,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                Selector<VaultProvider, double>(
                  selector: (_, vault) => vault.vaultSummary.legacyProgress,
                  builder: (context, progress, _) {
                    final pct = (progress * 100).toInt();
                    return CircularProgressRing(
                      progress: progress,
                      size: 56,
                      strokeWidth: 5,
                      trackColor: Colors.white.withValues(alpha: 0.2),
                      progressGradient: AppColors.glassAccentGradient,
                      child: Text(
                        '$pct%',
                        style: AppTextStyles.labelMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionRow() {
    return _buildRow(
      icon: Icons.workspace_premium_outlined,
      tintColor: AppColors.glassWarningColor,
      title: 'Subscription Plan',
      meta: 'Premium Account',
      trailing: const StatusBadge.premium('PREMIUM'),
      onTap: () {},
    );
  }

  Widget _buildRow({
    required IconData icon,
    required Color tintColor,
    required String title,
    required String meta,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Material(
      color: AppColors.glassSurface,
      borderRadius: AppRadius.radiusXL,
      child: InkWell(
        borderRadius: AppRadius.radiusXL,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: AppRadius.radiusXL,
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tintColor.withValues(alpha: 0.14),
                  borderRadius: AppRadius.radiusLG,
                ),
                child: Icon(icon, color: tintColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: AppTextStyles.titleSmall.copyWith(
                            color: AppColors.glassOnSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (trailing != null) ...[
                          const SizedBox(width: 8),
                          trailing,
                        ],
                      ],
                    ),
                    Text(
                      meta,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.glassOnSurfaceMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.glassOnSurfaceFaint),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignOutRow(BuildContext context) {
    return Material(
      color: AppColors.glassSurface,
      borderRadius: AppRadius.radiusXL,
      child: InkWell(
        borderRadius: AppRadius.radiusXL,
        onTap: () => signOutAndReturnToWelcome(context),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: AppRadius.radiusXL,
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Text(
            'Sign Out',
            style: AppTextStyles.titleSmall.copyWith(
              color: AppColors.glassDestructive,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
