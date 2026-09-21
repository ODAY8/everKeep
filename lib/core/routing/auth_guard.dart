import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../theme/app_colors.dart';

/// Wraps a signed-in-only screen. If nobody is authenticated — a cold link
/// into the app, or the session ending while the screen is open — it sends
/// the user to [redirectTo] instead of showing the screen's content.
class AuthGuard extends StatefulWidget {
  final Widget child;
  final String redirectTo;

  const AuthGuard({super.key, required this.child, required this.redirectTo});

  @override
  State<AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends State<AuthGuard> {
  bool _redirectScheduled = false;

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = context.select<AuthProvider, bool>(
      (auth) => auth.isAuthenticated,
    );

    if (isAuthenticated) {
      _redirectScheduled = false;
      return widget.child;
    }

    if (!_redirectScheduled) {
      _redirectScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // A screen that handled sign-out itself (navigating away) is already
        // gone by now, so there is nothing left to redirect.
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil(
          widget.redirectTo,
          (route) => false,
        );
      });
    }

    return const Scaffold(backgroundColor: AppColors.glassBackground);
  }
}
