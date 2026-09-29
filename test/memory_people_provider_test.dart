import 'package:flutter_test/flutter_test.dart';
import 'package:everkeep/models/memory_item.dart';
import 'package:everkeep/models/person_item.dart';
import 'package:everkeep/providers/memory_provider.dart';

import 'fakes.dart';

void main() {
  group('MemoryProvider - People Tagging & Management', () {
    late FakeMemoryRepository memoryRepo;
    late FakePeopleRepository peopleRepo;
    late MemoryProvider provider;

    setUp(() {
      memoryRepo = FakeMemoryRepository([]);
      peopleRepo = FakePeopleRepository([]);
      provider = MemoryProvider(
        memoryRepository: memoryRepo,
        peopleRepository: peopleRepo,
      );
    });

    test('initial state has empty people and no selected person', () {
      expect(provider.allPeople, isEmpty);
      expect(provider.selectedPerson, isNull);
    });

    test('fetchPeople populates allPeople list alphabetically or by insertion', () async {
      peopleRepo.people.addAll([
        PersonItem(id: 'p1', userId: 'user-001', name: 'Bob'),
        PersonItem(id: 'p2', userId: 'user-001', name: 'Alice'),
      ]);

      await provider.fetchPeople();

      expect(provider.allPeople.length, 2);
      expect(provider.allPeople.map((p) => p.name).toList(), ['Alice', 'Bob']);
    });

    test('createPerson adds a new person and updates allPeople', () async {
      final created = await provider.createPerson('Charlie Brown');

      expect(created, isNotNull);
      expect(created!.name, 'Charlie Brown');
      expect(provider.allPeople.length, 1);
      expect(provider.allPeople.first.name, 'Charlie Brown');
    });

    test('createPerson rejects empty or whitespace name', () async {
      final res1 = await provider.createPerson('');
      expect(res1, isNull);
      expect(provider.error, 'Person name cannot be empty.');

      final res2 = await provider.createPerson('    ');
      expect(res2, isNull);
      expect(provider.error, 'Person name cannot be empty.');
      expect(provider.allPeople, isEmpty);
    });

    test('createPerson returns existing person on duplicate name case-insensitively', () async {
      final p1 = await provider.createPerson('Alice');
      expect(provider.allPeople.length, 1);

      final p2 = await provider.createPerson('  alice  ');
      expect(p2, isNotNull);
      expect(p2!.id, p1!.id);
      expect(provider.allPeople.length, 1);
    });

    test('updatePerson renames person and refreshes memory items', () async {
      final person = await provider.createPerson('David');
      expect(person, isNotNull);

      // Seed a memory containing David
      final success = await provider.createMemory(
        MemoryItem(
          id: 'm1',
          title: 'Concert with David',
          content: 'Music festival',
          type: 'memory',
          people: [person!],
        ),
      );
      expect(success, isTrue);
      expect(provider.memories.first.people.first.name, 'David');

      // Update name to David Bowie
      final updated = await provider.updatePerson(person.id, 'David Bowie');
      expect(updated, isNotNull);
      expect(updated!.name, 'David Bowie');
      expect(provider.allPeople.first.name, 'David Bowie');

      // In-memory memory items should reflect updated person's name
      final updatedMem = provider.memories.firstWhere((m) => m.id == 'm1');
      expect(updatedMem.people.first.name, 'David Bowie');
    });

    test('deletePerson removes person from allPeople and attached memories', () async {
      final p1 = await provider.createPerson('Alice');
      final p2 = await provider.createPerson('Bob');

      await provider.createMemory(
        MemoryItem(
          id: 'm2',
          title: 'Lunch',
          content: 'Sandwiches',
          type: 'memory',
          people: [p1!, p2!],
        ),
      );

      expect(provider.memories.first.people.length, 2);

      await provider.deletePerson(p1.id);

      expect(provider.allPeople.any((p) => p.id == p1.id), isFalse);
      expect(provider.memories.first.people.length, 1);
      expect(provider.memories.first.people.first.name, 'Bob');
    });

    test('filtering memories by selected person', () async {
      final alice = await provider.createPerson('Alice');
      final bob = await provider.createPerson('Bob');

      await provider.createMemory(
        MemoryItem(
          id: 'm-alice',
          title: 'Coffee with Alice',
          content: 'Espresso',
          type: 'memory',
          people: [alice!],
        ),
      );

      await provider.createMemory(
        MemoryItem(
          id: 'm-bob',
          title: 'Gym with Bob',
          content: 'Work out',
          type: 'memory',
          people: [bob!],
        ),
      );

      await provider.createMemory(
        MemoryItem(
          id: 'm-both',
          title: 'Movie night',
          content: 'Watched sci-fi',
          type: 'memory',
          people: [alice, bob],
        ),
      );

      // Initially no filter
      expect(provider.getFilteredMemories().length, 3);

      // Filter by Alice
      provider.setSelectedPerson(alice);
      expect(provider.selectedPerson?.id, alice.id);
      expect(provider.selectedPerson?.name, 'Alice');

      final aliceMemories = provider.getFilteredMemories();
      expect(aliceMemories.length, 2);
      expect(aliceMemories.any((m) => m.id == 'm-alice'), isTrue);
      expect(aliceMemories.any((m) => m.id == 'm-both'), isTrue);
      expect(aliceMemories.any((m) => m.id == 'm-bob'), isFalse);

      // Filter by Bob
      provider.setSelectedPerson(bob);
      final bobMemories = provider.getFilteredMemories();
      expect(bobMemories.length, 2);
      expect(bobMemories.any((m) => m.id == 'm-bob'), isTrue);
      expect(bobMemories.any((m) => m.id == 'm-both'), isTrue);
      expect(bobMemories.any((m) => m.id == 'm-alice'), isFalse);

      // Clear filter
      provider.clearPersonFilter();
      expect(provider.selectedPerson, isNull);
      expect(provider.getFilteredMemories().length, 3);
    });

    test('attaching and removing people during memory updates', () async {
      final p1 = await provider.createPerson('Emma');
      final p2 = await provider.createPerson('Frank');

      // Create memory with Emma
      final initialItem = MemoryItem(
        id: 'm-dyn',
        title: 'Graduation',
        content: 'Caps and gowns',
        type: 'memory',
        people: [p1!],
      );
      final createdOk = await provider.createMemory(initialItem);
      expect(createdOk, isTrue);

      final created = provider.memories.firstWhere((m) => m.id == 'm-dyn');
      expect(created.people.length, 1);
      expect(created.people.first.name, 'Emma');

      // Update to attach Frank as well
      final withBoth = created.copyWith(people: [p1, p2!]);
      final updateBothOk = await provider.updateMemory(withBoth);
      expect(updateBothOk, isTrue);

      var current = provider.memories.firstWhere((m) => m.id == 'm-dyn');
      expect(current.people.length, 2);
      expect(current.hasPerson(p1.id), isTrue);
      expect(current.hasPerson(p2.id), isTrue);

      // Update to remove Emma
      final onlyFrank = current.copyWith(people: [p2]);
      final updateFrankOk = await provider.updateMemory(onlyFrank);
      expect(updateFrankOk, isTrue);

      current = provider.memories.firstWhere((m) => m.id == 'm-dyn');
      expect(current.people.length, 1);
      expect(current.hasPerson(p1.id), isFalse);
      expect(current.hasPerson(p2.id), isTrue);
    });

    test('reset clears people and selected filter', () async {
      final person = await provider.createPerson('Grace');
      provider.setSelectedPerson(person);

      expect(provider.allPeople.isNotEmpty, isTrue);
      expect(provider.selectedPerson, isNotNull);

      provider.reset();

      expect(provider.allPeople, isEmpty);
      expect(provider.selectedPerson, isNull);
    });
  });
}
