import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:everkeep/core/routing/app_router.dart';
import 'package:everkeep/core/theme/app_colors.dart';
import 'package:everkeep/core/theme/app_radius.dart';
import 'package:everkeep/core/theme/app_text_styles.dart';
import 'package:everkeep/core/utils/search_helper.dart';
import 'package:everkeep/features/accounts/presentation/widgets/account_form_sheet.dart';
import 'package:everkeep/features/documents/presentation/widgets/document_details_sheet.dart';
import 'package:everkeep/features/trusted_contacts/presentation/widgets/trusted_contact_form_sheet.dart';
import 'package:everkeep/features/wishes/presentation/widgets/memory_details_sheet.dart';
import 'package:everkeep/features/wishes/presentation/widgets/memory_form_sheet.dart';
import 'package:everkeep/models/vault_summary.dart';
import 'package:everkeep/providers/account_provider.dart';
import 'package:everkeep/providers/document_provider.dart';
import 'package:everkeep/providers/memory_provider.dart';
import 'package:everkeep/providers/trusted_contact_provider.dart';
import 'package:everkeep/providers/vault_provider.dart';
import 'package:everkeep/widgets/fade_slide_in.dart';
import 'package:everkeep/widgets/feedback.dart';
import 'package:everkeep/widgets/glass/glass_add_tile.dart';
import 'package:everkeep/widgets/glass/glass_card.dart';
import 'package:everkeep/widgets/glass/glass_item_row.dart';
import 'package:everkeep/widgets/glass/glass_scaffold.dart';
import 'package:everkeep/widgets/glass/glass_search_bar.dart';
import 'package:everkeep/widgets/glass/glass_sheet.dart';
import 'package:everkeep/widgets/vault_category_card.dart';

