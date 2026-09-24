import 'package:everkeep/core/routing/auth_guard.dart';
import 'package:everkeep/features/accounts/presentation/screens/accounts_screen.dart';
import 'package:everkeep/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:everkeep/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:everkeep/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:everkeep/features/auth/presentation/screens/sign_up_screen.dart';
import 'package:everkeep/features/auth/presentation/screens/welcome_screen.dart';
import 'package:everkeep/features/documents/presentation/screens/documents_screen.dart';
import 'package:everkeep/features/emergency_access/presentation/screens/emergency_access_screen.dart';
import 'package:everkeep/features/shell/main_shell.dart';
import 'package:everkeep/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:everkeep/features/profile/presentation/screens/profile_screen.dart';
import 'package:everkeep/features/security/presentation/screens/security_screen.dart';
import 'package:everkeep/features/settings/presentation/screens/settings_screen.dart';
import 'package:everkeep/features/splash/presentation/screens/splash_screen.dart';
import 'package:everkeep/features/timeline/presentation/screens/timeline_screen.dart';
import 'package:everkeep/features/trusted_contacts/presentation/screens/trusted_contacts_screen.dart';
import 'package:everkeep/features/vault/presentation/screens/vault_screen.dart';
import 'package:everkeep/features/wishes/presentation/screens/wishes_screen.dart';
import 'package:flutter/material.dart';

class AppRouter {
  /// Lets code outside the widget tree (a deep link, a session event) navigate.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String welcome = '/welcome';
  static const String signIn = '/sign-in';
  static const String signUp = '/sign-up';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String home = '/home';
  static const String vault = '/vault';
  static const String documents = '/documents';
  static const String accounts = '/accounts';
  static const String wishes = '/wishes';
  static const String trustedContacts = '/trusted-contacts';
  static const String emergencyAccess = '/emergency-access';
  static const String profile = '/profile';
  static const String security = '/security';
  static const String settings = '/settings';
  static const String timeline = '/timeline';

  /// Public screens (splash, onboarding, auth) are built as-is; everything
  /// else is wrapped in an [AuthGuard] so it can't be reached signed out.
  static Route<dynamic> generateRoute(RouteSettings settings) {
    final Widget page = switch (settings.name) {
      AppRouter.splash => const SplashScreen(),
      AppRouter.onboarding => const OnboardingScreen(),
      AppRouter.welcome => const WelcomeScreen(),
      AppRouter.signIn => const SignInScreen(),
      AppRouter.signUp => const SignUpScreen(),
      AppRouter.forgotPassword => const ForgotPasswordScreen(),
      AppRouter.resetPassword => const ResetPasswordScreen(),
      AppRouter.home => _guarded(const MainShell()),
      AppRouter.vault => _guarded(const VaultScreen()),
      AppRouter.documents => _guarded(const DocumentsScreen()),
      AppRouter.accounts => _guarded(const AccountsScreen()),
      AppRouter.wishes => _guarded(const WishesScreen()),
      AppRouter.trustedContacts => _guarded(const TrustedContactsScreen()),
      AppRouter.emergencyAccess => _guarded(const EmergencyAccessScreen()),
      AppRouter.profile => _guarded(const ProfileScreen()),
      AppRouter.security => _guarded(const SecurityScreen()),
      AppRouter.settings => _guarded(const SettingsScreen()),
      AppRouter.timeline => _guarded(const TimelineScreen()),
      _ => _guarded(const MainShell()),
    };

    return MaterialPageRoute(builder: (_) => page, settings: settings);
  }

  static Widget _guarded(Widget page) =>
      AuthGuard(redirectTo: welcome, child: page);
}
