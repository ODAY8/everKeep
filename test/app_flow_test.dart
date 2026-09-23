import 'package:everkeep/core/utils/greeting.dart';
import 'package:everkeep/core/routing/app_router.dart';
import 'package:everkeep/core/session/session_sync.dart';
import 'package:everkeep/core/session/sign_out.dart';
import 'package:everkeep/main.dart';
import 'package:everkeep/providers/account_provider.dart';
import 'package:everkeep/providers/auth_provider.dart';
import 'package:everkeep/providers/document_provider.dart';
import 'package:everkeep/providers/memory_provider.dart';
import 'package:everkeep/providers/settings_provider.dart';
import 'package:everkeep/providers/trusted_contact_provider.dart';
import 'package:everkeep/providers/user_provider.dart';
import 'package:everkeep/providers/vault_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'fakes.dart';

/// The whole app tree — the SessionSync coordinator, the router and its guard,
/// with fake repositories standing in for Supabase — exercised together, the
/// way `main()` assembles it.
void main() {
  Future<void> pumpFor(WidgetTester tester, Duration total) async {
    // Step in small increments so fake-async timers (service delays,
    // animations, route transitions) all get to fire in order.
    for (var elapsed = Duration.zero; elapsed < total;) {
      const step = Duration(milliseconds: 100);
      await tester.pump(step);
      elapsed += step;
    }
  }

  Widget buildApp() {
    final authRepo = FakeAuthRepository();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(authRepository: authRepo),
        ),
        ChangeNotifierProvider<UserProvider>(
          create: (_) =>
              UserProvider(userRepository: FakeUserRepository(authRepo)),
        ),
        ChangeNotifierProvider<VaultProvider>(
          create: (_) => VaultProvider(vaultRepository: FakeVaultRepository()),
        ),
        ChangeNotifierProvider<DocumentProvider>(
          create: (_) =>
              DocumentProvider(documentRepository: FakeDocumentRepository()),
        ),
        ChangeNotifierProvider<MemoryProvider>(
          create: (_) =>
              MemoryProvider(memoryRepository: FakeMemoryRepository()),
        ),
        ChangeNotifierProvider<AccountProvider>(
          create: (_) =>
              AccountProvider(accountRepository: FakeAccountRepository()),
        ),
        ChangeNotifierProvider<TrustedContactProvider>(
          create: (_) => TrustedContactProvider(
            trustedContactRepository: FakeTrustedContactRepository(),
          ),
        ),
        ChangeNotifierProvider<SettingsProvider>(
          create: (_) =>
              SettingsProvider(settingsRepository: FakeSettingsRepository()),
        ),
      ],
      child: const SessionSync(child: EverkeepApp()),
    );
  }

  testWidgets(
    'signed-out deep link is bounced; sign-up personalises Home; sign-out wipes it',
    (tester) async {
      await tester.pumpWidget(buildApp());

      // Cold start with no session: splash -> onboarding.
      await pumpFor(tester, const Duration(seconds: 3));
      expect(find.text('Skip'), findsOneWidget);

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));

      // A protected route while signed out must not render; it redirects.
      navigator.pushNamed(AppRouter.home);
      await pumpFor(tester, const Duration(seconds: 1));
      expect(find.textContaining('Good '), findsNothing);
      expect(find.text('Create Your Legacy'), findsOneWidget); // welcome

      // Sign up as a new user, then go home.
      final context = tester.element(find.byType(Navigator));
      final auth = context.read<AuthProvider>();
      final signUp = auth.signUp(
        name: 'Alex Rivera',
        email: 'alex@example.com',
        password: 'secret1',
      );
      await pumpFor(tester, const Duration(seconds: 1));
      expect(await signUp, isTrue);

      navigator.pushNamedAndRemoveUntil(AppRouter.home, (route) => false);
      await pumpFor(tester, const Duration(seconds: 2));

      // Home greets the person who signed up, not a stock persona...
      expect(
        find.textContaining(RegExp(r'Good (morning|afternoon|evening),')),
        findsOneWidget,
      );
      expect(find.text('Alex'), findsOneWidget);
      expect(find.text('Sarah'), findsNothing);
      // ...and its counts reflect the loaded data rather than fixed strings.
      final documents = context.read<DocumentProvider>();
      final contacts = context.read<TrustedContactProvider>();
      expect(documents.hasFetched, isTrue);
      expect(contacts.hasFetched, isTrue);
      expect(
        find.text('${countLabel(documents.count, 'file', 'files')} stored'),
        findsOneWidget,
      );
      expect(
        find.text(countLabel(contacts.count, 'trustee', 'trustees')),
        findsOneWidget,
      );
      expect(find.text('12 vital files'), findsNothing);

      // Sign out: land on welcome and leave nothing behind.
      final greetingText = find.textContaining(
        RegExp(r'Good (morning|afternoon|evening),'),
      );
      final homeContext = tester.element(greetingText);
      final signOut = signOutAndReturnToWelcome(homeContext);
      await pumpFor(tester, const Duration(seconds: 1));
      await signOut;
      await pumpFor(tester, const Duration(seconds: 1));

      expect(find.text('Create Your Legacy'), findsOneWidget);
      expect(greetingText, findsNothing);
      expect(auth.isAuthenticated, isFalse);
      expect(context.read<UserProvider>().user, isNull);
      expect(documents.documents, isEmpty);
      expect(documents.hasFetched, isFalse);
      expect(contacts.contacts, isEmpty);
      expect(context.read<AccountProvider>().accounts, isEmpty);
    },
  );
}
