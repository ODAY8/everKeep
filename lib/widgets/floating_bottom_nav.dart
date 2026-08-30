import 'package:flutter/material.dart';
import '../core/config/app_image_urls.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_shadows.dart';
import '../core/theme/app_text_styles.dart';
import 'profile_avatar.dart';

/// The bottom navigation bar shared by every authenticated screen: Home,
/// Vault, a raised gradient Add action, Memories, and Profile (shown as the
/// user's own avatar with an accent ring when active). Fixed full-width bar
/// flush to the screen edges, matching the Figma reference — not a floating
/// inset pill.
class FloatingBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const FloatingBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 84,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: const BoxDecoration(
        color: AppColors.glassNavBarBg,
        border: Border(top: BorderSide(color: AppColors.glassBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _NavItem(
            icon: Icons.home_rounded,
            label: 'Home',
            index: 0,
            currentIndex: currentIndex,
            onTap: onTap,
          ),
          _NavItem(
            icon: Icons.explore_outlined,
            label: 'Vault',
            index: 1,
            currentIndex: currentIndex,
            onTap: onTap,
          ),
          _CenterAddButton(onTap: () => onTap(2)),
          _NavItem(
            icon: Icons.favorite_rounded,
            label: 'Memories',
            index: 3,
            currentIndex: currentIndex,
            onTap: onTap,
          ),
          _ProfileNavItem(
            index: 4,
            currentIndex: currentIndex,
            onTap: onTap,
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = currentIndex == index;
    final color = isActive ? Colors.white : AppColors.glassOnSurfaceFaint;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              tween: Tween(begin: 1.0, end: isActive ? 1.12 : 1.0),
              builder: (context, scale, child) => Transform.scale(
                scale: scale,
                child: child,
              ),
              child: TweenAnimationBuilder<Color?>(
                duration: const Duration(milliseconds: 200),
                tween: ColorTween(end: color),
                builder: (context, animatedColor, _) =>
                    Icon(icon, size: 22, color: animatedColor),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: AppTextStyles.labelSmall.copyWith(
                color: color,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                fontSize: 11,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileNavItem extends StatelessWidget {
  final int index;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _ProfileNavItem({
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: ProfileAvatar(
        url: AppImageUrls.mockUserAvatar,
        size: 36,
        borderColor: isActive ? AppColors.glassAccentPink : Colors.transparent,
        borderWidth: isActive ? 2 : 0,
      ),
    );
  }
}

class _CenterAddButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CenterAddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Transform.translate(
        offset: const Offset(0, -14),
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: AppColors.glassAccentGradient,
            shape: BoxShape.circle,
            boxShadow: AppShadows.accentButtonShadow,
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}
