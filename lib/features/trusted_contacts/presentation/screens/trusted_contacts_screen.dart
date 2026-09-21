import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:everkeep/core/routing/app_router.dart';
import 'package:everkeep/core/theme/app_colors.dart';
import 'package:everkeep/core/theme/app_radius.dart';
import 'package:everkeep/core/theme/app_text_styles.dart';
import 'package:everkeep/models/trusted_contact_item.dart';
import 'package:everkeep/providers/trusted_contact_provider.dart';
import 'package:everkeep/widgets/fade_slide_in.dart';
import 'package:everkeep/widgets/feedback.dart';
import 'package:everkeep/widgets/glass/glass_card.dart';
import 'package:everkeep/widgets/glass/glass_page_header.dart';
import 'package:everkeep/widgets/glass/glass_primary_button.dart';
import 'package:everkeep/widgets/glass/glass_scaffold.dart';
import 'package:everkeep/widgets/glass/glass_sheet.dart';
import 'package:everkeep/widgets/glass/status_badge.dart';
import 'package:everkeep/widgets/profile_avatar.dart';

class TrustedContactsScreen extends StatefulWidget {
  const TrustedContactsScreen({super.key});

  @override
  State<TrustedContactsScreen> createState() => _TrustedContactsScreenState();
}

class _TrustedContactsScreenState extends State<TrustedContactsScreen> {
  static const List<String> _accessLevels = [
    'View Only',
    'On Release',
    'Full Access',
    'Verification Role',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final contactProv = context.read<TrustedContactProvider>();
      if (!contactProv.hasFetched) {
        contactProv.fetchContacts();
      }
    });
  }

  Future<void> _addContact() async {
    final contactProv = context.read<TrustedContactProvider>();
    final saved = await showGlassFormSheet(
      context,
      title: 'Add Trusted Person',
      subtitle: 'Choose someone you trust to carry out your wishes.',
      submitLabel: 'Add Person',
      fields: const [
        GlassFormField(
          key: 'name',
          label: 'Full name',
          hint: 'e.g. Jordan Lee',
        ),
        GlassFormField(
          key: 'relationship',
          label: 'Relationship',
          hint: 'e.g. Sibling, Attorney',
        ),
      ],
      choices: const [
        GlassFormChoice(
          key: 'accessLevel',
          label: 'Access level',
          options: _accessLevels,
        ),
      ],
      onSubmit: (values) async {
        final added = await contactProv.addContact(
          TrustedContactItem(
            id: '', // assigned by the backend; the saved contact comes back with it
            name: values['name']!,
            relationship: values['relationship']!,
            accessLevel: values['accessLevel']!,
            // No photo yet; the avatar falls back to a person icon.
            avatarUrl: '',
          ),
        );
        return added ? null : contactProv.error ?? 'Could not add this person.';
      },
    );

    if (saved && mounted) showAppSnackBar(context, 'Trusted person added');
  }

  void _showActions(TrustedContactItem contact) {
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
          label: 'Remove trusted person',
          icon: Icons.person_remove_outlined,
          destructive: true,
          onTap: () => _confirmRemove(contact),
        ),
      ],
    );
  }

  Future<void> _confirmRemove(TrustedContactItem contact) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Remove ${contact.name}?',
      message: 'They will lose any access you granted them.',
      confirmLabel: 'Remove',
    );
    if (!confirmed || !mounted) return;

    final contactProv = context.read<TrustedContactProvider>();
    final removed = await contactProv.removeContact(contact.id);
    if (!mounted) return;

    showAppSnackBar(
      context,
      removed
          ? '${contact.name} removed'
          : contactProv.error ?? 'Could not remove this person.',
      isError: !removed,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GlassPageHeader(
            title: 'Trusted People',
            subtitle: 'People you trust to carry out your wishes.',
          ),
          const SizedBox(height: 18),
          Consumer<TrustedContactProvider>(
            builder: (context, contactProv, _) {
              // Only a failed *first load* replaces the list. A failed
              // add/remove leaves the list alone and is reported in a
              // snackbar by whoever triggered it.
              if (!contactProv.hasFetched) {
                final loadError = contactProv.error;
                if (loadError != null && !contactProv.isLoading) {
                  return ErrorRetryView(
                    message: loadError,
                    onRetry: contactProv.fetchContacts,
                  );
                }
                return const LoadingView();
              }

              final contacts = contactProv.contacts;

              if (contacts.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      'No trusted contacts added yet.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.glassOnSurfaceMuted,
                      ),
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  for (final entry in contacts.asMap().entries) ...[
                    FadeSlideIn(
                      index: entry.key,
                      child: _buildContactCard(entry.value),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          GlassPrimaryButton(text: 'Invite Someone', onPressed: _addContact),
        ],
      ),
    );
  }

  Widget _buildContactCard(TrustedContactItem contact) {
    return GlassCard(
      borderRadius: AppRadius.radiusXXL,
      onTap: () => _showActions(contact),
      child: Row(
        children: [
          ProfileAvatar(
            url: contact.avatarUrl,
            size: 48,
            borderColor: AppColors.glassBorder,
            borderWidth: 1,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.glassOnSurface,
                  ),
                ),
                Text(
                  contact.relationship,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.glassOnSurfaceMuted,
                  ),
                ),
                const SizedBox(height: 8),
                StatusBadge.trust(contact.accessLevel),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.glassOnSurfaceFaint,
          ),
        ],
      ),
    );
  }
}
