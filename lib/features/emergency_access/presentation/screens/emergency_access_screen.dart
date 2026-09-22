import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:everkeep/core/routing/app_router.dart';
import 'package:everkeep/core/theme/app_colors.dart';
import 'package:everkeep/core/theme/app_text_styles.dart';
import 'package:everkeep/models/trusted_contact_item.dart';
import 'package:everkeep/providers/trusted_contact_provider.dart';
import 'package:everkeep/widgets/glass/glass_card.dart';
import 'package:everkeep/widgets/glass/glass_page_header.dart';
import 'package:everkeep/widgets/glass/glass_primary_button.dart';
import 'package:everkeep/widgets/glass/glass_scaffold.dart';
import 'package:everkeep/widgets/glass/status_badge.dart';
import 'package:everkeep/widgets/profile_avatar.dart';

/// Explains emergency access and shows who it would apply to.
///
/// Requesting access isn't built yet, so this screen says so plainly rather than
/// walking the user through a setup that saves nothing.
class EmergencyAccessScreen extends StatelessWidget {
  const EmergencyAccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GlassPageHeader(
            title: 'Emergency Access',
            subtitle: 'How trusted contacts will reach your vault',
            showBackButton: true,
          ),
          const SizedBox(height: 24),
          const Center(child: _Hero()),
          const SizedBox(height: 28),
          Text(
            'Your trusted people',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.glassOnSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'These are the people emergency access would apply to.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.glassOnSurfaceMuted,
            ),
          ),
          const SizedBox(height: 14),
          const _ContactsPreview(),
          const SizedBox(height: 28),
          Text(
            'How it will work',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.glassOnSurface,
            ),
          ),
          const SizedBox(height: 12),
          const _HowItWorks(),
          const SizedBox(height: 28),
          GlassPrimaryButton(
            text: 'Manage Trusted People',
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRouter.trustedContacts),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.glassAccentSecondary.withValues(alpha: 0.16),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.glassAccentSecondary,
            size: 44,
          ),
        ),
        const SizedBox(height: 14),
        const StatusBadge.neutral('Coming soon'),
        const SizedBox(height: 14),
        Text(
          'Emergency access isn\'t available yet.',
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.glassOnSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'When it is, someone you trust will be able to ask for access to your '
          'vault if something happens to you. For now, no one can request access '
          'to your data.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.glassOnSurfaceMuted,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ContactsPreview extends StatelessWidget {
  const _ContactsPreview();

  @override
  Widget build(BuildContext context) {
    final contacts = context.watch<TrustedContactProvider>().contacts;

    if (contacts.isEmpty) {
      return GlassCard(
        onTap: () => Navigator.of(context).pushNamed(AppRouter.trustedContacts),
        child: Text(
          'You haven\'t added anyone yet. Tap to add a trusted person.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.glassOnSurfaceMuted,
          ),
        ),
      );
    }

    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: contacts.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) => _ContactCard(contact: contacts[index]),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final TrustedContactItem contact;

  const _ContactCard({required this.contact});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 116,
      child: GlassCard(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ProfileAvatar(
              url: contact.avatarUrl,
              size: 34,
              borderColor: AppColors.glassBorder,
              borderWidth: 1,
            ),
            const SizedBox(height: 6),
            Text(
              contact.name,
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.glassOnSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              contact.relationship,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.glassOnSurfaceMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  static const _steps = [
    (Icons.request_page_rounded, 'Request', 'A trusted person asks for access'),
    (Icons.hourglass_empty_rounded, 'Waiting period', 'You have time to decline'),
    (Icons.check_circle_rounded, 'Access', 'Granted if you don\'t respond'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _steps.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final (icon, title, description) = _steps[index];
          return SizedBox(
            width: 116,
            child: GlassCard(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 22, color: AppColors.glassAccentBlue),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.glassOnSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    description,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.glassOnSurfaceMuted,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
