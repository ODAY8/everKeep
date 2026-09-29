import 'package:flutter_test/flutter_test.dart';
import 'package:everkeep/models/person_item.dart';
import 'package:everkeep/models/memory_item.dart';

void main() {
  group('PersonItem Model & Validation', () {
    test('validates empty and whitespace-only names', () {
      expect(PersonItem.validateName(null), 'Please enter a name.');
      expect(PersonItem.validateName(''), 'Please enter a name.');
      expect(PersonItem.validateName('   '), 'Please enter a name.');
      expect(PersonItem.validateName('\t\n'), 'Please enter a name.');
    });

    test('validates maximum length limit of 100 characters', () {
      final exactly100 = 'A' * 100;
      expect(PersonItem.validateName(exactly100), isNull);

      final over100 = 'A' * 101;
      expect(
        PersonItem.validateName(over100),
        'Name must be 100 characters or fewer.',
      );
    });

    test('accepts valid person names', () {
      expect(PersonItem.validateName('Alice Smith'), isNull);
      expect(PersonItem.validateName('Grandpa Joe'), isNull);
      expect(PersonItem.validateName('Dr. John Doe Jr.'), isNull);
    });

    test('sanitizes person names properly', () {
      expect(PersonItem.sanitizeName('   Alice   Smith   '), 'Alice Smith');
      expect(PersonItem.sanitizeName('Bob\t\tJones'), 'Bob Jones');
      expect(PersonItem.sanitizeName(''), '');
    });

    test('maps from database row correctly', () {
      final now = DateTime.now();
      final row = {
        'id': 'person-123',
        'user_id': 'user-001',
        'name': 'Sarah Connor',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final person = PersonItem.fromRow(row);
      expect(person.id, 'person-123');
      expect(person.userId, 'user-001');
      expect(person.name, 'Sarah Connor');
      expect(person.createdAt?.isUtc, isFalse); // parsed to local
      expect(person.updatedAt?.isUtc, isFalse);
    });

    test('serializes to JSON correctly', () {
      final person = PersonItem(
        id: 'person-99',
        userId: 'user-01',
        name: 'John Connor',
        createdAt: DateTime.parse('2026-01-01T10:00:00Z'),
        updatedAt: DateTime.parse('2026-01-02T12:00:00Z'),
      );

      final json = person.toJson();
      expect(json['id'], 'person-99');
      expect(json['user_id'], 'user-01');
      expect(json['name'], 'John Connor');
      expect(json['created_at'], '2026-01-01T10:00:00.000Z');
      expect(json['updated_at'], '2026-01-02T12:00:00.000Z');
    });

    test('implements equality, hashCode, and copyWith', () {
      final p1 = PersonItem(
        id: 'p1',
        userId: 'u1',
        name: 'Alice',
      );
      final p2 = PersonItem(
        id: 'p1',
        userId: 'u1',
        name: 'Alice',
      );
      final p3 = PersonItem(
        id: 'p2',
        userId: 'u1',
        name: 'Bob',
      );

      expect(p1, equals(p2));
      expect(p1.hashCode, equals(p2.hashCode));
      expect(p1, isNot(equals(p3)));

      final updated = p1.copyWith(name: 'Alice Cooper');
      expect(updated.id, 'p1');
      expect(updated.name, 'Alice Cooper');
    });
  });

  group('MemoryItem People Integration', () {
    test('defaults to empty people list and empty peopleNames', () {
      final memory = MemoryItem(
        id: 'mem-1',
        title: 'Trip to Paris',
        content: 'Saw the Eiffel tower.',
        type: 'memory',
      );

      expect(memory.people, isEmpty);
      expect(memory.peopleNames, isEmpty);
      expect(memory.hasPerson('person-1'), isFalse);
    });

    test('extracts peopleNames and checks hasPerson correctly', () {
      final p1 = PersonItem(id: 'p1', userId: 'u1', name: 'Alice');
      final p2 = PersonItem(id: 'p2', userId: 'u1', name: 'Bob');

      final memory = MemoryItem(
        id: 'mem-2',
        title: 'Family Dinner',
        content: 'Great food',
        type: 'memory',
        people: [p1, p2],
      );

      expect(memory.people.length, 2);
      expect(memory.peopleNames, ['Alice', 'Bob']);
      expect(memory.hasPerson('p1'), isTrue);
      expect(memory.hasPerson('p2'), isTrue);
      expect(memory.hasPerson('p3'), isFalse);
    });

    test('parses from database row with joined memory_people relation', () {
      final row = {
        'id': 'mem-db-1',
        'title': 'Birthday Party',
        'content': 'Turned 30!',
        'type': 'memory',
        'created_at': DateTime.now().toIso8601String(),
        'memory_people': [
          {
            'person_id': 'p-10',
            'people': {
              'id': 'p-10',
              'user_id': 'u-1',
              'name': 'Charlie',
              'created_at': '2026-01-01T00:00:00Z',
            },
          },
          {
            'person_id': 'p-20',
            'people': {
              'id': 'p-20',
              'user_id': 'u-1',
              'name': 'Diana',
              'created_at': '2026-01-01T00:00:00Z',
            },
          },
        ],
      };

      final memory = MemoryItem.fromRow(row);
      expect(memory.people.length, 2);
      expect(memory.people[0].name, 'Charlie');
      expect(memory.people[1].name, 'Diana');
      expect(memory.hasPerson('p-10'), isTrue);
      expect(memory.hasPerson('p-20'), isTrue);
    });

    test('parses from database row with direct people array fallback', () {
      final row = {
        'id': 'mem-db-2',
        'title': 'Road Trip',
        'content': 'Pacific Coast Highway',
        'type': 'memory',
        'created_at': DateTime.now().toIso8601String(),
        'people': [
          {
            'id': 'p-30',
            'user_id': 'u-1',
            'name': 'Elena',
          },
        ],
      };

      final memory = MemoryItem.fromRow(row);
      expect(memory.people.length, 1);
      expect(memory.people.first.name, 'Elena');
    });

    test('copyWith updates people accurately', () {
      final memory = MemoryItem(
        id: 'mem-3',
        title: 'Original Title',
        content: 'Original Content',
        type: 'memory',
        people: [PersonItem(id: 'p1', userId: 'u1', name: 'Alice')],
      );

      final p2 = PersonItem(id: 'p2', userId: 'u1', name: 'Bob');
      final updated = memory.copyWith(people: [p2]);

      expect(updated.people.length, 1);
      expect(updated.people.first.name, 'Bob');
      expect(updated.hasPerson('p1'), isFalse);
      expect(updated.hasPerson('p2'), isTrue);
    });

    test('toJson includes people list and people_names', () {
      final memory = MemoryItem(
        id: 'mem-4',
        title: 'Graduation',
        content: 'Finished college',
        type: 'memory',
        people: [
          PersonItem(id: 'p1', userId: 'u1', name: 'Alice'),
        ],
      );

      final json = memory.toJson();
      expect(json['people'], isA<List>());
      expect((json['people'] as List).length, 1);
      expect(json['people_names'], ['Alice']);
    });
  });
}
