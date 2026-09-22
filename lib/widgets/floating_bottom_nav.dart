import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_shadows.dart';
import '../core/theme/app_text_styles.dart';
import '../providers/user_provider.dart';
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
            AnimatedScale(
              scale: isActive ? 1.12 : 1.0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(height: 4),
            // Shrinks a long label (e.g. "Memories" at a large text scale)
            // to fit the 60px slot instead of wrapping and overflowing.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style: AppTextStyles.labelSmall.copyWith(
                  color: color,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 11,
                ),
                child: Text(label, maxLines: 1, softWrap: false),
              ),
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
      // The signed-in user's real photo (an icon until they add one).
      child: Selector<UserProvider, String?>(
        selector: (_, userProv) => userProv.user?.avatarUrl,
        builder: (context, avatarUrl, _) => ProfileAvatar(
          url: avatarUrl,
          size: 36,
          // Also the colour of the placeholder icon, so it stays visible when
          // there is no photo and no ring.
          borderColor: isActive
              ? AppColors.glassAccentPink
              : AppColors.glassOnSurfaceFaint,
          borderWidth: isActive ? 2 : 0,
        ),
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
