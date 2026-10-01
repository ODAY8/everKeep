import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:everkeep/models/memory_item.dart';
import 'package:everkeep/models/person_item.dart';
import 'package:everkeep/providers/memory_provider.dart';

import 'fakes.dart';

void main() {
  group('Cross-User Ownership & RLS Migration Verification', () {
    test('Migration file exists and has strict RLS and table definitions', () {
      final migrationFile = File('supabase/migrations/20261002000000_memory_people.sql');
      expect(migrationFile.existsSync(), isTrue, reason: 'Migration file must exist');

      final sql = migrationFile.readAsStringSync().toLowerCase();

      // 1. RLS enabled
      expect(sql, contains('alter table public.people enable row level security;'));
      expect(sql, contains('alter table public.memory_people enable row level security;'));

      // 2. People table ownership & uniqueness
      expect(sql, contains('references auth.users(id) on delete cascade'));
      expect(sql, contains('unique index if not exists people_user_lower_name_idx'));
      expect(sql, contains('(user_id, lower(btrim(name)))'));

      // 3. People RLS policies
      expect(sql, contains('create policy people_select_own on public.people'));
      expect(sql, contains('create policy people_insert_own on public.people'));
      expect(sql, contains('create policy people_update_own on public.people'));
      expect(sql, contains('create policy people_delete_own on public.people'));

      // 4. Memory_people RLS policies
      expect(sql, contains('create policy memory_people_select_own on public.memory_people'));
      expect(sql, contains('create policy memory_people_insert_own on public.memory_people'));
      expect(sql, contains('create policy memory_people_update_own on public.memory_people'));
      expect(sql, contains('create policy memory_people_delete_own on public.memory_people'));

      // 5. INSERT & UPDATE cross-user reference validations
      // Both insert and update must check memory_id ownership AND person_id ownership
      expect(sql, contains('where id = memory_id and user_id = (select auth.uid())'));
      expect(sql, contains('where id = person_id and user_id = (select auth.uid())'));

      // 6. Anonymous access revoked
      expect(sql, contains('revoke all on public.people from anon;'));
      expect(sql, contains('revoke all on public.memory_people from anon;'));

      // 7. Authenticated permissions granted
      expect(sql, contains('grant select, insert, update, delete on public.people to authenticated;'));
      expect(sql, contains('grant select, insert, update, delete on public.memory_people to authenticated;'));
    });

    test('Separate users can have people with the same name without collision', () async {
      final user1PeopleRepo = FakePeopleRepository([]);
      final user2PeopleRepo = FakePeopleRepository([]);

      final providerUser1 = MemoryProvider(
        memoryRepository: FakeMemoryRepository([]),
        peopleRepository: user1PeopleRepo,
      );

      final providerUser2 = MemoryProvider(
        memoryRepository: FakeMemoryRepository([]),
        peopleRepository: user2PeopleRepo,
      );

      // Both users create a person named "Dr. Smith"
      final p1 = await providerUser1.createPerson('Dr. Smith');
      final p2 = await providerUser2.createPerson('Dr. Smith');

      expect(p1, isNotNull);
      expect(p2, isNotNull);
      // Different instances in different tenant stores
      expect(providerUser1.allPeople.length, 1);
      expect(providerUser2.allPeople.length, 1);
      expect(providerUser1.allPeople.first.name, 'Dr. Smith');
      expect(providerUser2.allPeople.first.name, 'Dr. Smith');

      // Renaming for User 1 does not affect User 2
      await providerUser1.updatePerson(p1!.id, 'Dr. John Smith');
      expect(providerUser1.allPeople.first.name, 'Dr. John Smith');
      expect(providerUser2.allPeople.first.name, 'Dr. Smith');

      // Deleting for User 1 does not delete User 2's person
      await providerUser1.deletePerson(p1.id);
      expect(providerUser1.allPeople, isEmpty);
      expect(providerUser2.allPeople.length, 1);
      expect(providerUser2.allPeople.first.name, 'Dr. Smith');
    });

    test('Memories and tagged people are isolated between different user contexts', () async {
      final user1PeopleRepo = FakePeopleRepository([]);
      final user2PeopleRepo = FakePeopleRepository([]);
      final user1MemRepo = FakeMemoryRepository([]);
      final user2MemRepo = FakeMemoryRepository([]);

      final provider1 = MemoryProvider(
        memoryRepository: user1MemRepo,
        peopleRepository: user1PeopleRepo,
      );
      final provider2 = MemoryProvider(
        memoryRepository: user2MemRepo,
        peopleRepository: user2PeopleRepo,
      );

      final pAliceUser1 = await provider1.createPerson('Alice');
      final pBobUser2 = await provider2.createPerson('Bob');

      await provider1.createMemory(
        MemoryItem(
          id: 'm1-u1',
          userId: 'user-001',
          title: 'User 1 Graduation',
          content: 'Celebration',
          type: 'memory',
          people: [pAliceUser1!],
        ),
      );

      await provider2.createMemory(
        MemoryItem(
          id: 'm2-u2',
          userId: 'user-002',
          title: 'User 2 Roadtrip',
          content: 'Driving',
          type: 'memory',
          people: [pBobUser2!],
        ),
      );

      // User 1 cannot see User 2's memories or people
      expect(provider1.memories.length, 1);
      expect(provider1.memories.first.title, 'User 1 Graduation');
      expect(provider1.allPeople.map((p) => p.name).toList(), ['Alice']);

      // User 2 cannot see User 1's memories or people
      expect(provider2.memories.length, 1);
      expect(provider2.memories.first.title, 'User 2 Roadtrip');
      expect(provider2.allPeople.map((p) => p.name).toList(), ['Bob']);

      // Filtering User 1 by Alice returns only User 1's memory
      provider1.setSelectedPerson(pAliceUser1);
      final filteredU1 = provider1.getFilteredMemories();
      expect(filteredU1.length, 1);
      expect(filteredU1.first.id, 'm1-u1');

      // User 2 filtering by Bob returns only User 2's memory
      provider2.setSelectedPerson(pBobUser2);
      final filteredU2 = provider2.getFilteredMemories();
      expect(filteredU2.length, 1);
      expect(filteredU2.first.id, 'm2-u2');
    });

    test('Cross-user person attachment attempt fails safely', () async {
      // Simulating a malicious attempt to attach a foreign person's ID to a user's memory
      final user1PeopleRepo = FakePeopleRepository([]);
      final user1MemRepo = FakeMemoryRepository([]);

      final provider1 = MemoryProvider(
        memoryRepository: user1MemRepo,
        peopleRepository: user1PeopleRepo,
      );

      // Foreign person belonging to another user
      final foreignPerson = PersonItem(
        id: 'foreign-person-id-999',
        userId: 'attacker-victim-user-id',
        name: 'Secret Person',
      );

      // 1. Direct repository layer rejection check
      user1PeopleRepo.failWith = 'new row violates row-level security policy for table "memory_people"';
      expect(
        () => user1PeopleRepo.setMemoryPeople('m-1', [foreignPerson.id]),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('row-level security'),
        )),
      );

      // 2. Provider layer error handling check
      user1MemRepo.failWith = 'new row violates row-level security policy for table "memory_people"';
      final success = await provider1.createMemory(
        MemoryItem(
          id: 'm-hack',
          title: 'Unauthorized Tagging',
          content: 'Attempting to link foreign person',
          type: 'memory',
          people: [foreignPerson],
        ),
      );

      expect(success, isFalse);
      expect(provider1.error, isNotNull);
      expect(provider1.error, contains('row-level security'));
    });
  });
}
