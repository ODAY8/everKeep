import 'dart:async';

import 'package:everkeep/core/routing/auth_guard.dart';
import 'package:everkeep/core/session/session_sync.dart';
import 'package:everkeep/models/document_item.dart';
import 'package:everkeep/providers/account_provider.dart';
import 'package:everkeep/providers/auth_provider.dart';
import 'package:everkeep/providers/document_provider.dart';
import 'package:everkeep/providers/settings_provider.dart';
import 'package:everkeep/providers/trusted_contact_provider.dart';
import 'package:everkeep/providers/user_provider.dart';
import 'package:everkeep/providers/vault_provider.dart';
import 'package:everkeep/services/trusted_contact_service.dart';
import 'package:everkeep/models/trusted_contact_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'fakes.dart';

/// Everything the coordinator ties together, backed by instant fakes.
class Harness {
  final authRepo = FakeAuthRepository();
  final docRepo = FakeDocumentRepository();
  final accRepo = FakeAccountRepository();
  final contactRepo = FakeTrustedContactRepository();
  final settingsRepo = FakeSettingsRepository();
  final vaultRepo = FakeVaultRepository();

  late final auth = AuthProvider(authRepository: authRepo);
  late final user = UserProvider(userRepository: FakeUserRepository());
  late final vault = VaultProvider(vaultRepository: vaultRepo);
  late final documents = DocumentProvider(documentRepository: docRepo);
  late final accounts = AccountProvider(accountRepository: accRepo);
  late final contacts = TrustedContactProvider(
    trustedContactRepository: contactRepo,
  );
  late final settings = SettingsProvider(settingsRepository: settingsRepo);

  late final SessionCoordinator coordinator = SessionCoordinator(
    auth: auth,
    user: user,
    vault: vault,
    documents: documents,
    accounts: accounts,
    contacts: contacts,
    settings: settings,
  );

  Harness() {
    coordinator; // start listening
  }

  Future<void> signIn({String email = 'alex@example.com'}) async {
    await auth.signIn(email: email, password: 'secret1');
    await pumpEventQueue();
  }

  void dispose() => coordinator.dispose();
}

