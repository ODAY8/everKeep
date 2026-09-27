import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../providers/app_lock_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../screens/app_lock_screen.dart';

/// Wraps the entire application and displays [AppLockScreen] over the current route
/// whenever biometric app lock is engaged.
///
/// Also observes app lifecycle transitions ([AppLifecycleState.paused] / [AppLifecycleState.resumed])
/// to enforce the configured lock timeout.
class AppLockGate extends StatefulWidget {
  final Widget child;

  const AppLockGate({super.key, required this.child});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppLockProvider? lockProv;
      AuthProvider? authProv;
      try {
        lockProv = context.read<AppLockProvider>();
        authProv = context.read<AuthProvider>();
      } catch (_) {
        // AppLockProvider not mounted
      }

      if (lockProv != null && !lockProv.isInitialized) {
        lockProv.initialize().then((_) {
          if (mounted && lockProv!.isLocked && (authProv?.isAuthenticated ?? false)) {
            lockProv.unlock();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    AppLockProvider? lockProv;
    AuthProvider? authProv;
    try {
      lockProv = context.read<AppLockProvider>();
      authProv = context.read<AuthProvider>();
    } catch (_) {
      return;
    }

    if (lockProv == null || authProv == null) return;
    if (!authProv.isAuthenticated || !lockProv.isEnabled) return;

    if (state == AppLifecycleState.paused) {
      lockProv.onAppBackgrounded();
    } else if (state == AppLifecycleState.resumed) {
      lockProv.onAppForegrounded();
      if (lockProv.isLocked) {
        lockProv.unlock();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    AppLockProvider? lockProv;
    AuthProvider? authProv;
    try {
      lockProv = context.watch<AppLockProvider>();
      authProv = context.watch<AuthProvider>();
    } catch (_) {
      // AppLockProvider not mounted in test
    }

    final shouldShowLock =
        (lockProv?.isLocked ?? false) && (authProv?.isAuthenticated ?? false);

    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        widget.child,
        if (shouldShowLock)
          const Positioned.fill(
            child: AppLockScreen(),
          ),
      ],
    );
  }
}
