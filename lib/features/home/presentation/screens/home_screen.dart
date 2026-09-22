import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:everkeep/core/config/app_image_urls.dart';
import 'package:everkeep/core/routing/app_router.dart';
import 'package:everkeep/core/theme/app_colors.dart';
import 'package:everkeep/core/theme/app_text_styles.dart';
import 'package:everkeep/core/utils/greeting.dart';
import 'package:everkeep/core/utils/relative_time.dart';
import 'package:everkeep/models/legacy_checklist.dart';
import 'package:everkeep/models/recent_activity.dart';
import 'package:everkeep/models/vault_summary.dart';
import 'package:everkeep/providers/account_provider.dart';
import 'package:everkeep/providers/document_provider.dart';
import 'package:everkeep/providers/trusted_contact_provider.dart';
import 'package:everkeep/providers/user_provider.dart';
import 'package:everkeep/providers/vault_provider.dart';
import 'package:everkeep/widgets/fade_slide_in.dart';
import 'package:everkeep/widgets/glass/activity_row.dart';
import 'package:everkeep/widgets/glass/dashboard_grid_card.dart';
import 'package:everkeep/widgets/glass/glass_card.dart';
import 'package:everkeep/widgets/glass/glass_scaffold.dart';
import 'package:everkeep/widgets/glass/security_score_card.dart';
import 'package:everkeep/widgets/profile_avatar.dart';
import 'package:everkeep/widgets/progress_card.dart';

/// The signed-in home dashboard. Everything on it comes from the user's real
/// data: the checklist progress, the counts, and the recent activity.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  /// Where each unfinished setup step is done.
  static String routeFor(LegacyStep? step) => switch (step) {
    LegacyStep.addDocument => AppRouter.documents,
    LegacyStep.saveAccount => AppRouter.accounts,
    LegacyStep.addTrustedPerson => AppRouter.trustedContacts,
    LegacyStep.verifyEmail => AppRouter.settings,
    null => AppRouter.vault,
  };

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Header(),
          const SizedBox(height: 24),
          const _LegacyProgressCard(),
          const SizedBox(height: 24),
          Text(
            'Vault Chapters',
            style: AppTextStyles.serifLabel.copyWith(
              color: AppColors.glassOnSurface,
            ),
          ),
          const SizedBox(height: 14),
          const _ChaptersGrid(),
          const SizedBox(height: 26),
          Text(
            'RECENT ACTIVITY',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.glassOnSurfaceFaint,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          const _RecentActivity(),
          const SizedBox(height: 14),
          Selector<VaultProvider, VaultSummary>(
            selector: (_, vault) => vault.vaultSummary,
            builder: (context, summary, _) {
              return SecurityScoreCard(
                label: 'Security Score',
                scoreText: summary.securityScoreLabel,
                progress: (summary.securityScore / 100.0).clamp(0.0, 1.0),
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRouter.security),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${greetingFor(DateTime.now())},',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.glassOnSurfaceMuted,
                ),
              ),
              Selector<UserProvider, String>(
                selector: (_, userProv) => userProv.firstName,
                builder: (context, firstName, _) {
                  return Text(
                    firstName,
                    style: AppTextStyles.serifHeadline.copyWith(
                      color: AppColors.glassOnSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );
                },
              ),
            ],
          ),
        ),
        Selector<UserProvider, String?>(
          selector: (_, userProv) => userProv.user?.avatarUrl,
          builder: (context, avatarUrl, _) {
            return GestureDetector(
              onTap: () => Navigator.of(context).pushNamed(AppRouter.profile),
              child: ProfileAvatar(
                url: avatarUrl,
                size: 48,
                borderColor: AppColors.glassBorder,
                borderWidth: 1,
              ),
            );
          },
        ),
      ],
    );
  }
}

class _LegacyProgressCard extends StatelessWidget {
  const _LegacyProgressCard();

  @override
  Widget build(BuildContext context) {
    return Selector<VaultProvider, VaultSummary>(
      selector: (_, vault) => vault.vaultSummary,
      builder: (context, summary, _) {
        final checklist = summary.checklist;
        final next = checklist.nextStep;
        final percent = (checklist.progress * 100).round();

        final subtitle = next == null
            ? 'Everything is set up. Nicely done.'
            : '${countLabel(checklist.remaining, 'step', 'steps')} to go · '
                  '${next.prompt}';

        return ProgressCard(
          progress: checklist.progress,
          imageUrl: AppImageUrls.homeHeroCard,
          title: 'Your Legacy is $percent% Complete',
          subtitle: subtitle,
          onTap: () => Navigator.of(
            context,
          ).pushNamed(HomeScreen.routeFor(next)),
        );
      },
    );
  }
}

class _ChaptersGrid extends StatelessWidget {
  const _ChaptersGrid();

  @override
  Widget build(BuildContext context) {
    return Selector<VaultProvider, VaultSummary>(
      selector: (_, vault) => vault.vaultSummary,
      builder: (context, summary, _) {
        return DashboardGrid(
          cards: [
            FadeSlideIn(
              index: 0,
              child: DashboardGridCard(
                icon: Icons.folder_outlined,
                tintColor: AppColors.glassAccentSecondary,
                title: 'Documents',
                meta: '${countLabel(summary.documentsCount, 'file', 'files')} stored',
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRouter.documents),
              ),
            ),
            FadeSlideIn(
              index: 1,
              child: DashboardGridCard(
                icon: Icons.key_rounded,
                tintColor: AppColors.glassAccentBlue,
                title: 'Accounts',
                meta: '${countLabel(summary.accountsCount, 'login', 'logins')} saved',
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRouter.accounts),
              ),
            ),
            FadeSlideIn(
              index: 2,
              child: DashboardGridCard(
                icon: Icons.people_outline_rounded,
                tintColor: AppColors.glassAccentGreen,
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
            FadeSlideIn(
              index: 3,
              child: DashboardGridCard(
                icon: Icons.image_outlined,
                tintColor: AppColors.glassAccentPink,
                title: 'Memories',
                meta: 'Coming soon',
                onTap: () => Navigator.of(context).pushNamed(AppRouter.wishes),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity();

  static Color _colorFor(ActivityKind kind) => switch (kind) {
    ActivityKind.document => AppColors.glassAccentGreen,
    ActivityKind.account => AppColors.glassAccentBlue,
    ActivityKind.contact => AppColors.glassAccentPink,
  };

  static String _routeFor(ActivityKind kind) => switch (kind) {
    ActivityKind.document => AppRouter.documents,
    ActivityKind.account => AppRouter.accounts,
    ActivityKind.contact => AppRouter.trustedContacts,
  };

  @override
  Widget build(BuildContext context) {
    // Rebuilds when any of the three lists changes — a small widget, so cheap.
    final items = buildRecentActivity(
      documents: context.watch<DocumentProvider>().documents,
      accounts: context.watch<AccountProvider>().accounts,
      contacts: context.watch<TrustedContactProvider>().contacts,
    );

    if (items.isEmpty) {
      return GlassCard(
        onTap: () => Navigator.of(context).pushNamed(AppRouter.documents),
        child: Text(
          'Nothing here yet. Add a document, an account login or a trusted '
          'person and it will show up here.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.glassOnSurfaceMuted,
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final item in items) ...[
          ActivityRow(
            title: item.title,
            subtitle: '${item.kind.label} · ${relativeTime(item.at)}',
            dotColor: _colorFor(item.kind),
            onTap: () => Navigator.of(context).pushNamed(_routeFor(item.kind)),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
