import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/security/clipboard_safety_manager.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../models/account_item.dart';
import '../../../../providers/account_provider.dart';
import '../../../../providers/app_lock_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../widgets/feedback.dart';
import '../../../../widgets/glass/glass_card.dart';
import '../../../../widgets/glass/glass_fab.dart';
import '../../../../widgets/glass/glass_filter_chips.dart';
import '../../../../widgets/glass/glass_page_header.dart';
import '../../../../widgets/glass/glass_primary_button.dart';
import '../../../../widgets/glass/glass_scaffold.dart';
import '../../../../widgets/glass/glass_search_bar.dart';
import '../widgets/credential_form_sheet.dart';
import '../widgets/password_generator_sheet.dart';

/// Dedicated screen for EverKeep's Secure Password Vault.
///
/// Provides client-side encrypted credential management, search, generation,
/// reveal/hide, and clipboard safety timeouts.
class PasswordVaultScreen extends StatefulWidget {
  const PasswordVaultScreen({super.key});

  @override
  State<PasswordVaultScreen> createState() => _PasswordVaultScreenState();
}

class _PasswordVaultScreenState extends State<PasswordVaultScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _revealedCredentialIds = {};
  int _selectedFilter = 0;
  String _query = '';

  static const List<String> _categories = [
    'All',
    'Banking',
    'Social',
    'Work',
    'Personal',
    'Other',
  ];

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final lockProv = Provider.of<AppLockProvider>(context);
      if (lockProv.isLocked && _revealedCredentialIds.isNotEmpty) {
        _revealedCredentialIds.clear();
      }
    } catch (_) {
      // In isolated tests where AppLockProvider is omitted from provider scope
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _revealedCredentialIds.clear();
    super.dispose();
  }

  Future<void> _openAddSheet() async {
    await showCredentialFormSheet(context);
  }

  Future<void> _openEditSheet(AccountItem item) async {
    await showCredentialFormSheet(context, existing: item);
  }

  Future<void> _confirmDelete(AccountItem item) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete credential?',
      message: 'Are you sure you want to delete "${item.title}"? This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!confirmed || !mounted) return;

    final accProv = context.read<AccountProvider>();
    final ok = await accProv.deleteAccount(item.id);
    if (!mounted) return;

    if (ok) {
      showAppSnackBar(context, 'Credential deleted');
    } else {
      showAppSnackBar(
        context,
        accProv.error ?? 'Could not delete credential.',
        isError: true,
      );
    }
  }

  Future<void> _copyUsername(String username) async {
    await Clipboard.setData(ClipboardData(text: username));
    if (!mounted) return;
    showAppSnackBar(context, 'Username copied to clipboard');
  }

  Future<void> _copyPassword(AccountItem item) async {
    final auth = context.read<AuthProvider>();
    final userId = auth.currentUser?.id ?? '';
    final accProv = context.read<AccountProvider>();

    final plainPassword = await accProv.getDecryptedPassword(item, userId: userId);
    if (plainPassword == null || plainPassword.isEmpty) {
      if (!mounted) return;
      showAppSnackBar(context, 'No password saved for this item.', isError: true);
      return;
    }

    await ClipboardSafetyManager.instance.copySensitiveText(plainPassword);
    if (!mounted) return;
    showAppSnackBar(
      context,
      'Password copied. Clipboard auto-clearing in 30 seconds.',
    );
  }

  void _toggleReveal(AccountItem item) {
    setState(() {
      if (_revealedCredentialIds.contains(item.id)) {
        _revealedCredentialIds.remove(item.id);
      } else {
        _revealedCredentialIds.add(item.id);
      }
    });
  }

  Future<void> _openWebsite(String url) async {
    var formatted = url.trim();
    if (!formatted.startsWith('http://') && !formatted.startsWith('https://')) {
      formatted = 'https://$formatted';
    }
    final uri = Uri.tryParse(formatted);
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        if (!mounted) return;
        showAppSnackBar(context, 'Could not open website: $url', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accProv = context.watch<AccountProvider>();
    final auth = context.watch<AuthProvider>();
    final userId = auth.currentUser?.id ?? '';

    final selectedCategory = _categories[_selectedFilter];
    final items = accProv.filterCredentials(
      selectedCategory,
      query: _query,
      passwordsOnly: false,
    );

    return GlassScaffold(
      scrollable: false,
      floatingActionButton: GlassFab(
        icon: Icons.add_rounded,
        label: 'Add Credential',
        onPressed: _openAddSheet,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with back navigation
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: AppColors.glassOnSurface,
                  size: 20,
                ),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: GlassPageHeader(
                  title: 'Password Vault',
                  subtitle:
                      '${accProv.count} credentials · End-to-end encrypted',
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.glassAccentBlue,
                ),
                tooltip: 'Password Generator',
                onPressed: () => showPasswordGeneratorSheet(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Search bar
          GlassSearchBar(
            controller: _searchController,
            hintText: 'Search services, usernames, websites...',
            onChanged: (val) => setState(() => _query = val),
            onClear: () => setState(() => _query = ''),
          ),
          const SizedBox(height: 14),

          // Filter Chips
          GlassFilterChips(
            labels: _categories,
            selectedIndex: _selectedFilter,
            onSelected: (idx) => setState(() => _selectedFilter = idx),
          ),
          const SizedBox(height: 18),

          // Content body
          Expanded(
            child: _buildContent(
              accProv: accProv,
              items: items,
              userId: userId,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent({
    required AccountProvider accProv,
    required List<AccountItem> items,
    required String userId,
  }) {
    if (accProv.isLoading && !accProv.hasFetched) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.glassAccentBlue),
      );
    }

    if (accProv.error != null && accProv.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: AppColors.glassDestructive,
            ),
            const SizedBox(height: 12),
            Text(
              'Could not load vault items',
              style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.glassOnSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              accProv.error!,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.glassOnSurfaceMuted,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 140,
              child: GlassOutlineButton(
                text: 'Retry',
                onPressed: () => accProv.fetchAccounts(),
              ),
            ),
          ],
        ),
      );
    }

    if (items.isEmpty) {
      final isSearching = _query.trim().isNotEmpty || _selectedFilter != 0;
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.glassAccentBlue.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.glassAccentBlue.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  size: 36,
                  color: AppColors.glassAccentBlue,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isSearching
                    ? 'No credentials match your filter'
                    : 'Your Password Vault is Empty',
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.glassOnSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isSearching
                    ? 'Try adjusting your search terms or category selection.'
                    : 'Add logins, websites, and secure passwords. Everything is encrypted on-device before syncing.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.glassOnSurfaceMuted,
                ),
              ),
              if (!isSearching) ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: 200,
                  child: GlassPrimaryButton(
                    text: 'Add First Credential',
                    onPressed: _openAddSheet,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        final isRevealed = _revealedCredentialIds.contains(item.id);
        return _buildCredentialCard(
          item: item,
          isRevealed: isRevealed,
          userId: userId,
        );
      },
    );
  }

  Widget _buildCredentialCard({
    required AccountItem item,
    required bool isRevealed,
    required String userId,
  }) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Icon, Title, Category Badge, Action Menu
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.18),
                  borderRadius: AppRadius.radiusMD,
                  border: Border.all(
                    color: item.color.withValues(alpha: 0.35),
                  ),
                ),
                child: Icon(item.icon, color: item.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: AppTextStyles.titleSmall.copyWith(
                        color: AppColors.glassOnSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: item.color.withValues(alpha: 0.12),
                            borderRadius: AppRadius.radiusPill,
                          ),
                          child: Text(
                            item.category,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: item.color,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (item.hasPassword) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.glassAccentBlue
                                  .withValues(alpha: 0.12),
                              borderRadius: AppRadius.radiusPill,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.lock_outline_rounded,
                                  size: 10,
                                  color: AppColors.glassAccentBlue,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'Encrypted',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.glassAccentBlue,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: AppColors.glassOnSurfaceMuted,
                ),
                tooltip: 'Edit credential',
                onPressed: () => _openEditSheet(item),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: AppColors.glassDestructive,
                ),
                tooltip: 'Delete credential',
                onPressed: () => _confirmDelete(item),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Username row
          if (item.username != null && item.username!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.glassSurface,
                borderRadius: AppRadius.radiusSM,
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_outline_rounded,
                    size: 16,
                    color: AppColors.glassOnSurfaceMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.username!,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.glassOnSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.copy_rounded,
                      size: 16,
                      color: AppColors.glassOnSurfaceMuted,
                    ),
                    tooltip: 'Copy username',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _copyUsername(item.username!),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Password row
          if (item.hasPassword) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.glassSurface,
                borderRadius: AppRadius.radiusSM,
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.key_rounded,
                    size: 16,
                    color: AppColors.glassAccentBlue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: isRevealed
                        ? FutureBuilder<String?>(
                            future: context
                                .read<AccountProvider>()
                                .getDecryptedPassword(item, userId: userId),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Text(
                                  'Decrypting...',
                                  style: TextStyle(
                                    color: AppColors.glassOnSurfaceMuted,
                                    fontSize: 12,
                                  ),
                                );
                              }
                              final pwd = snapshot.data ?? '••••••••••••';
                              return SelectableText(
                                pwd,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.glassOnSurface,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            },
                          )
                        : Text(
                            '••••••••••••',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.glassOnSurfaceMuted,
                              letterSpacing: 2.0,
                            ),
                          ),
                  ),
                  IconButton(
                    icon: Icon(
                      isRevealed
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 18,
                      color: AppColors.glassOnSurfaceMuted,
                    ),
                    tooltip: isRevealed ? 'Hide password' : 'Reveal password',
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    constraints: const BoxConstraints(),
                    onPressed: () => _toggleReveal(item),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.copy_rounded,
                      size: 16,
                      color: AppColors.glassAccentBlue,
                    ),
                    tooltip: 'Copy password',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _copyPassword(item),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Website row
          if (item.website != null && item.website!.isNotEmpty) ...[
            GestureDetector(
              onTap: () => _openWebsite(item.website!),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.glassSurface,
                  borderRadius: AppRadius.radiusSM,
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.link_rounded,
                      size: 16,
                      color: AppColors.glassAccentBlue,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.website!,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.glassAccentBlue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.open_in_new_rounded,
                      size: 14,
                      color: AppColors.glassAccentBlue,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Notes row
          if (item.notes != null && item.notes!.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.glassBackground.withValues(alpha: 0.4),
                borderRadius: AppRadius.radiusSM,
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Text(
                item.notes!,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.glassOnSurfaceMuted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
