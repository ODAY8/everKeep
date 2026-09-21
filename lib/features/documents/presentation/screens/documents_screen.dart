import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:everkeep/core/theme/app_colors.dart';
import 'package:everkeep/core/theme/app_radius.dart';
import 'package:everkeep/core/theme/app_text_styles.dart';
import 'package:everkeep/models/document_item.dart';
import 'package:everkeep/models/vault_summary.dart';
import 'package:everkeep/providers/document_provider.dart';
import 'package:everkeep/providers/vault_provider.dart';
import 'package:everkeep/widgets/circular_icon_button.dart';
import 'package:everkeep/widgets/fade_slide_in.dart';
import 'package:everkeep/widgets/feedback.dart';
import 'package:everkeep/widgets/glass/glass_card.dart';
import 'package:everkeep/widgets/glass/glass_fab.dart';
import 'package:everkeep/widgets/glass/glass_filter_chips.dart';
import 'package:everkeep/widgets/glass/glass_item_row.dart';
import 'package:everkeep/widgets/glass/glass_page_header.dart';
import 'package:everkeep/widgets/glass/glass_scaffold.dart';
import 'package:everkeep/widgets/glass/glass_sheet.dart';
import 'package:everkeep/widgets/glass/status_badge.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  static const List<String> _categories = ['Legal', 'Financial', 'Medical'];

  int _selectedFilter = 0;
  final List<String> _filters = const ['All', ..._categories];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final docProv = context.read<DocumentProvider>();
      if (!docProv.hasFetched) {
        docProv.fetchDocuments();
      }
    });
  }

  Future<void> _addDocument() async {
    final docProv = context.read<DocumentProvider>();
    final saved = await showGlassFormSheet(
      context,
      title: 'Add Document',
      subtitle: 'Keep an important file safe in your vault.',
      submitLabel: 'Add Document',
      fields: const [
        GlassFormField(
          key: 'title',
          label: 'Document name',
          hint: 'e.g. Passport.pdf',
        ),
      ],
      choices: const [
        GlassFormChoice(
          key: 'category',
          label: 'Category',
          options: _categories,
        ),
      ],
      onSubmit: (values) async {
        final category = values['category']!;
        final added = await docProv.addDocument(
          // The id and the "Added ..." subtitle are assigned by the backend;
          // the saved document comes back with both.
          DocumentItem(
            id: '',
            title: values['title']!,
            subtitle: '',
            category: category,
          ),
        );
        return added ? null : docProv.error ?? 'Could not add the document.';
      },
    );

    if (saved && mounted) showAppSnackBar(context, 'Document added');
  }

  void _showActions(DocumentItem document) {
    showGlassActionSheet(
      context,
      title: document.title,
      subtitle: document.subtitle,
      actions: [
        GlassSheetAction(
          label: 'Delete document',
          icon: Icons.delete_outline_rounded,
          destructive: true,
          onTap: () => _confirmDelete(document),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(DocumentItem document) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete document?',
      message: '"${document.title}" will be permanently removed from your vault.',
      confirmLabel: 'Delete',
    );
    if (!confirmed || !mounted) return;

    final docProv = context.read<DocumentProvider>();
    final deleted = await docProv.deleteDocument(document.id);
    if (!mounted) return;

    showAppSnackBar(
      context,
      deleted
          ? 'Document deleted'
          : docProv.error ?? 'Could not delete the document.',
      isError: !deleted,
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeFilter = _filters[_selectedFilter];

    return GlassScaffold(
      floatingActionButton: GlassFab(onPressed: _addDocument),
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
              // Only a failed *first load* replaces the list. A failed
              // add/delete leaves the list alone and is reported in a
              // snackbar by whoever triggered it.
              if (!docProv.hasFetched) {
                final loadError = docProv.error;
                if (loadError != null && !docProv.isLoading) {
                  return ErrorRetryView(
                    message: loadError,
                    onRetry: docProv.fetchDocuments,
                  );
                }
                return const LoadingView();
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
                        onTap: () => _showActions(entry.value),
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
