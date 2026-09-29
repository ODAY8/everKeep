import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:everkeep/models/memory_item.dart';
import 'package:everkeep/models/person_item.dart';
import 'package:everkeep/providers/memory_provider.dart';
import 'package:everkeep/features/wishes/presentation/widgets/memory_card.dart';
import 'package:everkeep/features/wishes/presentation/widgets/memory_details_sheet.dart';
import 'package:everkeep/features/wishes/presentation/widgets/people_selector_sheet.dart';
import 'package:everkeep/features/wishes/presentation/widgets/memory_form_sheet.dart';

import 'fakes.dart';

void main() {
  Widget buildWrapper({
    required Widget child,
    required MemoryProvider memoryProvider,
  }) {
    return ChangeNotifierProvider<MemoryProvider>.value(
      value: memoryProvider,
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  group('MemoryCard People Display', () {
    testWidgets('displays tagged people chips when memory has people', (tester) async {
      final person1 = PersonItem(id: 'p1', userId: 'u1', name: 'Alice');
      final person2 = PersonItem(id: 'p2', userId: 'u1', name: 'Bob');

      final item = MemoryItem(
        id: 'mem-1',
        title: 'Beach Trip',
        content: 'Sunny afternoon by the ocean',
        type: 'memory',
        people: [person1, person2],
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

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
    });

    testWidgets('does not display people badge when people is empty', (tester) async {
      final item = MemoryItem(
        id: 'mem-2',
        title: 'Solo Trip',
        content: 'Quiet afternoon',
        type: 'memory',
        people: [],
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

      expect(find.byIcon(Icons.person_outline_rounded), findsNothing);
    });
  });

  group('MemoryDetailsSheet People Display', () {
    late MemoryProvider memProv;

    setUp(() {
      memProv = MemoryProvider(
        memoryRepository: FakeMemoryRepository([]),
        peopleRepository: FakePeopleRepository([]),
      );
    });

    testWidgets('renders PEOPLE section with chips when people are tagged', (tester) async {
      final person1 = PersonItem(id: 'p1', userId: 'u1', name: 'Charlie');
      final item = MemoryItem(
        id: 'mem-3',
        title: 'Cabin Weekend',
        content: 'Hot cocoa by the fire',
        type: 'memory',
        people: [person1],
      );

      await tester.pumpWidget(
        buildWrapper(
          memoryProvider: memProv,
          child: MemoryDetailsSheet(
            item: item,
            onEdit: () {},
          ),
        ),
      );

      expect(find.text('PEOPLE'), findsOneWidget);
      expect(find.text('Charlie'), findsOneWidget);
    });

    testWidgets('omits PEOPLE section when no people are tagged', (tester) async {
      final item = MemoryItem(
        id: 'mem-4',
        title: 'Stargazing',
        content: 'Clear skies',
        type: 'memory',
        people: [],
      );

      await tester.pumpWidget(
        buildWrapper(
          memoryProvider: memProv,
          child: MemoryDetailsSheet(
            item: item,
            onEdit: () {},
          ),
        ),
      );

      expect(find.text('PEOPLE'), findsNothing);
    });
  });

  group('PeopleSelectorSheet UI & Selection', () {
    late FakePeopleRepository peopleRepo;
    late MemoryProvider memProv;

    setUp(() {
      peopleRepo = FakePeopleRepository([
        PersonItem(id: 'p1', userId: 'u1', name: 'Alice Smith'),
        PersonItem(id: 'p2', userId: 'u1', name: 'Bob Jones'),
      ]);
      memProv = MemoryProvider(
        memoryRepository: FakeMemoryRepository([]),
        peopleRepository: peopleRepo,
      );
    });

    testWidgets('shows existing people and allows selection', (tester) async {
      await memProv.fetchPeople();

      await tester.pumpWidget(
        buildWrapper(
          memoryProvider: memProv,
          child: const PeopleSelectorSheet(
            initiallySelected: [],
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Tag People'), findsOneWidget);
      expect(find.text('Alice Smith'), findsOneWidget);
      expect(find.text('Bob Jones'), findsOneWidget);

      // Tap Alice to select
      await tester.tap(find.text('Alice Smith'));
      await tester.pumpAndSettle();

      // Check that "Done" button exists
      expect(find.byKey(const ValueKey('people_done_button')), findsOneWidget);
    });

    testWidgets('shows Add Person button when search query has no match', (tester) async {
      await memProv.fetchPeople();

      await tester.pumpWidget(
        buildWrapper(
          memoryProvider: memProv,
          child: const PeopleSelectorSheet(
            initiallySelected: [],
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter a new name in search
      await tester.enterText(find.byType(TextField).first, 'Daniel Craig');
      await tester.pumpAndSettle();

      // Person list shouldn't show Alice or Bob
      expect(find.text('Alice Smith'), findsNothing);
      expect(find.text('Bob Jones'), findsNothing);

      // "Add Daniel Craig" button should be visible
      expect(find.text('Add "Daniel Craig"'), findsOneWidget);
    });
  });

  group('MemoryFormSheet People Section', () {
    late MemoryProvider memProv;

    setUp(() {
      memProv = MemoryProvider(
        memoryRepository: FakeMemoryRepository([]),
        peopleRepository: FakePeopleRepository([]),
      );
    });

    testWidgets('shows PEOPLE section with Tag People button in form', (tester) async {
      await tester.pumpWidget(
        buildWrapper(
          memoryProvider: memProv,
          child: const MemoryFormSheet(
            initialType: 'memory',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('PEOPLE'), findsOneWidget);
      expect(find.text('Tag People'), findsOneWidget);
    });
  });
}
