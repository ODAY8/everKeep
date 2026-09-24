import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:everkeep/core/config/app_image_urls.dart';
import 'package:everkeep/core/routing/app_router.dart';
import 'package:everkeep/core/utils/greeting.dart';
import 'package:everkeep/models/legacy_checklist.dart';
import 'package:everkeep/models/vault_summary.dart';
import 'package:everkeep/providers/account_provider.dart';
import 'package:everkeep/providers/document_provider.dart';
import 'package:everkeep/providers/memory_provider.dart';
import 'package:everkeep/providers/trusted_contact_provider.dart';
import 'package:everkeep/providers/vault_provider.dart';
import 'package:everkeep/widgets/glass/glass_scaffold.dart';
import 'package:everkeep/widgets/glass/security_score_card.dart';
import 'package:everkeep/widgets/progress_card.dart';

import '../widgets/attention_section.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/quick_actions_section.dart';
import '../widgets/recent_items_section.dart';
import '../widgets/vault_overview_section.dart';

/// The central screen of EverKeep — Personal Life Vault Dashboard.
/// Answers: "What needs my attention?" and organizes all core vault chapters.
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

  Future<void> _refreshAll(BuildContext context) async {
    await Future.wait([
      context.read<DocumentProvider>().fetchDocuments(),
      context.read<MemoryProvider>().fetchMemories(),
      context.read<AccountProvider>().fetchAccounts(),
      context.read<TrustedContactProvider>().fetchContacts(),
      context.read<VaultProvider>().fetchVaultSummary(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      onRefresh: () => _refreshAll(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DashboardHeader(),
          const SizedBox(height: 24),
          const AttentionSection(),
          const SizedBox(height: 26),
          const VaultOverviewSection(),
          const SizedBox(height: 22),
          const _LegacyProgressCard(),
          const SizedBox(height: 26),
          const QuickActionsSection(),
          const SizedBox(height: 26),
          const RecentItemsSection(),
          const SizedBox(height: 22),
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
          const SizedBox(height: 20),
        ],
      ),
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
