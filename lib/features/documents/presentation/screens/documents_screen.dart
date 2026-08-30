import 'package:flutter/material.dart';
import 'package:everkeep/core/theme/app_colors.dart';
import 'package:everkeep/core/theme/app_radius.dart';
import 'package:everkeep/core/theme/app_text_styles.dart';
import 'package:everkeep/widgets/circular_icon_button.dart';
import 'package:everkeep/widgets/fade_slide_in.dart';
import 'package:everkeep/widgets/glass/glass_card.dart';
import 'package:everkeep/widgets/glass/glass_fab.dart';
import 'package:everkeep/widgets/glass/glass_filter_chips.dart';
import 'package:everkeep/widgets/glass/glass_item_row.dart';
import 'package:everkeep/widgets/glass/glass_page_header.dart';
import 'package:everkeep/widgets/glass/glass_scaffold.dart';
import 'package:everkeep/widgets/glass/status_badge.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  int _selectedFilter = 0;
  final List<String> _filters = const ['All', 'Legal', 'Financial', 'Medical'];

  final List<Map<String, dynamic>> _documents = const [
    {
      'title': 'Last Will and Testament.pdf',
      'subtitle': 'Legal · Added 2 days ago',
      'icon': Icons.description_outlined,
      'verified': true,
    },
    {
      'title': 'Medical Power of Attorney.pdf',
      'subtitle': 'Medical · Added 1 week ago',
      'icon': Icons.description_outlined,
      'verified': false,
    },
    {
      'title': 'Property Deed.jpg',
      'subtitle': 'Legal · Added 2 weeks ago',
      'icon': Icons.description_outlined,
      'verified': true,
    },
    {
      'title': 'Bank Statements Q3.xlsx',
      'subtitle': 'Financial · Added 1 month ago',
      'icon': Icons.description_outlined,
      'verified': true,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      floatingActionButton: GlassFab(onPressed: () {}),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassPageHeader(
            title: 'Documents',
            trailing: CircularIconButton(
              icon: Icons.search_rounded,
              background: AppColors.glassSurface,
              foreground: AppColors.glassOnSurface,
              size: 40,
              onPressed: () {},
            ),
          ),
          const SizedBox(height: 18),
          _buildStorageCard(),
          const SizedBox(height: 18),
          GlassFilterChips(
            labels: _filters,
            selectedIndex: _selectedFilter,
            onSelected: (index) => setState(() => _selectedFilter = index),
          ),
          const SizedBox(height: 20),
          for (final entry in _documents.asMap().entries) ...[
            FadeSlideIn(
              index: entry.key,
              child: GlassItemRow(
                icon: entry.value['icon'] as IconData,
                iconColor: AppColors.glassAccentPink,
                title: entry.value['title'] as String,
                subtitle: entry.value['subtitle'] as String,
                trailing: entry.value['verified'] == true
                    ? const StatusBadge.success('Verified')
                    : const StatusBadge.pending('Pending'),
                onTap: () {},
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildStorageCard() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Vault Storage',
                style: AppTextStyles.titleSmall.copyWith(
                  color: AppColors.glassOnSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '24.5 MB of 2 GB used',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.glassOnSurfaceMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: AppRadius.radiusPill,
            child: LinearProgressIndicator(
              value: 0.02,
              minHeight: 8,
              backgroundColor: AppColors.glassBorder,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.glassAccentPink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
