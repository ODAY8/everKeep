import 'package:flutter/material.dart';

/// A small circular tappable icon button, used for header actions (back,
/// notifications, add) across the gradient hero and vault headers.
class CircularIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final Color background;
  final Color foreground;
  final bool showBadge;
  final Color badgeColor;
  final String? tooltip;

  const CircularIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 44,
    this.background = Colors.white,
    this.foreground = Colors.black,
    this.showBadge = false,
    this.badgeColor = Colors.orange,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Ink(
          width: size,
          height: size,
          decoration: BoxDecoration(color: background, shape: BoxShape.circle),
          child: Icon(icon, color: foreground, size: size * 0.48),
        ),
      ),
    );

    final wrapped = Stack(
      clipBehavior: Clip.none,
      children: [
        button,
        if (showBadge)
          Positioned(
            top: 1,
            right: 1,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.circle,
                border: Border.all(color: background, width: 1.5),
              ),
            ),
          ),
      ],
    );

    return tooltip == null ? wrapped : Tooltip(message: tooltip!, child: wrapped);
  }
}
