import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';

/// The base dark translucent card used throughout the glassmorphism theme.
///
/// Deliberately no `BackdropFilter` here: on the app's flat near-black
/// canvas a live blur buys no visible effect, and this card renders many
/// times per screen (grids, lists) — a per-instance blur pass would be a
/// significant, avoidable GPU cost.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final Gradient? gradient;
  final Color? glowColor;
  final Color borderColor;
  final VoidCallback? onTap;

  const GlassCard({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = AppRadius.radiusXL,
    this.gradient,
    this.glowColor,
    this.borderColor = AppColors.glassBorder,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: gradient == null ? AppColors.glassSurface : null,
      gradient: gradient,
      borderRadius: borderRadius,
      border: Border.all(
        color: glowColor != null
            ? glowColor!.withValues(alpha: 0.45)
            : borderColor,
      ),
      boxShadow: glowColor != null
          ? [
              BoxShadow(
                color: glowColor!.withValues(alpha: 0.16),
                blurRadius: 28,
                spreadRadius: 1,
              ),
            ]
          : null,
    );

    final content = Container(padding: padding, decoration: decoration, child: child);

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: onTap,
        child: content,
      ),
    );
  }
}
