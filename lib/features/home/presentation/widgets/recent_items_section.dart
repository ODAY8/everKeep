import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/relative_time.dart';
import '../../../../models/recent_activity.dart';
import '../../../../providers/account_provider.dart';
import '../../../../providers/document_provider.dart';
import '../../../../providers/memory_provider.dart';
import '../../../../providers/trusted_contact_provider.dart';
import '../../../../widgets/glass/activity_row.dart';
import '../../../../widgets/glass/glass_card.dart';

/// The "Recent" section on the Dashboard.
/// Shows recently added memories, documents, accounts, and trusted contacts.
class RecentItemsSection extends StatelessWidget {
  const RecentItemsSection({super.key});

  static Color _colorFor(ActivityKind kind) => switch (kind) {
    ActivityKind.document => AppColors.glassAccentSecondary,
    ActivityKind.memory => AppColors.glassAccentPink,
    ActivityKind.account => AppColors.glassAccentBlue,
    ActivityKind.contact => AppColors.glassAccentGreen,
  };

  static String _routeFor(ActivityKind kind) => switch (kind) {
    ActivityKind.document => AppRouter.documents,
    ActivityKind.memory => AppRouter.wishes,
    ActivityKind.account => AppRouter.accounts,
    ActivityKind.contact => AppRouter.trustedContacts,
  };

  @override
  Widget build(BuildContext context) {
    final documents = context.watch<DocumentProvider>().documents;
    final memories = context.watch<MemoryProvider>().items;
    final accounts = context.watch<AccountProvider>().accounts;
    final contacts = context.watch<TrustedContactProvider>().contacts;

    final items = buildRecentActivity(
      documents: documents,
      memories: memories,
      accounts: accounts,
      contacts: contacts,
      limit: 4,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RECENT',
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.glassOnSurfaceFaint,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          GlassCard(
            onTap: () => Navigator.of(context).pushNamed(AppRouter.documents),
            child: Text(
              'Nothing here yet. Add a document, memory, account login or trusted person and it will show up here.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.glassOnSurfaceMuted,
              ),
            ),
          )
        else
          Column(
            children: [
              for (final item in items) ...[
                ActivityRow(
                  title: item.title,
                  subtitle: '${item.kind.label} · ${relativeTime(item.at)}',
                  dotColor: _colorFor(item.kind),
                  onTap: () =>
                      Navigator.of(context).pushNamed(_routeFor(item.kind)),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
      ],
    );
  }
}
