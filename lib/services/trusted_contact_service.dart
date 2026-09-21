import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/app_supabase.dart';
import '../core/supabase/supabase_errors.dart';
import '../models/trusted_contact_item.dart';

abstract class TrustedContactService {
  Future<List<TrustedContactItem>> fetchContacts();
  Future<TrustedContactItem> addContact(TrustedContactItem contact);
  Future<void> removeContact(String id);
}

/// [TrustedContactService] backed by the `trusted_contacts` table. Row Level
/// Security limits every query to the signed-in user's own rows.
class TrustedContactServiceImpl implements TrustedContactService {
  final SupabaseClient _client;

  TrustedContactServiceImpl({SupabaseClient? client})
      : _client = client ?? AppSupabase.client;

  @override
  Future<List<TrustedContactItem>> fetchContacts() {
    return guardBackend(() async {
      final rows = await _client
          .from('trusted_contacts')
          .select()
          .order('created_at', ascending: true);
      return rows.map(TrustedContactItem.fromRow).toList();
    });
  }

  @override
  Future<TrustedContactItem> addContact(TrustedContactItem contact) {
    return guardBackend(() async {
      final row = await _client
          .from('trusted_contacts')
          .insert(contact.toInsertRow())
          .select()
          .single();
      return TrustedContactItem.fromRow(row);
    });
  }

  @override
  Future<void> removeContact(String id) {
    return guardBackend(() async {
      await _client.from('trusted_contacts').delete().eq('id', id);
    });
  }
}
