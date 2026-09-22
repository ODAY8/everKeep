import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:everkeep/core/routing/app_router.dart';
import 'package:everkeep/core/theme/app_colors.dart';
import 'package:everkeep/core/theme/app_text_styles.dart';
import 'package:everkeep/models/vault_summary.dart';
import 'package:everkeep/providers/account_provider.dart';
import 'package:everkeep/providers/document_provider.dart';
import 'package:everkeep/providers/vault_provider.dart';
import 'package:everkeep/widgets/fade_slide_in.dart';
import 'package:everkeep/widgets/glass/glass_add_tile.dart';
import 'package:everkeep/widgets/glass/glass_item_row.dart';
import 'package:everkeep/widgets/glass/glass_scaffold.dart';
import 'package:everkeep/widgets/glass/glass_search_bar.dart';
import 'package:everkeep/widgets/vault_category_card.dart';

/// The vault overview: the categories that exist today, plus a search that looks
/// across documents and accounts.
class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  String _query = '';

  bool get _searching => _query.trim().isNotEmpty;

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
            hintText: 'Search your vault...',
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 20),
          if (_searching) _SearchResults(query: _query) else const _Categories(),
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
            route: AppRouter.accounts,
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

/// Documents and accounts whose name (or username) contains the query.
class _SearchResults extends StatelessWidget {
  final String query;

  const _SearchResults({required this.query});

  static const int _maxResults = 20;

  @override
  Widget build(BuildContext context) {
    final documents = context.watch<DocumentProvider>().filterByCategory(
      'All',
      query: query,
    );
    final accounts = context.watch<AccountProvider>().filterByCategory(
      'All',
      query: query,
    );

    final rows = <Widget>[
      for (final doc in documents)
        GlassItemRow(
          icon: doc.icon,
          iconColor: AppColors.glassAccentPink,
          title: doc.title,
          subtitle: doc.subtitle,
          onTap: () => Navigator.of(context).pushNamed(AppRouter.documents),
        ),
      for (final account in accounts)
        GlassItemRow(
          icon: account.icon,
          iconColor: account.color,
          title: account.title,
          subtitle: account.subtitle,
          onTap: () => Navigator.of(context).pushNamed(AppRouter.accounts),
        ),
    ].take(_maxResults).toList();

    if (rows.isEmpty) {
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
      children: [
        for (final row in rows) ...[row, const SizedBox(height: 10)],
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
