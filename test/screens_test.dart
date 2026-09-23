import 'dart:async';

import 'package:everkeep/features/accounts/presentation/screens/accounts_screen.dart';
import 'package:everkeep/features/documents/presentation/screens/documents_screen.dart';
import 'package:everkeep/features/emergency_access/presentation/screens/emergency_access_screen.dart';
import 'package:everkeep/features/home/presentation/screens/home_screen.dart';
import 'package:everkeep/features/profile/presentation/screens/profile_screen.dart';
import 'package:everkeep/features/security/presentation/screens/security_screen.dart';
import 'package:everkeep/features/settings/presentation/screens/settings_screen.dart';
import 'package:everkeep/features/vault/presentation/screens/vault_screen.dart';
import 'package:everkeep/features/wishes/presentation/screens/wishes_screen.dart';
import 'package:everkeep/models/account_item.dart';
import 'package:everkeep/models/document_item.dart';
import 'package:everkeep/models/user.dart';
import 'package:everkeep/providers/account_provider.dart';
import 'package:everkeep/providers/auth_provider.dart';
import 'package:everkeep/providers/document_provider.dart';
import 'package:everkeep/providers/memory_provider.dart';
import 'package:everkeep/providers/settings_provider.dart';
import 'package:everkeep/providers/trusted_contact_provider.dart';
import 'package:everkeep/providers/user_provider.dart';
import 'package:everkeep/providers/vault_provider.dart';
import 'package:everkeep/widgets/app_network_image.dart';
import 'package:everkeep/widgets/glass/glass_primary_button.dart';
import 'package:everkeep/widgets/glass/security_score_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import 'package:provider/provider.dart';

import 'fakes.dart';

