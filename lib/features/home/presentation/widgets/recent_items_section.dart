import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/document_expiration.dart';
import '../../../../core/utils/relative_time.dart';
import '../../../../models/document_item.dart';
import '../../../../models/memory_item.dart';
import '../../../../models/recent_activity.dart';
import '../../../../providers/account_provider.dart';
import '../../../../providers/document_provider.dart';
import '../../../../providers/memory_provider.dart';
import '../../../../providers/trusted_contact_provider.dart';
import '../../../../widgets/glass/activity_row.dart';
import '../../../../widgets/glass/glass_card.dart';
import '../../../../widgets/glass/glass_filter_chips.dart';
import '../../../../widgets/glass/status_badge.dart';

/// The "Recent" section on the Dashboard.
/// Shows recently added memories, documents, accounts, and trusted contacts,
/// with instant tabs for Recent Documents and Recent Memories.
class RecentItemsSection extends StatefulWidget {
  const RecentItemsSection({super.key});

  @override
  State<RecentItemsSection> createState() => _RecentItemsSectionState();
}

class _RecentItemsSectionState extends State<RecentItemsSection> {
  int _selectedFilter = 0;
  static const List<String> _filters = [
    'All Recent',
    'Recent Documents',
    'Recent Memories',
  ];

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

    final allItems = buildRecentActivity(
      documents: documents,
      memories: memories,
      accounts: accounts,
      contacts: contacts,
      limit: 4,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'RECENT',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.glassOnSurfaceFaint,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
            GestureDetector(
              onTap: () {
                if (_selectedFilter == 1) {
                  Navigator.of(context).pushNamed(AppRouter.documents);
                } else if (_selectedFilter == 2) {
                  Navigator.of(context).pushNamed(AppRouter.wishes);
                } else {
                  Navigator.of(context).pushNamed(AppRouter.vault);
                }
              },
              behavior: HitTestBehavior.opaque,
              child: Text(
                _selectedFilter == 1
                    ? 'All documents'
                    : (_selectedFilter == 2 ? 'All memories' : 'Explore all'),
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.glassAccentPink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GlassFilterChips(
          labels: _filters,
          selectedIndex: _selectedFilter,
          onSelected: (index) => setState(() => _selectedFilter = index),
        ),
        const SizedBox(height: 14),
        if (_selectedFilter == 0) ...[
          if (allItems.isEmpty)
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
                for (final item in allItems) ...[
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
        ] else if (_selectedFilter == 1) ...[
          _buildRecentDocumentsView(context, documents),
        ] else ...[
          _buildRecentMemoriesView(context, memories),
        ],
      ],
    );
  }

  Widget _buildRecentDocumentsView(
    BuildContext context,
    List<DocumentItem> documents,
  ) {
    if (documents.isEmpty) {
      return GlassCard(
        onTap: () => Navigator.of(context).pushNamed(AppRouter.documents),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.glassAccentSecondary.withValues(alpha: 0.14),
                borderRadius: AppRadius.radiusMD,
              ),
              child: const Icon(
                Icons.note_add_outlined,
                color: AppColors.glassAccentSecondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No documents yet',
                    style: AppTextStyles.titleSmall.copyWith(
                      color: AppColors.glassOnSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap to add your first document to your secure vault.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.glassOnSurfaceMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final recentDocs = List<DocumentItem>.from(documents)
      ..sort((a, b) {
        final aDate = a.dateAdded ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.dateAdded ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

    return Column(
      children: [
        for (final doc in recentDocs.take(4)) ...[
          _RecentDocumentCard(
            document: doc,
            onTap: () => Navigator.of(context).pushNamed(AppRouter.documents),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildRecentMemoriesView(
    BuildContext context,
    List<MemoryItem> memories,
  ) {
    if (memories.isEmpty) {
      return GlassCard(
        onTap: () => Navigator.of(context).pushNamed(AppRouter.wishes),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.glassAccentPink.withValues(alpha: 0.14),
                borderRadius: AppRadius.radiusMD,
              ),
              child: const Icon(
                Icons.favorite_outline_rounded,
                color: AppColors.glassAccentPink,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No memories preserved yet',
                    style: AppTextStyles.titleSmall.copyWith(
                      color: AppColors.glassOnSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap to record a story, message, or meaningful moment.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.glassOnSurfaceMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final recentMems = List<MemoryItem>.from(memories)
      ..sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

    return Column(
      children: [
        for (final mem in recentMems.take(4)) ...[
          _RecentMemoryCard(
            memory: mem,
            onTap: () => Navigator.of(context).pushNamed(AppRouter.wishes),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _RecentDocumentCard extends StatelessWidget {
  final DocumentItem document;
  final VoidCallback onTap;

  const _RecentDocumentCard({
    required this.document,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String metadataSubtitle;
    if (document.country != null && document.country!.isNotEmpty) {
      metadataSubtitle = '${document.displayType} · ${document.country}';
    } else if (document.institution != null && document.institution!.isNotEmpty) {
      metadataSubtitle = '${document.displayType} · ${document.institution}';
    } else {
      metadataSubtitle = document.displayType;
    }

    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.glassSurface,
              borderRadius: AppRadius.radiusMD,
              border: Border.all(color: AppColors.glassBorder),
            ),
            alignment: Alignment.center,
            child: Text(document.emoji, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  document.title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.glassOnSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  document.dateAdded != null
                      ? '$metadataSubtitle · ${relativeTime(document.dateAdded!)}'
                      : metadataSubtitle,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.glassOnSurfaceMuted,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (document.isExpired)
            const StatusBadge.danger('Expired')
          else if (document.isExpiringSoon)
            StatusBadge.warning(
              DocumentExpirationHelper.shortLabel(document.expiryDate),
            )
          else
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.glassOnSurfaceFaint,
              size: 18,
            ),
        ],
      ),
    );
  }
}

class _RecentMemoryCard extends StatelessWidget {
  final MemoryItem memory;
  final VoidCallback onTap;

  const _RecentMemoryCard({
    required this.memory,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.glassAccentPink.withValues(alpha: 0.14),
              borderRadius: AppRadius.radiusMD,
            ),
            child: Icon(
              memory.isWish ? Icons.star_rounded : Icons.favorite_rounded,
              color: AppColors.glassAccentPink,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  memory.title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.glassOnSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  memory.content.isNotEmpty
                      ? memory.content
                      : (memory.createdAt != null
                          ? relativeTime(memory.createdAt!)
                          : memory.type),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.glassOnSurfaceMuted,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.glassOnSurfaceFaint,
            size: 18,
          ),
        ],
      ),
    );
  }
}
