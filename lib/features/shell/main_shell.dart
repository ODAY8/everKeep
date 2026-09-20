import 'package:flutter/material.dart';
import 'package:everkeep/core/routing/app_router.dart';
import 'package:everkeep/core/theme/app_colors.dart';
import 'package:everkeep/features/home/presentation/screens/home_screen.dart';
import 'package:everkeep/features/vault/presentation/screens/vault_screen.dart';
import 'package:everkeep/features/wishes/presentation/screens/wishes_screen.dart';
import 'package:everkeep/features/profile/presentation/screens/profile_screen.dart';
import 'package:everkeep/widgets/floating_bottom_nav.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  static const _screens = [
    HomeScreen(),
    VaultScreen(),
    SizedBox.shrink(),
    WishesScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.glassBackground,
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: FloatingBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 2) {
            Navigator.of(context).pushNamed(AppRouter.documents);
            return;
          }
          setState(() => _currentIndex = index);
        },
      ),
    );
  }
}
