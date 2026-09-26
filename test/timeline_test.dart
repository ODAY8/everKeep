import 'package:everkeep/features/documents/presentation/screens/documents_screen.dart';
import 'package:everkeep/features/documents/presentation/widgets/document_details_sheet.dart';
import 'package:everkeep/features/timeline/presentation/screens/timeline_screen.dart';
import 'package:everkeep/features/wishes/presentation/screens/wishes_screen.dart';
import 'package:everkeep/features/wishes/presentation/widgets/memory_details_sheet.dart';
import 'package:everkeep/models/document_item.dart';
import 'package:everkeep/models/memory_item.dart';
import 'package:everkeep/providers/document_provider.dart';
import 'package:everkeep/providers/memory_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'fakes.dart';

void main() {
  group('Timeline Event Construction and Ordering', () {
    test('Events are ordered chronologically (newest first / descending date)', () {
      final doc1 = DocumentItem(
        id: 'd1',
        title: 'Older Doc',
        subtitle: 'Legal',
        category: 'Legal',
        issueDate: DateTime(2021, 3, 15),
      );
      final doc2 = DocumentItem(
        id: 'd2',
        title: 'Newest Doc',
        subtitle: 'Identity',
        category: 'Identity',
        issueDate: DateTime(2024, 6, 20),
      );
      final mem1 = MemoryItem(
        id: 'm1',
        title: 'Middle Memory',
        content: 'Notes',
        type: 'memory',
        date: DateTime(2023, 1, 10),
      );

      final events = TimelineScreen.buildTimelineEvents(
        documents: [doc1, doc2],
        memories: [mem1],
      );

      expect(events.length, 3);
      expect(events[0].id, 'd2');
      expect(events[0].date, DateTime(2024, 6, 20));
      expect(events[1].id, 'm1');
      expect(events[1].date, DateTime(2023, 1, 10));
      expect(events[2].id, 'd1');
      expect(events[2].date, DateTime(2021, 3, 15));
    });

    test('Memory items create expected TimelineEvent with correct id, kind, and tags', () {
      final mem = MemoryItem(
        id: 'mem-99',
        title: 'Trip to Tokyo',
        content: 'Visited temples and gardens.',
        type: 'memory',
        date: DateTime(2023, 10, 5),
        location: 'Tokyo, Japan',
        tags: 'Travel, Vacation',
      );

      final events = TimelineScreen.buildTimelineEvents(
        documents: [],
        memories: [mem],
      );

      expect(events.length, 1);
      final event = events.first;
      expect(event.id, 'mem-99');
      expect(event.title, 'Trip to Tokyo');
      expect(event.subtitle, '📍 Tokyo, Japan');
      expect(event.kind, TimelineEventKind.memory);
      expect(event.date, DateTime(2023, 10, 5));
      expect(event.item, mem);
    });

    test('Wish items are excluded from timeline events (memories only)', () {
      final memory = MemoryItem(
        id: 'm1',
        title: 'Real Memory',
        content: 'Past milestone',
        type: 'memory',
        date: DateTime(2022, 5, 1),
      );
      final wish = MemoryItem(
        id: 'w1',
        title: 'Future Wish',
        content: 'Someday wish',
        type: 'wish',
        date: DateTime(2025, 1, 1),
      );

      final events = TimelineScreen.buildTimelineEvents(
        documents: [],
        memories: [memory, wish],
      );

      expect(events.length, 1);
      expect(events.first.id, 'm1');
      expect(events.first.title, 'Real Memory');
    });

    test('Document items create expected TimelineEvent and fall back to dateAdded', () {
      final docWithIssue = DocumentItem(
        id: 'doc-1',
        title: 'Passport',
        subtitle: 'Identity',
        category: 'Identity',
        issueDate: DateTime(2020, 4, 1),
        dateAdded: DateTime(2022, 1, 1),
      );
      final docWithAddedOnly = DocumentItem(
        id: 'doc-2',
        title: 'Insurance Policy',
        subtitle: 'Financial',
        category: 'Financial',
        dateAdded: DateTime(2023, 8, 12),
      );

      final events = TimelineScreen.buildTimelineEvents(
        documents: [docWithIssue, docWithAddedOnly],
        memories: [],
      );

      expect(events.length, 2);
      expect(events[0].id, 'doc-2');
      expect(events[0].date, DateTime(2023, 8, 12));
      expect(events[0].kind, TimelineEventKind.document);

      expect(events[1].id, 'doc-1');
      expect(events[1].date, DateTime(2020, 4, 1));
      expect(events[1].kind, TimelineEventKind.document);
    });

    test('Year grouping puts same-year events together and sorts years descending', () {
      final e1 = TimelineEvent(
        id: '1',
        title: 'Event 2024 A',
        date: DateTime(2024, 11, 1),
        kind: TimelineEventKind.memory,
        icon: Icons.favorite,
        tintColor: Colors.pink,
        item: Object(),
      );
      final e2 = TimelineEvent(
        id: '2',
        title: 'Event 2024 B',
        date: DateTime(2024, 2, 15),
        kind: TimelineEventKind.document,
        icon: Icons.description,
        tintColor: Colors.blue,
        item: Object(),
      );
      final e3 = TimelineEvent(
        id: '3',
        title: 'Event 2022',
        date: DateTime(2022, 7, 20),
        kind: TimelineEventKind.memory,
        icon: Icons.favorite,
        tintColor: Colors.pink,
        item: Object(),
      );

      final grouped = TimelineScreen.groupByYear([e1, e2, e3]);
      final sortedYears = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

      expect(sortedYears, [2024, 2022]);
      expect(grouped[2024]!.length, 2);
      expect(grouped[2024]!.map((e) => e.id), ['1', '2']);
      expect(grouped[2022]!.length, 1);
      expect(grouped[2022]!.first.id, '3');
    });
  });

  group('Timeline Screen Widget & Deep-Link Navigation', () {
    late FakeDocumentRepository docRepo;
    late FakeMemoryRepository memRepo;
    late DocumentProvider docProv;
    late MemoryProvider memProv;

    setUp(() {
      docRepo = FakeDocumentRepository([]);
      memRepo = FakeMemoryRepository([]);
      docProv = DocumentProvider(documentRepository: docRepo);
      memProv = MemoryProvider(memoryRepository: memRepo);
    });

    Future<void> pumpTimeline(WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<DocumentProvider>.value(value: docProv),
            ChangeNotifierProvider<MemoryProvider>.value(value: memProv),
          ],
          child: const MaterialApp(
            home: TimelineScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('Empty state appears when there are no events', (tester) async {
      await docProv.fetchDocuments();
      await memProv.fetchMemories();
      await pumpTimeline(tester);

      expect(find.text('No timeline events yet.'), findsOneWidget);
      expect(
        find.text('Add memories with dates or documents to build your life timeline.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.history_edu_rounded), findsOneWidget);
    });

    testWidgets('Renders multiple years and event rows correctly', (tester) async {
      docRepo.items.add(
        DocumentItem(
          id: 'd-2024',
          title: 'Car Title',
          subtitle: 'Vehicles',
          category: 'Vehicles',
          issueDate: DateTime(2024, 5, 10),
        ),
      );
      memRepo.items.add(
        MemoryItem(
          id: 'm-2022',
          title: 'Mountain Hike',
          content: 'Reached the summit at dawn.',
          type: 'memory',
          date: DateTime(2022, 8, 24),
          location: 'Colorado',
        ),
      );

      await docProv.fetchDocuments();
      await memProv.fetchMemories();
      await pumpTimeline(tester);

      expect(find.text('2024'), findsOneWidget);
      expect(find.text('2022'), findsOneWidget);
      expect(find.text('Car Title'), findsOneWidget);
      expect(find.text('Mountain Hike'), findsOneWidget);
      expect(find.text('📍 Colorado'), findsOneWidget);
    });

    testWidgets('Tapping memory event opens MemoryDetailsSheet for that exact memory', (tester) async {
      memRepo.items.addAll([
        MemoryItem(
          id: 'mem-paris',
          title: 'Trip to Paris',
          content: 'The sunset over the Seine was unforgettable.',
          type: 'memory',
          date: DateTime(2024, 7, 14),
          location: 'Paris, France',
        ),
        MemoryItem(
          id: 'mem-tokyo',
          title: 'Trip to Tokyo',
          content: 'Cherry blossoms at Ueno Park.',
          type: 'memory',
          date: DateTime(2024, 4, 1),
          location: 'Tokyo, Japan',
        ),
      ]);

      await docProv.fetchDocuments();
      await memProv.fetchMemories();
      await pumpTimeline(tester);

      // Tap the specific memory "Trip to Paris"
      await tester.tap(find.text('Trip to Paris'));
      await tester.pumpAndSettle();

      // Verify that MemoryDetailsSheet opened with the exact memory's details
      expect(find.byType(MemoryDetailsSheet), findsOneWidget);
      expect(find.text('The sunset over the Seine was unforgettable.'), findsOneWidget);
      expect(find.text('Paris, France'), findsOneWidget);

      // Verify that it did NOT merely open the generic Wishes/Memories list
      expect(find.byType(WishesScreen), findsNothing);
    });

    testWidgets('Tapping document event opens DocumentDetailsSheet for that exact document', (tester) async {
      docRepo.items.addAll([
        DocumentItem(
          id: 'doc-passport',
          title: 'US Passport',
          subtitle: 'Identity · Active',
          category: 'Identity',
          documentNumber: 'X12345678',
          issueDate: DateTime(2023, 6, 1),
        ),
        DocumentItem(
          id: 'doc-deed',
          title: 'Property Deed',
          subtitle: 'Legal · Recorded',
          category: 'Legal',
          issueDate: DateTime(2021, 2, 10),
        ),
      ]);

      await docProv.fetchDocuments();
      await memProv.fetchMemories();
      await pumpTimeline(tester);

      // Tap the specific document "US Passport"
      await tester.tap(find.text('US Passport'));
      await tester.pumpAndSettle();

      // Verify that DocumentDetailsSheet opened for the exact document
      expect(find.byType(DocumentDetailsSheet), findsOneWidget);
      expect(find.text('US Passport'), findsWidgets);
      expect(find.text('Identity'), findsWidgets);

      // Verify that it did NOT merely open the generic Documents list
      expect(find.byType(DocumentsScreen), findsNothing);
    });

    testWidgets('Safe lookup when a memory no longer exists in provider shows error', (tester) async {
      final memory = MemoryItem(
        id: 'mem-deleted',
        title: 'Temporary Memory',
        content: 'Soon gone',
        type: 'memory',
        date: DateTime(2024, 3, 1),
      );
      memRepo.items.add(memory);

      await docProv.fetchDocuments();
      await memProv.fetchMemories();
      await pumpTimeline(tester);

      // Delete the memory from repository and provider behind the scenes
      await memProv.deleteMemory('mem-deleted');

      // Tap the memory card in timeline
      await tester.tap(find.text('Temporary Memory'));
      await tester.pumpAndSettle();

      // Details sheet should NOT open; error snackbar is displayed
      expect(find.byType(MemoryDetailsSheet), findsNothing);
      expect(find.text("That memory couldn't be found."), findsOneWidget);
    });

    testWidgets('Safe lookup when a document no longer exists in provider shows error', (tester) async {
      final doc = DocumentItem(
        id: 'doc-deleted',
        title: 'Temporary Doc',
        subtitle: 'Other',
        category: 'Other',
        issueDate: DateTime(2024, 2, 1),
      );
      docRepo.items.add(doc);

      await docProv.fetchDocuments();
      await memProv.fetchMemories();
      await pumpTimeline(tester);

      // Delete the document from repository and provider
      await docProv.deleteDocument('doc-deleted');

      // Tap the document card in timeline
      await tester.tap(find.text('Temporary Doc'));
      await tester.pumpAndSettle();

      // Details sheet should NOT open; error snackbar is displayed
      expect(find.byType(DocumentDetailsSheet), findsNothing);
      expect(find.text("That document couldn't be found."), findsOneWidget);
    });

    testWidgets('Incomplete optional metadata does not crash details sheet', (tester) async {
      // Memory with minimal metadata
      memRepo.items.add(
        MemoryItem(
          id: 'm-sparse',
          title: 'Bare Memory',
          content: 'Just content',
          type: 'memory',
          date: DateTime(2024, 1, 1),
        ),
      );
      // Document with minimal metadata
      docRepo.items.add(
        DocumentItem(
          id: 'd-sparse',
          title: 'Bare Document',
          subtitle: '',
          category: 'Other',
          issueDate: DateTime(2024, 1, 2),
        ),
      );

      await docProv.fetchDocuments();
      await memProv.fetchMemories();
      await pumpTimeline(tester);

      // Tap bare memory
      await tester.tap(find.text('Bare Memory'));
      await tester.pumpAndSettle();
      expect(find.byType(MemoryDetailsSheet), findsOneWidget);

      // Close sheet
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      // Tap bare document
      await tester.tap(find.text('Bare Document'));
      await tester.pumpAndSettle();
      expect(find.byType(DocumentDetailsSheet), findsOneWidget);
    });

    testWidgets('Updated data reflects fresh content upon opening details', (tester) async {
      final memory = MemoryItem(
        id: 'm-edit',
        title: 'Draft Memory',
        content: 'First draft',
        type: 'memory',
        date: DateTime(2024, 5, 5),
      );
      memRepo.items.add(memory);

      await docProv.fetchDocuments();
      await memProv.fetchMemories();
      await pumpTimeline(tester);

      // Update the memory content in provider
      await memProv.updateMemory(
        memory.copyWith(content: 'Polished second draft with more details'),
      );
      await tester.pumpAndSettle();

      // Tap to open
      await tester.tap(find.text('Draft Memory'));
      await tester.pumpAndSettle();

      expect(find.byType(MemoryDetailsSheet), findsOneWidget);
      expect(find.text('Polished second draft with more details'), findsOneWidget);
    });
  });
}
