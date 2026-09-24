import 'package:everkeep/features/home/presentation/screens/home_screen.dart';
import 'package:everkeep/features/home/presentation/widgets/attention_section.dart';
import 'package:everkeep/features/home/presentation/widgets/quick_actions_section.dart';
import 'package:everkeep/features/home/presentation/widgets/recent_items_section.dart';
import 'package:everkeep/features/home/presentation/widgets/vault_overview_section.dart';
import 'package:everkeep/models/document_item.dart';
import 'package:everkeep/models/memory_item.dart';
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

void main() {
  late FakeAuthRepository authRepo;
  late FakeUserRepository userRepo;
  late FakeDocumentRepository docRepo;
  late FakeMemoryRepository memRepo;
  late FakeAccountRepository accRepo;
  late FakeTrustedContactRepository contactRepo;
  late FakeVaultRepository vaultRepo;

  late DocumentProvider docProv;
  late MemoryProvider memProv;
  late AccountProvider accProv;
  late TrustedContactProvider contactProv;
  late VaultProvider vaultProv;
  late UserProvider userProv;
  late AuthProvider authProv;

  setUp(() {
    authRepo = FakeAuthRepository();
    userRepo = FakeUserRepository(authRepo);
    docRepo = FakeDocumentRepository();
    memRepo = FakeMemoryRepository();
    accRepo = FakeAccountRepository();
    contactRepo = FakeTrustedContactRepository();
    vaultRepo = FakeVaultRepository();

    authProv = AuthProvider(authRepository: authRepo);
    userProv = UserProvider(userRepository: userRepo)..setUser(testUser);
    docProv = DocumentProvider(documentRepository: docRepo);
    memProv = MemoryProvider(memoryRepository: memRepo);
    accProv = AccountProvider(accountRepository: accRepo);
    contactProv = TrustedContactProvider(trustedContactRepository: contactRepo);
    vaultProv = VaultProvider(vaultRepository: vaultRepo);
  });

  void tallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpDashboard(WidgetTester tester) async {
    tallScreen(tester);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProv),
          ChangeNotifierProvider<UserProvider>.value(value: userProv),
          ChangeNotifierProvider<VaultProvider>.value(value: vaultProv),
          ChangeNotifierProvider<DocumentProvider>.value(value: docProv),
          ChangeNotifierProvider<MemoryProvider>.value(value: memProv),
          ChangeNotifierProvider<AccountProvider>.value(value: accProv),
          ChangeNotifierProvider<TrustedContactProvider>.value(value: contactProv),
          ChangeNotifierProvider<SettingsProvider>(
            create: (_) => SettingsProvider(settingsRepository: FakeSettingsRepository()),
          ),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Dashboard — What Needs My Attention', () {
    testWidgets('shows calm empty state when no items need attention', (tester) async {
      docRepo.items.clear();
      await docProv.fetchDocuments();
      await pumpDashboard(tester);

      expect(find.byType(AttentionSection), findsOneWidget);
      expect(find.text('WHAT NEEDS MY ATTENTION'), findsOneWidget);
      expect(find.text('All documents up to date'), findsOneWidget);
      expect(
        find.text('Nothing expiring soon or requiring immediate attention.'),
        findsOneWidget,
      );
    });

    testWidgets('highlights expired documents and documents expiring soon with breakdown pills', (
      tester,
    ) async {
      final now = DateTime.now();
      docRepo.items
        ..clear()
        ..addAll([
          DocumentItem(
            id: 'doc-expired',
            title: 'My Expired Passport',
            subtitle: '',
            category: 'Legal',
            documentType: 'passport',
            expiryDate: now.subtract(const Duration(days: 5)),
          ),
          DocumentItem(
            id: 'doc-expiring',
            title: 'Car Insurance Policy',
            subtitle: '',
            category: 'Financial',
            documentType: 'insurance',
            expiryDate: now.add(const Duration(days: 12)),
          ),
          DocumentItem(
            id: 'doc-valid',
            title: 'University Degree',
            subtitle: '',
            category: 'Legal',
            documentType: 'academic',
          ),
        ]);
      await docProv.fetchDocuments();
      await pumpDashboard(tester);

      expect(find.text('1 expired'), findsOneWidget);
      expect(find.text('1 expiring soon'), findsOneWidget);

      expect(find.text('My Expired Passport'), findsOneWidget);
      expect(find.text('Car Insurance Policy'), findsOneWidget);
      expect(find.text('University Degree'), findsNothing); // valid, not in attention
    });
  });

  group('Dashboard — Vault Overview Counts', () {
    testWidgets('displays real live counts for all 4 chapters', (tester) async {
      vaultProv.updateLiveCounts(
        documents: 5,
        memories: 8,
        accounts: 4,
        banking: 1,
        contacts: 3,
      );
      await pumpDashboard(tester);

      expect(find.byType(VaultOverviewSection), findsOneWidget);
      expect(find.text('5 files stored'), findsOneWidget);
      expect(find.text('8 memories'), findsOneWidget);
      expect(find.text('3 trustees'), findsOneWidget);
      expect(find.text('4 logins saved'), findsOneWidget);
    });
  });

  group('Dashboard — Quick Actions', () {
    testWidgets('shows Add Document, Add Memory, Add Important Information in order', (
      tester,
    ) async {
      await pumpDashboard(tester);

      expect(find.byType(QuickActionsSection), findsOneWidget);
      expect(find.text('QUICK ACTIONS'), findsOneWidget);
      expect(find.text('Add Document'), findsOneWidget);
      expect(find.text('Add Memory'), findsOneWidget);
      expect(find.text('Add Important Information'), findsOneWidget);
    });
  });

  group('Dashboard — Recent Items & Tabs', () {
    testWidgets('shows recent documents and recent memories tabs', (tester) async {
      final now = DateTime.now();
      docRepo.items
        ..clear()
        ..add(
          DocumentItem(
            id: 'd1',
            title: 'Work Visa.pdf',
            subtitle: '',
            category: 'Legal',
            documentType: 'visa',
            dateAdded: now.subtract(const Duration(hours: 3)),
          ),
        );
      memRepo.items
        ..clear()
        ..add(
          MemoryItem(
            id: 'm1',
            title: 'Trip to Kyoto',
            content: 'Walked through bamboo groves.',
            type: 'memory',
            createdAt: now.subtract(const Duration(hours: 1)),
          ),
        );
      await docProv.fetchDocuments();
      await memProv.fetchMemories();
      await pumpDashboard(tester);

      expect(find.byType(RecentItemsSection), findsOneWidget);
      expect(find.text('All Recent'), findsOneWidget);
      expect(find.text('Recent Documents'), findsOneWidget);
      expect(find.text('Recent Memories'), findsOneWidget);

      // Default 'All Recent' shows both activities
      expect(find.text('Work Visa.pdf added'), findsOneWidget);
      expect(find.text('Trip to Kyoto added to memories'), findsOneWidget);

      // Tap 'Recent Documents' tab
      await tester.tap(find.text('Recent Documents'));
      await tester.pumpAndSettle();

      expect(find.text('Work Visa.pdf'), findsOneWidget);
      expect(find.text('Trip to Kyoto added to memories'), findsNothing);

      // Tap 'Recent Memories' tab
      await tester.tap(find.text('Recent Memories'));
      await tester.pumpAndSettle();

      expect(find.text('Trip to Kyoto'), findsOneWidget);
      expect(find.text('Work Visa.pdf'), findsNothing);
    });
  });
}
