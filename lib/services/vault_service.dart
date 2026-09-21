import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/app_supabase.dart';
import '../core/supabase/client_extensions.dart';
import '../core/supabase/supabase_errors.dart';
import '../models/security_settings.dart';
import '../models/vault_summary.dart';

abstract class VaultService {
  Future<VaultSummary> fetchVaultSummary();
}

/// [VaultService] that builds the dashboard summary from the user's real data.
/// Row Level Security means each count only ever covers the caller's own rows.
class VaultServiceImpl implements VaultService {
  final SupabaseClient _client;

  VaultServiceImpl({SupabaseClient? client})
      : _client = client ?? AppSupabase.client;

  @override
  Future<VaultSummary> fetchVaultSummary() {
    return guardBackend(() async {
      final userId = _client.requireUser.id;

      // The builders only send their request when awaited, so gather them in
      // Future.wait to run the four queries at once.
      final results = await Future.wait<Object?>([
        _client.from('documents').select('file_size'),
        _client.from('accounts').select('id'),
        _client.from('trusted_contacts').select('id'),
        _client
            .from('security_settings')
            .select()
            .eq('user_id', userId)
            .maybeSingle(),
      ]);

      final documents = (results[0]! as List).cast<Map<String, dynamic>>();
      final accounts = results[1]! as List;
      final contacts = results[2]! as List;
      final settingsRow = results[3] as Map<String, dynamic>?;

      final storageBytes = documents.fold<int>(
        0,
        (sum, row) => sum + ((row['file_size'] as num?)?.toInt() ?? 0),
      );

      return VaultSummary.fromData(
        documents: documents.length,
        accounts: accounts.length,
        trustedContacts: contacts.length,
        storageBytes: storageBytes,
        settings: settingsRow == null
            ? const SecuritySettings()
            : SecuritySettings.fromRow(settingsRow),
      );
    });
  }
}
