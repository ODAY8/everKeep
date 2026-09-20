import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../circular_icon_button.dart';

/// A page title + subtitle, with an optional leading back button — the
/// shared header pattern for detail/utility screens (Settings, Emergency
/// Access) that sit outside the main bottom-nav tabs.
class GlassPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool showBackButton;

  /// An optional trailing action (e.g. a circular search button), placed
  /// beside the title on the same row — matches the Figma header pattern
  /// used on Documents and Legacy.
  final Widget? trailing;

  const GlassPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showBackButton = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showBackButton) ...[
          CircularIconButton(
            icon: Icons.arrow_back_rounded,
            background: AppColors.glassSurface,
            foreground: AppColors.glassOnSurface,
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(height: 14),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.serifHeadline.copyWith(
                  color: AppColors.glassOnSurface,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.glassOnSurfaceMuted,
            ),
          ),
        ],
      ],
    );
  }
}
