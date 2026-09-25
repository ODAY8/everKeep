import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:everkeep/features/wishes/presentation/screens/wishes_screen.dart';
import 'package:everkeep/features/wishes/presentation/widgets/memory_card.dart';
import 'package:everkeep/features/wishes/presentation/widgets/memory_details_sheet.dart';
import 'package:everkeep/features/wishes/presentation/widgets/memory_form_sheet.dart';
import 'package:everkeep/models/memory_item.dart';
import 'package:everkeep/providers/memory_provider.dart';
import 'package:everkeep/widgets/glass/glass_primary_button.dart';
import 'package:everkeep/widgets/glass/glass_search_bar.dart';

import 'fakes.dart';

void main() {
  group('MemoryItem Model & Serialization', () {
    test('parses row with user_id, date, tags, and location', () {
      final row = {
        'id': 'mem-101',
        'user_id': 'usr-abc-123',
        'title': 'Trip to Kyoto',
        'content': 'We visited the bamboo grove in Arashiyama and it was peaceful.',
        'type': 'memory',
        'date': '2024-04-12',
        'location': 'Kyoto, Japan',
        'tags': 'Travel, Family, Spring',
        'file_path': 'usr-abc-123/memories/photo.jpg',
        'file_size': 1024000,
        'mime_type': 'image/jpeg',
        'created_at': '2024-04-15T10:00:00Z',
        'updated_at': '2024-04-15T12:00:00Z',
      };

      final item = MemoryItem.fromRow(row);

      expect(item.id, 'mem-101');
      expect(item.userId, 'usr-abc-123');
      expect(item.title, 'Trip to Kyoto');
      expect(item.story, 'We visited the bamboo grove in Arashiyama and it was peaceful.');
      expect(item.type, 'memory');
      expect(item.isMemory, isTrue);
      expect(item.isWish, isFalse);
      expect(item.date, DateTime.parse('2024-04-12'));
      expect(item.formattedDate, 'Apr 12, 2024');
      expect(item.location, 'Kyoto, Japan');
      expect(item.tags, 'Travel, Family, Spring');
      expect(item.tagList, ['Travel', 'Family', 'Spring']);
      expect(item.hasTag('travel'), isTrue);
      expect(item.hasTag('Family'), isTrue);
      expect(item.hasTag('Work'), isFalse);
      expect(item.hasAttachment, isTrue);
      expect(item.isPhotoAttachment, isTrue);
      expect(item.timelineDate, item.date);
    });

    test('toInsertRow includes user_id when provided, trims strings', () {
      final item = MemoryItem(
        id: '',
        userId: 'user-77',
        title: '  Graduation Day  ',
        content: '  Walking across the stage.  ',
        type: 'memory',
        date: DateTime(2023, 6, 15),
        location: ' Boston ',
        tags: ' University, Milestone ',
      );

      final row = item.toInsertRow();

      expect(row['user_id'], 'user-77');
      expect(row['title'], 'Graduation Day');
      expect(row['content'], 'Walking across the stage.');
      expect(row['type'], 'memory');
      expect(row['date'], '2023-06-15');
      expect(row['location'], 'Boston');
      expect(row['tags'], 'University, Milestone');
    });

    test('matchesQuery checks title, content, location, tags, date, and year', () {
      final item = MemoryItem(
        id: '1',
        title: 'Mountain Hike',
        content: 'Reaching the summit at sunrise',
        date: DateTime(2025, 9, 12),
        location: 'Rocky Mountains',
        tags: 'Adventure, Nature',
      );

      expect(item.matchesQuery('mountain'), isTrue);
      expect(item.matchesQuery('summit'), isTrue);
      expect(item.matchesQuery('rocky'), isTrue);
      expect(item.matchesQuery('nature'), isTrue);
      expect(item.matchesQuery('2025'), isTrue);
      expect(item.matchesQuery('september'), isTrue);
      expect(item.matchesQuery('beach'), isFalse);
    });

    test('shortStoryPreview limits long content to 110 characters', () {
      const shortText = 'Quick moment.';
      final shortItem = MemoryItem(id: '1', title: 't', content: shortText);
      expect(shortItem.shortStoryPreview, shortText);

      final longText = 'A' * 200;
      final longItem = MemoryItem(id: '2', title: 't', content: longText);
      expect(longItem.shortStoryPreview.length, 110);
      expect(longItem.shortStoryPreview.endsWith('...'), isTrue);
    });

    test('copyWith updates fields selectively', () {
      final original = MemoryItem(
        id: '1',
        userId: 'u1',
        title: 'Original Title',
        content: 'Original Content',
        location: 'Original Location',
        tags: 'Tag1',
      );

      final modified = original.copyWith(
        title: 'New Title',
        tags: 'Tag1, Tag2',
      );

      expect(modified.id, '1');
      expect(modified.userId, 'u1');
      expect(modified.title, 'New Title');
      expect(modified.content, 'Original Content');
      expect(modified.location, 'Original Location');
      expect(modified.tags, 'Tag1, Tag2');
    });
  });

  group('MemoryProvider Search, Filtering & Sorting', () {
    late FakeMemoryRepository repo;
    late MemoryProvider provider;

    setUp(() {
      repo = FakeMemoryRepository([
        MemoryItem(
          id: 'm1',
          title: 'Trip to Rome',
          content: 'Walking around the Colosseum in the morning.',
          type: 'memory',
          date: DateTime(2022, 5, 10),
          location: 'Rome, Italy',
          tags: 'Travel, Europe',
          createdAt: DateTime(2024, 1, 1),
        ),
        MemoryItem(
          id: 'm2',
          title: 'Childhood Home',
          content: 'The maple tree in the front yard.',
          type: 'memory',
          date: DateTime(2010, 8, 20),
          location: 'Seattle',
          tags: 'Family, Childhood',
          createdAt: DateTime(2024, 2, 1),
        ),
        MemoryItem(
          id: 'm3',
          title: 'New Year Celebration',
          content: 'Counting down with close friends.',
          type: 'memory',
          date: DateTime(2024, 1, 1),
          tags: 'Friends, Milestone',
          createdAt: DateTime(2024, 1, 2),
        ),
        MemoryItem(
          id: 'w1',
          title: 'Letter to Future Self',
          content: 'Remember to stay curious.',
          type: 'wish',
          createdAt: DateTime(2024, 3, 1),
        ),
      ]);
      provider = MemoryProvider(memoryRepository: repo);
    });

    test('allMemoryTags extracts unique, sorted tags across memories', () async {
      await provider.fetchMemories();

      final tags = provider.allMemoryTags;
      expect(tags, containsAll(['Childhood', 'Europe', 'Family', 'Friends', 'Milestone', 'Travel']));
    });

    test('getFilteredMemories filters by query matching title or location', () async {
      await provider.fetchMemories();

      final results = provider.getFilteredMemories(query: 'Rome');
      expect(results.length, 1);
      expect(results.first.title, 'Trip to Rome');

      final seattleResults = provider.getFilteredMemories(query: 'Seattle');
      expect(seattleResults.length, 1);
      expect(seattleResults.first.title, 'Childhood Home');
    });

    test('getFilteredMemories filters by specific tag', () async {
      await provider.fetchMemories();

      final travelMemories = provider.getFilteredMemories(tag: 'Travel');
      expect(travelMemories.length, 1);
      expect(travelMemories.first.title, 'Trip to Rome');

      final familyMemories = provider.getFilteredMemories(tag: 'Family');
      expect(familyMemories.length, 1);
      expect(familyMemories.first.title, 'Childhood Home');
    });

    test('getFilteredMemories sorts by memory date descending and ascending', () async {
      await provider.fetchMemories();

      final desc = provider.getFilteredMemories(sort: MemorySortOption.memoryDateDesc);
      expect(desc.first.title, 'New Year Celebration'); // 2024
      expect(desc.last.title, 'Childhood Home'); // 2010

      final asc = provider.getFilteredMemories(sort: MemorySortOption.memoryDateAsc);
      expect(asc.first.title, 'Childhood Home'); // 2010
      expect(asc.last.title, 'New Year Celebration'); // 2024
    });

    test('getFilteredMemories sorts alphabetically by title', () async {
      await provider.fetchMemories();

      final alphabetical = provider.getFilteredMemories(sort: MemorySortOption.titleAsc);
      expect(alphabetical.first.title, 'Childhood Home');
      expect(alphabetical[1].title, 'New Year Celebration');
      expect(alphabetical[2].title, 'Trip to Rome');
    });
  });

  group('MemoryCard Widget', () {
    testWidgets('renders title, formatted date, location, and tags', (tester) async {
      final item = MemoryItem(
        id: '1',
        title: 'Graduation Day',
        content: 'Exciting milestone celebration.',
        date: DateTime(2023, 6, 12),
        location: 'Boston',
        tags: 'University, Family',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MemoryCard(
              item: item,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Graduation Day'), findsOneWidget);
      expect(find.text('“Exciting milestone celebration.”'), findsOneWidget);
      expect(find.text('Jun 12, 2023'), findsOneWidget);
      expect(find.text('Boston'), findsOneWidget);
      expect(find.text('#University'), findsOneWidget);
      expect(find.text('#Family'), findsOneWidget);
    });

    testWidgets('shows photo badge when item has a photo attachment', (tester) async {
      final item = MemoryItem(
        id: '1',
        title: 'Photo memory',
        content: 'A snapshot.',
        filePath: 'user/memories/pic.jpg',
        mimeType: 'image/jpeg',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MemoryCard(
              item: item,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Photo'), findsOneWidget);
    });
  });

  group('MemoryDetailsSheet Widget', () {
    testWidgets('renders full title, content, tags, and action buttons', (tester) async {
      bool editCalled = false;
      bool deleteCalled = false;

      final item = MemoryItem(
        id: '1',
        title: 'A Beautiful Evening',
        content: 'The sunset over the hills was unforgettable.',
        date: DateTime(2024, 7, 4),
        location: 'California Coast',
        tags: 'Sunset, Summer',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MemoryDetailsSheet(
              item: item,
              onEdit: () => editCalled = true,
              onDelete: () => deleteCalled = true,
            ),
          ),
        ),
      );

      expect(find.text('A Beautiful Evening'), findsOneWidget);
      expect(find.text('The sunset over the hills was unforgettable.'), findsOneWidget);
      expect(find.text('Jul 4, 2024'), findsOneWidget);
      expect(find.text('California Coast'), findsOneWidget);
      expect(find.text('#Sunset'), findsOneWidget);
      expect(find.text('#Summer'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      expect(editCalled, isTrue);

      await tester.tap(find.byIcon(Icons.delete_outline_rounded).first);
      expect(deleteCalled, isTrue);
    });
  });

  group('MemoryFormSheet Widget', () {
    testWidgets('validates required title and creates new memory', (tester) async {
      final repo = FakeMemoryRepository([]);
      final provider = MemoryProvider(memoryRepository: repo);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<MemoryProvider>.value(
            value: provider,
            child: const Scaffold(
              body: MemoryFormSheet(initialType: 'memory'),
            ),
          ),
        ),
      );

      expect(find.text('Add Memory'), findsOneWidget);

      // Tap Save with empty title
      await tester.ensureVisible(find.widgetWithText(GlassPrimaryButton, 'Save'));
      await tester.tap(find.widgetWithText(GlassPrimaryButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Title is required'), findsOneWidget);
      expect(repo.items, isEmpty);

      // Enter valid title and content
      await tester.enterText(find.byType(TextFormField).first, 'Camping Trip');
      await tester.ensureVisible(find.widgetWithText(GlassPrimaryButton, 'Save'));
      await tester.tap(find.widgetWithText(GlassPrimaryButton, 'Save'));
      await tester.pumpAndSettle();

      expect(repo.items.length, 1);
      expect(repo.items.first.title, 'Camping Trip');
    });

    testWidgets('initializes fields in edit mode and updates memory', (tester) async {
      final initialItem = MemoryItem(
        id: 'm1',
        title: 'Original Title',
        content: 'Original Story',
        location: 'Denver',
        tags: 'Hike',
      );
      final repo = FakeMemoryRepository([initialItem]);
      final provider = MemoryProvider(memoryRepository: repo);
      await provider.fetchMemories();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<MemoryProvider>.value(
            value: provider,
            child: Scaffold(
              body: MemoryFormSheet(initialItem: initialItem),
            ),
          ),
        ),
      );

      expect(find.text('Edit Memory'), findsOneWidget);
      expect(find.text('Original Title'), findsOneWidget);
      expect(find.text('Original Story'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, 'Updated Title');
      await tester.ensureVisible(find.widgetWithText(GlassPrimaryButton, 'Save Changes'));
      await tester.tap(find.widgetWithText(GlassPrimaryButton, 'Save Changes'));
      await tester.pumpAndSettle();

      expect(repo.items.first.title, 'Updated Title');
    });
  });

  group('WishesScreen Search and Filter Integration', () {
    testWidgets('search filters memories in real-time and clearing restores list', (tester) async {
      final repo = FakeMemoryRepository([
        MemoryItem(
          id: 'm1',
          title: 'Trip to Rome',
          content: 'Colosseum visit',
          type: 'memory',
        ),
        MemoryItem(
          id: 'm2',
          title: 'Trip to Tokyo',
          content: 'Shibuya crossing',
          type: 'memory',
        ),
      ]);
      final provider = MemoryProvider(memoryRepository: repo);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<MemoryProvider>.value(
            value: provider,
            child: const WishesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Trip to Rome'), findsOneWidget);
      expect(find.text('Trip to Tokyo'), findsOneWidget);

      // Open search bar
      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(GlassSearchBar), findsOneWidget);

      // Type "Rome"
      await tester.enterText(find.descendant(of: find.byType(GlassSearchBar), matching: find.byType(TextField)), 'Rome');
      await tester.pumpAndSettle();

      expect(find.text('Trip to Rome'), findsOneWidget);
      expect(find.text('Trip to Tokyo'), findsNothing);

      // Close search
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Trip to Rome'), findsOneWidget);
      expect(find.text('Trip to Tokyo'), findsOneWidget);
    });

    testWidgets('shows search empty state when no items match query', (tester) async {
      final repo = FakeMemoryRepository([
        MemoryItem(
          id: 'm1',
          title: 'Trip to Rome',
          content: 'Colosseum visit',
          type: 'memory',
        ),
      ]);
      final provider = MemoryProvider(memoryRepository: repo);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<MemoryProvider>.value(
            value: provider,
            child: const WishesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();

      await tester.enterText(find.descendant(of: find.byType(GlassSearchBar), matching: find.byType(TextField)), 'Nonexistent');
      await tester.pumpAndSettle();

      expect(find.text('No memories found'), findsOneWidget);
      expect(find.text('Clear search & filter'), findsOneWidget);
    });
  });
}
