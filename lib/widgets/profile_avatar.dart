import 'package:flutter/material.dart';
import 'app_network_image.dart';

/// Circular user avatar loaded from a network photo, with a graceful
/// icon fallback when no photo is available or the load fails.
class ProfileAvatar extends StatelessWidget {
  final String? url;
  final double size;
  final Color borderColor;
  final double borderWidth;

  const ProfileAvatar({
    Key? key,
    this.url,
    this.size = 48,
    this.borderColor = Colors.white,
    this.borderWidth = 2,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: borderWidth > 0
            ? Border.all(color: borderColor, width: borderWidth)
            : null,
      ),
      child: ClipOval(
        child: (url == null || url!.isEmpty)
            ? ColoredBox(
                color: borderColor.withValues(alpha: 0.2),
                child: Icon(
                  Icons.person_rounded,
                  color: borderColor,
                  size: size * 0.55,
                ),
              )
            : AppNetworkImage(
                url: url!,
                fallbackIcon: Icons.person_rounded,
              ),
      ),
    );
  }
}
