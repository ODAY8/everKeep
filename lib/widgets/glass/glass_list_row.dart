import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';

/// A label (+ optional subtitle) row with a trailing chevron, switch, or
/// custom widget, grouped into [GlassListCard] sections — used by Profile
/// and Settings.
class GlassListRow {
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? labelColor;
  final bool showChevron;
  final Widget? trailing;

  const GlassListRow({
    required this.label,
    this.subtitle,
    this.onTap,
    this.labelColor,
    this.showChevron = true,
    this.trailing,
  });
}

class GlassListCard extends StatelessWidget {
  final List<GlassListRow> rows;

  const GlassListCard({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.glassSurface,
        borderRadius: AppRadius.radiusXL,
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            _GlassListRowTile(row: rows[i]),
            if (i != rows.length - 1)
              Divider(height: 1, thickness: 1, color: AppColors.glassBorder),
          ],
        ],
      ),
    );
  }
}

class _GlassListRowTile extends StatelessWidget {
  final GlassListRow row;

  const _GlassListRowTile({required this.row});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: row.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.label,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: row.labelColor ?? AppColors.glassOnSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (row.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        row.subtitle!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.glassOnSurfaceMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (row.trailing != null)
                row.trailing!
              else if (row.showChevron && row.onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.glassOnSurfaceFaint,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
