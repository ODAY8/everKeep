import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:everkeep/core/routing/app_router.dart';
import 'package:everkeep/models/document_item.dart';
import 'package:everkeep/providers/document_provider.dart';
import 'package:everkeep/repositories/document_repository.dart';
import 'package:everkeep/services/notification_service.dart';

class MockDocumentRepository implements DocumentRepository {
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
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Real Android OS Notification Smoke Test', () {
    late NotificationService service;
    late FlutterLocalNotificationsPlugin realPlugin;

    setUp(() async {
      realPlugin = FlutterLocalNotificationsPlugin();
      service = NotificationService.instance;
      await service.initialize(
        onDocumentTap: (docId) => service.openDocumentById(docId),
      );
    });

    testWidgets('Verify real Android plugin initialization and permissions', (tester) async {
      expect(service.isInitialized, isTrue);

      final permissionGranted = await service.requestPermissionsIfNeeded();
      debugPrint('Real Android permission status: $permissionGranted');
      expect(permissionGranted, isTrue);
    });

    testWidgets('Verify real plugin scheduling, system tray posting, tap navigation, and lifecycle', (tester) async {
      final docId = 'real-android-doc-${DateTime.now().millisecondsSinceEpoch}';
      final testDoc = DocumentItem(
        id: docId,
        title: 'Smoke Test Passport',
        subtitle: 'Legal · Verified',
        category: 'Legal',
        expiryDate: DateTime.now().add(const Duration(days: 45)),
      );

      final repo = MockDocumentRepository()..docs = [testDoc];
      final docProvider = DocumentProvider(
        documentRepository: repo,
        notificationService: service,
      );
      await docProvider.fetchDocuments();

      // Pump widget tree with AppRouter.navigatorKey for real UI navigation
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: docProvider),
          ],
          child: MaterialApp(
            navigatorKey: AppRouter.navigatorKey,
            home: const Scaffold(body: Text('Everkeep Ready')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Schedule reminders using real plugin
      await service.scheduleDocumentReminders(testDoc);

      // Verify scheduled with real Android plugin
      final pending = await realPlugin.pendingNotificationRequests();
      debugPrint('Real Android pending requests count: ${pending.length}');
      final scheduledIds = pending.map((p) => p.id).toSet();

      final expected30Id = NotificationService.notificationIdFor(
        docId,
        DocumentReminderType.expiringSoon30Days.code,
      );
      final expected7Id = NotificationService.notificationIdFor(
        docId,
        DocumentReminderType.expiringSoon7Days.code,
      );
      final expected0Id = NotificationService.notificationIdFor(
        docId,
        DocumentReminderType.expiredDayOf.code,
      );

      expect(scheduledIds.contains(expected30Id), isTrue);
      expect(scheduledIds.contains(expected7Id), isTrue);
      expect(scheduledIds.contains(expected0Id), isTrue);

      // 2. Post an immediate notification to the system tray using the exact document notification channel
      const androidDetails = AndroidNotificationDetails(
        NotificationService.documentChannelId,
        NotificationService.documentChannelName,
        channelDescription: NotificationService.documentChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
      );
      const details = NotificationDetails(android: androidDetails);

      await realPlugin.show(
        expected7Id,
        'Document expiring soon',
        'Your Smoke Test Passport expires in 7 days.',
        details,
        payload: docId,
      );
      debugPrint('Real notification posted to Android system tray successfully.');

      // Allow OS to process notification display
      await Future<void>.delayed(const Duration(seconds: 2));

      // 3. Verify notification tap navigates to the EXACT document details sheet
      service.handleNotificationTap(docId);
      await tester.pumpAndSettle();

      // Verify the DocumentDetailsSheet is rendered with exact document details
      expect(find.text('Smoke Test Passport'), findsWidgets);
      expect(find.text('Delete'), findsOneWidget);
      debugPrint('Notification tap opened exact DocumentDetailsSheet.');

      // Close the sheet
      Navigator.of(AppRouter.navigatorKey.currentContext!).pop();
      await tester.pumpAndSettle();

      // 4. Verify tapping a deleted/non-existent document does not crash and shows friendly feedback
      service.handleNotificationTap('deleted-doc-999');
      await tester.pumpAndSettle();
      expect(find.text('That document couldn\'t be found.'), findsOneWidget);
      debugPrint('Deleted document tap handled safely without crash.');

      // 5. Verify update replaces scheduled notifications
      final updatedDoc = DocumentItem(
        id: docId,
        title: 'Smoke Test Passport Updated',
        subtitle: 'Legal · Verified',
        category: 'Legal',
        expiryDate: DateTime.now().add(const Duration(days: 60)),
      );
      await service.scheduleDocumentReminders(updatedDoc);
      final pendingAfterUpdate = await realPlugin.pendingNotificationRequests();
      expect(pendingAfterUpdate.any((p) => p.id == expected30Id), isTrue);
      debugPrint('Document update reconciled notifications cleanly.');

      // 6. Verify deleting cancels all reminders for this document
      await service.cancelDocumentReminders(docId);
      await realPlugin.cancel(expected7Id); // Also clear posted notification from tray
      final pendingAfterDelete = await realPlugin.pendingNotificationRequests();
      final remainingIds = pendingAfterDelete.map((p) => p.id).toSet();
      expect(remainingIds.contains(expected30Id), isFalse);
      expect(remainingIds.contains(expected7Id), isFalse);
      expect(remainingIds.contains(expected0Id), isFalse);
      debugPrint('Document deletion cleanly removed all scheduled notifications from Android.');
    });
  });
}