/// Every screen against fake repositories: nothing on them is made up, and every
/// control does what it says (or isn't there).
void main() {
  /// The repositories and providers a screen may need, wired the way `main()`
  /// wires the real ones.
  late FakeAuthRepository authRepo;
  late FakeUserRepository userRepo;
  late FakeDocumentRepository docRepo;
  late FakeMemoryRepository memoryRepo;
  late FakeAccountRepository accRepo;
  late FakeTrustedContactRepository contactRepo;
  late AuthProvider auth;
  late UserProvider user;
  late VaultProvider vault;
  late DocumentProvider documents;
  late MemoryProvider memories;
  late AccountProvider accounts;
  late TrustedContactProvider contacts;

  setUp(() {
    authRepo = FakeAuthRepository();
    userRepo = FakeUserRepository(authRepo);
    docRepo = FakeDocumentRepository();
    memoryRepo = FakeMemoryRepository();
    accRepo = FakeAccountRepository();
    contactRepo = FakeTrustedContactRepository();
    auth = AuthProvider(authRepository: authRepo);
    user = UserProvider(userRepository: userRepo)..setUser(testUser);
    vault = VaultProvider(vaultRepository: FakeVaultRepository());
    documents = DocumentProvider(documentRepository: docRepo);
    memories = MemoryProvider(memoryRepository: memoryRepo);
    accounts = AccountProvider(accountRepository: accRepo);
    contacts = TrustedContactProvider(trustedContactRepository: contactRepo);
  });

  /// A tall screen, so long pages don't need scrolling to reach their bottom.
  void tallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  /// Shows [screen]; any route it navigates to is drawn as `ROUTE <name>`, so a
  /// test can check where a tap went.
  Future<void> pump(WidgetTester tester, Widget screen) async {
    tallScreen(tester);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<UserProvider>.value(value: user),
          ChangeNotifierProvider<VaultProvider>.value(value: vault),
          ChangeNotifierProvider<DocumentProvider>.value(value: documents),
          ChangeNotifierProvider<MemoryProvider>.value(value: memories),
          ChangeNotifierProvider<AccountProvider>.value(value: accounts),
          ChangeNotifierProvider<TrustedContactProvider>.value(value: contacts),
          ChangeNotifierProvider<SettingsProvider>(
            create: (_) =>
                SettingsProvider(settingsRepository: FakeSettingsRepository()),
          ),
        ],
        child: MaterialApp(
          home: screen,
          onGenerateRoute: (settings) => MaterialPageRoute(
            settings: settings,
            builder: (_) => Scaffold(body: Text('ROUTE ${settings.name}')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> loadEverything() async {
    await documents.fetchDocuments();
    await memories.fetchMemories();
    await accounts.fetchAccounts();
    await contacts.fetchContacts();
    await vault.fetchVaultSummary();
  }

  const fakeNames = [
    'Sarah Kim',
    'Will & Testament',
    'Sarah Johnson',
    'Michael Chen',
    'Emily Davis',
    'Robert Wilson',
    'Emma (Daughter)',
    'Michael (Son)',
    'Family Summer 2023',
    "Dad's 60th Birthday",
    'Premium Account',
    'Legacy Prefs',
    '142 items',
    '12 vital files',
    'Vault Score: Strong',
    'zero-knowledge',
  ];

  void expectNoSampleContent() {
    for (final name in fakeNames) {
      expect(
        find.textContaining(name),
        findsNothing,
        reason: '"$name" is sample data',
      );
    }
  }

  // ── Home ────────────────────────────────────────────────────────────────────

  group('Home', () {
    testWidgets('greets by time of day and shows only real content', (
      tester,
    ) async {
      await pump(tester, const HomeScreen());

      expect(
        find.textContaining(RegExp(r'Good (morning|afternoon|evening),')),
        findsOneWidget,
      );
      expect(find.text('Sarah'), findsOneWidget);
      expectNoSampleContent();
      // There is no notification feature, so no notification bell (or badge).
      expect(find.byIcon(Icons.notifications_none_rounded), findsNothing);
    });

    testWidgets('the counts come from live data', (tester) async {
      await pump(tester, const HomeScreen());

      vault.updateLiveCounts(
        documents: 3,
        accounts: 2,
        banking: 0,
        contacts: 2,
      );
      await tester.pumpAndSettle();

      expect(find.text('3 files stored'), findsOneWidget);
      expect(find.text('2 logins saved'), findsOneWidget);
      expect(find.text('2 trustees'), findsOneWidget);
    });

    testWidgets('a feature that isn\'t built says "Coming soon"', (
      tester,
    ) async {
      await pump(tester, const HomeScreen());
      expect(find.text('Coming soon'), findsOneWidget); // Memories
      expect(find.text('Future Messages'), findsNothing);
    });

    testWidgets('progress reflects the checklist and points at the next step', (
      tester,
    ) async {
      await pump(tester, const HomeScreen());

      expect(find.text('Your Legacy is 0% Complete'), findsOneWidget);
      expect(
        find.textContaining('4 steps to go · Add your first document'),
        findsOneWidget,
      );

      await tester.tap(find.text('Your Legacy is 0% Complete'));
      await tester.pumpAndSettle();
      expect(find.text('ROUTE /documents'), findsOneWidget);
    });

    testWidgets('the next step moves on as things get done', (tester) async {
      await pump(tester, const HomeScreen());

      vault.updateLiveCounts(
        documents: 1,
        accounts: 0,
        banking: 0,
        contacts: 0,
      );
      await tester.pumpAndSettle();
      expect(find.text('Your Legacy is 25% Complete'), findsOneWidget);
      expect(find.textContaining('Save an account login'), findsOneWidget);
    });

    testWidgets('finishing every step says so', (tester) async {
      await loadEverything(); // the sample summary has a confirmed email
      await pump(tester, const HomeScreen());

      vault.updateLiveCounts(
        documents: 1,
        accounts: 1,
        banking: 0,
        contacts: 1,
      );
      await tester.pumpAndSettle();

      expect(find.text('Your Legacy is 100% Complete'), findsOneWidget);
      expect(find.text('Everything is set up. Nicely done.'), findsOneWidget);
    });

    testWidgets('recent activity lists what the user really added', (
      tester,
    ) async {
      final now = DateTime.now();
      docRepo.items
        ..clear()
        ..add(
          DocumentItem(
            id: 'd',
            title: 'Passport.pdf',
            subtitle: '',
            category: 'Legal',
            dateAdded: now.subtract(const Duration(days: 2)),
          ),
        );
      await documents.fetchDocuments();

      await pump(tester, const HomeScreen());

      expect(find.text('Passport.pdf added'), findsOneWidget);
      expect(find.text('Documents · 2 days ago'), findsOneWidget);
      expect(find.textContaining('Nothing here yet'), findsNothing);
    });

    testWidgets('with nothing yet, it says so and invites the first step', (
      tester,
    ) async {
      await pump(tester, const HomeScreen());

      expect(find.textContaining('Nothing here yet'), findsOneWidget);
      await tester.tap(find.textContaining('Nothing here yet'));
      await tester.pumpAndSettle();
      expect(find.text('ROUTE /documents'), findsOneWidget);
    });

    testWidgets(
      'the security score card shows the real score and opens Security',
      (tester) async {
        await loadEverything();
        await pump(tester, const HomeScreen());

        expect(find.text('Good — 67/100'), findsOneWidget);
        await tester.tap(find.byType(SecurityScoreCard));
        await tester.pumpAndSettle();
        expect(find.text('ROUTE /security'), findsOneWidget);
      },
    );
  });

  // ── Security ────────────────────────────────────────────────────────────────

  group('Security', () {
    testWidgets('states what is in place, what is to do, and what is coming', (
      tester,
    ) async {
      await loadEverything();
      await pump(tester, const SecurityScreen());

      expect(find.text('Security: Good — 67/100'), findsOneWidget);
      expect(find.text('Confirmed email'), findsOneWidget);
      expect(find.text('Done'), findsNWidgets(2)); // email + a trusted person
      expect(find.text('Coming soon'), findsNWidgets(2)); // 2FA + biometric
      // No switch that does nothing, no fake "recovery key".
      expect(find.byType(Switch), findsNothing);
      expect(find.text('Recovery Key'), findsNothing);
      expectNoSampleContent();
    });

    testWidgets('an unfinished safeguard shows "To do"', (tester) async {
      await pump(
        tester,
        const SecurityScreen(),
      ); // nothing loaded: nothing in place

      expect(find.text('To do'), findsNWidgets(2));
      expect(find.text('Security: Weak — 0/100'), findsOneWidget);
    });

    testWidgets('a to-do safeguard takes you to where it is done', (
      tester,
    ) async {
      await pump(tester, const SecurityScreen());

      await tester.tap(find.text('A trusted person'));
      await tester.pumpAndSettle();
      expect(find.text('ROUTE /trusted-contacts'), findsOneWidget);
    });

    testWidgets('changing the password works', (tester) async {
      await pump(tester, const SecurityScreen());

      await tester.tap(find.text('Change password'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'brand-new-1');
      await tester.enterText(find.byType(TextField).at(1), 'brand-new-1');
      await tester.tap(
        find.widgetWithText(GlassPrimaryButton, 'Update Password'),
      );
      await tester.pumpAndSettle();

      expect(authRepo.lastPassword, 'brand-new-1');
      expect(find.text('Password updated'), findsOneWidget);
    });

    testWidgets('mismatched or too-short passwords are refused before saving', (
      tester,
    ) async {
      await pump(tester, const SecurityScreen());

      await tester.tap(find.text('Change password'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'brand-new-1');
      await tester.enterText(find.byType(TextField).at(1), 'different-2');
      await tester.tap(
        find.widgetWithText(GlassPrimaryButton, 'Update Password'),
      );
      await tester.pumpAndSettle();
      expect(find.text('The passwords don\'t match.'), findsOneWidget);
      expect(authRepo.lastPassword, isNull);

      await tester.enterText(find.byType(TextField).at(0), '123');
      await tester.tap(
        find.widgetWithText(GlassPrimaryButton, 'Update Password'),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('at least 6 characters'), findsOneWidget);
      expect(authRepo.lastPassword, isNull);
    });

    testWidgets('a failed password change keeps the sheet and what was typed', (
      tester,
    ) async {
      await pump(tester, const SecurityScreen());
      authRepo.failWith = 'Choose a password you haven\'t used before.';

      await tester.tap(find.text('Change password'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'old-password');
      await tester.enterText(find.byType(TextField).at(1), 'old-password');
      await tester.tap(
        find.widgetWithText(GlassPrimaryButton, 'Update Password'),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Choose a password you haven\'t used before.'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(GlassPrimaryButton, 'Update Password'),
        findsOneWidget,
      );
    });

    testWidgets('signing out everywhere asks first, then does it and leaves', (
      tester,
    ) async {
      await pump(tester, const SecurityScreen());

      await tester.tap(find.text('Sign out of all devices'));
      await tester.pumpAndSettle();
      expect(find.text('Sign out everywhere?'), findsOneWidget);
      expect(
        authRepo.signOutEverywhereCalls,
        0,
        reason: 'not before confirming',
      );

      await tester.tap(find.widgetWithText(TextButton, 'Sign Out Everywhere'));
      await tester.pumpAndSettle();

      expect(authRepo.signOutEverywhereCalls, 1);
      expect(find.text('ROUTE /welcome'), findsOneWidget);
    });

    testWidgets('cancelling leaves you signed in', (tester) async {
      await pump(tester, const SecurityScreen());

      await tester.tap(find.text('Sign out of all devices'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(authRepo.signOutEverywhereCalls, 0);
      expect(find.text('ROUTE /welcome'), findsNothing);
    });
  });

  // ── Settings ────────────────────────────────────────────────────────────────

  group('Settings', () {
    testWidgets(
      'every row is real; rows with no feature behind them are gone',
      (tester) async {
        user.setUser(testUser.copyWith(emailVerified: true));
        await pump(tester, const SettingsScreen());

        for (final row in [
          'Email',
          'Password',
          'Phone',
          'Download My Data',
          'About Everkeep',
        ]) {
          expect(find.text(row), findsOneWidget, reason: row);
        }
        expect(find.text('sarah.mitchell@example.com'), findsOneWidget);
        expect(find.text('+1 (555) 123-4567'), findsOneWidget);

        for (final gone in [
          'Data Sharing',
          'Visibility',
          'Email Alerts',
          'Push Notifications',
          'Message Reminders',
          'FAQ',
          // Only shown when a link is configured (none is in tests).
          'Help Center',
          'Contact Us',
          'Terms of Service',
          'Privacy Policy',
        ]) {
          expect(
            find.text(gone),
            findsNothing,
            reason: '"$gone" would be a dead button',
          );
        }
        expectNoSampleContent();
      },
    );

    testWidgets(
      'changing the email validates, then asks Supabase to email a link',
      (tester) async {
        await pump(tester, const SettingsScreen());

        await tester.tap(find.text('Email'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'not-an-email');
        await tester.tap(find.widgetWithText(GlassPrimaryButton, 'Send Link'));
        await tester.pumpAndSettle();
        expect(find.text('Enter a valid email address'), findsOneWidget);
        expect(authRepo.lastEmailChange, isNull);

        await tester.enterText(find.byType(TextField), 'new@example.com');
        await tester.tap(find.widgetWithText(GlassPrimaryButton, 'Send Link'));
        await tester.pumpAndSettle();

        expect(authRepo.lastEmailChange, 'new@example.com');
        expect(
          find.textContaining('confirmation link to new@example.com'),
          findsOneWidget,
        );
      },
    );

    testWidgets('an unconfirmed email is labelled as such', (tester) async {
      user.setUser(testUser.copyWith(emailVerified: false));
      await pump(tester, const SettingsScreen());
      expect(find.textContaining('Not confirmed'), findsOneWidget);
    });

    testWidgets(
      'the phone number is validated against a real country and saved as E.164',
      (tester) async {
        await pump(tester, const SettingsScreen());

        await tester.tap(find.text('Phone'));
        await tester.pumpAndSettle();

        // Choose the country for real, through the picker.
        await tester.tap(find.byKey(const Key('phone-country-button')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, 'United Kingdom');
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('country-GB')));
        await tester.pumpAndSettle();
        expect(find.text('+44'), findsOneWidget);

        await tester.enterText(find.byType(TextField), '20 7946 0000');
        await tester.tap(find.widgetWithText(GlassPrimaryButton, 'Save'));
        await tester.pumpAndSettle();

        final expected = PhoneNumber.parse(
          '20 7946 0000',
          callerCountry: IsoCode.GB,
        ).international;
        expect(user.user?.phone, expected);
        expect(find.text(expected), findsOneWidget);
        expect(find.text('Phone number saved'), findsOneWidget);
      },
    );

    testWidgets('an invalid phone number is rejected before saving', (tester) async {
      user.setUser(testUser.copyWith(phone: ''));
      await pump(tester, const SettingsScreen());

      await tester.tap(find.text('Phone'));
      await tester.pumpAndSettle();
      // The default country is whatever the device reports; too short for any
      // real country's numbering plan.
      await tester.enterText(find.byType(TextField), '123');
      await tester.tap(find.widgetWithText(GlassPrimaryButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Enter a valid phone number'), findsOneWidget);
      expect(user.user?.phone, isEmpty);
    });

    testWidgets('an empty phone number removes it', (tester) async {
      user.setUser(testUser.copyWith(phone: '+442079460000'));
      await pump(tester, const SettingsScreen());

      await tester.tap(find.text('Phone'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.widgetWithText(GlassPrimaryButton, 'Save'));
      await tester.pumpAndSettle();

      expect(user.user?.phone, isEmpty);
      expect(find.text('Not set'), findsOneWidget);
    });

    testWidgets('reopening the sheet on an existing number restores its country', (
      tester,
    ) async {
      user.setUser(
        testUser.copyWith(
          phone: PhoneNumber.parse('20 7946 0000', callerCountry: IsoCode.GB).international,
        ),
      );
      await pump(tester, const SettingsScreen());

      await tester.tap(find.text('Phone'));
      await tester.pumpAndSettle();

      expect(find.text('+44'), findsOneWidget);
      expect(find.text('20 7946 0000'), findsOneWidget);
    });

    testWidgets(
      '"Download My Data" puts the account\'s data on the clipboard',
      (tester) async {
        String? copied;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = (call.arguments as Map)['text'] as String?;
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        await pump(tester, const SettingsScreen());

        await tester.tap(find.text('Download My Data'));
        await tester.pumpAndSettle();

        expect(copied, isNotNull);
        expect(copied, contains('sarah.mitchell@example.com'));
        expect(find.textContaining('Copied to your clipboard'), findsOneWidget);
      },
    );

    testWidgets('a failed export says so and copies nothing', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') copied = 'something';
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      userRepo.failWith = 'Can\'t reach the server.';
      await pump(tester, const SettingsScreen());

      await tester.tap(find.text('Download My Data'));
      await tester.pumpAndSettle();

      expect(copied, isNull);
      expect(find.text('Can\'t reach the server.'), findsOneWidget);
    });

    testWidgets('About shows the app name and version', (tester) async {
      await pump(tester, const SettingsScreen());

      await tester.tap(find.text('About Everkeep'));
      await tester.pumpAndSettle();

      expect(find.byType(AboutDialog), findsOneWidget);
      expect(find.text('1.0.0'), findsWidgets);
    });

    testWidgets('logging out returns to the welcome screen', (tester) async {
      await auth.signIn(email: 'a@b.co', password: 'secret1');
      await pump(tester, const SettingsScreen());

      await tester.tap(find.text('Log Out'));
      await tester.pumpAndSettle();

      expect(find.text('ROUTE /welcome'), findsOneWidget);
    });

    testWidgets('deleting the account needs DELETE typed exactly', (
      tester,
    ) async {
      await pump(tester, const SettingsScreen());

      await tester.tap(find.text('Delete Account'));
      await tester.pumpAndSettle();
      expect(find.textContaining('cannot be undone'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'delete');
      await tester.tap(
        find.widgetWithText(GlassPrimaryButton, 'Delete Everything'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Type DELETE exactly'), findsOneWidget);
      expect(userRepo.accountDeleted, isFalse);
    });

    testWidgets('confirming deletes the account and leaves', (tester) async {
      await pump(tester, const SettingsScreen());

      await tester.tap(find.text('Delete Account'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.tap(
        find.widgetWithText(GlassPrimaryButton, 'Delete Everything'),
      );
      await tester.pumpAndSettle();

      expect(userRepo.accountDeleted, isTrue);
      expect(find.text('ROUTE /welcome'), findsOneWidget);
      expect(find.text('Your account has been deleted.'), findsOneWidget);
    });

    testWidgets('if deletion fails the account is kept and the sheet shows why', (
      tester,
    ) async {
      userRepo.failWith =
          'Some of your files couldn\'t be removed, so your account was not deleted.';
      await pump(tester, const SettingsScreen());

      await tester.tap(find.text('Delete Account'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.tap(
        find.widgetWithText(GlassPrimaryButton, 'Delete Everything'),
      );
      await tester.pumpAndSettle();

      expect(userRepo.accountDeleted, isFalse);
      expect(
        find.textContaining('your account was not deleted'),
        findsOneWidget,
      );
      expect(find.text('ROUTE /welcome'), findsNothing);
    });
  });

  // ── Profile ─────────────────────────────────────────────────────────────────

  group('Profile', () {
    testWidgets('shows the real user and no invented rows', (tester) async {
      await loadEverything();
      await pump(tester, const ProfileScreen());

      expect(find.text('Sarah Mitchell'), findsWidgets);
      expect(find.text('sarah.mitchell@example.com'), findsOneWidget);
      expect(find.text('Last sign-in'), findsOneWidget);
      expect(find.text('Subscription Plan'), findsNothing);
      expect(find.text('Activity Log'), findsNothing);
      expectNoSampleContent();
    });

    testWidgets('the tiles show real counts and lead somewhere', (
      tester,
    ) async {
      await loadEverything();
      await pump(tester, const ProfileScreen());

      expect(
        find.text('11 files stored'),
        findsOneWidget,
      ); // the summary's figure
      expect(find.text('2 trustees'), findsOneWidget);
      expect(find.text('Good — 67/100'), findsOneWidget);

      await tester.tap(find.text('Security'));
      await tester.pumpAndSettle();
      expect(find.text('ROUTE /security'), findsOneWidget);
    });

    testWidgets(
      'tapping the photo offers to choose one (and remove only if there is one)',
      (tester) async {
        await pump(tester, const ProfileScreen());

        await tester.tap(find.byIcon(Icons.camera_alt_rounded));
        await tester.pumpAndSettle();

        expect(find.text('Profile photo'), findsOneWidget);
        expect(find.text('Choose a photo'), findsOneWidget);
        expect(find.text('Remove photo'), findsNothing);
        expect(find.text('View photo'), findsNothing, reason: 'nothing to view yet');
      },
    );

    testWidgets('a photo can be viewed full-size and closed', (tester) async {
      user.setUser(testUser.copyWith(avatarUrl: 'https://example.test/me.png'));
      await pump(tester, const ProfileScreen());

      await tester.tap(find.byIcon(Icons.camera_alt_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View photo'));
      await tester.pumpAndSettle();

      // The full-size viewer shows the same photo again, over black, and can
      // be pinch-zoomed.
      expect(find.byType(AppNetworkImage), findsNWidgets(2));
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(AppNetworkImage), findsOneWidget, reason: 'back to just the thumbnail');
    });

    testWidgets('tapping the backdrop also closes the viewer', (tester) async {
      user.setUser(testUser.copyWith(avatarUrl: 'https://example.test/me.png'));
      await pump(tester, const ProfileScreen());

      await tester.tap(find.byIcon(Icons.camera_alt_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View photo'));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(400, 100));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });

    testWidgets('a photo can be removed', (tester) async {
      user.setUser(testUser.copyWith(avatarUrl: 'https://example.test/me.png'));
      await pump(tester, const ProfileScreen());

      await tester.tap(find.byIcon(Icons.camera_alt_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove photo'));
      await tester.pumpAndSettle();

      expect(userRepo.avatarRemoved, isTrue);
      expect(user.user?.avatarUrl, anyOf(isNull, isEmpty));
      expect(find.text('Photo removed'), findsOneWidget);
    });

    testWidgets('a failed photo removal says so and keeps the photo', (
      tester,
    ) async {
      user.setUser(testUser.copyWith(avatarUrl: 'https://example.test/me.png'));
      await pump(tester, const ProfileScreen());
      userRepo.failWith = 'Can\'t reach the server.';

      await tester.tap(find.byIcon(Icons.camera_alt_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove photo'));
      await tester.pumpAndSettle();

      expect(find.text('Can\'t reach the server.'), findsOneWidget);
      expect(user.user?.avatarUrl, 'https://example.test/me.png');
    });
  });

  // ── Screens for features that aren't built ──────────────────────────────────

  group('Emergency access', () {
    testWidgets(
      'says plainly it isn\'t available and shows the user\'s real people',
      (tester) async {
        await loadEverything();
        await pump(tester, const EmergencyAccessScreen());

        expect(find.text('Coming soon'), findsOneWidget);
        expect(
          find.text('Emergency access isn\'t available yet.'),
          findsOneWidget,
        );
        expect(find.text('Ada Lovelace'), findsOneWidget);
        expect(find.text('Grace Hopper'), findsOneWidget);

        // The old wizard's fake password field and fake success are gone.
        expect(find.text('Enter your password'), findsNothing);
        expect(find.textContaining('successfully set up'), findsNothing);
        expect(find.text('Get Started'), findsNothing);
        expectNoSampleContent();
      },
    );

    testWidgets('with nobody added it invites you to add someone', (
      tester,
    ) async {
      await pump(tester, const EmergencyAccessScreen());
      expect(find.textContaining('haven\'t added anyone yet'), findsOneWidget);
    });

    testWidgets('leads to managing trusted people', (tester) async {
      await pump(tester, const EmergencyAccessScreen());

      await tester.tap(
        find.widgetWithText(GlassPrimaryButton, 'Manage Trusted People'),
      );
      await tester.pumpAndSettle();
      expect(find.text('ROUTE /trusted-contacts'), findsOneWidget);
    });
  });

  group('Memories', () {
    testWidgets('shows only real memories and wishes, split by tab', (
      tester,
    ) async {
      await pump(tester, const WishesScreen());

      // Memories is the default tab; the seeded wish is not shown on it.
      expect(find.text('Summer at the lake'), findsOneWidget);
      expect(find.text('For my daughter'), findsNothing);
      expect(find.text('Coming soon'), findsNothing);
      expectNoSampleContent();

      await tester.tap(find.text('Wishes'));
      await tester.pumpAndSettle();

      expect(find.text('For my daughter'), findsOneWidget);
      expect(find.text('Summer at the lake'), findsNothing);
    });

    testWidgets('an empty tab invites you to add the first one', (
      tester,
    ) async {
      memoryRepo.items.clear();
      await pump(tester, const WishesScreen());

      expect(find.textContaining('No memories yet'), findsOneWidget);
      expect(find.widgetWithText(GlassPrimaryButton, 'Add Memory'), findsOneWidget);
    });

    testWidgets('adding a memory without a file shows it in the list', (
      tester,
    ) async {
      await pump(tester, const WishesScreen());

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add without a file'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'A quiet morning');
      await tester.tap(find.widgetWithText(GlassPrimaryButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('A quiet morning'), findsOneWidget);
      expect(find.text('Memory added'), findsOneWidget);
      expect(memories.memoriesCount, 2);
    });

    testWidgets('an empty title is rejected before anything is saved', (
      tester,
    ) async {
      await pump(tester, const WishesScreen());

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add without a file'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(GlassPrimaryButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Title is required'), findsOneWidget);
      expect(memories.count, 2); // nothing added
    });

    testWidgets('a failed save keeps the sheet open with what was typed', (
      tester,
    ) async {
      await pump(tester, const WishesScreen());
      memoryRepo.failWith = 'Storage is full';

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add without a file'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'A quiet morning');
      await tester.tap(find.widgetWithText(GlassPrimaryButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Storage is full'), findsOneWidget);
      expect(find.text('A quiet morning'), findsOneWidget); // still typed
      expect(memories.count, 2);

      memoryRepo.failWith = null;
      await tester.tap(find.widgetWithText(GlassPrimaryButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Storage is full'), findsNothing);
      expect(memories.count, 3);
    });

    testWidgets('the + button adds to whichever tab is open', (tester) async {
      await pump(tester, const WishesScreen());
      await tester.tap(find.text('Wishes'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Add Wish'), findsWidgets);

      await tester.tap(find.text('Add without a file'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first,
        'Take care of the garden',
      );
      await tester.tap(find.widgetWithText(GlassPrimaryButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Take care of the garden'), findsOneWidget);
      expect(find.text('Wish added'), findsOneWidget);
      expect(memories.wishesCount, 2);
    });

    testWidgets('editing a memory updates it in place', (tester) async {
      await pump(tester, const WishesScreen());

      await tester.tap(find.text('Summer at the lake'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Summer at the cabin');
      await tester.tap(find.widgetWithText(GlassPrimaryButton, 'Save Changes'));
      await tester.pumpAndSettle();

      expect(find.text('Summer at the cabin'), findsOneWidget);
      expect(find.text('Memory updated'), findsOneWidget);
    });

    testWidgets('a failed edit keeps the original and reports why', (
      tester,
    ) async {
      await pump(tester, const WishesScreen());
      memoryRepo.failWith = 'Offline';

      await tester.tap(find.text('Summer at the lake'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Summer at the cabin');
      await tester.tap(find.widgetWithText(GlassPrimaryButton, 'Save Changes'));
      await tester.pumpAndSettle();

      expect(find.text('Offline'), findsOneWidget);
      expect(memories.items.first.title, 'Summer at the lake');
    });

    testWidgets('viewing details shows the full content, read only', (
      tester,
    ) async {
      await pump(tester, const WishesScreen());

      await tester.tap(find.text('Summer at the lake'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View details'));
      await tester.pumpAndSettle();

      expect(find.text('Some notes about Summer at the lake.'), findsOneWidget);

      await tester.tap(find.widgetWithText(GlassPrimaryButton, 'Close'));
      await tester.pumpAndSettle();
      expect(find.text('Some notes about Summer at the lake.'), findsNothing);
    });

    testWidgets('deleting a memory asks first, then removes it', (
      tester,
    ) async {
      await pump(tester, const WishesScreen());

      await tester.tap(find.text('Summer at the lake'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete memory'));
      await tester.pumpAndSettle();
      expect(find.text('Delete memory?'), findsOneWidget);
      expect(memories.count, 2); // nothing deleted yet

      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Summer at the lake'), findsNothing);
      expect(find.text('Memory deleted'), findsOneWidget);
      expect(memories.count, 1);
    });

    testWidgets('cancelling the confirmation deletes nothing', (tester) async {
      await pump(tester, const WishesScreen());

      await tester.tap(find.text('Summer at the lake'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete memory'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Summer at the lake'), findsOneWidget);
      expect(memories.count, 2);
    });

    testWidgets('a failed delete keeps the list and reports the error', (
      tester,
    ) async {
      await pump(tester, const WishesScreen());
      memoryRepo.failWith = 'Locked by another device';

      await tester.tap(find.text('Summer at the lake'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete memory'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Summer at the lake'), findsOneWidget);
      expect(find.text('Locked by another device'), findsOneWidget);
      expect(memories.count, 2);
    });

    testWidgets(
      'an item without a file offers to add one, not replace or remove',
      (tester) async {
        await pump(tester, const WishesScreen());

        await tester.tap(find.text('Summer at the lake'));
        await tester.pumpAndSettle();

        expect(find.text('Add attachment'), findsOneWidget);
        expect(find.text('Replace attachment'), findsNothing);
        expect(find.text('Remove attachment'), findsNothing);
        expect(find.text('Open attachment'), findsNothing);
      },
    );

    testWidgets('an item with a file offers to open, replace or remove it', (
      tester,
    ) async {
      memoryRepo.items
        ..clear()
        ..add(
          FakeMemoryRepository.memory(
            'm1',
            'Old photo',
            filePath: 'user/memories/a.jpg',
          ),
        );
      await pump(tester, const WishesScreen());

      await tester.tap(find.text('Old photo'));
      await tester.pumpAndSettle();

      expect(find.text('Open attachment'), findsOneWidget);
      expect(find.text('Replace attachment'), findsOneWidget);
      expect(find.text('Remove attachment'), findsOneWidget);
      expect(find.text('Add attachment'), findsNothing);
    });

    testWidgets('removing an attachment keeps the memory itself', (
      tester,
    ) async {
      memoryRepo.items
        ..clear()
        ..add(
          FakeMemoryRepository.memory(
            'm1',
            'Old photo',
            filePath: 'user/memories/a.jpg',
          ),
        );
      await pump(tester, const WishesScreen());

      await tester.tap(find.text('Old photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove attachment'));
      await tester.pumpAndSettle();
      expect(find.text('Remove attachment?'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(find.text('Attachment removed'), findsOneWidget);
      expect(find.text('Old photo'), findsOneWidget); // the memory is kept
      expect(memories.items.first.hasAttachment, isFalse);
    });

    testWidgets('a failed attachment removal keeps the file and says why', (
      tester,
    ) async {
      memoryRepo.items
        ..clear()
        ..add(
          FakeMemoryRepository.memory(
            'm1',
            'Old photo',
            filePath: 'user/memories/a.jpg',
          ),
        );
      await pump(tester, const WishesScreen());
      memoryRepo.failWith = 'Could not reach the server';

      await tester.tap(find.text('Old photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove attachment'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(find.text('Could not reach the server'), findsOneWidget);
      expect(memories.items.first.hasAttachment, isTrue);
    });

    testWidgets('pulling to refresh reloads the list', (tester) async {
      await pump(tester, const WishesScreen());
      memoryRepo.items.add(FakeMemoryRepository.memory('m3', 'Added on the server'));

      expect(find.byType(RefreshIndicator), findsOneWidget);
      // Not awaited: the returned future only resolves as frames are pumped,
      // so awaiting it directly here would deadlock.
      unawaited(
        tester
            .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
            .show(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Added on the server'), findsOneWidget);
    });

    testWidgets('a failed first load shows a retry that recovers', (
      tester,
    ) async {
      memoryRepo.failWith = 'No connection';
      await pump(tester, const WishesScreen());

      expect(find.text('No connection'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Summer at the lake'), findsNothing);

      memoryRepo.failWith = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('No connection'), findsNothing);
      expect(find.text('Summer at the lake'), findsOneWidget);
    });
  });

  // ── Search ──────────────────────────────────────────────────────────────────

  group('Search', () {
    testWidgets(
      'Documents: the search icon opens a search that filters the list',
      (tester) async {
        await documents.fetchDocuments();
        await vault.fetchVaultSummary();
        await pump(tester, const DocumentsScreen());
        expect(find.byType(TextField), findsNothing);

        await tester.tap(find.byIcon(Icons.search_rounded));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'tax');
        await tester.pumpAndSettle();

        expect(find.text('Tax.pdf'), findsOneWidget);
        expect(find.text('Will.pdf'), findsNothing);
        expect(find.text('Deed.pdf'), findsNothing);
      },
    );

    testWidgets(
      'Documents: no match says so, and closing search restores the list',
      (tester) async {
        await documents.fetchDocuments();
        await vault.fetchVaultSummary();
        await pump(tester, const DocumentsScreen());

        await tester.tap(find.byIcon(Icons.search_rounded));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'zzz');
        await tester.pumpAndSettle();
        expect(find.text('No documents match "zzz".'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsNothing);
        expect(find.text('Will.pdf'), findsOneWidget);
        expect(find.text('Tax.pdf'), findsOneWidget);
      },
    );

    testWidgets('Accounts: the search box filters by name and username', (
      tester,
    ) async {
      accRepo.items
        ..clear()
        ..addAll([
          FakeAccountRepository.account(
            'a1',
            'GitHub',
          ).copyWith(username: 'alex@dev.io'),
          FakeAccountRepository.account('a2', 'Netflix'),
        ]);
      await accounts.fetchAccounts();
      await pump(tester, const AccountsScreen());

      await tester.enterText(find.byType(TextField), 'net');
      await tester.pumpAndSettle();
      expect(find.text('Netflix'), findsWidgets);
      expect(find.text('GitHub'), findsNothing);

      await tester.enterText(find.byType(TextField), 'dev.io'); // by username
      await tester.pumpAndSettle();
      expect(find.text('GitHub'), findsWidgets);
      expect(find.text('Netflix'), findsNothing);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('No accounts match "zzz".'), findsOneWidget);
    });

    testWidgets('Accounts: the dead "See All" link is gone', (tester) async {
      await accounts.fetchAccounts();
      await pump(tester, const AccountsScreen());
      expect(find.text('See All'), findsNothing);
    });

    testWidgets('Vault: search finds documents and accounts together', (
      tester,
    ) async {
      await documents.fetchDocuments();
      await accounts.fetchAccounts();
      await vault.fetchVaultSummary();
      await pump(tester, const VaultScreen());

      await tester.enterText(find.byType(TextField), 'will');
      await tester.pumpAndSettle();
      expect(find.text('Will.pdf'), findsOneWidget);
      expect(find.text('GitHub'), findsNothing);
      expect(
        find.text('Passwords'),
        findsNothing,
        reason: 'results replace the categories',
      );

      await tester.enterText(find.byType(TextField), 'git');
      await tester.pumpAndSettle();
      expect(find.text('GitHub'), findsOneWidget);
      expect(find.text('Will.pdf'), findsNothing);

      await tester.tap(find.text('GitHub'));
      await tester.pumpAndSettle();
      expect(find.text('ROUTE /accounts'), findsOneWidget);
    });

    testWidgets(
      'Vault: a search with no match says so; clearing it brings the categories back',
      (tester) async {
        await documents.fetchDocuments();
        await accounts.fetchAccounts();
        await vault.fetchVaultSummary();
        await pump(tester, const VaultScreen());

        await tester.enterText(find.byType(TextField), 'zzz');
        await tester.pumpAndSettle();
        expect(
          find.text('Nothing in your vault matches "zzz".'),
          findsOneWidget,
        );

        await tester.enterText(find.byType(TextField), '');
        await tester.pumpAndSettle();
        expect(find.text('Passwords'), findsOneWidget);
        expect(find.text('Documents'), findsOneWidget);
        expect(find.text('Financials'), findsOneWidget);
      },
    );

    testWidgets('Vault: only categories that exist are shown', (tester) async {
      await vault.fetchVaultSummary();
      await pump(tester, const VaultScreen());

      expect(find.text('Messages'), findsNothing);
      expect(find.text('Memories'), findsNothing);
      expect(find.text('Add to Vault'), findsOneWidget);
    });
  });

  // A quick guard that the search helpers respect both category and query.
  test('the providers combine category and search', () async {
    await documents.fetchDocuments();
    expect(documents.filterByCategory('All', query: 'TAX'), hasLength(1));
    expect(documents.filterByCategory('Medical', query: 'tax'), isEmpty);
    expect(documents.filterByCategory('All'), hasLength(3));

    accRepo.items.add(
      AccountItem(
        id: 'x',
        title: 'Chase',
        subtitle: '',
        category: 'Banking',
        icon: Icons.key_rounded,
        color: Colors.blue,
        username: 'me@chase.com',
      ),
    );
    await accounts.fetchAccounts();
    expect(accounts.filterByCategory('Banking', query: 'chase'), hasLength(1));
    expect(accounts.filterByCategory('Work', query: 'chase'), isEmpty);
    expect(accounts.filterByCategory('All', query: 'me@chase'), hasLength(1));
    expect(accounts.bankingCount, 1);
  });

  test('User stays signed-in state while a profile is loaded', () {
    const loaded = User(
      id: 'u',
      name: 'A',
      email: 'a@b.co',
      isAuthenticated: true,
    );
    user.setUser(loaded);
    expect(user.user?.isAuthenticated, isTrue);
  });
}
