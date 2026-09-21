import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:everkeep/core/routing/app_router.dart';
import 'package:everkeep/core/theme/app_colors.dart';
import 'package:everkeep/core/theme/app_radius.dart';
import 'package:everkeep/core/theme/app_text_styles.dart';
import 'package:everkeep/models/trusted_contact_item.dart';
import 'package:everkeep/providers/trusted_contact_provider.dart';
import 'package:everkeep/widgets/fade_slide_in.dart';
import 'package:everkeep/widgets/glass/glass_card.dart';
import 'package:everkeep/widgets/glass/glass_page_header.dart';
import 'package:everkeep/widgets/glass/glass_primary_button.dart';
import 'package:everkeep/widgets/glass/glass_scaffold.dart';
import 'package:everkeep/widgets/glass/status_badge.dart';
import 'package:everkeep/widgets/profile_avatar.dart';

class TrustedContactsScreen extends StatefulWidget {
  const TrustedContactsScreen({super.key});

  @override
  State<TrustedContactsScreen> createState() => _TrustedContactsScreenState();
}

class _TrustedContactsScreenState extends State<TrustedContactsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final contactProv = context.read<TrustedContactProvider>();
      if (!contactProv.hasFetched) {
        contactProv.fetchContacts();
      }
    });
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
              if (contactProv.isLoading && !contactProv.hasFetched) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: CircularProgressIndicator(
                      color: AppColors.glassAccentPink,
                    ),
                  ),
                );
              }

              if (contactProv.error != null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      contactProv.error!,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.glassDestructive,
                      ),
                    ),
                  ),
                );
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
          GlassPrimaryButton(
            text: 'Invite Someone',
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRouter.emergencyAccess),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(TrustedContactItem contact) {
    return GlassCard(
      borderRadius: AppRadius.radiusXXL,
      onTap: () => Navigator.of(context).pushNamed(AppRouter.emergencyAccess),
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
