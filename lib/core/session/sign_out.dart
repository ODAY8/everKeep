import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../widgets/feedback.dart';
import '../routing/app_router.dart';

/// Signs the user out and returns to the welcome screen.
///
/// Only navigates away if the session really ended: if the backend couldn't
/// sign the user out they are still signed in, so they stay where they are
/// and are told why. Resetting the per-user providers happens in
/// `SessionCoordinator`, in response to the sign-out itself.
Future<void> signOutAndReturnToWelcome(BuildContext context) async {
  final auth = context.read<AuthProvider>();
  final signedOut = await auth.signOut();
  if (!context.mounted) return;

  if (signedOut) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRouter.welcome,
      (route) => false,
    );
  } else {
    showAppSnackBar(
      context,
      auth.error ?? 'Could not sign out. Please try again.',
      isError: true,
    );
    auth.clearError();
  }
}