void main() {
  group('SessionCoordinator', () {
    late Harness h;
    setUp(() => h = Harness());
    tearDown(() => h.dispose());

    test('sign-up hands the new user to UserProvider (not a stock persona)',
        () async {
      await h.auth.signUp(
        name: 'Alex Rivera',
        email: 'alex@example.com',
        password: 'secret1',
      );
      await pumpEventQueue();

      expect(h.user.displayName, 'Alex Rivera');
      expect(h.user.firstName, 'Alex');
      expect(h.user.displayEmail, 'alex@example.com');
    });

    test('sign-in loads the data the dashboard shows', () async {
      await h.signIn();

      expect(h.user.displayEmail, 'alex@example.com');
      expect(h.documents.hasFetched, isTrue);
      expect(h.accounts.hasFetched, isTrue);
      expect(h.contacts.hasFetched, isTrue);
      expect(h.documents.count, 3);
      expect(h.accounts.count, 2);
      expect(h.contacts.count, 2);
    });

    test('sign-out resets every user-scoped provider', () async {
      await h.signIn();
      await h.documents.addDocument(FakeDocumentRepository.doc('x', 'Mine.pdf'));
      expect(h.documents.count, 4);

      final signedOut = await h.auth.signOut();
      await pumpEventQueue();

      expect(signedOut, isTrue);
      expect(h.user.user, isNull);
      expect(h.documents.documents, isEmpty);
      expect(h.documents.hasFetched, isFalse);
      expect(h.accounts.accounts, isEmpty);
      expect(h.accounts.hasFetched, isFalse);
      expect(h.contacts.contacts, isEmpty);
      expect(h.contacts.hasFetched, isFalse);
      expect(h.vault.vaultSummary.documentsCount, 11); // back to defaults
      expect(h.settings.settings.twoFactorEnabled, isTrue);
    });

    test('a failed sign-out keeps the session and its data', () async {
      await h.signIn();
      h.authRepo.failSignOut = true;

      final signedOut = await h.auth.signOut();
      await pumpEventQueue();

      expect(signedOut, isFalse);
      expect(h.auth.isAuthenticated, isTrue);
      expect(h.auth.error, 'Network unavailable');
      expect(h.documents.count, 3);
      expect(h.user.displayEmail, 'alex@example.com');
    });

    test('the next user never sees the previous user\'s data', () async {
      await h.signIn(email: 'first@example.com');
      await h.auth.signOut();
      await pumpEventQueue();
      h.docRepo.items.clear(); // the second user has no documents

      await h.signIn(email: 'second@example.com');

      expect(h.user.displayEmail, 'second@example.com');
      expect(h.documents.documents, isEmpty);
    });

    test('a fetch that resolves after sign-out is discarded', () async {
      final pending = Completer<List<DocumentItem>>();
      h.docRepo.pendingFetch = pending;

      await h.signIn(); // starts the (pending) documents fetch
      expect(h.documents.isLoading, isTrue);

      await h.auth.signOut();
      await pumpEventQueue();
      pending.complete([FakeDocumentRepository.doc('leak', 'Private.pdf')]);
      await pumpEventQueue();

      expect(h.documents.documents, isEmpty);
      expect(h.documents.hasFetched, isFalse);
      expect(h.documents.isLoading, isFalse);
    });

    test('vault counts follow the real document and account lists', () async {
      await h.signIn();
      // Defaults are 92 total / 11 documents / 24 passwords.
      expect(h.vault.vaultSummary.documentsCount, 3);
      expect(h.vault.vaultSummary.passwordsCount, 2);
      expect(h.vault.vaultSummary.totalItems, 92 - 11 - 24 + 3 + 2);

      await h.documents.addDocument(FakeDocumentRepository.doc('n', 'New.pdf'));
      expect(h.vault.vaultSummary.documentsCount, 4);
      expect(h.vault.vaultSummary.totalItems, 92 - 11 - 24 + 4 + 2);

      await h.documents.deleteDocument('n');
      expect(h.vault.vaultSummary.documentsCount, 3);
    });

    test('a late vault-summary fetch does not undo the live counts', () async {
      await h.signIn();
      await h.vault.fetchVaultSummary();

      expect(h.vault.vaultSummary.documentsCount, 3);
      expect(h.vault.vaultSummary.passwordsCount, 2);
    });
  });

  group('Error handling', () {
    test('a failed add keeps the list and reports a clean message', () async {
      final repo = FakeDocumentRepository();
      final docs = DocumentProvider(documentRepository: repo);
      await docs.fetchDocuments();

      repo.failWith = 'Storage is full';
      final added = await docs.addDocument(
        FakeDocumentRepository.doc('n', 'New.pdf'),
      );

      expect(added, isFalse);
      expect(docs.count, 3);
      expect(docs.error, 'Storage is full'); // no "Exception: " prefix
      expect(docs.isLoading, isFalse);
    });

    test('a failed first load can be retried', () async {
      final repo = FakeDocumentRepository()..failWith = 'No connection';
      final docs = DocumentProvider(documentRepository: repo);

      await docs.fetchDocuments();
      expect(docs.hasFetched, isFalse);
      expect(docs.error, 'No connection');

      repo.failWith = null;
      await docs.fetchDocuments();
      expect(docs.hasFetched, isTrue);
      expect(docs.error, isNull);
      expect(docs.count, 3);
    });

    test('a failed favorite rolls back the right item after the list shifts',
        () async {
      final repo = FakeAccountRepository();
      final accounts = AccountProvider(accountRepository: repo);
      await accounts.fetchAccounts(); // [a1, a2]

      final hold = Completer<void>();
      repo.pendingToggle = hold;
      final toggle = accounts.toggleFavorite('a2');
      expect(accounts.accounts.last.isFavorite, isTrue); // optimistic

      // Something is inserted at the top while the request is in flight, so
      // a2 is no longer at the index it had when the toggle started.
      await accounts.addAccount(FakeAccountRepository.account('new', 'Netflix'));
      hold.completeError(Exception('Server error'));

      expect(await toggle, isFalse);
      expect(accounts.accounts.map((a) => a.id), ['new', 'a1', 'a2']);
      expect(accounts.accounts[2].isFavorite, isFalse); // a2 reverted
      expect(accounts.accounts[1].title, 'Bank'); // a1 untouched
      expect(accounts.error, 'Server error');
    });

    test('a failed settings save reverts only the flag that changed', () async {
      final repo = FakeSettingsRepository();
      final settings = SettingsProvider(settingsRepository: repo);

      final hold = Completer<void>();
      repo.holdNextUpdate = hold;
      final twoFactor = settings.toggleTwoFactor(false); // in flight
      expect(settings.twoFactorEnabled, isFalse);

      await settings.toggleBiometric(false); // saves fine meanwhile
      hold.completeError(Exception('Save failed'));

      expect(await twoFactor, isFalse);
      expect(settings.twoFactorEnabled, isTrue); // reverted
      expect(settings.biometricEnabled, isFalse); // kept
      expect(settings.error, 'Save failed');
    });

    test('a failed no-op toggle does not flip the setting', () async {
      final repo = FakeSettingsRepository()..failWith = 'Save failed';
      final settings = SettingsProvider(settingsRepository: repo);

      // Already enabled; "turning it on" and failing must leave it enabled.
      expect(await settings.toggleTwoFactor(true), isFalse);
      expect(settings.twoFactorEnabled, isTrue);
    });

    test('clearError also clears the error status a failed sign-in left',
        () async {
      final repo = FakeAuthRepository()..failWith = 'Invalid credentials';
      final auth = AuthProvider(authRepository: repo);

      await auth.signIn(email: 'a@b.co', password: 'secret1');
      expect(auth.status, AuthStatus.error);
      expect(auth.error, 'Invalid credentials');

      auth.clearError();
      expect(auth.error, isNull);
      expect(auth.status, AuthStatus.unauthenticated);
    });
  });

  group('Session restore', () {
    test('checkSession signs in an existing session', () async {
      final repo = FakeAuthRepository();
      await repo.signIn(email: 'back@example.com', password: 'secret1');
      final auth = AuthProvider(authRepository: repo);

      await auth.checkSession();

      expect(auth.isAuthenticated, isTrue);
      expect(auth.currentUser?.email, 'back@example.com');
    });

    test('checkSession with no session leaves the user signed out', () async {
      final auth = AuthProvider(authRepository: FakeAuthRepository());
      await auth.checkSession();
      expect(auth.status, AuthStatus.unauthenticated);
    });

    test('a failed restore is not surfaced as a user-facing error', () async {
      final repo = FakeAuthRepository()..failRestore = true;
      final auth = AuthProvider(authRepository: repo);

      await auth.checkSession();

      expect(auth.status, AuthStatus.unauthenticated);
      expect(auth.error, isNull);
    });
  });

  group('TrustedContactService', () {
    test('added and removed contacts persist across refetches', () async {
      final service = TrustedContactServiceImpl();
      const added = TrustedContactItem(
        id: 'tc-new',
        name: 'New Person',
        relationship: 'Friend',
        accessLevel: 'View Only',
        avatarUrl: '',
      );

      await service.addContact(added);
      expect((await service.fetchContacts()).map((c) => c.id), contains('tc-new'));

      await service.removeContact('tc-1');
      final ids = (await service.fetchContacts()).map((c) => c.id);
      expect(ids, isNot(contains('tc-1')));
      expect(ids, contains('tc-new'));
    });
  });

  group('AuthGuard', () {
    Future<AuthProvider> pumpGuarded(
      WidgetTester tester, {
      required bool signedIn,
    }) async {
      final auth = AuthProvider(authRepository: FakeAuthRepository());
      if (signedIn) await auth.signIn(email: 'a@b.co', password: 'secret1');

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp(
            routes: {'/welcome': (_) => const Text('welcome screen')},
            home: const AuthGuard(
              redirectTo: '/welcome',
              child: Text('private content'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return auth;
    }

    testWidgets('shows its child when signed in', (tester) async {
      await pumpGuarded(tester, signedIn: true);
      expect(find.text('private content'), findsOneWidget);
      expect(find.text('welcome screen'), findsNothing);
    });

    testWidgets('redirects instead of showing its child when signed out',
        (tester) async {
      await pumpGuarded(tester, signedIn: false);
      expect(find.text('private content'), findsNothing);
      expect(find.text('welcome screen'), findsOneWidget);
    });

    testWidgets('redirects if the session ends while it is open',
        (tester) async {
      final auth = await pumpGuarded(tester, signedIn: true);
      expect(find.text('private content'), findsOneWidget);

      await auth.signOut();
      await tester.pumpAndSettle();

      expect(find.text('private content'), findsNothing);
      expect(find.text('welcome screen'), findsOneWidget);
    });
  });
}
