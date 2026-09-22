import 'package:everkeep/features/documents/presentation/screens/documents_screen.dart';
import 'package:everkeep/features/profile/presentation/screens/profile_screen.dart';
import 'package:everkeep/features/trusted_contacts/presentation/screens/trusted_contacts_screen.dart';
import 'package:everkeep/providers/auth_provider.dart';
import 'package:everkeep/providers/document_provider.dart';
import 'package:everkeep/providers/trusted_contact_provider.dart';
import 'package:everkeep/providers/user_provider.dart';
import 'package:everkeep/providers/vault_provider.dart';
import 'package:everkeep/widgets/glass/glass_fab.dart';
import 'package:everkeep/widgets/glass/glass_primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'fakes.dart';

/// Drives the real screens against fake repositories: the add/delete/edit
/// flows are wired to the providers, and failures are reported without
/// losing the list or what the user typed.
void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget screen,
    List<ChangeNotifierProvider> providers,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: MaterialApp(home: screen),
      ),
    );
    await tester.pumpAndSettle();
  }

  ChangeNotifierProvider<VaultProvider> vaultProvider() =>
      ChangeNotifierProvider(
        create: (_) => VaultProvider(vaultRepository: FakeVaultRepository()),
      );

  group('Documents screen', () {
    late FakeDocumentRepository repo;
    late DocumentProvider docs;

    Future<void> pumpDocuments(WidgetTester tester) async {
      docs = DocumentProvider(documentRepository: repo);
      await pump(tester, const DocumentsScreen(), [
        ChangeNotifierProvider<DocumentProvider>.value(value: docs),
        vaultProvider(),
      ]);
    }

    Future<void> openAddSheetAndType(WidgetTester tester, String name) async {
      await tester.tap(find.byType(GlassFab));
      await tester.pumpAndSettle();
      // The + button asks how to add: with a file from the device, or just a record.
      await tester.tap(find.text('Add without a file'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), name);
      await tester.tap(find.widgetWithText(GlassPrimaryButton, 'Add Document'));
      await tester.pumpAndSettle();
    }

    setUp(() => repo = FakeDocumentRepository());

    testWidgets('adding a document shows it in the list', (tester) async {
      await pumpDocuments(tester);
      expect(find.text('Will.pdf'), findsOneWidget);

      await openAddSheetAndType(tester, 'Passport.pdf');

      expect(find.text('Passport.pdf'), findsOneWidget);
      expect(find.text('Document added'), findsOneWidget);
      expect(docs.count, 4);
    });

    testWidgets('an empty name is rejected before anything is saved', (
      tester,
    ) async {
      await pumpDocuments(tester);

      await openAddSheetAndType(tester, '   ');

      expect(find.text('Document name is required'), findsOneWidget);
      expect(docs.count, 3);
    });

    testWidgets('a failed save keeps the sheet open with the typed text', (
      tester,
    ) async {
      await pumpDocuments(tester);
      repo.failWith = 'Storage is full';

      await openAddSheetAndType(tester, 'Passport.pdf');

      expect(find.text('Storage is full'), findsOneWidget);
      expect(find.text('Passport.pdf'), findsOneWidget); // still in the field
      expect(docs.count, 3);

      // Retrying once the problem is gone works without retyping.
      repo.failWith = null;
      await tester.tap(find.widgetWithText(GlassPrimaryButton, 'Add Document'));
      await tester.pumpAndSettle();

      expect(find.text('Storage is full'), findsNothing);
      expect(docs.count, 4);
      expect(find.text('Document added'), findsOneWidget);
    });

    testWidgets('a failed first load shows a retry that recovers', (
      tester,
    ) async {
      repo.failWith = 'No connection';
      await pumpDocuments(tester);

      expect(find.text('No connection'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Will.pdf'), findsNothing);

      repo.failWith = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('No connection'), findsNothing);
      expect(find.text('Will.pdf'), findsOneWidget);
    });

    testWidgets('deleting a document asks first, then removes it', (
      tester,
    ) async {
      await pumpDocuments(tester);

      await tester.tap(find.text('Will.pdf'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete document'));
      await tester.pumpAndSettle();
      expect(find.text('Delete document?'), findsOneWidget); // confirmation
      expect(docs.count, 3); // nothing deleted yet

      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Will.pdf'), findsNothing);
      expect(find.text('Document deleted'), findsOneWidget);
      expect(docs.count, 2);
    });

    testWidgets('cancelling the confirmation deletes nothing', (tester) async {
      await pumpDocuments(tester);

      await tester.tap(find.text('Will.pdf'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete document'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Will.pdf'), findsOneWidget);
      expect(docs.count, 3);
    });

    testWidgets('a failed delete keeps the list and reports the error', (
      tester,
    ) async {
      await pumpDocuments(tester);
      repo.failWith = 'Locked by another device';

      await tester.tap(find.text('Will.pdf'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete document'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      // The whole list must not be replaced by the error message.
      expect(find.text('Will.pdf'), findsOneWidget);
      expect(find.text('Deed.pdf'), findsOneWidget);
      expect(find.text('Locked by another device'), findsOneWidget);
      expect(docs.count, 3);
    });
  });

  group('Trusted contacts screen', () {
    late FakeTrustedContactRepository repo;
    late TrustedContactProvider contacts;

    Future<void> pumpContacts(WidgetTester tester) async {
      contacts = TrustedContactProvider(trustedContactRepository: repo);
      await pump(tester, const TrustedContactsScreen(), [
        ChangeNotifierProvider<TrustedContactProvider>.value(value: contacts),
      ]);
    }

    setUp(() => repo = FakeTrustedContactRepository());

    testWidgets('inviting someone adds them to the list', (tester) async {
      await pumpContacts(tester);
      expect(contacts.count, 2);

      await tester.ensureVisible(find.text('Invite Someone'));
      await tester.tap(find.text('Invite Someone'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'Jordan Lee');
      await tester.enterText(find.byType(TextField).at(1), 'Sibling');
      await tester.tap(find.widgetWithText(GlassPrimaryButton, 'Add Person'));
      await tester.pumpAndSettle();

      expect(find.text('Jordan Lee'), findsOneWidget);
      expect(contacts.count, 3);
      expect(repo.items.map((c) => c.name), contains('Jordan Lee'));
    });

    testWidgets('removing a contact asks first, then removes them', (
      tester,
    ) async {
      await pumpContacts(tester);

      await tester.tap(find.text('Ada Lovelace'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove trusted person'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(find.text('Ada Lovelace'), findsNothing);
      expect(find.text('Ada Lovelace removed'), findsOneWidget);
      expect(contacts.count, 1);
    });

    testWidgets('a failed removal keeps the contact and says why', (
      tester,
    ) async {
      await pumpContacts(tester);
      repo.failWith = 'Could not reach server';

      await tester.tap(find.text('Ada Lovelace'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove trusted person'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('Could not reach server'), findsOneWidget);
      expect(contacts.count, 2);
    });
  });

  group('Profile screen', () {
    late UserProvider user;
    late FakeUserRepository userRepo;

    Future<void> pumpProfile(WidgetTester tester) async {
      userRepo = FakeUserRepository();
      user = UserProvider(userRepository: userRepo)..setUser(testUser);
      await pump(tester, const ProfileScreen(), [
        ChangeNotifierProvider<UserProvider>.value(value: user),
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(authRepository: FakeAuthRepository()),
        ),
        ChangeNotifierProvider<TrustedContactProvider>(
          create: (_) => TrustedContactProvider(
            trustedContactRepository: FakeTrustedContactRepository(),
          ),
        ),
        vaultProvider(),
      ]);
    }

    testWidgets('editing personal info updates the profile', (tester) async {
      await pumpProfile(tester);

      await tester.tap(find.text('Personal Info'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Jane Doe');
      await tester.tap(find.widgetWithText(GlassPrimaryButton, 'Save Changes'));
      await tester.pumpAndSettle();

      expect(user.displayName, 'Jane Doe');
      expect(find.text('Jane Doe'), findsWidgets);
      expect(find.text('Profile updated'), findsOneWidget);
    });

    testWidgets('a failed save keeps the sheet open and the name unchanged', (
      tester,
    ) async {
      await pumpProfile(tester);
      userRepo.failWith = 'Offline';

      await tester.tap(find.text('Personal Info'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Jane Doe');
      await tester.tap(find.widgetWithText(GlassPrimaryButton, 'Save Changes'));
      await tester.pumpAndSettle();

      expect(find.text('Offline'), findsOneWidget);
      expect(user.displayName, 'Sarah Mitchell');
      expect(find.text('Jane Doe'), findsOneWidget); // the field, not the hero
    });
  });
}
