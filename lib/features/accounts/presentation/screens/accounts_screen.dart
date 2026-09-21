import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:everkeep/core/theme/app_colors.dart';
import 'package:everkeep/core/theme/app_text_styles.dart';
import 'package:everkeep/providers/account_provider.dart';
import 'package:everkeep/widgets/glass/glass_fab.dart';
import 'package:everkeep/widgets/glass/glass_filter_chips.dart';
import 'package:everkeep/widgets/glass/glass_item_row.dart';
import 'package:everkeep/widgets/glass/glass_page_header.dart';
import 'package:everkeep/widgets/glass/glass_scaffold.dart';
import 'package:everkeep/widgets/glass/glass_search_bar.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  int _selectedFilter = 0;
  final List<String> _filters = const [
    'All',
    'Banking',
    'Social',
    'Work',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final accProv = context.read<AccountProvider>();
      if (!accProv.hasFetched) {
        accProv.fetchAccounts();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeFilter = _filters[_selectedFilter];

    return GlassScaffold(
      floatingActionButton: GlassFab(
        label: 'Add Account',
        onPressed: () {},
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
            onChanged: (_) {},
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
              if (accProv.isLoading && !accProv.hasFetched) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: CircularProgressIndicator(
                      color: AppColors.glassAccentPink,
                    ),
                  ),
                );
              }

              if (accProv.error != null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      accProv.error!,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.glassDestructive,
                      ),
                    ),
                  ),
                );
              }

              final displayedAccounts =
                  accProv.filterByCategory(activeFilter);
              final favorites =
                  displayedAccounts.where((a) => a.isFavorite).toList();

              if (displayedAccounts.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      'No accounts found.',
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
                        onTap: () => accProv.toggleFavorite(account.id),
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
                      onTap: () {},
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
                        onTap: () {},
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: AppTextStyles.titleLarge.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.glassOnSurface,
          ),
        ),
        GestureDetector(
          onTap: () {},
          child: Text(
            'See All',
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.glassAccentPink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
