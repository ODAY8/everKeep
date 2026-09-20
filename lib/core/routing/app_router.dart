import 'package:everkeep/features/accounts/presentation/screens/accounts_screen.dart';
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
import 'package:everkeep/features/trusted_contacts/presentation/screens/trusted_contacts_screen.dart';
import 'package:everkeep/features/vault/presentation/screens/vault_screen.dart';
import 'package:everkeep/features/wishes/presentation/screens/wishes_screen.dart';
import 'package:flutter/material.dart';

class AppRouter {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String welcome = '/welcome';
  static const String signIn = '/sign-in';
  static const String signUp = '/sign-up';
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

  static Route<dynamic> generateRoute(RouteSettings settings) {
    final Widget page = switch (settings.name) {
      AppRouter.splash => const SplashScreen(),
      AppRouter.onboarding => const OnboardingScreen(),
      AppRouter.welcome => const WelcomeScreen(),
      AppRouter.signIn => const SignInScreen(),
      AppRouter.signUp => const SignUpScreen(),
      AppRouter.home => const MainShell(),
      AppRouter.vault => const VaultScreen(),
      AppRouter.documents => const DocumentsScreen(),
      AppRouter.accounts => const AccountsScreen(),
      AppRouter.wishes => const WishesScreen(),
      AppRouter.trustedContacts => const TrustedContactsScreen(),
      AppRouter.emergencyAccess => const EmergencyAccessScreen(),
      AppRouter.profile => const ProfileScreen(),
      AppRouter.security => const SecurityScreen(),
      AppRouter.settings => const SettingsScreen(),
      _ => const MainShell(),
    };

    return MaterialPageRoute(builder: (_) => page, settings: settings);
  }
}
