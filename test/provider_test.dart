import 'package:flutter_test/flutter_test.dart';
import 'package:everkeep/models/document_item.dart';
import 'package:everkeep/providers/account_provider.dart';
import 'package:everkeep/providers/auth_provider.dart';
import 'package:everkeep/providers/document_provider.dart';
import 'package:everkeep/providers/settings_provider.dart';
import 'package:everkeep/providers/trusted_contact_provider.dart';
import 'package:everkeep/providers/user_provider.dart';
import 'package:everkeep/providers/vault_provider.dart';

import 'fakes.dart';

void main() {
  group('AuthProvider Tests', () {
    test('Initial status is unauthenticated after checkSession', () async {
      final auth = AuthProvider(authRepository: FakeAuthRepository());
      expect(auth.status, AuthStatus.initial);
      await auth.checkSession();
      expect(auth.status, AuthStatus.unauthenticated);
      expect(auth.isAuthenticated, isFalse);
    });

    test('SignIn succeeds with valid credentials', () async {
      final auth = AuthProvider(authRepository: FakeAuthRepository());
      final success = await auth.signIn(
        email: 'test@example.com',
        password: 'password123',
      );
      expect(success, isTrue);
      expect(auth.status, AuthStatus.authenticated);
      expect(auth.currentUser?.email, 'test@example.com');
    });

    test('SignIn fails when the backend rejects the credentials', () async {
      final repo = FakeAuthRepository()
        ..failWith = 'Incorrect email or password.';
      final auth = AuthProvider(authRepository: repo);
      final success = await auth.signIn(
        email: 'test@example.com',
        password: '123',
      );
      expect(success, isFalse);
      expect(auth.status, AuthStatus.error);
      expect(auth.error, 'Incorrect email or password.');
    });

    test('SignOut resets authentication', () async {
      final auth = AuthProvider(authRepository: FakeAuthRepository());
      await auth.signIn(email: 'test@example.com', password: 'password123');
      expect(auth.isAuthenticated, isTrue);
      await auth.signOut();
      expect(auth.isAuthenticated, isFalse);
      expect(auth.currentUser, isNull);
    });
  });

  group('UserProvider Tests', () {
    test('Starts with no user until one is set', () {
      final userProv = UserProvider(userRepository: FakeUserRepository());
      expect(userProv.user, isNull);
      expect(userProv.displayName, 'User');

      userProv.setUser(testUser);
      expect(userProv.displayName, 'Sarah Mitchell');
      expect(userProv.firstName, 'Sarah');
    });

    test('Update user profile updates display name', () async {
      final userProv = UserProvider(userRepository: FakeUserRepository())
        ..setUser(testUser);
      final updated = testUser.copyWith(name: 'Jane Doe');
      final success = await userProv.updateUserProfile(updated);
      expect(success, isTrue);
      expect(userProv.displayName, 'Jane Doe');
      expect(userProv.firstName, 'Jane');
    });
  });

  group('DocumentProvider Tests', () {
    test('Fetches initial documents and filters by category', () async {
      final repo = FakeDocumentRepository([
        FakeDocumentRepository.doc('1', 'Will.pdf'),
        FakeDocumentRepository.doc('2', 'Chart.pdf', category: 'Medical'),
      ]);
      final docProv = DocumentProvider(documentRepository: repo);
      expect(docProv.documents, isEmpty);
      await docProv.fetchDocuments();
      expect(docProv.documents.length, 2);

      final legalDocs = docProv.filterByCategory('Legal');
      expect(legalDocs, hasLength(1));
      expect(legalDocs.every((d) => d.category == 'Legal'), isTrue);
    });

    test('Add and delete document', () async {
      final docProv = DocumentProvider(
        documentRepository: FakeDocumentRepository(),
      );
      await docProv.fetchDocuments();
      final initialCount = docProv.documents.length;

      const newDoc = DocumentItem(
        id: '',
        title: 'Test Will.pdf',
        subtitle: '',
        category: 'Legal',
      );
      await docProv.addDocument(newDoc);
      expect(docProv.documents.length, initialCount + 1);

      // The backend assigns the id; delete by the id it gave back.
      final saved = docProv.documents.first;
      expect(saved.id, isNotEmpty);
      await docProv.deleteDocument(saved.id);
      expect(docProv.documents.length, initialCount);
    });
  });

  group('AccountProvider Tests', () {
    test('Fetches accounts and toggles favorite', () async {
      final repo = FakeAccountRepository();
      final accProv = AccountProvider(accountRepository: repo);
      await accProv.fetchAccounts();
      expect(accProv.accounts, isNotEmpty);

      final firstId = accProv.accounts.first.id;
      final initialFav = accProv.accounts.first.isFavorite;

      await accProv.toggleFavorite(firstId);
      expect(
        accProv.accounts.firstWhere((a) => a.id == firstId).isFavorite,
        !initialFav,
      );
      // The provider sends the new value explicitly rather than "flip it".
      expect(repo.lastFavorite, (firstId, !initialFav));
    });
  });

  group('TrustedContactProvider Tests', () {
    test('Fetches contacts successfully', () async {
      final contactProv = TrustedContactProvider(
        trustedContactRepository: FakeTrustedContactRepository(),
      );
      await contactProv.fetchContacts();
      expect(contactProv.contacts.length, 2);
    });
  });

  group('VaultProvider Tests', () {
    test('Starts as an empty vault, not with invented numbers', () {
      final vaultProv = VaultProvider(vaultRepository: FakeVaultRepository());
      expect(vaultProv.vaultSummary.totalItems, 0);
      expect(vaultProv.vaultSummary.securityScore, 0);
    });

    test('Loads the summary from the repository', () async {
      final vaultProv = VaultProvider(vaultRepository: FakeVaultRepository());
      await vaultProv.fetchVaultSummary();
      expect(vaultProv.vaultSummary.totalItems, 92);
      // Derived from what the summary holds: email confirmed + a trusted
      // person is 2 of 3 safeguards.
      expect(vaultProv.vaultSummary.securityScore, 67);
      expect(vaultProv.vaultSummary.securityScoreLabel, 'Good — 67/100');
      expect(vaultProv.vaultSummary.legacyProgress, 1.0);
    });
  });

  group('SettingsProvider Tests', () {
    test('Toggle security settings updates state', () async {
      final settingsProv = SettingsProvider(
        settingsRepository: FakeSettingsRepository(),
      );
      // Protections start off: a new account must not claim any it hasn't set up.
      expect(settingsProv.twoFactorEnabled, isFalse);

      await settingsProv.toggleTwoFactor(true);
      expect(settingsProv.twoFactorEnabled, isTrue);

      await settingsProv.toggleBiometric(true);
      expect(settingsProv.biometricEnabled, isTrue);

      await settingsProv.toggleLoginAlerts(true);
      expect(settingsProv.loginAlertsEnabled, isTrue);
    });
  });
}
