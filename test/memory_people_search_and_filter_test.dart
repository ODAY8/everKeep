import 'package:flutter_test/flutter_test.dart';
import 'package:everkeep/core/utils/search_helper.dart';
import 'package:everkeep/models/memory_item.dart';
import 'package:everkeep/models/person_item.dart';
import 'package:everkeep/providers/memory_provider.dart';

import 'fakes.dart';

void main() {
  group('SearchMatcher — Memory People Search', () {
    final personAlice = PersonItem(
      id: 'p-1',
      userId: 'u-1',
      name: 'Alice Johnson',
    );
    final personBob = PersonItem(
      id: 'p-2',
      userId: 'u-1',
      name: 'Bob Dylan',
    );

    final memoryWithAlice = MemoryItem(
      id: 'm1',
      title: 'Coffee in Seattle',
      content: 'Met at the roastery',
      type: 'memory',
      location: 'Seattle, WA',
      tags: 'travel, coffee',
      people: [personAlice],
    );

    final memoryWithBoth = MemoryItem(
      id: 'm2',
      title: 'Studio Session',
      content: 'Recording acoustic guitars',
      type: 'memory',
      location: 'Nashville, TN',
      tags: 'music, studio',
      people: [personAlice, personBob],
    );

    final memoryNoPeople = MemoryItem(
      id: 'm3',
      title: 'Solo Hike',
      content: 'Walked the mountain trail alone',
      type: 'memory',
      location: 'Mount Rainier',
      tags: 'nature, hiking',
      people: [],
    );

    test('matches memory by tagged person name case-insensitively', () {
      expect(SearchMatcher.matchesMemory(memoryWithAlice, query: 'alice'), isTrue);
      expect(SearchMatcher.matchesMemory(memoryWithAlice, query: 'ALICE'), isTrue);
      expect(SearchMatcher.matchesMemory(memoryWithAlice, query: 'Johnson'), isTrue);
      expect(SearchMatcher.matchesMemory(memoryWithAlice, query: 'johnson'), isTrue);
    });

    test('matches memory with multiple people by either person name', () {
      expect(SearchMatcher.matchesMemory(memoryWithBoth, query: 'alice'), isTrue);
      expect(SearchMatcher.matchesMemory(memoryWithBoth, query: 'dylan'), isTrue);
      expect(SearchMatcher.matchesMemory(memoryWithBoth, query: 'bob'), isTrue);
    });

    test('does not match memory when person name is not tagged', () {
      expect(SearchMatcher.matchesMemory(memoryNoPeople, query: 'alice'), isFalse);
      expect(SearchMatcher.matchesMemory(memoryNoPeople, query: 'bob'), isFalse);
    });

    test('supports multi-token searches combining title and person name', () {
      // "Seattle Alice" matches memoryWithAlice
      expect(SearchMatcher.matchesMemory(memoryWithAlice, query: 'Seattle Alice'), isTrue);
      // "Studio Dylan" matches memoryWithBoth
      expect(SearchMatcher.matchesMemory(memoryWithBoth, query: 'Studio Dylan'), isTrue);
      // "Seattle Dylan" does not match memoryWithAlice because Dylan is not present
      expect(SearchMatcher.matchesMemory(memoryWithAlice, query: 'Seattle Dylan'), isFalse);
    });

    test('handles empty or blank search queries safely', () {
      expect(SearchMatcher.matchesMemory(memoryWithAlice, query: ''), isTrue);
      expect(SearchMatcher.matchesMemory(memoryWithAlice, query: '   '), isTrue);
    });
  });

  group('MemoryProvider Search and Filtering Integration', () {
    late FakeMemoryRepository memoryRepo;
    late FakePeopleRepository peopleRepo;
    late MemoryProvider provider;

    setUp(() async {
      memoryRepo = FakeMemoryRepository([]);
      peopleRepo = FakePeopleRepository([]);
      provider = MemoryProvider(
        memoryRepository: memoryRepo,
        peopleRepository: peopleRepo,
      );

      final pAlice = await provider.createPerson('Alice');
      final pBob = await provider.createPerson('Bob');
      final pCharlie = await provider.createPerson('Charlie');

      await provider.createMemory(
        MemoryItem(
          id: 'mem-1',
          title: 'Birthday Dinner',
          content: 'Surprise party at Italian restaurant',
          type: 'memory',
          tags: 'food, celebration',
          people: [pAlice!, pCharlie!],
        ),
      );

      await provider.createMemory(
        MemoryItem(
          id: 'mem-2',
          title: 'Road Trip',
          content: 'Driving down Route 66',
          type: 'memory',
          tags: 'roadtrip, summer',
          people: [pBob!],
        ),
      );

      await provider.createMemory(
        MemoryItem(
          id: 'wish-1',
          title: 'Visit Japan with Alice',
          content: 'See cherry blossoms in Tokyo',
          type: 'wish',
          tags: 'japan, travel',
          people: [pAlice],
        ),
      );
    });

    test('search query filters memories matching person name', () {
      final results = provider.getFilteredMemories(query: 'Alice');
      expect(results.length, 1);
      expect(results.first.id, 'mem-1');

      final wishResults = provider.getFilteredMemories(query: 'Alice', type: 'wish');
      expect(wishResults.length, 1);
      expect(wishResults.first.id, 'wish-1');
    });

    test('combines search query with tag filter', () {
      final results = provider.getFilteredMemories(query: 'Alice', tag: 'celebration');
      expect(results.length, 1);
      expect(results.first.id, 'mem-1');

      final noResults = provider.getFilteredMemories(query: 'Alice', tag: 'roadtrip');
      expect(noResults, isEmpty);
    });

    test('combines person filter with free-text search query', () {
      final alice = provider.allPeople.firstWhere((p) => p.name == 'Alice');
      provider.setSelectedPerson(alice);

      final results = provider.getFilteredMemories(query: 'cherry', type: 'wish');
      expect(results.length, 1);
      expect(results.first.id, 'wish-1');

      final noResults = provider.getFilteredMemories(query: 'Route', type: 'memory');
      expect(noResults, isEmpty);
    });

    test('clearing person filter restores memory list', () {
      final bob = provider.allPeople.firstWhere((p) => p.name == 'Bob');
      provider.setSelectedPerson(bob);
      expect(provider.getFilteredMemories().length, 1);

      provider.clearPersonFilter();
      expect(provider.getFilteredMemories().length, 2);
    });
  });
}
