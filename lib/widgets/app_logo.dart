import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// The Everkeep brand mark: a small circular badge with the shield glyph,
/// used wherever a compact logo is needed (hero overlays, splash, headers).
class AppLogo extends StatelessWidget {
  final double size;
  final Color background;
  final Color foreground;

  const AppLogo({
    Key? key,
    this.size = 40,
    this.background = Colors.white,
    this.foreground = AppColors.accentPink,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.shield_rounded,
        color: foreground,
        size: size * 0.52,
      ),
    );
  }
}
