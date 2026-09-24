import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';

/// A small color-coded status pill — Verified / Pending / Set Up /
/// Configured / Full Access / PREMIUM, etc. — used across Documents,
/// Trusted People, Profile, and Security.
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;
  final Color? borderColor;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    required this.background,
    this.borderColor,
  });

  /// Green "Verified" / "Active" style.
  const StatusBadge.success(this.label, {super.key})
      : color = AppColors.glassAccentGreen,
        background = AppColors.glassSuccessBg,
        borderColor = null;

  /// Peach "Pending" / "Configured" style.
  const StatusBadge.pending(this.label, {super.key})
      : color = AppColors.glassAccentSecondary,
        background = AppColors.glassAccentSecondaryBg,
        borderColor = null;

  /// Neutral gray "Set Up" style.
  const StatusBadge.neutral(this.label, {super.key})
      : color = AppColors.glassOnSurfaceMuted,
        background = AppColors.glassSurfaceRaised,
        borderColor = null;

  /// Gold "PREMIUM" style, always bordered.
  const StatusBadge.premium(this.label, {super.key})
      : color = AppColors.glassWarningColor,
        background = AppColors.glassWarningBg,
        borderColor = AppColors.glassWarningColor;

  /// Amber/Gold "Expiring" style.
  const StatusBadge.warning(this.label, {super.key})
      : color = AppColors.glassWarningColor,
        background = AppColors.glassWarningBg,
        borderColor = null;

  /// Red "Expired" / "Destructive" style.
  const StatusBadge.danger(this.label, {super.key})
      : color = AppColors.glassDestructive,
        background = const Color(0x26FF453A),
        borderColor = null;

  /// Peach-bordered trust pill ("Full Access", "On Release"...).
  const StatusBadge.trust(this.label, {super.key})
      : color = AppColors.glassAccentSecondary,
        background = AppColors.glassAccentSecondaryBg,
        borderColor = AppColors.glassAccentSecondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.radiusSM,
        border: borderColor != null ? Border.all(color: borderColor!) : null,
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
