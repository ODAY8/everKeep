import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/app_supabase.dart';
import '../core/supabase/client_extensions.dart';
import '../core/supabase/supabase_errors.dart';
import '../models/security_settings.dart';

abstract class SettingsService {
  Future<SecuritySettings> fetchSecuritySettings();
  Future<void> updateSecuritySettings(SecuritySettings settings);
}

/// [SettingsService] backed by the `security_settings` table: one row per user,
/// created at sign-up and readable/writable only by its owner.
class SettingsServiceImpl implements SettingsService {
  final SupabaseClient _client;

  SettingsServiceImpl({SupabaseClient? client})
      : _client = client ?? AppSupabase.client;

  @override
  Future<SecuritySettings> fetchSecuritySettings() {
    return guardBackend(() async {
      final row = await _client
          .from('security_settings')
          .select()
          .eq('user_id', _client.requireUser.id)
          .maybeSingle();

      // No row yet just means nothing has been changed: everything is off.
      return row == null ? const SecuritySettings() : SecuritySettings.fromRow(row);
    });
  }

  @override
  Future<void> updateSecuritySettings(SecuritySettings settings) {
    return guardBackend(() async {
      await _client.from('security_settings').upsert({
        'user_id': _client.requireUser.id,
        ...settings.toRow(),
      }, onConflict: 'user_id');
    });
  }
}
