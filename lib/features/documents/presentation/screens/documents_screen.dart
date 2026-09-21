import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:everkeep/core/theme/app_colors.dart';
import 'package:everkeep/core/theme/app_radius.dart';
import 'package:everkeep/core/theme/app_text_styles.dart';
import 'package:everkeep/models/vault_summary.dart';
import 'package:everkeep/providers/document_provider.dart';
import 'package:everkeep/providers/vault_provider.dart';
import 'package:everkeep/widgets/circular_icon_button.dart';
import 'package:everkeep/widgets/fade_slide_in.dart';
import 'package:everkeep/widgets/glass/glass_card.dart';
import 'package:everkeep/widgets/glass/glass_fab.dart';
import 'package:everkeep/widgets/glass/glass_filter_chips.dart';
import 'package:everkeep/widgets/glass/glass_item_row.dart';
import 'package:everkeep/widgets/glass/glass_page_header.dart';
import 'package:everkeep/widgets/glass/glass_scaffold.dart';
import 'package:everkeep/widgets/glass/status_badge.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  int _selectedFilter = 0;
  final List<String> _filters = const ['All', 'Legal', 'Financial', 'Medical'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final docProv = context.read<DocumentProvider>();
      if (!docProv.hasFetched) {
        docProv.fetchDocuments();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeFilter = _filters[_selectedFilter];

    return GlassScaffold(
      floatingActionButton: GlassFab(onPressed: () {}),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassPageHeader(
            title: 'Documents',
            showBackButton: Navigator.of(context).canPop(),
            trailing: CircularIconButton(
              icon: Icons.search_rounded,
              background: AppColors.glassSurface,
              foreground: AppColors.glassOnSurface,
              size: 40,
              onPressed: () {},
            ),
          ),
          const SizedBox(height: 18),
          _buildStorageCard(),
          const SizedBox(height: 18),
          GlassFilterChips(
            labels: _filters,
            selectedIndex: _selectedFilter,
            onSelected: (index) => setState(() => _selectedFilter = index),
          ),
          const SizedBox(height: 20),
          Consumer<DocumentProvider>(
            builder: (context, docProv, _) {
              if (docProv.isLoading && !docProv.hasFetched) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: CircularProgressIndicator(
                      color: AppColors.glassAccentPink,
                    ),
                  ),
                );
              }

              if (docProv.error != null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      docProv.error!,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.glassDestructive,
                      ),
                    ),
                  ),
                );
              }

              final displayedDocuments =
                  docProv.filterByCategory(activeFilter);

              if (displayedDocuments.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      'No documents found.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.glassOnSurfaceMuted,
                      ),
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  for (final entry in displayedDocuments.asMap().entries) ...[
                    FadeSlideIn(
                      index: entry.key,
                      child: GlassItemRow(
                        icon: entry.value.icon,
                        iconColor: AppColors.glassAccentPink,
                        title: entry.value.title,
                        subtitle: entry.value.subtitle,
                        trailing: entry.value.isVerified
                            ? const StatusBadge.success('Verified')
                            : const StatusBadge.pending('Pending'),
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStorageCard() {
    return Selector<VaultProvider, VaultSummary>(
      selector: (_, vault) => vault.vaultSummary,
      builder: (context, summary, _) {
        final usedMb = summary.storageUsedMb;
        final totalGb = (summary.storageLimitMb / 1024).toStringAsFixed(0);
        final ratio = (summary.storageUsedMb / summary.storageLimitMb)
            .clamp(0.0, 1.0);

        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Vault Storage',
                    style: AppTextStyles.titleSmall.copyWith(
                      color: AppColors.glassOnSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${usedMb.toStringAsFixed(1)} MB of $totalGb GB used',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.glassOnSurfaceMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: AppRadius.radiusPill,
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 8,
                  backgroundColor: AppColors.glassBorder,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.glassAccentPink,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
