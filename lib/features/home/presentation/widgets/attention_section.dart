import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/document_expiration.dart';
import '../../../../models/document_item.dart';
import '../../../../providers/document_provider.dart';
import '../../../../widgets/glass/glass_card.dart';

/// The central "What needs my attention?" section on the Dashboard.
/// Displays expiring documents, expired items, and urgent vault alerts.
class AttentionSection extends StatelessWidget {
  const AttentionSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'WHAT NEEDS MY ATTENTION',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.glassOnSurfaceFaint,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
            Consumer<DocumentProvider>(
              builder: (context, docProv, _) {
                final expiredCount = docProv.expiredDocuments.length;
                final expiringCount = docProv.expiringSoonDocuments.length;
                if (expiredCount == 0 && expiringCount == 0) return const SizedBox.shrink();

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (expiredCount > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.glassDestructive.withValues(alpha: 0.16),
                          borderRadius: AppRadius.radiusPill,
                          border: Border.all(
                            color: AppColors.glassDestructive.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          '$expiredCount expired',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.glassDestructive,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (expiringCount > 0) const SizedBox(width: 6),
                    ],
                    if (expiringCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.glassWarningBg,
                          borderRadius: AppRadius.radiusPill,
                          border: Border.all(
                            color: AppColors.glassWarningColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          '$expiringCount expiring soon',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.glassWarningColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        Consumer<DocumentProvider>(
          builder: (context, docProv, _) {
            if (!docProv.hasFetched && docProv.isLoading) {
              return const _LoadingCard();
            }

            final items = docProv.attentionDocuments;

            if (items.isEmpty) {
              return const _CalmEmptyStateCard();
            }

            return Column(
              children: [
                for (final item in items.take(4)) ...[
                  _AttentionItemCard(
                    document: item,
                    onTap: () =>
                        Navigator.of(context).pushNamed(AppRouter.documents),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AttentionItemCard extends StatelessWidget {
  final DocumentItem document;
  final VoidCallback onTap;

  const _AttentionItemCard({
    required this.document,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isExpired = document.isExpired;
    final accentColor = isExpired
        ? AppColors.glassDestructive
        : AppColors.glassWarningColor;
    final bgColor = isExpired
        ? AppColors.glassDestructive.withValues(alpha: 0.14)
        : AppColors.glassWarningBg;

    final shortText = DocumentExpirationHelper.shortLabel(document.expiryDate);
    final statusHeader = isExpired
        ? '⚠️ Expired · ${document.expirationNotice}'
        : '⏳ Expiring soon · ${document.expirationNotice}';

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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: AppRadius.radiusMD,
              border: Border.all(
                color: accentColor.withValues(alpha: 0.3),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              document.emoji,
              style: const TextStyle(fontSize: 20),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusHeader,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: accentColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  document.title,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: AppColors.glassOnSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  metadataSubtitle,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.glassOnSurfaceMuted,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: AppRadius.radiusPill,
              border: Border.all(color: accentColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              isExpired ? 'Expired' : shortText,
              style: AppTextStyles.labelSmall.copyWith(
                color: accentColor,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalmEmptyStateCard extends StatelessWidget {
  const _CalmEmptyStateCard();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.glassSuccessBg,
              borderRadius: AppRadius.radiusMD,
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              color: AppColors.glassAccentGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'All documents up to date',
                  style: AppTextStyles.titleSmall.copyWith(
                    color: AppColors.glassOnSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Nothing expiring soon or requiring immediate attention.',
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
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const GlassCard(
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.glassAccentPink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
