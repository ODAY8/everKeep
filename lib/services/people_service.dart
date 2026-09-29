import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/app_supabase.dart';
import '../core/supabase/client_extensions.dart';
import '../core/supabase/supabase_errors.dart';
import '../models/person_item.dart';

abstract class PeopleService {
  /// Fetches all people created by the current user, ordered alphabetically.
  Future<List<PersonItem>> fetchPeople();

  /// Creates a new person or returns an existing one if a case-insensitive name match exists.
  Future<PersonItem> createPerson(String name);

  /// Renames an existing person.
  Future<PersonItem> updatePerson(String id, String newName);

  /// Deletes a person and cascades removal from memory associations.
  Future<void> deletePerson(String id);

  /// Fetches all people associated with a specific memory.
  Future<List<PersonItem>> fetchPeopleForMemory(String memoryId);

  /// Synchronizes the set of people associated with a memory.
  Future<void> setMemoryPeople(String memoryId, List<String> personIds);
}

class PeopleServiceImpl implements PeopleService {
  final SupabaseClient _client;

  PeopleServiceImpl({SupabaseClient? client})
      : _client = client ?? AppSupabase.client;

  @override
  Future<List<PersonItem>> fetchPeople() {
    return guardBackend(() async {
      try {
        final rows = await _client
            .from('people')
            .select()
            .order('name', ascending: true);
        return rows.map(PersonItem.fromRow).toList();
      } catch (_) {
        // Fallback when migration has not been applied remotely yet
        return const [];
      }
    });
  }

  @override
  Future<PersonItem> createPerson(String name) {
    return guardBackend(() async {
      final validation = PersonItem.validateName(name);
      if (validation != null) {
        throw BackendException(validation);
      }
      final cleanName = PersonItem.sanitizeName(name);
      final user = _client.requireUser;

      // Check if a person with the same name already exists for this user (case-insensitive)
      try {
        final existing = await _client
            .from('people')
            .select()
            .ilike('name', cleanName);

        if (existing.isNotEmpty) {
          return PersonItem.fromRow(existing.first);
        }
      } catch (_) {
        // Fall through to insert if table exists
      }

      final inserted = await _client
          .from('people')
          .insert({
            'name': cleanName,
            'user_id': user.id,
          })
          .select()
          .single();

      return PersonItem.fromRow(inserted);
    });
  }

  @override
  Future<PersonItem> updatePerson(String id, String newName) {
    return guardBackend(() async {
      final validation = PersonItem.validateName(newName);
      if (validation != null) {
        throw BackendException(validation);
      }
      final cleanName = PersonItem.sanitizeName(newName);

      final rows = await _client
          .from('people')
          .update({'name': cleanName})
          .eq('id', id)
          .select();

      requireAffected(rows);
      return PersonItem.fromRow(rows.first);
    });
  }

  @override
  Future<void> deletePerson(String id) {
    return guardBackend(() async {
      await _client.from('people').delete().eq('id', id);
    });
  }

  @override
  Future<List<PersonItem>> fetchPeopleForMemory(String memoryId) {
    return guardBackend(() async {
      try {
        final rows = await _client
            .from('memory_people')
            .select('person_id, people(*)')
            .eq('memory_id', memoryId);

        return rows
            .map((r) => r['people'])
            .whereType<Map<String, dynamic>>()
            .map(PersonItem.fromRow)
            .toList();
      } catch (_) {
        return const [];
      }
    });
  }

  @override
  Future<void> setMemoryPeople(String memoryId, List<String> personIds) {
    return guardBackend(() async {
      final user = _client.requireUser;

      try {
        // 1. Delete existing associations for this memory
        await _client
            .from('memory_people')
            .delete()
            .eq('memory_id', memoryId);

        // 2. Insert unique new associations
        final uniqueIds = personIds.toSet().toList();
        if (uniqueIds.isNotEmpty) {
          final rows = uniqueIds.map((pid) => {
            'memory_id': memoryId,
            'person_id': pid,
            'user_id': user.id,
          }).toList();

          await _client.from('memory_people').insert(rows);
        }
      } catch (_) {
        // Graceful fallback if tables do not exist remotely yet
      }
    });
  }
}
