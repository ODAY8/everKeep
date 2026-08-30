import 'package:flutter/material.dart';
import 'package:everkeep/core/config/app_image_urls.dart';
import 'package:everkeep/core/theme/app_colors.dart';
import 'package:everkeep/core/theme/app_radius.dart';
import 'package:everkeep/core/theme/app_text_styles.dart';
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
  final List<Map<String, dynamic>> _trustedContacts = const [
    {
      'name': 'Sarah Johnson',
      'relationship': 'Spouse',
      'accessLevel': 'Full Access',
      'avatar': AppImageUrls.trustedContact1,
    },
    {
      'name': 'Michael Chen',
      'relationship': 'Attorney',
      'accessLevel': 'On Release',
      'avatar': AppImageUrls.trustedContact2,
    },
    {
      'name': 'Emily Davis',
      'relationship': 'Financial Advisor',
      'accessLevel': 'View Only',
      'avatar': AppImageUrls.trustedContact3,
    },
    {
      'name': 'Robert Wilson',
      'relationship': 'Family Friend',
      'accessLevel': 'Verification Role',
      'avatar': AppImageUrls.trustedContact4,
    },
  ];

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
          for (final entry in _trustedContacts.asMap().entries) ...[
            FadeSlideIn(index: entry.key, child: _buildContactCard(entry.value)),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          GlassPrimaryButton(text: 'Invite Someone', onPressed: () {}),
        ],
      ),
    );
  }

  Widget _buildContactCard(Map<String, dynamic> contact) {
    return GlassCard(
      borderRadius: AppRadius.radiusXXL,
      onTap: () {},
      child: Row(
        children: [
          ProfileAvatar(
            url: contact['avatar'] as String,
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
                  contact['name'] as String,
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.glassOnSurface,
                  ),
                ),
                Text(
                  contact['relationship'] as String,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.glassOnSurfaceMuted,
                  ),
                ),
                const SizedBox(height: 8),
                StatusBadge.trust(contact['accessLevel'] as String),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.glassOnSurfaceFaint),
        ],
      ),
    );
  }
}
