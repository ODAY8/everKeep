import 'package:everkeep/core/routing/app_router.dart';
import 'package:everkeep/features/accounts/presentation/screens/accounts_screen.dart';
import 'package:everkeep/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:everkeep/features/auth/presentation/screens/welcome_screen.dart';
import 'package:everkeep/features/documents/presentation/screens/documents_screen.dart';
import 'package:everkeep/features/emergency_access/presentation/screens/emergency_access_screen.dart';
import 'package:everkeep/features/home/presentation/screens/home_screen.dart';
import 'package:everkeep/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:everkeep/features/profile/presentation/screens/profile_screen.dart';
import 'package:everkeep/features/settings/presentation/screens/settings_screen.dart';
import 'package:everkeep/features/splash/presentation/screens/splash_screen.dart';
import 'package:everkeep/features/trusted_contacts/presentation/screens/trusted_contacts_screen.dart';
import 'package:everkeep/features/vault/presentation/screens/vault_screen.dart';
import 'package:everkeep/features/wishes/presentation/screens/wishes_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Smoke tests: every top-level screen must build without throwing, so
/// runtime issues that `flutter analyze` can't see (missing required args,
/// layout assertions, null derefs during build) surface in CI without ever
/// needing a real display.
void main() {
  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: AppRouter.generateRoute,
        home: screen,
      ),
    );
    await tester.pump();
  }

  testWidgets('SplashScreen builds without throwing', (tester) async {
    await pumpScreen(tester, const SplashScreen());
    expect(tester.takeException(), isNull);
  });

  testWidgets('WelcomeScreen builds without throwing', (tester) async {
    await pumpScreen(tester, const WelcomeScreen());
    expect(tester.takeException(), isNull);
    expect(find.text('Create your legacy'), findsOneWidget);
  });

  testWidgets('SignInScreen builds without throwing', (tester) async {
    await pumpScreen(tester, const SignInScreen());
    expect(tester.takeException(), isNull);
  });

  testWidgets('OnboardingScreen builds without throwing', (tester) async {
    await pumpScreen(tester, const OnboardingScreen());
    expect(tester.takeException(), isNull);
  });

  testWidgets('HomeScreen builds without throwing', (tester) async {
    await pumpScreen(tester, const HomeScreen());
    expect(tester.takeException(), isNull);
    expect(find.text('Welcome back,'), findsOneWidget);
  });

  testWidgets('VaultScreen builds without throwing', (tester) async {
    await pumpScreen(tester, const VaultScreen());
    expect(tester.takeException(), isNull);
    expect(find.text('Your Vault'), findsOneWidget);
  });

  testWidgets('DocumentsScreen builds without throwing', (tester) async {
    await pumpScreen(tester, const DocumentsScreen());
    expect(tester.takeException(), isNull);
  });

  testWidgets('AccountsScreen builds without throwing', (tester) async {
    await pumpScreen(tester, const AccountsScreen());
    expect(tester.takeException(), isNull);
  });

  testWidgets('WishesScreen (Memories) builds without throwing', (tester) async {
    await pumpScreen(tester, const WishesScreen());
    expect(tester.takeException(), isNull);
    // Both the page title and the bottom-nav label read "Memories".
    expect(find.text('Memories'), findsWidgets);
  });

  testWidgets('TrustedContactsScreen builds without throwing', (tester) async {
    await pumpScreen(tester, const TrustedContactsScreen());
    expect(tester.takeException(), isNull);
  });

  testWidgets('EmergencyAccessScreen builds without throwing', (tester) async {
    await pumpScreen(tester, const EmergencyAccessScreen());
    expect(tester.takeException(), isNull);
  });

  testWidgets('ProfileScreen builds without throwing', (tester) async {
    await pumpScreen(tester, const ProfileScreen());
    expect(tester.takeException(), isNull);
    expect(find.text('Adom Mensah'), findsOneWidget);
  });

  testWidgets('SettingsScreen builds without throwing', (tester) async {
    await pumpScreen(tester, const SettingsScreen());
    expect(tester.takeException(), isNull);
  });
}
