import 'package:flutter/material.dart';
import 'package:everkeep/core/config/app_image_urls.dart';
import 'package:everkeep/core/routing/app_router.dart';
import 'package:everkeep/core/theme/app_colors.dart';
import 'package:everkeep/core/theme/app_text_styles.dart';
import 'package:everkeep/widgets/circular_icon_button.dart';
import 'package:everkeep/widgets/fade_slide_in.dart';
import 'package:everkeep/widgets/glass/activity_row.dart';
import 'package:everkeep/widgets/glass/dashboard_grid_card.dart';
import 'package:everkeep/widgets/glass/glass_scaffold.dart';
import 'package:everkeep/widgets/glass/security_score_card.dart';
import 'package:everkeep/widgets/profile_avatar.dart';
import 'package:everkeep/widgets/progress_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final String _userFirstName = 'Sarah';

  final List<Map<String, dynamic>> _recentActivity = const [
    {
      'title': 'Will & Testament added',
      'subtitle': 'Documents · 2 days ago',
      'color': AppColors.glassAccentGreen,
    },
    {
      'title': 'Sarah Kim verified',
      'subtitle': 'Trusted Contact · 5 days ago',
      'color': AppColors.glassAccentBlue,
    },
    {
      'title': 'Passwords updated',
      'subtitle': 'Vault · 1 week ago',
      'color': AppColors.glassAccentPink,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 24),
          ProgressCard(
            progress: 0.73,
            imageUrl: AppImageUrls.homeHeroCard,
            title: 'Your Legacy is 73% Complete',
            subtitle: '3 tasks remaining to safeguard your story',
            onTap: () => Navigator.of(context).pushNamed(AppRouter.settings),
          ),
          const SizedBox(height: 24),
          Text(
            'Vault Chapters',
            style: AppTextStyles.serifLabel.copyWith(
              color: AppColors.glassOnSurface,
            ),
          ),
          const SizedBox(height: 14),
          DashboardGrid(
            cards: [
              FadeSlideIn(
                index: 0,
                child: DashboardGridCard(
                  icon: Icons.image_outlined,
                  tintColor: AppColors.glassAccentPink,
                  title: 'Memories',
                  meta: '142 items saved',
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRouter.wishes),
                ),
              ),
              FadeSlideIn(
                index: 1,
                child: DashboardGridCard(
                  icon: Icons.folder_outlined,
                  tintColor: AppColors.glassAccentSecondary,
                  title: 'Documents',
                  meta: '12 vital files',
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRouter.documents),
                ),
              ),
              FadeSlideIn(
                index: 2,
                child: DashboardGridCard(
                  icon: Icons.people_outline_rounded,
                  tintColor: AppColors.glassAccentBlue,
                  title: 'Trusted People',
                  meta: '4 secure trustees',
                  onTap: () => Navigator.of(context)
                      .pushNamed(AppRouter.trustedContacts),
                ),
              ),
              FadeSlideIn(
                index: 3,
                child: DashboardGridCard(
                  icon: Icons.mail_outline_rounded,
                  tintColor: AppColors.glassAccentCrimson,
                  title: 'Future Messages',
                  meta: '8 letters scheduled',
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRouter.wishes),
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionLabel('RECENT ACTIVITY'),
              GestureDetector(
                onTap: () => Navigator.of(context).pushNamed(AppRouter.settings),
                child: Text(
                  'See all',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.glassAccentPink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final activity in _recentActivity) ...[
            ActivityRow(
              title: activity['title'] as String,
              subtitle: activity['subtitle'] as String,
              dotColor: activity['color'] as Color,
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 4),
          SecurityScoreCard(
            label: 'Security Score',
            scoreText: 'Excellent — 94/100',
            progress: 0.94,
            onTap: () => Navigator.of(context).pushNamed(AppRouter.security),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: AppTextStyles.labelSmall.copyWith(
        color: AppColors.glassOnSurfaceFaint,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good morning,',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.glassOnSurfaceMuted,
                ),
              ),
              Text(
                _userFirstName,
                style: AppTextStyles.serifHeadline.copyWith(
                  color: AppColors.glassOnSurface,
                ),
              ),
            ],
          ),
        ),
        CircularIconButton(
          icon: Icons.notifications_none_rounded,
          background: AppColors.glassSurface,
          foreground: AppColors.glassOnSurface,
          showBadge: true,
          badgeColor: AppColors.glassAccentPink,
          tooltip: 'Notifications',
          onPressed: () => Navigator.of(context).pushNamed(AppRouter.settings),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => Navigator.of(context).pushNamed(AppRouter.profile),
          child: const ProfileAvatar(
            url: AppImageUrls.mockUserAvatar,
            size: 48,
            borderColor: AppColors.glassBorder,
            borderWidth: 1,
          ),
        ),
      ],
    );
  }
}
