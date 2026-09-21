import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/app_supabase.dart';
import '../core/supabase/supabase_errors.dart';
import '../models/account_item.dart';

abstract class AccountService {
  Future<List<AccountItem>> fetchAccounts();
  Future<AccountItem> addAccount(AccountItem item);
  Future<AccountItem> updateAccount(AccountItem item);

  /// Sets (not toggles) the favorite flag, so retrying or double-tapping can
  /// never leave the server and the screen disagreeing.
  Future<void> setFavorite(String id, bool isFavorite);
  Future<void> deleteAccount(String id);
}

/// [AccountService] backed by the `accounts` table. Row Level Security limits
/// every query to the signed-in user's own rows.
///
/// Only descriptive fields are stored (name, username, category, favorite).
/// There is no password column: see the note in the migration.
class AccountServiceImpl implements AccountService {
  final SupabaseClient _client;

  AccountServiceImpl({SupabaseClient? client})
      : _client = client ?? AppSupabase.client;

  @override
  Future<List<AccountItem>> fetchAccounts() {
    return guardBackend(() async {
      final rows = await _client
          .from('accounts')
          .select()
          .order('created_at', ascending: false);
      return rows.map(AccountItem.fromRow).toList();
    });
  }

  @override
  Future<AccountItem> addAccount(AccountItem item) {
    return guardBackend(() async {
      final row =
          await _client.from('accounts').insert(item.toInsertRow()).select().single();
      return AccountItem.fromRow(row);
    });
  }

  @override
  Future<AccountItem> updateAccount(AccountItem item) {
    return guardBackend(() async {
      final rows = await _client
          .from('accounts')
          .update(item.toUpdateRow())
          .eq('id', item.id)
          .select();
      requireAffected(rows);
      return AccountItem.fromRow(rows.first);
    });
  }

  @override
  Future<void> setFavorite(String id, bool isFavorite) {
    return guardBackend(() async {
      final rows = await _client
          .from('accounts')
          .update({'is_favorite': isFavorite})
          .eq('id', id)
          .select('id');
      requireAffected(rows);
    });
  }

  @override
  Future<void> deleteAccount(String id) {
    return guardBackend(() async {
      await _client.from('accounts').delete().eq('id', id);
    });
  }
}
