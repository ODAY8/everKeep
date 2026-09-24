import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:everkeep/core/theme/app_colors.dart';
import 'package:everkeep/core/theme/app_radius.dart';
import 'package:everkeep/core/theme/app_text_styles.dart';
import 'package:everkeep/core/utils/document_expiration.dart';
import 'package:everkeep/core/utils/pick_upload.dart';
import 'package:everkeep/models/document_item.dart';
import 'package:everkeep/models/document_upload.dart';
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
import 'package:everkeep/widgets/glass/glass_primary_button.dart';
import 'package:everkeep/widgets/glass/glass_scaffold.dart';
import 'package:everkeep/widgets/glass/glass_search_bar.dart';
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

  // ── Adding ──────────────────────────────────────────────────────────────────

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
          onTap: () => _showAddForm(),
        ),
      ],
    );
  }

  Future<void> _pickThenAdd() async {
    DocumentUpload? upload;
    try {
      upload = await pickDocument();
    } on PickedTooLarge catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
      return;
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          'Couldn\'t read that file. Try another one.',
          isError: true,
        );
      }
      return;
    }
    if (upload == null || !mounted) return; // cancelled
    await _showAddForm(upload: upload);
  }

  Future<void> _showAddForm({DocumentUpload? upload}) async {
    final docProv = context.read<DocumentProvider>();
    final fileName = upload?.fileName;

    final saved = await showGlassFormSheet(
      context,
      title: 'Add Document',
      subtitle: upload == null
          ? 'Keep a record of an important document.'
          : 'Attached: $fileName',
      submitLabel: upload == null ? 'Add Document' : 'Upload & Add',
      fields: [
        GlassFormField(
          key: 'title',
          label: 'Document name',
          hint: 'e.g. Passport.pdf',
          initialValue: fileName ?? '',
          validator: (value) =>
              value.trim().isEmpty ? 'Document name is required' : null,
        ),
      ],
      choices: const [
        GlassFormChoice(
          key: 'category',
          label: 'Category',
          options: _categories,
        ),
      ],
      dateFields: const [
        GlassFormDateField(key: 'expiry_date', label: 'Expiry date (optional)'),
        GlassFormDateField(key: 'issue_date', label: 'Issue date (optional)'),
      ],
      onSubmit: (values) async {
        final expiryStr = values['expiry_date'];
        final issueStr = values['issue_date'];

        final added = await docProv.addDocument(
          DocumentItem(
            id: '',
            title: values['title']!,
            subtitle: '',
            category: values['category']!,
            expiryDate: expiryStr != null && expiryStr.isNotEmpty
                ? DateTime.tryParse(expiryStr)
                : null,
            issueDate: issueStr != null && issueStr.isNotEmpty
                ? DateTime.tryParse(issueStr)
                : null,
          ),
          upload: upload,
        );
        return added ? null : docProv.error ?? 'Could not add the document.';
      },
    );

    if (saved && mounted) {
      showAppSnackBar(
        context,
        upload == null ? 'Document added' : 'Document uploaded',
      );
    }
  }

  // ── Editing & Details ───────────────────────────────────────────────────────

  Future<void> _showEditForm(DocumentItem document) async {
    final docProv = context.read<DocumentProvider>();

    final initialCategoryIndex = _categories.indexOf(document.category);

    final saved = await showGlassFormSheet(
      context,
      title: 'Edit Document',
      subtitle: document.title,
      submitLabel: 'Save Changes',
      fields: [
        GlassFormField(
          key: 'title',
          label: 'Document name',
          hint: 'e.g. Passport or Insurance Policy',
          initialValue: document.title,
          validator: (v) =>
              v.trim().isEmpty ? 'Document name is required' : null,
        ),
      ],
      choices: [
        GlassFormChoice(
          key: 'category',
          label: 'Category',
          options: _categories,
          initialIndex: initialCategoryIndex != -1 ? initialCategoryIndex : 0,
        ),
      ],
      dateFields: [
        GlassFormDateField(
          key: 'expiry_date',
          label: 'Expiry date (optional)',
          initialValue: document.expiryDate,
        ),
        GlassFormDateField(
          key: 'issue_date',
          label: 'Issue date (optional)',
          initialValue: document.issueDate,
        ),
      ],
      onSubmit: (values) async {
        final expiryStr = values['expiry_date'];
        final issueStr = values['issue_date'];

        final ok = await docProv.updateDocument(
          document.copyWith(
            title: values['title']!,
            category: values['category']!,
            expiryDate: expiryStr != null && expiryStr.isNotEmpty
                ? DateTime.tryParse(expiryStr)
                : null,
            issueDate: issueStr != null && issueStr.isNotEmpty
                ? DateTime.tryParse(issueStr)
                : null,
          ),
        );
        return ok ? null : docProv.error ?? 'Could not save changes.';
      },
    );

    if (saved && mounted) {
      showAppSnackBar(context, 'Document updated');
    }
  }

  void _showDetails(DocumentItem document) {
    showGlassSheet<void>(
      context,
      builder: (_) => _DocumentDetailsSheet(document: document),
    );
  }

  // ── Existing documents ──────────────────────────────────────────────────────

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
        if (document.filePath != null)
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

  // ── Layout ──────────────────────────────────────────────────────────────────

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
              hintText: 'Search documents...',
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

              final displayedDocuments = docProv.filterByCategory(
                activeFilter,
                query: _query,
              );

              if (displayedDocuments.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      _query.trim().isNotEmpty
                          ? 'No documents match "${_query.trim()}".'
                          : 'No documents yet. Tap + to add one.',
                      textAlign: TextAlign.center,
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
                        iconColor: entry.value.isExpired
                            ? AppColors.glassDestructive
                            : (entry.value.isExpiringSoon
                                ? AppColors.glassWarningColor
                                : AppColors.glassAccentPink),
                        title: entry.value.title,
                        subtitle: entry.value.isExpired
                            ? '⚠️ Expired · ${entry.value.subtitle}'
                            : (entry.value.isExpiringSoon
                                ? '⚠️ ${entry.value.expirationNotice} · ${entry.value.category}'
                                : entry.value.subtitle),
                        trailing: _buildTrailingBadge(entry.value),
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

  Widget _buildTrailingBadge(DocumentItem doc) {
    if (doc.isExpired) {
      return const StatusBadge.danger('Expired');
    }
    if (doc.isExpiringSoon) {
      return StatusBadge.warning(
        DocumentExpirationHelper.shortLabel(doc.expiryDate),
      );
    }
    return doc.isVerified
        ? const StatusBadge.success('Verified')
        : const StatusBadge.pending('Pending');
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

class _DocumentDetailsSheet extends StatelessWidget {
  final DocumentItem document;

  const _DocumentDetailsSheet({required this.document});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: document.isExpired
                    ? AppColors.glassDestructive.withValues(alpha: 0.16)
                    : (document.isExpiringSoon
                        ? AppColors.glassWarningBg
                        : AppColors.glassAccentSecondaryBg),
                borderRadius: AppRadius.radiusLG,
              ),
              child: Icon(
                document.icon,
                color: document.isExpired
                    ? AppColors.glassDestructive
                    : (document.isExpiringSoon
                        ? AppColors.glassWarningColor
                        : AppColors.glassAccentSecondary),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.title,
                    style: AppTextStyles.serifTitleSmall.copyWith(
                      color: AppColors.glassOnSurface,
                      fontSize: 18,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    document.subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.glassOnSurfaceMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: DocumentExpirationHelper.backgroundColorFor(
              document.expirationStatus,
            ),
            borderRadius: AppRadius.radiusMD,
            border: Border.all(
              color: DocumentExpirationHelper.colorFor(
                document.expirationStatus,
              ).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                document.isExpired
                    ? Icons.warning_amber_rounded
                    : (document.isExpiringSoon
                        ? Icons.schedule_rounded
                        : Icons.verified_user_outlined),
                color: DocumentExpirationHelper.colorFor(
                  document.expirationStatus,
                ),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  document.expirationNotice,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: DocumentExpirationHelper.colorFor(
                      document.expirationStatus,
                    ),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (document.issueDate != null) ...[
          _DetailRow(
            label: 'Issue Date',
            value:
                '${document.issueDate!.year}-${document.issueDate!.month.toString().padLeft(2, '0')}-${document.issueDate!.day.toString().padLeft(2, '0')}',
          ),
          const SizedBox(height: 8),
        ],
        if (document.expiryDate != null) ...[
          _DetailRow(
            label: 'Expiry Date',
            value:
                '${document.expiryDate!.year}-${document.expiryDate!.month.toString().padLeft(2, '0')}-${document.expiryDate!.day.toString().padLeft(2, '0')}',
          ),
          const SizedBox(height: 8),
        ],
        _DetailRow(label: 'Category', value: document.category),
        if (document.filePath != null) ...[
          const SizedBox(height: 8),
          const _DetailRow(label: 'Stored File', value: 'Saved in secure vault'),
        ],
        if (document.description != null &&
            document.description!.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Notes',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.glassOnSurfaceFaint,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            document.description!,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.glassOnSurface,
            ),
          ),
        ],
        const SizedBox(height: 20),
        GlassPrimaryButton(
          text: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.glassOnSurfaceMuted,
          ),
        ),
        Text(
          value,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.glassOnSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
