import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import 'package:everkeep/core/routing/app_router.dart';
import 'package:everkeep/core/utils/document_expiration.dart';
import 'package:everkeep/models/document_item.dart';
import 'package:everkeep/providers/document_provider.dart';
import 'package:everkeep/repositories/document_repository.dart';
import 'package:everkeep/services/notification_service.dart';

class FakeDocumentRepository implements DocumentRepository {
  List<DocumentItem> docs = [];

  @override
  Future<List<DocumentItem>> fetchDocuments() async => List.of(docs);

  @override
  Future<DocumentItem> addDocument(DocumentItem doc, {dynamic upload}) async {
    docs.add(doc);
    return doc;
  }

  @override
  Future<DocumentItem> updateDocument(DocumentItem doc) async {
    final idx = docs.indexWhere((d) => d.id == doc.id);
    if (idx != -1) {
      docs[idx] = doc;
    }
    return doc;
  }

  @override
  Future<void> deleteDocument(String id) async {
    docs.removeWhere((d) => d.id == id);
  }

  @override
  Future<String> createDownloadUrl(String path) async => 'https://example.com/$path';
}

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
  });

  DocumentItem makeDoc({
    required String id,
    required String title,
    DateTime? expiryDate,
  }) {
    return DocumentItem(
      id: id,
      title: title,
      subtitle: 'Legal',
      category: 'Legal',
      expiryDate: expiryDate,
    );
  }

  group('Document Expiration Notifications', () {
    late FakeNotificationPluginAdapter fakeAdapter;
    late NotificationService service;

    setUp(() async {
      fakeAdapter = FakeNotificationPluginAdapter();
      service = NotificationService(adapter: fakeAdapter);
      NotificationService.setInstance(service);
      await service.initialize();
    });

    tearDown(() {
      NotificationService.setInstance(null);
    });

    test('1. Notification service initialization configures adapter and timezone', () async {
      var tappedDocId = '';
      await service.initialize(onDocumentTap: (id) => tappedDocId = id);

      expect(service.isInitialized, isTrue);
      expect(fakeAdapter.isInitialized, isTrue);
      expect(fakeAdapter.onNotificationResponse, isNotNull);

      fakeAdapter.simulateNotificationTap('doc-tap-test');
      expect(tappedDocId, 'doc-tap-test');
    });

    test('2. Correct notification ID generation produces valid positive 31-bit integers', () {
      final id1 = NotificationService.notificationIdFor('doc-123', 1);
      final id2 = NotificationService.notificationIdFor('doc-123', 2);
      final id3 = NotificationService.notificationIdFor('doc-123', 3);

      expect(id1, isPositive);
      expect(id1, lessThan(0x7FFFFFFF));
      expect(id2, isPositive);
      expect(id3, isPositive);
      expect(id1, isNot(equals(id2)));
      expect(id2, isNot(equals(id3)));
    });

    test('3. Notification IDs are stable for the same document and reminder type', () {
      final first = NotificationService.notificationIdFor('passport-uuid-456', 1);
      final second = NotificationService.notificationIdFor('passport-uuid-456', 1);
      final third = NotificationService.notificationIdFor('passport-uuid-456', 1);

      expect(first, equals(second));
      expect(second, equals(third));
    });

    test('4. Different documents receive different IDs for the same reminder type', () {
      final docA = NotificationService.notificationIdFor('doc-aaa', 1);
      final docB = NotificationService.notificationIdFor('doc-bbb', 1);

      expect(docA, isNot(equals(docB)));
    });

    test('5. Correct expiration reminder calculation yields 30-day, 7-day, and day-of reminders', () {
      final now = DateTime(2026, 1, 1, 8, 0);
      final expiryDate = DateTime(2026, 2, 15); // 45 days away
      final doc = makeDoc(id: 'doc-calc', title: 'Passport', expiryDate: expiryDate);

      final reminders = service.calculateReminders(doc, now: now);

      expect(reminders.length, 3);
      // 30 days before Feb 15 = Jan 16 at 9:00 AM
      expect(reminders[0].type, DocumentReminderType.expiringSoon30Days);
      expect(reminders[0].scheduledAt, DateTime(2026, 1, 16, 9, 0));
      expect(reminders[0].title, 'Document expiring soon');
      expect(reminders[0].body, 'Your Passport expires in 30 days.');

      // 7 days before Feb 15 = Feb 8 at 9:00 AM
      expect(reminders[1].type, DocumentReminderType.expiringSoon7Days);
      expect(reminders[1].scheduledAt, DateTime(2026, 2, 8, 9, 0));
      expect(reminders[1].title, 'Document expiring soon');
      expect(reminders[1].body, 'Your Passport expires in 7 days.');

      // Day of Feb 15 at 9:00 AM
      expect(reminders[2].type, DocumentReminderType.expiredDayOf);
      expect(reminders[2].scheduledAt, DateTime(2026, 2, 15, 9, 0));
      expect(reminders[2].title, 'Document expired');
      expect(reminders[2].body, 'Your Passport expired today.');
    });

    test('6. Document expiring soon schedules the expected future reminders', () async {
      // 10 days away: 30 days before is in the past, but 7-day and day-of are in future
      final now = DateTime(2026, 6, 1, 8, 0);
      final expiryDate = DateTime(2026, 6, 11);
      final doc = makeDoc(id: 'doc-soon', title: 'Visa', expiryDate: expiryDate);

      await service.scheduleDocumentReminders(doc, now: now);

      expect(fakeAdapter.scheduledNotifications.length, 2);
      final id7 = NotificationService.notificationIdFor('doc-soon', DocumentReminderType.expiringSoon7Days.code);
      final id0 = NotificationService.notificationIdFor('doc-soon', DocumentReminderType.expiredDayOf.code);
      expect(fakeAdapter.scheduledNotifications.containsKey(id7), isTrue);
      expect(fakeAdapter.scheduledNotifications.containsKey(id0), isTrue);
    });

    test('7. Expired document has past reminders and schedules 0 future notifications', () async {
      final now = DateTime(2026, 6, 15, 10, 0);
      final expiryDate = DateTime(2026, 6, 10); // Expired 5 days ago
      final doc = makeDoc(id: 'doc-expired', title: 'Old ID', expiryDate: expiryDate);

      await service.scheduleDocumentReminders(doc, now: now);

      expect(fakeAdapter.scheduledNotifications.isEmpty, isTrue);
    });

    test('8. Already-past notification times are not scheduled', () async {
      // Expiration is in 5 days.
      // 30 days before and 7 days before are both in the past. Only day-of is scheduled.
      final now = DateTime(2026, 7, 10, 8, 0);
      final expiryDate = DateTime(2026, 7, 15);
      final doc = makeDoc(id: 'doc-past-check', title: 'Contract', expiryDate: expiryDate);

      await service.scheduleDocumentReminders(doc, now: now);

      expect(fakeAdapter.scheduledNotifications.length, 1);
      final id0 = NotificationService.notificationIdFor('doc-past-check', DocumentReminderType.expiredDayOf.code);
      expect(fakeAdapter.scheduledNotifications.containsKey(id0), isTrue);
    });

    test('9. Updating expiration date cancels/replaces previous schedule', () async {
      final now = DateTime(2026, 1, 1, 8, 0);
      final oldExpiry = DateTime(2026, 3, 1);
      final docOld = makeDoc(id: 'doc-update', title: 'License', expiryDate: oldExpiry);

      await service.scheduleDocumentReminders(docOld, now: now);
      final old30Id = NotificationService.notificationIdFor('doc-update', 1);
      final oldScheduledDate = fakeAdapter.scheduledNotifications[old30Id]!.scheduledDate;

      // Update to new expiry date
      final newExpiry = DateTime(2026, 5, 1);
      final docNew = makeDoc(id: 'doc-update', title: 'License', expiryDate: newExpiry);

      await service.scheduleDocumentReminders(docNew, now: now);
      final newScheduledDate = fakeAdapter.scheduledNotifications[old30Id]!.scheduledDate;

      expect(newScheduledDate, isNot(equals(oldScheduledDate)));
      expect(fakeAdapter.scheduledNotifications.length, 3);
    });

    test('10. Deleting a document cancels all its reminders', () async {
      final now = DateTime(2026, 1, 1, 8, 0);
      final doc = makeDoc(id: 'doc-delete', title: 'Permit', expiryDate: DateTime(2026, 3, 1));

      await service.scheduleDocumentReminders(doc, now: now);
      expect(fakeAdapter.scheduledNotifications.length, 3);

      await service.cancelDocumentReminders('doc-delete');
      expect(fakeAdapter.scheduledNotifications.isEmpty, isTrue);
    });

    test('11. Startup reconciliation schedules missing reminders', () async {
      final now = DateTime(2026, 1, 1, 8, 0);
      final docs = [
        makeDoc(id: 'doc-1', title: 'Doc 1', expiryDate: DateTime(2026, 3, 1)),
        makeDoc(id: 'doc-2', title: 'Doc 2', expiryDate: DateTime(2026, 4, 1)),
        makeDoc(id: 'doc-3', title: 'Doc 3', expiryDate: null), // No expiry
      ];

      await service.reconcileDocumentReminders(docs, now: now);

      // Doc 1 has 3 reminders, Doc 2 has 3 reminders, Doc 3 has 0
      expect(fakeAdapter.scheduledNotifications.length, 6);
    });

    test('12. Reconciliation is idempotent and does not duplicate schedules', () async {
      final now = DateTime(2026, 1, 1, 8, 0);
      final docs = [
        makeDoc(id: 'doc-dup', title: 'Warranty', expiryDate: DateTime(2026, 3, 1)),
      ];

      await service.reconcileDocumentReminders(docs, now: now);
      expect(fakeAdapter.scheduledNotifications.length, 3);

      // Reconcile again with same data
      await service.reconcileDocumentReminders(docs, now: now);
      expect(fakeAdapter.scheduledNotifications.length, 3);
    });

    test('13. Notification disabled state cancels and prevents scheduling', () async {
      final now = DateTime(2026, 1, 1, 8, 0);
      final doc = makeDoc(id: 'doc-dis', title: 'Card', expiryDate: DateTime(2026, 3, 1));

      await service.scheduleDocumentReminders(doc, now: now);
      expect(fakeAdapter.scheduledNotifications.length, 3);

      await service.setEnabled(false);
      expect(service.isEnabled, isFalse);
      expect(fakeAdapter.scheduledNotifications.isEmpty, isTrue);

      // Attempting to schedule while disabled should do nothing
      await service.scheduleDocumentReminders(doc, now: now);
      expect(fakeAdapter.scheduledNotifications.isEmpty, isTrue);
    });

    test('14. DocumentProvider.reset() (logout) clears scheduled notifications', () async {
      final repo = FakeDocumentRepository();
      final doc = makeDoc(
        id: 'doc-user',
        title: 'Will',
        expiryDate: DateTime.now().add(const Duration(days: 60)),
      );
      repo.docs = [doc];

      final provider = DocumentProvider(
        documentRepository: repo,
        notificationService: service,
      );

      await provider.fetchDocuments();
      await Future<void>.delayed(Duration.zero);
      expect(fakeAdapter.scheduledNotifications.isNotEmpty, isTrue);

      provider.reset();
      await Future<void>.delayed(Duration.zero);
      expect(fakeAdapter.scheduledNotifications.isEmpty, isTrue);
      expect(provider.documents.isEmpty, isTrue);
    });

    testWidgets('15. Notification tap resolves the correct document ID and opens details', (tester) async {
      final doc = makeDoc(
        id: 'doc-tap-resolved',
        title: 'Passport',
        expiryDate: DateTime.now().add(const Duration(days: 60)),
      );
      final repo = FakeDocumentRepository()..docs = [doc];
      final docProvider = DocumentProvider(
        documentRepository: repo,
        notificationService: service,
      );
      await docProvider.fetchDocuments();

      await service.initialize(
        onDocumentTap: (docId) => service.openDocumentById(docId),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: docProvider),
          ],
          child: MaterialApp(
            navigatorKey: AppRouter.navigatorKey,
            home: const Scaffold(body: Text('Home Screen')),
          ),
        ),
      );

      // Simulate notification tap
      fakeAdapter.simulateNotificationTap('doc-tap-resolved');
      await tester.pumpAndSettle();

      // Document details sheet opens showing document title and details
      expect(find.text('Passport'), findsWidgets);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('16. Missing/deleted document from notification is handled safely without crashing', (tester) async {
      final repo = FakeDocumentRepository()..docs = [];
      final docProvider = DocumentProvider(
        documentRepository: repo,
        notificationService: service,
      );
      await docProvider.fetchDocuments();

      await service.initialize(
        onDocumentTap: (docId) => service.openDocumentById(docId),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: docProvider),
          ],
          child: MaterialApp(
            navigatorKey: AppRouter.navigatorKey,
            home: const Scaffold(body: Text('Home Screen')),
          ),
        ),
      );

      // Simulate notification tap for a non-existent document
      fakeAdapter.simulateNotificationTap('non-existent-doc-id');
      await tester.pumpAndSettle();

      // Shows friendly error message
      expect(find.text('That document couldn\'t be found.'), findsOneWidget);
    });

    test('17. Existing document expiration calculations remain unchanged', () {
      final now = DateTime(2026, 3, 15);

      // Valid (more than 30 days)
      final valid = DateTime(2026, 5, 1);
      expect(
        DocumentExpirationHelper.statusFor(valid, now: now),
        DocumentExpirationStatus.valid,
      );

      // Expiring soon (within 30 days)
      final soon = DateTime(2026, 3, 25);
      expect(
        DocumentExpirationHelper.statusFor(soon, now: now),
        DocumentExpirationStatus.expiringSoon,
      );

      // Expired
      final expired = DateTime(2026, 3, 10);
      expect(
        DocumentExpirationHelper.statusFor(expired, now: now),
        DocumentExpirationStatus.expired,
      );

      // No expiry date
      expect(
        DocumentExpirationHelper.statusFor(null, now: now),
        DocumentExpirationStatus.noExpiryDate,
      );
    });
  });
}
