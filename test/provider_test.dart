import 'package:flutter_test/flutter_test.dart';
import 'package:everkeep/models/document_item.dart';
import 'package:everkeep/models/user.dart';
import 'package:everkeep/providers/account_provider.dart';
import 'package:everkeep/providers/auth_provider.dart';
import 'package:everkeep/providers/document_provider.dart';
import 'package:everkeep/providers/settings_provider.dart';
import 'package:everkeep/providers/trusted_contact_provider.dart';
import 'package:everkeep/providers/user_provider.dart';
import 'package:everkeep/providers/vault_provider.dart';

void main() {
  group('AuthProvider Tests', () {
    test('Initial status is unauthenticated after checkSession', () async {
      final auth = AuthProvider();
      expect(auth.status, AuthStatus.initial);
      await auth.checkSession();
      expect(auth.status, AuthStatus.unauthenticated);
      expect(auth.isAuthenticated, isFalse);
    });

    test('SignIn succeeds with valid credentials', () async {
      final auth = AuthProvider();
      final success = await auth.signIn(
        email: 'test@example.com',
        password: 'password123',
      );
      expect(success, isTrue);
      expect(auth.status, AuthStatus.authenticated);
      expect(auth.currentUser?.email, 'test@example.com');
    });

    test('SignIn fails with invalid password', () async {
      final auth = AuthProvider();
      final success = await auth.signIn(
        email: 'test@example.com',
        password: '123',
      );
      expect(success, isFalse);
      expect(auth.status, AuthStatus.error);
      expect(auth.error, isNotNull);
    });

    test('SignOut resets authentication', () async {
      final auth = AuthProvider();
      await auth.signIn(email: 'test@example.com', password: 'password123');
      expect(auth.isAuthenticated, isTrue);
      await auth.signOut();
      expect(auth.isAuthenticated, isFalse);
      expect(auth.currentUser, isNull);
    });
  });

  group('UserProvider Tests', () {
    test('Default user initialized with Sarah Mitchell', () {
      final userProv = UserProvider();
      expect(userProv.displayName, 'Sarah Mitchell');
      expect(userProv.firstName, 'Sarah');
    });

    test('Update user profile updates display name', () async {
      final userProv = UserProvider();
      final updated = User.defaultUser.copyWith(name: 'Jane Doe');
      final success = await userProv.updateUserProfile(updated);
      expect(success, isTrue);
      expect(userProv.displayName, 'Jane Doe');
      expect(userProv.firstName, 'Jane');
    });
  });

  group('DocumentProvider Tests', () {
    test('Fetches initial documents and filters by category', () async {
      final docProv = DocumentProvider();
      expect(docProv.documents, isEmpty);
      await docProv.fetchDocuments();
      expect(docProv.documents.length, greaterThan(0));

      final legalDocs = docProv.filterByCategory('Legal');
      expect(legalDocs.every((d) => d.category == 'Legal'), isTrue);
    });

    test('Add and delete document', () async {
      final docProv = DocumentProvider();
      await docProv.fetchDocuments();
      final initialCount = docProv.documents.length;

      const newDoc = DocumentItem(
        id: 'test-doc-1',
        title: 'Test Will.pdf',
        subtitle: 'Legal · Added today',
        category: 'Legal',
      );
      await docProv.addDocument(newDoc);
      expect(docProv.documents.length, initialCount + 1);

      await docProv.deleteDocument('test-doc-1');
      expect(docProv.documents.length, initialCount);
    });
  });

  group('AccountProvider Tests', () {
    test('Fetches accounts and toggles favorite', () async {
      final accProv = AccountProvider();
      await accProv.fetchAccounts();
      expect(accProv.accounts, isNotEmpty);

      final firstId = accProv.accounts.first.id;
      final initialFav = accProv.accounts.first.isFavorite;

      await accProv.toggleFavorite(firstId);
      expect(
        accProv.accounts.firstWhere((a) => a.id == firstId).isFavorite,
        !initialFav,
      );
    });
  });

  group('TrustedContactProvider Tests', () {
    test('Fetches contacts successfully', () async {
      final contactProv = TrustedContactProvider();
      await contactProv.fetchContacts();
      expect(contactProv.contacts.length, greaterThanOrEqualTo(4));
    });
  });

  group('VaultProvider Tests', () {
    test('VaultSummary contains correct default values', () async {
      final vaultProv = VaultProvider();
      expect(vaultProv.vaultSummary.totalItems, 92);
      expect(vaultProv.vaultSummary.securityScore, 94);
    });
  });

  group('SettingsProvider Tests', () {
    test('Toggle security settings updates state', () async {
      final settingsProv = SettingsProvider();
      expect(settingsProv.twoFactorEnabled, isTrue);

      await settingsProv.toggleTwoFactor(false);
      expect(settingsProv.twoFactorEnabled, isFalse);

      await settingsProv.toggleBiometric(false);
      expect(settingsProv.biometricEnabled, isFalse);

      await settingsProv.toggleLoginAlerts(false);
      expect(settingsProv.loginAlertsEnabled, isFalse);
    });
  });
}