/// The vault overview: the categories that exist today, plus a unified search
/// that looks across documents, accounts, memories, and trusted contacts.
class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  bool get _searching => _query.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final docProv = context.read<DocumentProvider>();
      if (!docProv.hasFetched) docProv.fetchDocuments();
      final accProv = context.read<AccountProvider>();
      if (!accProv.hasFetched) accProv.fetchAccounts();
      final memProv = context.read<MemoryProvider>();
      if (!memProv.hasFetched) memProv.fetchMemories();
      final contactProv = context.read<TrustedContactProvider>();
      if (!contactProv.hasFetched) contactProv.fetchContacts();
      final vaultProv = context.read<VaultProvider>();
      vaultProv.fetchVaultSummary();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Vault',
            style: AppTextStyles.serifHeadline.copyWith(
              color: AppColors.glassOnSurface,
            ),
          ),
          const SizedBox(height: 4),
          Selector<VaultProvider, VaultSummary>(
            selector: (_, vault) => vault.vaultSummary,
            builder: (context, summary, _) {
              return Text(
                '${summary.totalItems} items · ${summary.encryptionStatus}',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.glassOnSurfaceMuted,
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          GlassSearchBar(
            controller: _searchController,
            hintText: 'Search your vault...',
            onChanged: (value) => setState(() => _query = value),
            onClear: () => setState(() => _query = ''),
          ),
          const SizedBox(height: 20),
          if (_searching)
            _SearchResults(query: _query)
          else ...[
            const _Categories(),
            const SizedBox(height: 18),
            GlassCard(
              onTap: () =>
                  Navigator.of(context).pushNamed(AppRouter.timeline),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.glassAccentPink
                          .withValues(alpha: 0.16),
                      borderRadius: AppRadius.radiusMD,
                    ),
                    child: const Icon(
                      Icons.history_edu_rounded,
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
                          'Life Timeline',
                          style: AppTextStyles.titleSmall.copyWith(
                            color: AppColors.glassOnSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'View your memories and documents unified through time',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.glassOnSurfaceMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.glassOnSurfaceFaint,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Categories extends StatelessWidget {
  const _Categories();

  @override
  Widget build(BuildContext context) {
    return Selector<VaultProvider, VaultSummary>(
      selector: (_, vault) => vault.vaultSummary,
      builder: (context, summary, _) {
        final categories = <_VaultCategory>[
          _VaultCategory(
            icon: Icons.lock_rounded,
            iconColor: AppColors.glassAccentBlue,
            label: 'Passwords',
            count: summary.passwordsCount,
            route: AppRouter.passwordVault,
          ),
          _VaultCategory(
            icon: Icons.description_rounded,
            iconColor: AppColors.glassOnSurfaceMuted,
            label: 'Documents',
            count: summary.documentsCount,
            route: AppRouter.documents,
          ),
          _VaultCategory(
            icon: Icons.account_balance_wallet_rounded,
            iconColor: AppColors.glassAccentGreen,
            label: 'Financials',
            count: summary.financialsCount,
            route: AppRouter.accounts,
          ),
        ];

        return VaultGrid(
          cards: [
            for (final entry in categories.asMap().entries)
              FadeSlideIn(
                index: entry.key,
                child: VaultCategoryCard(
                  icon: entry.value.icon,
                  iconColor: entry.value.iconColor,
                  label: entry.value.label,
                  count: entry.value.count,
                  onTap: () =>
                      Navigator.of(context).pushNamed(entry.value.route),
                ),
              ),
            FadeSlideIn(
              index: categories.length,
              child: GlassAddTile(
                label: 'Add to Vault',
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRouter.documents),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Displays unified search results across Documents, Accounts, Memories,
/// and Trusted Contacts with exact-entity details navigation.
class _SearchResults extends StatelessWidget {
  final String query;

  const _SearchResults({required this.query});

  void _openDocument(BuildContext context, String docId) {
    final docProv = context.read<DocumentProvider>();
    final doc = docProv.documents.where((d) => d.id == docId).firstOrNull;
    if (doc == null) {
      showAppSnackBar(context, 'That document couldn\'t be found.', isError: true);
      return;
    }
    showDocumentDetailsSheet(context, document: doc);
  }

  void _openAccount(BuildContext context, String accountId) {
    final accProv = context.read<AccountProvider>();
    final account =
        accProv.accounts.where((a) => a.id == accountId).firstOrNull;
    if (account == null) {
      showAppSnackBar(context, 'That account couldn\'t be found.', isError: true);
      return;
    }
    showGlassActionSheet(
      context,
      title: account.title,
      subtitle: account.subtitle,
      actions: [
        GlassSheetAction(
          label: account.isFavorite
              ? 'Remove from favorites'
              : 'Add to favorites',
          icon: account.isFavorite
              ? Icons.favorite_border_rounded
              : Icons.favorite_rounded,
          onTap: () async {
            final ok = await accProv.toggleFavorite(account.id);
            if (!ok && context.mounted) {
              showAppSnackBar(
                context,
                accProv.error ?? 'Could not update favorite.',
                isError: true,
              );
            }
          },
        ),
        GlassSheetAction(
          label: 'Edit account',
          icon: Icons.edit_outlined,
          onTap: () => showAccountFormSheet(context, existing: account),
        ),
        GlassSheetAction(
          label: 'Delete account',
          icon: Icons.delete_outline_rounded,
          destructive: true,
          onTap: () async {
            final confirmed = await confirmDestructive(
              context,
              title: 'Delete account?',
              message:
                  '"${account.title}" will be permanently removed from your vault.',
              confirmLabel: 'Delete',
            );
            if (!confirmed || !context.mounted) return;
            final ok = await accProv.deleteAccount(account.id);
            if (!context.mounted) return;
            showAppSnackBar(
              context,
              ok ? 'Account deleted' : accProv.error ?? 'Could not delete.',
              isError: !ok,
            );
          },
        ),
      ],
    );
  }

  void _openMemory(BuildContext context, String memId) {
    final memProv = context.read<MemoryProvider>();
    final mem = memProv.items.where((m) => m.id == memId).firstOrNull;
    if (mem == null) {
      showAppSnackBar(context, 'That memory couldn\'t be found.', isError: true);
      return;
    }
    showGlassSheet<void>(
      context,
      builder: (sheetContext) => MemoryDetailsSheet(
        item: mem,
        onEdit: () async {
          Navigator.of(sheetContext).pop();
          final saved = await MemoryFormSheet.show(context, item: mem);
          if (saved == true && context.mounted) {
            showAppSnackBar(context, '${mem.typeLabel} updated');
          }
        },
        onDelete: () async {
          Navigator.of(sheetContext).pop();
          final confirmed = await confirmDestructive(
            context,
            title: 'Delete ${mem.typeLabel.toLowerCase()}?',
            message: '"${mem.title}" will be permanently removed.',
            confirmLabel: 'Delete',
          );
          if (!confirmed || !context.mounted) return;
          final ok = await memProv.deleteMemory(mem.id);
          if (!context.mounted) return;
          showAppSnackBar(
            context,
            ok ? '${mem.typeLabel} deleted' : memProv.error ?? 'Could not delete.',
            isError: !ok,
          );
        },
        onOpenAttachment: mem.hasAttachment
            ? () {
                final memProv = context.read<MemoryProvider>();
                openRemoteFile(
                  context,
                  fetchUrl: () => memProv.downloadUrlFor(mem),
                  errorMessage: () => memProv.error,
                );
              }
            : null,
      ),
    );
  }

  void _openContact(BuildContext context, String contactId) {
    final contactProv = context.read<TrustedContactProvider>();
    final contact =
        contactProv.contacts.where((c) => c.id == contactId).firstOrNull;
    if (contact == null) {
      showAppSnackBar(context, 'That person couldn\'t be found.', isError: true);
      return;
    }
    showGlassActionSheet(
      context,
      title: contact.name,
      subtitle: '${contact.relationship} · ${contact.accessLevel}',
      actions: [
        GlassSheetAction(
          label: 'Emergency access settings',
          icon: Icons.warning_amber_rounded,
          onTap: () =>
              Navigator.of(context).pushNamed(AppRouter.emergencyAccess),
        ),
        GlassSheetAction(
          label: 'Edit trusted person',
          icon: Icons.edit_outlined,
          onTap: () =>
              showTrustedContactFormSheet(context, existing: contact),
        ),
        GlassSheetAction(
          label: 'Remove trusted person',
          icon: Icons.person_remove_outlined,
          destructive: true,
          onTap: () async {
            final confirmed = await confirmDestructive(
              context,
              title: 'Remove ${contact.name}?',
              message: 'They will no longer have access as a trusted person.',
              confirmLabel: 'Remove',
            );
            if (!confirmed || !context.mounted) return;
            final ok = await contactProv.deleteContact(contact.id);
            if (!context.mounted) return;
            showAppSnackBar(
              context,
              ok
                  ? 'Trusted person removed'
                  : contactProv.error ?? 'Could not remove.',
              isError: !ok,
            );
          },
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 8, left: 4),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.glassOnSurfaceMuted,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.glassSurfaceRaised,
              borderRadius: AppRadius.radiusPill,
            ),
            child: Text(
              '$count',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.glassOnSurfaceMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final docProv = context.watch<DocumentProvider>();
    final accProv = context.watch<AccountProvider>();
    final memProv = context.watch<MemoryProvider>();
    final contactProv = context.watch<TrustedContactProvider>();

    final isLoading = docProv.isLoading ||
        accProv.isLoading ||
        memProv.isLoading ||
        contactProv.isLoading;

    final results = SearchMatcher.searchAll(
      documents: docProv.documents,
      accounts: accProv.accounts,
      memories: memProv.items,
      contacts: contactProv.contacts,
      query: query,
    );

    if (isLoading && results.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.glassAccentPink),
        ),
      );
    }

    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            'Nothing in your vault matches "${query.trim()}".',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.glassOnSurfaceMuted,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (results.documents.isNotEmpty) ...[
          _buildSectionHeader('Documents', results.documents.length),
          for (final doc in results.documents) ...[
            GlassItemRow(
              icon: doc.icon,
              iconColor: AppColors.glassAccentPink,
              title: doc.title,
              subtitle: doc.subtitle,
              onTap: () => _openDocument(context, doc.id),
            ),
            const SizedBox(height: 10),
          ],
        ],
        if (results.accounts.isNotEmpty) ...[
          _buildSectionHeader('Accounts', results.accounts.length),
          for (final account in results.accounts) ...[
            GlassItemRow(
              icon: account.icon,
              iconColor: account.color,
              title: account.title,
              subtitle: account.subtitle,
              onTap: () => _openAccount(context, account.id),
            ),
            const SizedBox(height: 10),
          ],
        ],
        if (results.memories.isNotEmpty) ...[
          _buildSectionHeader('Memories & Wishes', results.memories.length),
          for (final mem in results.memories) ...[
            GlassItemRow(
              icon: mem.isMemory
                  ? Icons.favorite_rounded
                  : Icons.star_rounded,
              iconColor: mem.isMemory
                  ? AppColors.glassAccentPink
                  : AppColors.glassWarningColor,
              title: mem.title,
              subtitle: mem.formattedDate != null
                  ? '${mem.typeLabel} · ${mem.formattedDate}'
                  : mem.typeLabel,
              onTap: () => _openMemory(context, mem.id),
            ),
            const SizedBox(height: 10),
          ],
        ],
        if (results.contacts.isNotEmpty) ...[
          _buildSectionHeader('Trusted Contacts', results.contacts.length),
          for (final contact in results.contacts) ...[
            GlassItemRow(
              icon: Icons.person_rounded,
              iconColor: AppColors.glassAccentBlue,
              title: contact.name,
              subtitle: '${contact.relationship} · ${contact.accessLevel}',
              onTap: () => _openContact(context, contact.id),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }
}

class _VaultCategory {
  final IconData icon;
  final Color iconColor;
  final String label;
  final int count;
  final String route;

  const _VaultCategory({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.count,
    required this.route,
  });
}
