import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/document_expiration.dart';
import '../../../../core/utils/pick_upload.dart';
import '../../../../models/document_item.dart';
import '../../../../models/document_upload.dart';
import '../../../../models/vault_summary.dart';
import '../../../../providers/document_provider.dart';
import '../../../../providers/vault_provider.dart';
import '../../../../widgets/circular_icon_button.dart';
import '../../../../widgets/fade_slide_in.dart';
import '../../../../widgets/feedback.dart';
import '../../../../widgets/glass/glass_card.dart';
import '../../../../widgets/glass/glass_fab.dart';
import '../../../../widgets/glass/glass_filter_chips.dart';
import '../../../../widgets/glass/glass_page_header.dart';
import '../../../../widgets/glass/glass_scaffold.dart';
import '../../../../widgets/glass/glass_search_bar.dart';
import '../../../../widgets/glass/glass_sheet.dart';
import '../../../../widgets/glass/status_badge.dart';
import '../widgets/document_details_sheet.dart';
import '../widgets/document_form_sheet.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  static const List<String> _filters = [
    'All',
    'Expiring Soon',
    'Expired',
    'No Expiry',
    'Legal',
    'Financial',
    'Medical',
  ];

  int _selectedFilter = 0;
  bool _searching = false;
  String _query = '';

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

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) _query = '';
    });
  }

  void _chooseHowToAdd() {
    showGlassActionSheet(
      context,
      title: 'Add Document',
      subtitle: 'Store a file securely, or just keep a record of it.',
      actions: [
        GlassSheetAction(
          label: 'Choose a file',
          icon: Icons.upload_file_rounded,
          onTap: _pickThenAdd,
        ),
        GlassSheetAction(
          label: 'Add without a file',
          icon: Icons.edit_note_rounded,
          onTap: () => _openAddForm(),
        ),
      ],
    );
  }

  Future<void> _pickThenAdd() async {
    try {
      final upload = await pickDocument();
      if (upload != null && mounted) {
        await _openAddForm(upload: upload);
      }
    } on PickedTooLarge catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          'Couldn\'t read that file. Try another one.',
          isError: true,
        );
      }
    }
  }

  Future<void> _openAddForm({DocumentUpload? upload}) async {
    final saved = await DocumentFormSheet.show(context, initialUpload: upload);
    if (saved == true && mounted) {
      showAppSnackBar(
        context,
        upload == null ? 'Document added' : 'Document uploaded',
      );
    }
  }

  Future<void> _showEditForm(DocumentItem document) async {
    final saved = await DocumentFormSheet.show(context, document: document);
    if (saved == true && mounted) {
      showAppSnackBar(context, 'Document updated');
    }
  }

  void _showDetails(DocumentItem document) {
    showGlassSheet<void>(
      context,
      builder: (sheetContext) => DocumentDetailsSheet(
        document: document,
        onEdit: () {
          Navigator.of(sheetContext).pop();
          _showEditForm(document);
        },
        onDelete: () {
          Navigator.of(sheetContext).pop();
          _confirmDelete(document);
        },
        onOpenFile: document.hasFile ? () => _openFile(document) : null,
      ),
    );
  }

  void _showActions(DocumentItem document) {
    showGlassActionSheet(
      context,
      title: document.title,
      subtitle: document.subtitle,
      actions: [
        GlassSheetAction(
          label: 'View details',
          icon: Icons.visibility_outlined,
          onTap: () => _showDetails(document),
        ),
        GlassSheetAction(
          label: 'Edit document',
          icon: Icons.edit_outlined,
          onTap: () => _showEditForm(document),
        ),
        if (document.hasFile)
          GlassSheetAction(
            label: 'Open file',
            icon: Icons.open_in_new_rounded,
            onTap: () => _openFile(document),
          ),
        GlassSheetAction(
          label: 'Delete document',
          icon: Icons.delete_outline_rounded,
          destructive: true,
          onTap: () => _confirmDelete(document),
        ),
      ],
    );
  }

  Future<void> _openFile(DocumentItem document) {
    final docProv = context.read<DocumentProvider>();
    return openRemoteFile(
      context,
      fetchUrl: () => docProv.downloadUrlFor(document),
      errorMessage: () => docProv.error,
    );
  }

  Future<void> _confirmDelete(DocumentItem document) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete document?',
      message:
          '"${document.title}" will be permanently removed from your vault.',
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
      floatingActionButton: GlassFab(onPressed: _chooseHowToAdd),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassPageHeader(
            title: 'Documents',
            showBackButton: Navigator.of(context).canPop(),
            trailing: CircularIconButton(
              icon: _searching ? Icons.close_rounded : Icons.search_rounded,
              background: AppColors.glassSurface,
              foreground: AppColors.glassOnSurface,
              size: 40,
              tooltip: _searching ? 'Close search' : 'Search documents',
              onPressed: _toggleSearch,
            ),
          ),
          const SizedBox(height: 18),
          if (_searching) ...[
            GlassSearchBar(
              hintText: 'Search title, type, country, institution...',
              autofocus: true,
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 18),
          ],
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

              final displayedDocuments = docProv.filterDocuments(
                filter: activeFilter,
                query: _query,
              );

              if (displayedDocuments.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _query.trim().isNotEmpty
                              ? Icons.search_off_rounded
                              : Icons.folder_open_outlined,
                          size: 42,
                          color: AppColors.glassOnSurfaceFaint,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _query.trim().isNotEmpty
                              ? 'No documents match "${_query.trim()}".'
                              : (_selectedFilter > 0
                                  ? 'No documents in "$activeFilter".'
                                  : 'No documents yet. Tap + to add one.'),
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.glassOnSurfaceMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  for (final entry in displayedDocuments.asMap().entries) ...[
                    FadeSlideIn(
                      index: entry.key,
                      child: _DocumentCard(
                        document: entry.value,
                        onTap: () => _showActions(entry.value),
                        onLongPress: () => _showDetails(entry.value),
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
        final ratio = (summary.storageUsedMb / summary.storageLimitMb).clamp(
          0.0,
          1.0,
        );

        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Vault Storage',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.glassOnSurfaceMuted,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    '${usedMb.toStringAsFixed(1)} MB of $totalGb GB',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.glassAccentPink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: AppRadius.radiusPill,
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 4,
                  backgroundColor: AppColors.glassBorder,
                  valueColor: const AlwaysStoppedAnimation(
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

/// Clean, structured document card displaying emoji/icon, title, document type,
/// contextual metadata (country/institution), expiration status, and file indicator.
class _DocumentCard extends StatelessWidget {
  final DocumentItem document;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _DocumentCard({
    required this.document,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final status = document.expirationStatus;
    final statusColor = DocumentExpirationHelper.colorFor(status);

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
      onLongPress: onLongPress,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Leading Emoji / Icon
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: status.isExpired
                    ? AppColors.glassDestructive.withValues(alpha: 0.14)
                    : (status.isExpiringSoon
                        ? AppColors.glassWarningBg
                        : AppColors.glassSurface),
                borderRadius: AppRadius.radiusMD,
                border: Border.all(
                  color: status.isExpired
                      ? AppColors.glassDestructive.withValues(alpha: 0.3)
                      : (status.isExpiringSoon
                          ? AppColors.glassWarningColor.withValues(alpha: 0.3)
                          : AppColors.glassBorder),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                document.emoji,
                style: const TextStyle(fontSize: 20),
              ),
            ),
            const SizedBox(width: 14),

            // Center details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          document.title,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.glassOnSurface,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (document.hasFile) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.attach_file_rounded,
                          size: 14,
                          color: AppColors.glassOnSurfaceMuted,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    metadataSubtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.glassOnSurfaceMuted,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (document.hasExpiryDate) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          document.expirationNotice,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Trailing badge
            _buildTrailingBadge(),
          ],
        ),
    );
  }

  Widget _buildTrailingBadge() {
    if (document.isExpired) {
      return const StatusBadge.danger('Expired');
    }
    if (document.isExpiringSoon) {
      return StatusBadge.warning(
        DocumentExpirationHelper.shortLabel(document.expiryDate),
      );
    }
    if (document.isVerified) {
      return const StatusBadge.success('Verified');
    }
    return const Icon(
      Icons.chevron_right_rounded,
      color: AppColors.glassOnSurfaceFaint,
      size: 18,
    );
  }
}
