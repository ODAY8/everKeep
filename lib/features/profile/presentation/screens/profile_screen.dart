import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:everkeep/core/routing/app_router.dart';
import 'package:everkeep/core/session/sign_out.dart';
import 'package:everkeep/core/theme/app_colors.dart';
import 'package:everkeep/core/theme/app_radius.dart';
import 'package:everkeep/core/theme/app_text_styles.dart';
import 'package:everkeep/core/utils/greeting.dart';
import 'package:everkeep/core/utils/pick_upload.dart';
import 'package:everkeep/core/utils/relative_time.dart';
import 'package:everkeep/models/document_upload.dart';
import 'package:everkeep/models/vault_summary.dart';
import 'package:everkeep/providers/user_provider.dart';
import 'package:everkeep/providers/vault_provider.dart';
import 'package:everkeep/widgets/app_network_image.dart';
import 'package:everkeep/widgets/circular_icon_button.dart';
import 'package:everkeep/widgets/circular_progress_ring.dart';
import 'package:everkeep/widgets/fade_slide_in.dart';
import 'package:everkeep/widgets/feedback.dart';
import 'package:everkeep/widgets/glass/dashboard_grid_card.dart';
import 'package:everkeep/widgets/glass/glass_scaffold.dart';
import 'package:everkeep/widgets/glass/glass_sheet.dart';
import 'package:everkeep/widgets/profile_avatar.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  // ── Editing ─────────────────────────────────────────────────────────────────

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

  void _photoActions(BuildContext context) {
    final userProv = context.read<UserProvider>();
    final avatarUrl = userProv.user?.avatarUrl ?? '';
    final hasPhoto = avatarUrl.isNotEmpty;

    showGlassActionSheet(
      context,
      title: 'Profile photo',
      actions: [
        if (hasPhoto)
          GlassSheetAction(
            label: 'View photo',
            icon: Icons.visibility_outlined,
            onTap: () => _viewPhoto(context, avatarUrl),
          ),
        GlassSheetAction(
          label: 'Choose a photo',
          icon: Icons.photo_library_outlined,
          onTap: () => _choosePhoto(context),
        ),
        if (hasPhoto)
          GlassSheetAction(
            label: 'Remove photo',
            icon: Icons.delete_outline_rounded,
            destructive: true,
            onTap: () => _removePhoto(context),
          ),
      ],
    );
  }

  /// Shows the full-size profile photo over a black backdrop.
  void _viewPhoto(BuildContext context, String url) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, animation, _) =>
            FadeTransition(opacity: animation, child: _PhotoViewer(url: url)),
      ),
    );
  }

  Future<void> _choosePhoto(BuildContext context) async {
    final userProv = context.read<UserProvider>();

    final photo = await _pickPhoto(context);
    if (photo == null || !context.mounted) return;

    showAppSnackBar(context, 'Uploading photo…');
    final saved = await userProv.uploadAvatar(photo);
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      saved ? 'Photo updated' : userProv.error ?? 'Could not update your photo.',
      isError: !saved,
    );
  }

  /// Lets the user pick a photo, turning a picker or decode failure into a
  /// message instead of a crash.
  Future<DocumentUpload?> _pickPhoto(BuildContext context) async {
    try {
      return await pickAvatar();
    } catch (_) {
      if (context.mounted) {
        showAppSnackBar(context, 'Couldn\'t open that image. Try another one.', isError: true);
      }
      return null;
    }
  }

  Future<void> _removePhoto(BuildContext context) async {
    final userProv = context.read<UserProvider>();
    final removed = await userProv.removeAvatar();
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      removed ? 'Photo removed' : userProv.error ?? 'Could not remove your photo.',
      isError: !removed,
    );
  }

  // ── Layout ──────────────────────────────────────────────────────────────────

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
          _buildHeroCard(context),
          const SizedBox(height: 22),
          Selector<VaultProvider, VaultSummary>(
            selector: (_, vault) => vault.vaultSummary,
            builder: (context, summary, _) {
              return DashboardGrid(
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
                      icon: Icons.folder_outlined,
                      tintColor: AppColors.glassAccentBlue,
                      title: 'Documents',
                      meta:
                          '${countLabel(summary.documentsCount, 'file', 'files')} stored',
                      onTap: () =>
                          Navigator.of(context).pushNamed(AppRouter.documents),
                    ),
                  ),
                  FadeSlideIn(
                    index: 2,
                    child: DashboardGridCard(
                      icon: Icons.shield_outlined,
                      tintColor: AppColors.glassAccentGreen,
                      title: 'Security',
                      meta: summary.securityScoreLabel,
                      onTap: () =>
                          Navigator.of(context).pushNamed(AppRouter.security),
                    ),
                  ),
                  FadeSlideIn(
                    index: 3,
                    child: DashboardGridCard(
                      icon: Icons.people_outline_rounded,
                      tintColor: AppColors.glassAccentSecondary,
                      title: 'Trusted People',
                      meta: countLabel(
                        summary.trustedContactsCount,
                        'trustee',
                        'trustees',
                      ),
                      onTap: () => Navigator.of(
                        context,
                      ).pushNamed(AppRouter.trustedContacts),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Selector<UserProvider, DateTime?>(
            selector: (_, userProv) => userProv.user?.lastLogin,
            builder: (context, lastLogin, _) {
              return _buildRow(
                icon: Icons.history_rounded,
                tintColor: AppColors.glassOnSurfaceMuted,
                title: 'Last sign-in',
                meta: lastLogin == null ? 'Just now' : relativeTime(lastLogin),
              );
            },
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
            meta: 'Account, privacy, and more',
            onTap: () => Navigator.of(context).pushNamed(AppRouter.settings),
          ),
          const SizedBox(height: 22),
          _buildSignOutRow(context),
        ],
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    return Container(
      height: 160,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: AppRadius.radiusXXL,
        color: AppColors.glassSurface,
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(gradient: AppColors.glassPinkTint),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Selector<UserProvider, String?>(
                  selector: (_, userProv) => userProv.user?.avatarUrl,
                  builder: (context, avatarUrl, _) {
                    return GestureDetector(
                      onTap: () => _photoActions(context),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ProfileAvatar(
                            url: avatarUrl,
                            size: 60,
                            borderColor: Colors.white54,
                            borderWidth: 1,
                          ),
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppColors.glassAccentPink,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(width: 16),
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            userProv.displayEmail,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Selector<VaultProvider, double>(
                  selector: (_, vault) => vault.vaultSummary.legacyProgress,
                  builder: (context, progress, _) {
                    final pct = (progress * 100).round();
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

  /// A settings-style row. With no [onTap] it is informational: no chevron and
  /// no ripple, so nothing looks tappable that isn't.
  Widget _buildRow({
    required IconData icon,
    required Color tintColor,
    required String title,
    required String meta,
    VoidCallback? onTap,
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
                    Text(
                      title,
                      style: AppTextStyles.titleSmall.copyWith(
                        color: AppColors.glassOnSurface,
                        fontWeight: FontWeight.w600,
                      ),
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
              if (onTap != null)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.glassOnSurfaceFaint,
                ),
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

/// The profile photo shown full-size over black, dismissed by the close
/// button, the back gesture, or tapping the backdrop.
class _PhotoViewer extends StatelessWidget {
  final String url;

  const _PhotoViewer({required this.url});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: AppNetworkImage(
                  url: url,
                  fit: BoxFit.contain,
                  fallbackIcon: Icons.person_rounded,
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: CircularIconButton(
                  icon: Icons.close_rounded,
                  background: Colors.white24,
                  foreground: Colors.white,
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
