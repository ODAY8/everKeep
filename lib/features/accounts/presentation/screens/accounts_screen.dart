import 'package:flutter/material.dart';
import 'package:everkeep/core/theme/app_colors.dart';
import 'package:everkeep/core/theme/app_text_styles.dart';
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
  final List<String> _filters = const ['All', 'Banking', 'Social', 'Work', 'Other'];

  final List<Map<String, dynamic>> _accounts = const [
    {
      'title': 'Bank of America - Checking',
      'subtitle': 'Updated yesterday · •••• 1234',
      'icon': Icons.account_balance_rounded,
      'color': AppColors.glassAccentGreen,
      'isFavorite': true,
    },
    {
      'title': 'Amazon.com',
      'subtitle': 'Updated 3 days ago · •••• 5678',
      'icon': Icons.shopping_cart_rounded,
      'color': AppColors.glassAccentPink,
      'isFavorite': false,
    },
    {
      'title': 'GitHub',
      'subtitle': 'Updated 1 week ago',
      'icon': Icons.code_rounded,
      'color': AppColors.glassOnSurfaceMuted,
      'isFavorite': true,
    },
    {
      'title': 'Wi-Fi Home Network',
      'subtitle': 'Updated 2 weeks ago',
      'icon': Icons.wifi_rounded,
      'color': AppColors.glassAccentBlue,
      'isFavorite': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final favorites = _accounts.where((a) => a['isFavorite'] == true).toList();

    return GlassScaffold(
      floatingActionButton: GlassFab(
        label: 'Add Account',
        onPressed: () {},
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GlassPageHeader(
            title: 'Accounts',
            subtitle: 'Your secure login credentials',
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
          _buildSectionHeader('Recent Accounts'),
          const SizedBox(height: 12),
          for (final account in _accounts) ...[
            GlassItemRow(
              icon: account['icon'] as IconData,
              iconColor: account['color'] as Color,
              title: account['title'] as String,
              subtitle: account['subtitle'] as String,
              trailing: Icon(
                account['isFavorite'] == true ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: account['isFavorite'] == true
                    ? AppColors.glassAccentPink
                    : AppColors.glassOnSurfaceFaint,
                size: 20,
              ),
              onTap: () {},
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 14),
          _buildSectionHeader('Favorites'),
          const SizedBox(height: 12),
          for (final account in favorites) ...[
            GlassItemRow(
              icon: account['icon'] as IconData,
              iconColor: account['color'] as Color,
              title: account['title'] as String,
              subtitle: account['subtitle'] as String,
              onTap: () {},
            ),
            const SizedBox(height: 10),
          ],
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
