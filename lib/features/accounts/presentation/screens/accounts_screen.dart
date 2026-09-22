import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:everkeep/core/theme/app_colors.dart';
import 'package:everkeep/core/theme/app_text_styles.dart';
import 'package:everkeep/models/account_item.dart';
import 'package:everkeep/providers/account_provider.dart';
import 'package:everkeep/widgets/feedback.dart';
import 'package:everkeep/widgets/glass/glass_fab.dart';
import 'package:everkeep/widgets/glass/glass_filter_chips.dart';
import 'package:everkeep/widgets/glass/glass_item_row.dart';
import 'package:everkeep/widgets/glass/glass_page_header.dart';
import 'package:everkeep/widgets/glass/glass_scaffold.dart';
import 'package:everkeep/widgets/glass/glass_search_bar.dart';
import 'package:everkeep/widgets/glass/glass_sheet.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  static const List<String> _categories = ['Banking', 'Social', 'Work', 'Other'];

  int _selectedFilter = 0;
  String _query = '';
  final List<String> _filters = const ['All', ..._categories];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final accProv = context.read<AccountProvider>();
      if (!accProv.hasFetched) {
        accProv.fetchAccounts();
      }
    });
  }

  Future<void> _addAccount() async {
    final accProv = context.read<AccountProvider>();
    final saved = await showGlassFormSheet(
      context,
      title: 'Add Account',
      subtitle: 'Save a login so your trusted people can find it later.',
      submitLabel: 'Add Account',
      fields: const [
        GlassFormField(
          key: 'title',
          label: 'Account name',
          hint: 'e.g. Netflix',
        ),
        GlassFormField(
          key: 'username',
          label: 'Username or email',
          hint: 'Optional',
          required: false,
          keyboardType: TextInputType.emailAddress,
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
        final username = values['username']!;
        final (icon, color) = AccountItem.styleFor(category);
        // The id and the "Added ..." subtitle are assigned by the backend;
        // the saved account comes back with both.
        final added = await accProv.addAccount(
          AccountItem(
            id: '',
            title: values['title']!,
            subtitle: '',
            category: category,
            icon: icon,
            color: color,
            username: username.isEmpty ? null : username,
          ),
        );
        return added ? null : accProv.error ?? 'Could not add the account.';
      },
    );

    if (saved && mounted) showAppSnackBar(context, 'Account added');
  }

  Future<void> _toggleFavorite(AccountItem account) async {
    final accProv = context.read<AccountProvider>();
    final ok = await accProv.toggleFavorite(account.id);
    if (ok || !mounted) return;
    showAppSnackBar(
      context,
      accProv.error ?? 'Could not update the favorite.',
      isError: true,
    );
  }

  void _showActions(AccountItem account) {
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
          onTap: () => _toggleFavorite(account),
        ),
        GlassSheetAction(
          label: 'Delete account',
          icon: Icons.delete_outline_rounded,
          destructive: true,
          onTap: () => _confirmDelete(account),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(AccountItem account) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete account?',
      message: '"${account.title}" will be permanently removed from your vault.',
      confirmLabel: 'Delete',
    );
    if (!confirmed || !mounted) return;

    final accProv = context.read<AccountProvider>();
    final deleted = await accProv.deleteAccount(account.id);
    if (!mounted) return;

    showAppSnackBar(
      context,
      deleted
          ? 'Account deleted'
          : accProv.error ?? 'Could not delete the account.',
      isError: !deleted,
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeFilter = _filters[_selectedFilter];

    return GlassScaffold(
      floatingActionButton: GlassFab(
        label: 'Add Account',
        onPressed: _addAccount,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassPageHeader(
            title: 'Accounts',
            subtitle: 'Your secure login credentials',
            showBackButton: Navigator.of(context).canPop(),
          ),
          const SizedBox(height: 18),
          GlassSearchBar(
            hintText: 'Search accounts...',
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 14),
          GlassFilterChips(
            labels: _filters,
            selectedIndex: _selectedFilter,
            onSelected: (index) => setState(() => _selectedFilter = index),
          ),
          const SizedBox(height: 22),
          Consumer<AccountProvider>(
            builder: (context, accProv, _) {
              // Only a failed *first load* replaces the list. A failed
              // add/delete/favorite leaves the list alone and is reported in
              // a snackbar by whoever triggered it.
              if (!accProv.hasFetched) {
                final loadError = accProv.error;
                if (loadError != null && !accProv.isLoading) {
                  return ErrorRetryView(
                    message: loadError,
                    onRetry: accProv.fetchAccounts,
                  );
                }
                return const LoadingView();
              }

              final displayedAccounts = accProv.filterByCategory(
                activeFilter,
                query: _query,
              );
              final favorites =
                  displayedAccounts.where((a) => a.isFavorite).toList();

              if (displayedAccounts.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      _query.trim().isNotEmpty
                          ? 'No accounts match "${_query.trim()}".'
                          : 'No accounts yet. Tap Add Account to save one.',
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
                  _buildSectionHeader('Recent Accounts'),
                  const SizedBox(height: 12),
                  for (final account in displayedAccounts) ...[
                    GlassItemRow(
                      icon: account.icon,
                      iconColor: account.color,
                      title: account.title,
                      subtitle: account.subtitle,
                      trailing: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _toggleFavorite(account),
                        child: Icon(
                          account.isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: account.isFavorite
                              ? AppColors.glassAccentPink
                              : AppColors.glassOnSurfaceFaint,
                          size: 20,
                        ),
                      ),
                      onTap: () => _showActions(account),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (favorites.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _buildSectionHeader('Favorites'),
                    const SizedBox(height: 12),
                    for (final account in favorites) ...[
                      GlassItemRow(
                        icon: account.icon,
                        iconColor: account.color,
                        title: account.title,
                        subtitle: account.subtitle,
                        onTap: () => _showActions(account),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: AppTextStyles.titleLarge.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.glassOnSurface,
      ),
    );
  }
}
