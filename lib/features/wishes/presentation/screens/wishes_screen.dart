import 'package:flutter/material.dart';
import 'package:everkeep/core/config/app_image_urls.dart';
import 'package:everkeep/core/theme/app_colors.dart';
import 'package:everkeep/core/theme/app_text_styles.dart';
import 'package:everkeep/widgets/fade_slide_in.dart';
import 'package:everkeep/widgets/floating_bottom_nav.dart';
import 'package:everkeep/widgets/glass/glass_add_tile.dart';
import 'package:everkeep/widgets/glass/glass_filter_chips.dart';
import 'package:everkeep/widgets/glass/glass_scaffold.dart';
import 'package:everkeep/widgets/glass/glass_search_bar.dart';
import 'package:everkeep/widgets/glass/memory_photo_card.dart';
import 'package:everkeep/widgets/glass/timeline_milestone_card.dart';
import 'package:everkeep/widgets/profile_avatar.dart';

/// The "Memories" experience: a scattered masonry grid of preserved family
/// photos and milestones, plus a Future Messages timeline for private
/// legacy notes. Routed as AppRouter.wishes — both the Figma "Memories" and
/// "Future Messages" frames live on this one screen (see the app's nav IA
/// decision: this app keeps a single Memories destination rather than
/// splitting into two routes).
class WishesScreen extends StatefulWidget {
  const WishesScreen({super.key});

  @override
  State<WishesScreen> createState() => _WishesScreenState();
}

class _WishesScreenState extends State<WishesScreen> {
  int _selectedFilter = 0;
  final _filters = const ['Photos', 'Videos', 'Audio', 'Notes'];

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      bottomNavigationBar: FloatingBottomNav(
        currentIndex: 3,
        onTap: (index) {
          if (index == 0) Navigator.of(context).maybePop();
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Memories',
            style: AppTextStyles.serifHeadline.copyWith(
              color: AppColors.glassOnSurface,
            ),
          ),
          const SizedBox(height: 16),
          GlassSearchBar(hintText: 'Search memories...', onChanged: (_) {}),
          const SizedBox(height: 14),
          GlassFilterChips(
            labels: _filters,
            selectedIndex: _selectedFilter,
            onSelected: (index) => setState(() => _selectedFilter = index),
          ),
          const SizedBox(height: 16),
          _buildMasonryGrid(),
          const SizedBox(height: 28),
          Text(
            'Future Messages',
            style: AppTextStyles.serifLabel.copyWith(
              color: AppColors.glassOnSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Words for tomorrow, written today.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.glassOnSurfaceMuted,
            ),
          ),
          const SizedBox(height: 16),
          _buildFutureMessages(),
        ],
      ),
    );
  }

  Widget _buildMasonryGrid() {
    final memories = [
      (
        AppImageUrls.memoryFamilySummer,
        'Family Summer 2023',
        'With Sarah, Marcus',
        190.0,
        -2.0,
      ),
      (
        AppImageUrls.memoryChristmasTogether,
        'Christmas Together',
        'The whole family',
        155.0,
        1.5,
      ),
      (
        AppImageUrls.memoryOurFirstHome,
        'Our First Home',
        'With Emma',
        225.0,
        3.0,
      ),
      (
        AppImageUrls.memoryMorningWalks,
        'Morning Walks',
        'With the kids',
        150.0,
        -1.0,
      ),
      (
        AppImageUrls.memoryDadsBirthday,
        "Dad's 60th Birthday",
        'With Dad',
        165.0,
        2.0,
      ),
    ];

    final cards = [
      for (final entry in memories.asMap().entries)
        FadeSlideIn(
          index: entry.key,
          child: MemoryPhotoCard(
            imageUrl: entry.value.$1,
            title: entry.value.$2,
            subtitle: entry.value.$3,
            date: '',
            height: entry.value.$4,
            rotationDegrees: entry.value.$5,
            onTap: () {},
          ),
        ),
      FadeSlideIn(
        index: memories.length,
        child: GlassAddTile(label: 'Add Memory', onTap: () {}),
      ),
    ];

    return MemoryMasonryGrid(children: cards);
  }

  Widget _buildFutureMessages() {
    final messages = [
      (
        AppImageUrls.futureMessageAvatar1,
        'Emma (Daughter)',
        'Video Letter · Created Feb 12, 2026',
        'Trigger: When she graduates college',
        '"Emma, my sweet girl. Today you step into a larger world…"',
      ),
      (
        AppImageUrls.futureMessageAvatar2,
        'Michael (Son)',
        'Voice Note · Created Jan 3, 2026',
        'Trigger: On his wedding day',
        '"Son, if you\'re hearing this, it means you\'ve found the one…"',
      ),
      (
        AppImageUrls.futureMessageAvatar3,
        'Sarah (Spouse)',
        'Letter · Created Dec 20, 2025',
        'Trigger: 10 years from today',
        '"My love, I hope this finds you well and still smiling…"',
      ),
    ];

    return Column(
      children: [
        for (var i = 0; i < messages.length; i++)
          FadeSlideIn(
            index: i,
            child: TimelineMilestoneCard(
              leading: ProfileAvatar(
                url: messages[i].$1,
                size: 40,
                borderColor: AppColors.glassBorder,
                borderWidth: 1,
              ),
              title: messages[i].$2,
              meta: messages[i].$3,
              triggerLabel: messages[i].$4,
              preview: messages[i].$5,
              isLast: i == messages.length - 1,
              onTap: () {},
            ),
          ),
      ],
    );
  }
}
