import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:everkeep/core/security/clipboard_safety_manager.dart';
import 'package:everkeep/core/security/vault_crypto_service.dart';
import 'package:everkeep/core/utils/data_export_helper.dart';
import 'package:everkeep/features/accounts/presentation/screens/password_vault_screen.dart';
import 'package:everkeep/features/accounts/presentation/widgets/credential_form_sheet.dart';
import 'package:everkeep/models/account_item.dart';
import 'package:everkeep/models/user.dart';
import 'package:everkeep/providers/account_provider.dart';
import 'package:everkeep/providers/auth_provider.dart';
import 'package:everkeep/widgets/glass/glass_primary_button.dart';

import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAccountRepository accRepo;
  late InMemoryVaultKeyStorage keyStorage;
  late VaultCryptoService cryptoService;
  late AccountProvider accountProvider;
  late FakeAuthRepository authRepo;
  late AuthProvider authProvider;

  const testUser = User(
    id: 'user-vault-123',
    email: 'tester@everkeep.test',
    name: 'Test User',
    isAuthenticated: true,
  );

  setUp(() async {
    accRepo = FakeAccountRepository([]);
    keyStorage = InMemoryVaultKeyStorage();
    cryptoService = VaultCryptoService(keyStorage: keyStorage);
    accountProvider = AccountProvider(
      accountRepository: accRepo,
      cryptoService: cryptoService,
    );
    authRepo = FakeAuthRepository()..sessionUser = testUser;
    authProvider = AuthProvider(authRepository: authRepo);
    await authProvider.signIn(email: testUser.email, password: 'pw');
  });

  Widget buildTestScreen(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<AccountProvider>.value(value: accountProvider),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('AccountItem Password Vault Extensions', () {
    test('fromRow parses website, notes, and encrypted_password', () {
      final row = {
        'id': 'acc-101',
        'name': 'ProtonMail',
        'username': 'proton@secure.io',
        'category': 'Work',
        'website': 'https://proton.me',
        'notes': 'Use physical hardware key',
        'encrypted_password': 'v1:ivBase64:cipherBase64:macBase64',
        'created_at': DateTime.now().toIso8601String(),
        'is_favorite': true,
      };

      final item = AccountItem.fromRow(row);
      expect(item.id, 'acc-101');
      expect(item.title, 'ProtonMail');
      expect(item.username, 'proton@secure.io');
      expect(item.website, 'https://proton.me');
      expect(item.notes, 'Use physical hardware key');
      expect(item.encryptedPassword, 'v1:ivBase64:cipherBase64:macBase64');
      expect(item.hasPassword, isTrue);
    });

    test('toInsertRow and toUpdateRow include website, notes, and encrypted_password when present', () {
      final item = AccountItem(
        id: 'acc-102',
        title: 'GitHub',
        subtitle: 'Added today',
        category: 'Work',
        icon: Icons.key,
        color: Colors.blue,
        website: 'https://github.com',
        notes: 'Personal account',
        encryptedPassword: 'v1:sample:sample:sample',
      );

      final insertMap = item.toInsertRow();
      expect(insertMap['website'], 'https://github.com');
      expect(insertMap['notes'], 'Personal account');
      expect(insertMap['encrypted_password'], 'v1:sample:sample:sample');
      expect(insertMap.containsKey('password'), isFalse); // Never plaintext

      final updateMap = item.toUpdateRow();
      expect(updateMap['website'], 'https://github.com');
      expect(updateMap['notes'], 'Personal account');
      expect(updateMap['encrypted_password'], 'v1:sample:sample:sample');
    });

    test('toInsertRow omits optional fields when null to preserve exact legacy signatures', () {
      const item = AccountItem(
        id: '',
        title: 'Bank',
        subtitle: '',
        category: 'Banking',
        icon: Icons.account_balance,
        color: Colors.green,
      );

      final map = item.toInsertRow();
      expect(map.containsKey('website'), isFalse);
      expect(map.containsKey('notes'), isFalse);
      expect(map.containsKey('encrypted_password'), isFalse);
    });
  });

  group('Secure Credential Flow & Client-Side Encryption', () {
    test('addCredential encrypts password client-side before repository call', () async {
      final success = await accountProvider.addCredential(
        title: 'ProtonVPN',
        username: 'vpn@user.com',
        website: 'https://protonvpn.com',
        password: 'TopSecretVpnPassword!2026',
        category: 'Work',
        notes: 'Server Netherlands',
        userId: testUser.id,
      );

      expect(success, isTrue);
      expect(accountProvider.accounts.length, 1);

      final saved = accountProvider.accounts.first;
      expect(saved.title, 'ProtonVPN');
      expect(saved.website, 'https://protonvpn.com');
      expect(saved.notes, 'Server Netherlands');
      expect(saved.hasPassword, isTrue);

      // Verify that what was stored in the repository is encrypted (not plaintext)
      expect(saved.encryptedPassword, startsWith('v1:'));
      expect(saved.encryptedPassword, isNot(contains('TopSecretVpnPassword!2026')));

      // Decrypt via getDecryptedPassword
      final decrypted = await accountProvider.getDecryptedPassword(saved, userId: testUser.id);
      expect(decrypted, 'TopSecretVpnPassword!2026');
    });

    test('updateCredential encrypts new password and updates item', () async {
      await accountProvider.addCredential(
        title: 'Netflix',
        username: 'user@netflix.com',
        password: 'InitialPassword1!',
        category: 'Social',
        userId: testUser.id,
      );

      final initialItem = accountProvider.accounts.first;

      final updated = await accountProvider.updateCredential(
        account: initialItem,
        newTitle: 'Netflix Premium',
        newPassword: 'UpdatedSecretPassword2@',
        userId: testUser.id,
      );

      expect(updated, isTrue);
      final currentItem = accountProvider.accounts.first;
      expect(currentItem.title, 'Netflix Premium');

      final decrypted = await accountProvider.getDecryptedPassword(currentItem, userId: testUser.id);
      expect(decrypted, 'UpdatedSecretPassword2@');
    });

    test('reset drops all accounts and wipes in-memory crypto cache', () async {
      await accountProvider.addCredential(
        title: 'SecretService',
        password: 'ClearMePlease!',
        category: 'Other',
        userId: testUser.id,
      );

      final item = accountProvider.accounts.first;
      // Pre-warm cache
      await accountProvider.getDecryptedPassword(item, userId: testUser.id);
      expect(cryptoService.getCachedDecryptedPassword(item.id), 'ClearMePlease!');

      accountProvider.reset();

      expect(accountProvider.accounts, isEmpty);
      expect(accountProvider.count, 0);
      expect(cryptoService.getCachedDecryptedPassword(item.id), isNull);
    });
  });

  group('Data Export Excludes Passwords & Secrets', () {
    test('buildExportPayload strips encrypted_password and passwords from accounts', () {
      final accountsData = [
        {
          'id': 'acc-1',
          'name': 'Netflix',
          'username': 'user@netflix.com',
          'category': 'Social',
          'website': 'https://netflix.com',
          'notes': 'Family plan',
          'encrypted_password': 'v1:secretIv:secretCipher:secretMac',
          'password': 'plainPasswordIfAny',
          'created_at': DateTime.now().toIso8601String(),
        },
      ];

      final payload = DataExportHelper.buildExportPayload(
        userId: testUser.id,
        userEmail: testUser.email,
        accounts: accountsData,
      );

      final exportedAccounts = payload['accounts'] as List<dynamic>;
      expect(exportedAccounts.length, 1);

      final exportedAccount = exportedAccounts.first as Map<String, dynamic>;
      expect(exportedAccount['name'], 'Netflix');
      expect(exportedAccount['username'], 'user@netflix.com');
      expect(exportedAccount['website'], 'https://netflix.com');

      // Crucial Security Checks:
      expect(exportedAccount.containsKey('encrypted_password'), isFalse);
      expect(exportedAccount.containsKey('password'), isFalse);
      expect(exportedAccount.containsKey('vault_key'), isFalse);
      expect(exportedAccount.containsKey('secret'), isFalse);
    });
  });

  void tallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  group('PasswordVaultScreen Widgets', () {
    testWidgets('displays credentials with masked passwords by default', (tester) async {
      tallScreen(tester);
      await accountProvider.addCredential(
        title: 'GitHub',
        username: 'octocat',
        website: 'https://github.com',
        password: 'SuperSecretGithubPassword!',
        category: 'Work',
        notes: '2FA via YubiKey',
        userId: testUser.id,
      );

      await tester.pumpWidget(buildTestScreen(const PasswordVaultScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Password Vault'), findsOneWidget);
      expect(find.text('GitHub'), findsOneWidget);
      expect(find.text('octocat'), findsOneWidget);
      expect(find.text('https://github.com'), findsOneWidget);
      expect(find.text('2FA via YubiKey'), findsOneWidget);

      // Password should be masked by default
      expect(find.text('••••••••••••'), findsOneWidget);
      expect(find.text('SuperSecretGithubPassword!'), findsNothing);
    });

    testWidgets('reveal and hide toggle displays plaintext password then masks again', (tester) async {
      tallScreen(tester);
      await accountProvider.addCredential(
        title: 'Spotify',
        username: 'music@fan.io',
        password: 'MySpotifyMusicPassword!',
        category: 'Social',
        userId: testUser.id,
      );

      await tester.pumpWidget(buildTestScreen(const PasswordVaultScreen()));
      await tester.pumpAndSettle();

      expect(find.text('••••••••••••'), findsOneWidget);

      // Tap reveal eye icon
      await tester.tap(find.byTooltip('Reveal password'));
      await tester.pumpAndSettle();

      expect(find.text('MySpotifyMusicPassword!'), findsOneWidget);

      // Tap hide eye icon
      await tester.tap(find.byTooltip('Hide password'));
      await tester.pumpAndSettle();

      expect(find.text('••••••••••••'), findsOneWidget);
      expect(find.text('MySpotifyMusicPassword!'), findsNothing);
    });

    testWidgets('copy password copies text and displays feedback', (tester) async {
      tallScreen(tester);
      String copiedText = '';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<dynamic, dynamic>;
          copiedText = (args['text'] as String?) ?? '';
        }
        return null;
      });

      await accountProvider.addCredential(
        title: 'Bitbucket',
        password: 'BitbucketPassword!',
        category: 'Work',
        userId: testUser.id,
      );

      await tester.pumpWidget(buildTestScreen(const PasswordVaultScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Copy password'));
      await tester.pumpAndSettle();

      expect(copiedText, 'BitbucketPassword!');
      expect(find.textContaining('Password copied'), findsOneWidget);

      ClipboardSafetyManager.instance.cancel();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('search filters credentials across title, username, website, and notes', (tester) async {
      tallScreen(tester);
      await accountProvider.addCredential(
        title: 'AWS Cloud',
        username: 'admin@company.com',
        website: 'https://aws.amazon.com',
        password: 'Password1!',
        category: 'Work',
        notes: 'Root account MFA token in vault',
        userId: testUser.id,
      );

      await accountProvider.addCredential(
        title: 'Personal Bank',
        username: 'john_doe',
        website: 'https://chase.com',
        password: 'Password2@',
        category: 'Banking',
        notes: 'Checking and Savings',
        userId: testUser.id,
      );

      await tester.pumpWidget(buildTestScreen(const PasswordVaultScreen()));
      await tester.pumpAndSettle();

      expect(find.text('AWS Cloud'), findsOneWidget);
      expect(find.text('Personal Bank'), findsOneWidget);

      // Search by website
      await tester.enterText(find.byType(TextField), 'amazon');
      await tester.pumpAndSettle();

      expect(find.text('AWS Cloud'), findsOneWidget);
      expect(find.text('Personal Bank'), findsNothing);

      // Search by notes
      await tester.enterText(find.byType(TextField), 'Savings');
      await tester.pumpAndSettle();

      expect(find.text('Personal Bank'), findsOneWidget);
      expect(find.text('AWS Cloud'), findsNothing);
    });

    testWidgets('delete credential asks confirmation and deletes item', (tester) async {
      tallScreen(tester);
      await accountProvider.addCredential(
        title: 'Discardable',
        password: 'Password123!',
        category: 'Other',
        userId: testUser.id,
      );

      await tester.pumpWidget(buildTestScreen(const PasswordVaultScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Discardable'), findsOneWidget);

      await tester.tap(find.byTooltip('Delete credential'));
      await tester.pumpAndSettle();

      expect(find.text('Delete credential?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Credential deleted'), findsOneWidget);
      expect(find.text('Discardable'), findsNothing);
    });

    testWidgets('credential form sheet validates required title and prevents duplicate submit', (tester) async {
      tallScreen(tester);
      await tester.pumpWidget(buildTestScreen(
        Builder(builder: (context) {
          return Scaffold(
            body: ElevatedButton(
              onPressed: () => showCredentialFormSheet(context),
              child: const Text('Open Sheet'),
            ),
          );
        }),
      ));

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Add Credential'), findsOneWidget);

      // Tap submit with empty title
      await tester.tap(find.widgetWithText(GlassPrimaryButton, 'Save to Vault'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a service or account name.'), findsOneWidget);
    });
  });
}
